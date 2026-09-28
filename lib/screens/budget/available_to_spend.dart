import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

/// Franja bajo el balance neto: cuánto está apartado en metas de ahorro y
/// cuánto queda para gastar sin tocarlo. Solo aparece si hay ahorro definido.
class AvailableToSpendStrip extends StatelessWidget {
  final AppState state;
  const AvailableToSpendStrip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final saved = state.totalSavings;
    if (saved <= 0) return const SizedBox.shrink();
    final available = state.availableToSpend;
    final availableColor = available >= 0 ? kSuccess : kDanger;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kSaving.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSaving.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          const PhosphorIcon(
            PhosphorIconsLight.piggyBank,
            color: kSaving,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ahorro apartado',
                  style: TextStyle(color: kTextSoft, fontSize: 10.5),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCurrency(saved),
                  style: const TextStyle(
                    color: kSaving,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Disponible para gastar',
                style: TextStyle(color: kTextSoft, fontSize: 10.5),
              ),
              const SizedBox(height: 2),
              Text(
                formatCurrencyFull(available),
                style: TextStyle(
                  color: availableColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
