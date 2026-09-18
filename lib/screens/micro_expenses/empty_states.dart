import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'actions.dart';

class EmptyMicroState extends StatelessWidget {
  final AppState state;
  const EmptyMicroState({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const PhosphorIcon(
              PhosphorIconsLight.receipt,
              color: kAccent,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sin gastos por ahora',
            style: TextStyle(
              color: kTextMain,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Registra tus gastos del día para ver cómo impactan tu balance.',
            style: TextStyle(color: kTextSoft, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              showAddExpenseSheet(context, state);
            },
            icon: const PhosphorIcon(
              PhosphorIconsLight.plus,
              size: 16,
              color: kAccent,
            ),
            label: const Text(
              'Agregar primer gasto',
              style: TextStyle(color: kAccent),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyDayState extends StatelessWidget {
  final String dateLabel;
  final VoidCallback onAddExpense;

  const EmptyDayState({required this.dateLabel, required this.onAddExpense});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: cardDecoration(),
      child: Column(
        children: [
          const PhosphorIcon(
            PhosphorIconsLight.calendarBlank,
            color: kTextSoft,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin gastos el $dateLabel',
            style: const TextStyle(
              color: kTextMain,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Prueba con otro día o registra un gasto nuevo.',
            style: TextStyle(color: kTextSoft, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAddExpense,
            icon: const PhosphorIcon(
              PhosphorIconsLight.plus,
              size: 16,
              color: kAccent,
            ),
            label: const Text(
              'Agregar gasto',
              style: TextStyle(color: kAccent),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

