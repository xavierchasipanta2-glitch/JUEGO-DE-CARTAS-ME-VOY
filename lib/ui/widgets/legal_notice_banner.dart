import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Aviso normativo sobre la naturaleza contable de los créditos internos del juego (Sección 3).
class LegalNoticeBanner extends StatelessWidget {
  final bool compact;

  const LegalNoticeBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MeVoyTheme.warningAmber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: MeVoyTheme.goldSoft,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              compact
                  ? 'Unidad contable interna de juego. Las asignaciones iniciales y recargas se distinguen de las ganancias y no constituyen depósitos bancarios.'
                  : 'Aviso contable: Los créditos internos de «Me Voy» son unidades de contabilidad del juego para liquidar puntos y premios de la mesa. No constituyen depósitos bancarios ni dinero en una entidad financiera. Toda emisión queda registrada con auditoría.',
              style: TextStyle(
                fontSize: compact ? 11.5 : 12,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
