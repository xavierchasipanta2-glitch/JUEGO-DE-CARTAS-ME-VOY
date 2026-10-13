/**
 * Cloud Functions para «Me Voy — Banco Virtual Multijugador»
 *
 * Implementa la validación financiera en servidor, transacciones atómicas en Firestore,
 * control de idempotencia, motor determinista de cálculo de premios y protección de saldos.
 *
 * IMPORTANTE: El servidor NUNCA confía en importes netos enviados por el cliente.
 * Recalcula las obligaciones a partir de las tarifas de la mesa y valida permisos y saldos.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

/**
 * Motor determinista de cálculo en el servidor (espejo exacto de SettlementEngine en Dart).
 */
function calculateRoundServerSide(roundId, roundNumber, tariffs, inputs) {
  if (!Array.isArray(inputs) || inputs.length < 2 || inputs.length > 4) {
    throw new HttpsError(
      "invalid-argument",
      "La partida debe tener entre 2 y 4 participantes activos."
    );
  }

  const winners = inputs.filter((p) => p.isWinner === true);
  if (winners.length !== 1) {
    throw new HttpsError(
      "invalid-argument",
      "Debe existir exactamente 1 ganador de la mesa por partida."
    );
  }

  let totalAces = 0;
  let totalKings = 0;

  for (const p of inputs) {
    if (
      p.acesCount < 0 ||
      p.kingsCount < 0 ||
      p.rusosCount < 0 ||
      p.patasCount < 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        `Cantidades negativas no permitidas para ${p.displayName}.`
      );
    }
    if (p.rusosCount > (tariffs.maxRusosPerPlayer ?? 6)) {
      throw new HttpsError(
        "invalid-argument",
        `${p.displayName} excede el máximo de Rusos permitidos.`
      );
    }
    if (p.patasCount > (tariffs.maxPatasPerPlayer ?? 6)) {
      throw new HttpsError(
        "invalid-argument",
        `${p.displayName} excede el máximo de Patas permitidas.`
      );
    }
    totalAces += p.acesCount;
    totalKings += p.kingsCount;
  }

  if (totalAces > (tariffs.maxAcesPerRound ?? 8)) {
    throw new HttpsError(
      "invalid-argument",
      `El total de Ases (${totalAces}) supera el límite del mazo.`
    );
  }
  if (totalKings > (tariffs.maxKingsPerRound ?? 8)) {
    throw new HttpsError(
      "invalid-argument",
      `El total de K (${totalKings}) supera el límite del mazo.`
    );
  }

  const n = inputs.length;
  const rivalsCount = n - 1;
  const grossBreakdowns = [];
  const grossByPlayerId = {};

  for (const input of inputs) {
    const cardPrizePerRivalCents =
      input.acesCount * tariffs.aceCents +
      input.kingsCount * tariffs.kingCents +
      input.rusosCount * tariffs.rusoCents +
      input.patasCount * tariffs.patasCents;
    const tablePrizePerRivalCents = input.isWinner ? tariffs.tableWinCents : 0;
    const totalClaimPerRivalCents =
      cardPrizePerRivalCents + tablePrizePerRivalCents;

    const breakdown = {
      playerId: input.playerId,
      displayName: input.displayName,
      rivalsCount,
      cardPrizePerRivalCents,
      tablePrizePerRivalCents,
      totalClaimPerRivalCents,
      grossCardPrizeTotalCents: cardPrizePerRivalCents * rivalsCount,
      grossTablePrizeTotalCents: tablePrizePerRivalCents * rivalsCount,
      grossTotalCents: totalClaimPerRivalCents * rivalsCount,
    };
    grossBreakdowns.push(breakdown);
    grossByPlayerId[input.playerId] = breakdown;
  }

  const rawPairwiseObligations = [];
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      if (i === j) continue;
      const debtor = inputs[i];
      const creditor = inputs[j];
      const cg = grossByPlayerId[creditor.playerId];
      rawPairwiseObligations.push({
        debtorId: debtor.playerId,
        debtorName: debtor.displayName,
        creditorId: creditor.playerId,
        creditorName: creditor.displayName,
        cardAmountCents: cg.cardPrizePerRivalCents,
        tableWinAmountCents: cg.tablePrizePerRivalCents,
        totalAmountCents: cg.totalClaimPerRivalCents,
      });
    }
  }

  const bilateralCompensations = [];
  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      const playerA = inputs[i];
      const playerB = inputs[j];
      const aOwesB = grossByPlayerId[playerB.playerId].totalClaimPerRivalCents;
      const bOwesA = grossByPlayerId[playerA.playerId].totalClaimPerRivalCents;
      const compensatedCents = Math.min(aOwesB, bOwesA);
      const diff = aOwesB - bOwesA;
      const netAmountCents = Math.abs(diff);

      bilateralCompensations.push({
        playerAId: playerA.playerId,
        playerAName: playerA.displayName,
        playerBId: playerB.playerId,
        playerBName: playerB.displayName,
        obligationAToBCents: aOwesB,
        obligationBToACents: bOwesA,
        compensatedCents,
        netDebtorId: diff > 0 ? playerA.playerId : diff < 0 ? playerB.playerId : null,
        netDebtorName:
          diff > 0 ? playerA.displayName : diff < 0 ? playerB.displayName : null,
        netCreditorId:
          diff > 0 ? playerB.playerId : diff < 0 ? playerA.playerId : null,
        netCreditorName:
          diff > 0 ? playerB.displayName : diff < 0 ? playerA.displayName : null,
        netAmountCents,
      });
    }
  }

  const netBalancesByPlayerCents = {};
  let sumOfNets = 0;
  for (const p of inputs) {
    const grossEarned = grossByPlayerId[p.playerId].grossTotalCents;
    let totalOwed = 0;
    for (const r of inputs) {
      if (r.playerId === p.playerId) continue;
      totalOwed += grossByPlayerId[r.playerId].totalClaimPerRivalCents;
    }
    const net = grossEarned - totalOwed;
    netBalancesByPlayerCents[p.playerId] = net;
    sumOfNets += net;
  }

  if (sumOfNets !== 0) {
    throw new HttpsError(
      "internal",
      `Violación de suma cero en servidor: sum=${sumOfNets}`
    );
  }

  // Optimización global de liquidación
  const namesById = {};
  for (const p of inputs) namesById[p.playerId] = p.displayName;

  const sortedIds = Object.keys(netBalancesByPlayerCents).sort();
  const debtors = [];
  const creditors = [];
  for (const pid of sortedIds) {
    const net = netBalancesByPlayerCents[pid];
    if (net < 0) debtors.push({ playerId: pid, remainingCents: -net });
    else if (net > 0) creditors.push({ playerId: pid, remainingCents: net });
  }

  const optimizedSettlementPlan = [];
  let stepIndex = 1;

  // Paso 1: Emparejamiento exacto
  for (const d of debtors) {
    if (d.remainingCents === 0) continue;
    for (const c of creditors) {
      if (c.remainingCents === 0) continue;
      if (d.remainingCents === c.remainingCents) {
        optimizedSettlementPlan.push({
          itemId: `tr_${roundId}_${stepIndex}`,
          index: stepIndex,
          fromPlayerId: d.playerId,
          fromPlayerName: namesById[d.playerId],
          toPlayerId: c.playerId,
          toPlayerName: namesById[c.playerId],
          amountCents: d.remainingCents,
          status: "pending",
          ledgerTransactionId: null,
          settledAt: null,
        });
        d.remainingCents = 0;
        c.remainingCents = 0;
        stepIndex++;
        break;
      }
    }
  }

  // Paso 2: Emparejamiento voraz determinista
  while (true) {
    const activeDebtors = debtors.filter((d) => d.remainingCents > 0);
    const activeCreditors = creditors.filter((c) => c.remainingCents > 0);
    if (activeDebtors.length === 0 || activeCreditors.length === 0) break;

    activeDebtors.sort(
      (a, b) =>
        b.remainingCents - a.remainingCents ||
        a.playerId.localeCompare(b.playerId)
    );
    activeCreditors.sort(
      (a, b) =>
        b.remainingCents - a.remainingCents ||
        a.playerId.localeCompare(b.playerId)
    );

    const topD = activeDebtors[0];
    const topC = activeCreditors[0];
    const amount = Math.min(topD.remainingCents, topC.remainingCents);

    optimizedSettlementPlan.push({
      itemId: `tr_${roundId}_${stepIndex}`,
      index: stepIndex,
      fromPlayerId: topD.playerId,
      fromPlayerName: namesById[topD.playerId],
      toPlayerId: topC.playerId,
      toPlayerName: namesById[topC.playerId],
      amountCents: amount,
      status: "pending",
      ledgerTransactionId: null,
      settledAt: null,
    });

    topD.remainingCents -= amount;
    topC.remainingCents -= amount;
    stepIndex++;
  }

  const canonicalPayload = JSON.stringify({
    roundId,
    roundNumber,
    tariffs: {
      tableWinCents: tariffs.tableWinCents,
      aceCents: tariffs.aceCents,
      kingCents: tariffs.kingCents,
      rusoCents: tariffs.rusoCents,
      patasCents: tariffs.patasCents,
    },
    inputs,
    netBalances: netBalancesByPlayerCents,
    settlementPlan: optimizedSettlementPlan.map((e) => ({
      from: e.fromPlayerId,
      to: e.toPlayerId,
      amountCents: e.amountCents,
    })),
  });

  const auditChecksum = crypto
    .createHash("sha256")
    .update(canonicalPayload)
    .digest("hex")
    .substring(0, 16);

  return {
    calculationId: `calc_${roundId}_${auditChecksum}`,
    roundId,
    roundNumber,
    tariffSnapshot: { ...tariffs },
    playerInputs: inputs,
    grossBreakdowns,
    rawPairwiseObligations,
    bilateralCompensations,
    netBalancesByPlayerCents,
    sumOfNetBalancesCents: 0,
    optimizedSettlementPlan,
    auditChecksum,
    calculatedAt: new Date().toISOString(),
  };
}

