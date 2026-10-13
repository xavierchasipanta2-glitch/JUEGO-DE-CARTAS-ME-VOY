import 'package:flutter/material.dart';
import '../../models/round_models.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/money_badge.dart';
import 'bank_admin_tab.dart';
import 'history_tab.dart';
import 'personal_balance_tab.dart';
import 'prize_entry_tab.dart';
import 'recharge_tab.dart';
import 'settings_tab.dart';
import 'settlement_tab.dart';
import 'shared_table_tab.dart';

/// Contenedor principal de navegación para la mesa activa (Pantallas 3 a 10).
class HomeShellScreen extends StatefulWidget {
  final AppController controller;

  const HomeShellScreen({super.key, required this.controller});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _selectedIndex = 0;

  void _navigateToTab(int idx) {
    setState(() {
      _selectedIndex = idx.clamp(0, 7);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final table = ctrl.activeTable!;
    final players = table.sortedParticipants;
    final activePlayer =
        table.participants[ctrl.effectivePlayerId] ?? players.first;
    final pendingRecharges = table.pendingRechargeRequestsCount;
    final hasRoundReadyToSettle = table.currentRound != null &&
        table.currentRound!.status != RoundStatus.collectingPrizes;

    final tabs = <Widget>[
      SharedTableTab(
        controller: ctrl,
        onNavigateToTab: _navigateToTab,
      ),
      PersonalBalanceTab(
        controller: ctrl,
        onGoToRecharge: () => _navigateToTab(4),
      ),
      PrizeEntryTab(
        controller: ctrl,
        onCalculatedSuccess: () => _navigateToTab(3),
      ),
      SettlementTab(
        controller: ctrl,
        onGoToPrizeEntry: () => _navigateToTab(2),
        onGoToBankAdmin: () => _navigateToTab(6),
      ),
      RechargeTab(controller: ctrl),
      HistoryTab(controller: ctrl),
      BankAdminTab(controller: ctrl),
      SettingsTab(controller: ctrl),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'ME VOY',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: MeVoyTheme.goldAccent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'CÓDIGO: ${table.inviteCode}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: MeVoyTheme.goldSoft,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Jugador activo: ${activePlayer.displayName} (Disp: ${MoneyFormatter.formatCents(activePlayer.availableBalanceCents)})',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
        actions: [
          // Selector rápido de perspectiva entre los jugadores sentados
          PopupMenuButton<String>(
            tooltip: 'Cambiar jugador activo',
            onSelected: (pid) {
              ctrl.setActingPlayerOverride(pid);
            },
            itemBuilder: (ctx) {
              return players.map((p) {
                final isSelected = p.playerId == activePlayer.playerId;
                return PopupMenuItem<String>(
                  value: p.playerId,
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 18,
                        color:
                            isSelected ? MeVoyTheme.goldAccent : Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Asiento ${p.seatNumber}: ${p.displayName} ${p.isAdmin ? "(Admin)" : ""}',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        MoneyFormatter.formatCents(p.availableBalanceCents),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: MeVoyTheme.goldAccent,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(
                  Icons.switch_account_rounded,
                  size: 16,
                  color: MeVoyTheme.goldAccent,
                ),
                label: Text(
                  'Asiento ${activePlayer.seatNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF061B14),
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: [
                _NavPill(
                  index: 0,
                  selectedIndex: _selectedIndex,
                  icon: Icons.table_restaurant_rounded,
                  label: 'Mesa (${players.length}/4)',
                  onTap: _navigateToTab,
                ),
                _NavPill(
                  index: 1,
                  selectedIndex: _selectedIndex,
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Mi Saldo',
                  hasAlert: activePlayer.hasLowOrInsufficientBalance ||
                      activePlayer.hasPendingDebts,
                  onTap: _navigateToTab,
                ),
                _NavPill(
                  index: 2,
                  selectedIndex: _selectedIndex,
                  icon: Icons.emoji_events_rounded,
                  label: 'Premios',
                  onTap: _navigateToTab,
                ),
                _NavPill(
                  index: 3,
                  selectedIndex: _selectedIndex,
                  icon: Icons.receipt_long_rounded,
                  label: 'Liquidación',
                  hasAlert: hasRoundReadyToSettle,
                  onTap: _navigateToTab,
                ),
                _NavPill(
                  index: 4,
                  selectedIndex: _selectedIndex,
                  icon: Icons.add_card_rounded,
                  label: 'Recarga',
                  onTap: _navigateToTab,
                ),
                _NavPill(
                  index: 5,
                  selectedIndex: _selectedIndex,
                  icon: Icons.history_edu_rounded,
                  label: 'Historial',
                  onTap: _navigateToTab,
                ),
                _NavPill(
                  index: 6,
                  selectedIndex: _selectedIndex,
                  icon: Icons.account_balance_rounded,
                  label: pendingRecharges > 0
                      ? 'Banco ($pendingRecharges)'
                      : 'Banco',
                  hasAlert: pendingRecharges > 0,
                  onTap: _navigateToTab,
                ),
                _NavPill(
                  index: 7,
                  selectedIndex: _selectedIndex,
                  icon: Icons.settings_rounded,
                  label: 'Configuración',
                  onTap: _navigateToTab,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Mensajes de estado o alertas operativas
          if (ctrl.errorMessage != null)
            MaterialBanner(
              backgroundColor: MeVoyTheme.debtNegative.withValues(alpha: 0.2),
              leading: const Icon(
                Icons.error_outline_rounded,
                color: MeVoyTheme.debtNegative,
              ),
              content: Text(
                ctrl.errorMessage!,
                style: const TextStyle(fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: ctrl.clearMessages,
                  child: const Text('Cerrar'),
                ),
              ],
            )
          else if (ctrl.successMessage != null)
            Container(
              width: double.infinity,
              color: MeVoyTheme.creditPositive.withValues(alpha: 0.16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: MeVoyTheme.creditPositive,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ctrl.successMessage!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: ctrl.clearMessages,
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),

          Expanded(child: tabs[_selectedIndex]),
        ],
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final IconData icon;
  final String label;
  final bool hasAlert;
  final ValueChanged<int> onTap;

  const _NavPill({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    this.hasAlert = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? MeVoyTheme.goldAccent
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: hasAlert && !isSelected
                ? Border.all(color: MeVoyTheme.warningAmber, width: 1.4)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? const Color(0xFF1A1600)
                    : (hasAlert ? MeVoyTheme.warningAmber : Colors.white70),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? const Color(0xFF1A1600) : Colors.white,
                ),
              ),
              if (hasAlert && !isSelected) ...[
                const SizedBox(width: 5),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: MeVoyTheme.warningAmber,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
