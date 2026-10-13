/// Modelo de tarifas de juego para «Me Voy» (Rummy).
/// Todos los importes se almacenan internamente en centavos enteros (`int`)
/// para garantizar precisión contable absoluta sin errores de punto flotante.
class TariffConfig {
  /// Tarifa por mesa ganada que cobra el ganador a cada rival (por defecto: 50 centavos = $0.50).
  final int tableWinCents;

  /// Tarifa por cada As que cobra el jugador a cada rival (por defecto: 10 centavos = $0.10).
  final int aceCents;

  /// Tarifa por cada K (Rey) que cobra el jugador a cada rival (por defecto: 10 centavos = $0.10).
  final int kingCents;

  /// Tarifa por cada Ruso que cobra el jugador a cada rival (por defecto: 10 centavos = $0.10).
  final int rusoCents;

  /// Tarifa por cada Pata que cobra el jugador a cada rival (por defecto: 20 centavos = $0.20).
  final int patasCents;

  /// Límite máximo de Ases permitidos en una partida (validación de mazo, por defecto 8 en doble mazo).
  final int maxAcesPerRound;

  /// Límite máximo de Reyes (K) permitidos en una partida (por defecto 8 en doble mazo).
  final int maxKingsPerRound;

  /// Límite máximo de Rusos permitidos por jugador en una partida.
  final int maxRusosPerPlayer;

  /// Límite máximo de Patas permitidas por jugador en una partida.
  final int maxPatasPerPlayer;

  /// Fecha de la configuración o instantánea.
  final DateTime updatedAt;

  /// Usuario administrador que definió esta tarifa.
  final String updatedByUserId;

  const TariffConfig({
    this.tableWinCents = 50,
    this.aceCents = 10,
    this.kingCents = 10,
    this.rusoCents = 10,
    this.patasCents = 20,
    this.maxAcesPerRound = 8,
    this.maxKingsPerRound = 8,
    this.maxRusosPerPlayer = 6,
    this.maxPatasPerPlayer = 6,
    required this.updatedAt,
    required this.updatedByUserId,
  });

  factory TariffConfig.defaultStandard({String adminUserId = 'system'}) {
    return TariffConfig(
      tableWinCents: 50, // $0,50 por cada rival
      aceCents: 10, // $0,10
      kingCents: 10, // $0,10
      rusoCents: 10, // $0,10
      patasCents: 20, // $0,20
      maxAcesPerRound: 8,
      maxKingsPerRound: 8,
      maxRusosPerPlayer: 6,
      maxPatasPerPlayer: 6,
      updatedAt: DateTime.now().toUtc(),
      updatedByUserId: adminUserId,
    );
  }

  /// Crea una copia inmutable congelada para adjuntar a una partida/ronda cerrada o calculada,
  /// garantizando que cambios futuros en la configuración de la mesa no alteren resultados anteriores.
  TariffConfig freezeCopy() {
    return TariffConfig(
      tableWinCents: tableWinCents,
      aceCents: aceCents,
      kingCents: kingCents,
      rusoCents: rusoCents,
      patasCents: patasCents,
      maxAcesPerRound: maxAcesPerRound,
      maxKingsPerRound: maxKingsPerRound,
      maxRusosPerPlayer: maxRusosPerPlayer,
      maxPatasPerPlayer: maxPatasPerPlayer,
      updatedAt: updatedAt,
      updatedByUserId: updatedByUserId,
    );
  }

  /// Valida que todas las tarifas sean positivas o cero y coherentes.
  List<String> validate() {
    final errors = <String>[];
    if (tableWinCents <= 0) {
      errors.add('La tarifa de mesa ganada debe ser mayor a \$0.00.');
    }
    if (aceCents < 0) errors.add('La tarifa por cada As no puede ser negativa.');
    if (kingCents < 0) errors.add('La tarifa por cada K no puede ser negativa.');
    if (rusoCents < 0) errors.add('La tarifa por Ruso no puede ser negativa.');
    if (patasCents < 0) errors.add('La tarifa por Patas no puede ser negativa.');
    if (maxAcesPerRound < 1) {
      errors.add('El máximo de Ases por partida debe ser al menos 1.');
    }
    if (maxKingsPerRound < 1) {
      errors.add('El máximo de K por partida debe ser al menos 1.');
    }
    return errors;
  }