/**
 * 1. Ejecutar Liquidación Atómica de Partida (executeRoundSettlement)
 */
exports.executeRoundSettlement = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "El usuario debe iniciar sesión.");
  }

  const callerUid = request.auth.uid;
  const { tableId, roundId, allowPendingIfInsufficient } = request.data;

  if (!tableId || !roundId) {
    throw new HttpsError(
      "invalid-argument",
      "Faltan parámetros requeridos (tableId, roundId)."
    );
  }

  const tableRef = db.collection("tables").doc(tableId);

  return db.runTransaction(async (transaction) => {
    const tableSnap = await transaction.get(tableRef);
    if (!tableSnap.exists) {
      throw new HttpsError("not-found", "La mesa no existe.");
    }

    const table = tableSnap.data();
    if (table.adminUserId !== callerUid) {
      throw new HttpsError(
        "permission-denied",
        "Solo el administrador de la mesa puede ejecutar la liquidación."
      );
    }

    const settlementId = `stl_${roundId}`;
    const processedKeys = table.processedIdempotencyKeys || [];
    if (processedKeys.includes(settlementId)) {
      throw new HttpsError(
        "already-exists",
        "Esta partida ya fue liquidada anteriormente (operación idempotente)."
      );
    }

    const currentRound = table.currentRound;
    if (!currentRound || currentRound.roundId !== roundId) {
      throw new HttpsError(
        "failed-precondition",
        "La ronda indicada no coincide con la partida activa."
      );
    }

    // Recalcular en servidor para no confiar jamás en importes manipulados por el cliente
    const inputsList = Object.values(currentRound.playerInputs || {});
    const calcResult = calculateRoundServerSide(
      roundId,
      currentRound.roundNumber,
      currentRound.tariffSnapshot,
      inputsList
    );

    const participants = { ...table.participants };
    const ledgerEntries = [...(table.ledgerEntries || [])];
    const nowIso = new Date().toISOString();

    // Verificar si todos los deudores tienen saldo suficiente
    let allDebtorsHaveBalance = true;
    for (const [pid, netCents] of Object.entries(
      calcResult.netBalancesByPlayerCents
    )) {
      if (netCents < 0) {
        const needed = -netCents;
        const player = participants[pid];
        if (!player || player.availableBalanceCents < needed) {
          allDebtorsHaveBalance = false;
          break;
        }
      }
    }

    if (!allDebtorsHaveBalance && !allowPendingIfInsufficient) {
      throw new HttpsError(
        "failed-precondition",
        "Uno o más deudores no tienen créditos disponibles suficientes. Recargue créditos o habilite liquidación con deuda pendiente verificable."
      );
    }

    // Contabilizar ganancias y pérdidas acumuladas de la sesión UNA SOLA VEZ
    if (!currentRound.sessionPnlAccounted) {
      for (const input of inputsList) {
        const pid = input.playerId;
        const net = calcResult.netBalancesByPlayerCents[pid] || 0;
        const p = { ...participants[pid] };
        if (net > 0) {
          p.accumulatedWinningsCents = (p.accumulatedWinningsCents || 0) + net;
        } else if (net < 0) {
          p.accumulatedLossesCents = (p.accumulatedLossesCents || 0) + -net;
        }
        if (input.isWinner) {
          p.roundsWon = (p.roundsWon || 0) + 1;
        }
        p.lastUpdatedAt = nowIso;
        participants[pid] = p;
      }
    }

    const updatedPlan = [];
    for (const item of calcResult.optimizedSettlementPlan) {
      const debtor = { ...participants[item.fromPlayerId] };
      const creditor = { ...participants[item.toPlayerId] };

      if (
        allDebtorsHaveBalance ||
        debtor.availableBalanceCents >= item.amountCents
      ) {
        const txId = `tx_${roundId}_${item.index}`;
        debtor.availableBalanceCents -= item.amountCents;
        creditor.availableBalanceCents += item.amountCents;
        debtor.lastUpdatedAt = nowIso;
        creditor.lastUpdatedAt = nowIso;

        participants[debtor.playerId] = debtor;
        participants[creditor.playerId] = creditor;

        ledgerEntries.unshift({
          entryId: txId,
          idempotencyKey: `${settlementId}_${item.index}`,
          tableId,
          roundId,
          roundNumber: currentRound.roundNumber,
          type: "roundSettlementTransfer",
          fromAccountId: debtor.playerId,
          fromAccountName: debtor.displayName,
          toAccountId: creditor.playerId,
          toAccountName: creditor.displayName,
          amountCents: item.amountCents,
          createdAt: nowIso,
          status: "completed",
          reason: `Liquidación Partida #${currentRound.roundNumber}`,
          authorizedByUserId: callerUid,
          authorizedByUserName: table.adminDisplayName,
          calculationReferenceId: calcResult.calculationId,
        });

        updatedPlan.push({
          ...item,
          status: "settledInternalCredits",
          ledgerTransactionId: txId,
          settledAt: nowIso,
        });
      } else {
        // Registrar como obligación pendiente de pago / cobro sin permitir saldo negativo
        debtor.pendingDebtsCents =
          (debtor.pendingDebtsCents || 0) + item.amountCents;
        creditor.pendingPrizesCents =
          (creditor.pendingPrizesCents || 0) + item.amountCents;
        participants[debtor.playerId] = debtor;
        participants[creditor.playerId] = creditor;

        updatedPlan.push({
          ...item,
          status: "pending",
        });
      }
    }

    const hasPending = updatedPlan.some((i) => i.status === "pending");
    const updatedRound = {
      ...currentRound,
      status: hasPending ? "partiallySettledPending" : "closed",
      calculationResult: {
        ...calcResult,
        optimizedSettlementPlan: updatedPlan,
      },
      settlementId,
      sessionPnlAccounted: true,
      closedAt: hasPending ? null : nowIso,
    };

    const completedRounds = [...(table.completedRounds || [])];
    if (!hasPending) {
      completedRounds.unshift(updatedRound);
    }

    transaction.update(tableRef, {
      participants,
      ledgerEntries,
      currentRound: hasPending ? updatedRound : null,
      completedRounds,
      status: hasPending ? "settlingRound" : "inProgress",
      processedIdempotencyKeys: [...processedKeys, settlementId],
      version: (table.version || 1) + 1,
      updatedAt: nowIso,
    });

    return {
      status: "ok",
      settlementId,
      hasPending,
    };
  });
});

