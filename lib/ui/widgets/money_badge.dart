import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Utilidades de formato monetario exacto en centavos con dos decimales.
class MoneyFormatter {
  const MoneyFormatter._();

  /// Formatea centavos a cadena con dos decimales (ej. 50 -> "$0.50", -125 -> "-$1.25").
  static String formatCents(int cents, {bool showPlusSign = false}) {
    final isNeg = cents < 0;
    final absCents = cents.abs();
    final dollars = absCents ~/ 100;
    final remCents = (absCents % 100).toString().padLeft(2, '0');
    final prefix = isNeg
        ? '-'
        : (showPlusSign && cents > 0)
            ? '+'
            : '';
    return '$prefix\$$dollars.$remCents';
  }

  /// Convierte un texto decimal (ej. "0.50" o "0,50") en centavos enteros.
  static int? parseDollarsToCents(String input) {
    final cleaned = input
        .trim()
        .replaceAll('\$', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return (value * 100).round();
  }
}

/// Etiqueta visual para mostrar cantidades monetarias con dos decimales y código de color.
class MoneyBadge extends StatelessWidget {
  final int cents;
  final bool showPlusSign;
  final double fontSize;
  final bool neutralZero;

  const MoneyBadge({
    super.key,
    required this.cents,
    this.showPlusSign = false,
    this.fontSize = 15,
    this.neutralZero = true,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;

    if (cents > 0) {
      textColor = MeVoyTheme.creditPositive;
      bgColor = MeVoyTheme.creditPositive.withValues(alpha: 0.14);
    } else if (cents < 0) {
      textColor = MeVoyTheme.debtNegative;
      bgColor = MeVoyTheme.debtNegative.withValues(alpha: 0.14);
    } else {
      textColor = neutralZero ? Colors.white70 : MeVoyTheme.goldSoft;
      bgColor = Colors.white.withValues(alpha: 0.08);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        MoneyFormatter.formatCents(cents, showPlusSign: showPlusSign),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