  TariffConfig copyWith({
    int? tableWinCents,
    int? aceCents,
    int? kingCents,
    int? rusoCents,
    int? patasCents,
    int? maxAcesPerRound,
    int? maxKingsPerRound,
    int? maxRusosPerPlayer,
    int? maxPatasPerPlayer,
    DateTime? updatedAt,
    String? updatedByUserId,
  }) {
    return TariffConfig(
      tableWinCents: tableWinCents ?? this.tableWinCents,
      aceCents: aceCents ?? this.aceCents,
      kingCents: kingCents ?? this.kingCents,
      rusoCents: rusoCents ?? this.rusoCents,
      patasCents: patasCents ?? this.patasCents,
      maxAcesPerRound: maxAcesPerRound ?? this.maxAcesPerRound,
      maxKingsPerRound: maxKingsPerRound ?? this.maxKingsPerRound,
      maxRusosPerPlayer: maxRusosPerPlayer ?? this.maxRusosPerPlayer,
      maxPatasPerPlayer: maxPatasPerPlayer ?? this.maxPatasPerPlayer,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUserId: updatedByUserId ?? this.updatedByUserId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tableWinCents': tableWinCents,
      'aceCents': aceCents,
      'kingCents': kingCents,
      'rusoCents': rusoCents,
      'patasCents': patasCents,
      'maxAcesPerRound': maxAcesPerRound,
      'maxKingsPerRound': maxKingsPerRound,
      'maxRusosPerPlayer': maxRusosPerPlayer,
      'maxPatasPerPlayer': maxPatasPerPlayer,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'updatedByUserId': updatedByUserId,
    };
  }

  factory TariffConfig.fromMap(Map<String, dynamic> map) {
    return TariffConfig(
      tableWinCents: (map['tableWinCents'] as num?)?.toInt() ?? 50,
      aceCents: (map['aceCents'] as num?)?.toInt() ?? 10,
      kingCents: (map['kingCents'] as num?)?.toInt() ?? 10,
      rusoCents: (map['rusoCents'] as num?)?.toInt() ?? 10,
      patasCents: (map['patasCents'] as num?)?.toInt() ?? 20,
      maxAcesPerRound: (map['maxAcesPerRound'] as num?)?.toInt() ?? 8,
      maxKingsPerRound: (map['maxKingsPerRound'] as num?)?.toInt() ?? 8,
      maxRusosPerPlayer: (map['maxRusosPerPlayer'] as num?)?.toInt() ?? 6,
      maxPatasPerPlayer: (map['maxPatasPerPlayer'] as num?)?.toInt() ?? 6,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())?.toUtc() ??
              DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      updatedByUserId: map['updatedByUserId']?.toString() ?? 'system',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TariffConfig &&
        other.tableWinCents == tableWinCents &&
        other.aceCents == aceCents &&
        other.kingCents == kingCents &&
        other.rusoCents == rusoCents &&
        other.patasCents == patasCents &&
        other.maxAcesPerRound == maxAcesPerRound &&
        other.maxKingsPerRound == maxKingsPerRound &&
        other.maxRusosPerPlayer == maxRusosPerPlayer &&
        other.maxPatasPerPlayer == maxPatasPerPlayer;
  }

  @override
  int get hashCode => Object.hash(
        tableWinCents,
        aceCents,
        kingCents,
        rusoCents,
        patasCents,
        maxAcesPerRound,
        maxKingsPerRound,
        maxRusosPerPlayer,
        maxPatasPerPlayer,
      );
}