/**
 * 2. Aprobar o Rechazar Solicitud de Recarga (resolveRechargeRequest)
 */
exports.resolveRechargeRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "El usuario debe iniciar sesión.");
  }

  const callerUid = request.auth.uid;
  const { tableId, requestId, approve, reason } = request.data;

  const tableRef = db.collection("tables").doc(tableId);

  return db.runTransaction(async (transaction) => {
    const tableSnap = await transaction.get(tableRef);
    if (!tableSnap.exists) {
      throw new HttpsError("not-found", "La mesa no existe.");
    }

    const table = tableSnap.data();
    if (table.adminUserId !== callerUid) {
      throw new HttpsError(
        "permission-denied",
        "Solo el administrador del banco puede aprobar o rechazar recargas."
      );
    }

    const idempotencyKey = `recharge_${requestId}`;
    const processedKeys = table.processedIdempotencyKeys || [];
    if (processedKeys.includes(idempotencyKey)) {
      throw new HttpsError(
        "already-exists",
        "Esta solicitud de recarga ya fue procesada."
      );
    }

    const requests = [...(table.rechargeRequests || [])];
    const reqIdx = requests.findIndex((r) => r.requestId === requestId);
    if (reqIdx === -1 || requests[reqIdx].status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        "La solicitud de recarga no existe o ya no está pendiente."
      );
    }

    const reqItem = { ...requests[reqIdx] };
    const nowIso = new Date().toISOString();
    const participants = { ...table.participants };
    const ledgerEntries = [...(table.ledgerEntries || [])];

    if (approve) {
      const player = { ...participants[reqItem.playerId] };
      const txId = `tx_rec_${requestId}`;

      // Actualizar saldo disponible y total de recargas (NUNCA ganancias de juego)
      player.availableBalanceCents =
        (player.availableBalanceCents || 0) + reqItem.amountCents;
      player.totalRechargesCents =
        (player.totalRechargesCents || 0) + reqItem.amountCents;
      player.lastUpdatedAt = nowIso;
      participants[reqItem.playerId] = player;

      ledgerEntries.unshift({
        entryId: txId,
        idempotencyKey,
        tableId,
        roundId: null,
        roundNumber: null,
        type: "approvedRecharge",
        fromAccountId: "BANK",
        fromAccountName: "Banco Virtual",
        toAccountId: player.playerId,
        toAccountName: player.displayName,
        amountCents: reqItem.amountCents,
        createdAt: nowIso,
        status: "completed",
        reason: reason || reqItem.note || "Recarga aprobada por el banco",
        authorizedByUserId: callerUid,
        authorizedByUserName: table.adminDisplayName,
        calculationReferenceId: requestId,
      });

      reqItem.status = "approved";
      reqItem.ledgerEntryId = txId;
    } else {
      reqItem.status = "rejected";
    }

    reqItem.resolvedAt = nowIso;
    reqItem.resolvedByUserId = callerUid;
    reqItem.resolvedByUserName = table.adminDisplayName;
    reqItem.resolutionReason = reason || "";
    requests[reqIdx] = reqItem;

    transaction.update(tableRef, {
      participants,
      ledgerEntries,
      rechargeRequests: requests,
      processedIdempotencyKeys: [...processedKeys, idempotencyKey],
      version: (table.version || 1) + 1,
      updatedAt: nowIso,
    });

    return { status: reqItem.status };
  });
});
