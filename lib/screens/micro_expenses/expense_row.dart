import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/budget_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'actions.dart';

class MicroExpenseRow extends StatelessWidget {
  final int index;
  final MicroExpense item;
  final String category;
  final bool isLastInGroup;
  final AppState state;
  const MicroExpenseRow({
    required this.index,
    required this.item,
    required this.category,
    required this.isLastInGroup,
    required this.state,
  });

  String _formatExpenseDate(BuildContext context, DateTime value) {
    final date = value.toLocal();
    final now = DateTime.now();
    final dayDate = DateTime(date.year, date.month, date.day);
    final dayNow = DateTime(now.year, now.month, now.day);
    final diff = dayNow.difference(dayDate).inDays;

    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';

    return MaterialLocalizations.of(context).formatShortDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = isLastInGroup
        ? const BorderRadius.vertical(bottom: Radius.circular(16))
        : BorderRadius.zero;

    return Slidable(
      key: ValueKey(item.id),
      // ── Deslizar derecha → Editar ─────────────────────────────────────────
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.22,
        children: [
          CustomSlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              showAddExpenseSheet(context, state, editIndex: index);
            },
            backgroundColor: kAccent,
            borderRadius: BorderRadius.only(
              bottomLeft: isLastInGroup
                  ? const Radius.circular(16)
                  : Radius.zero,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(
                  PhosphorIconsLight.pencilSimple,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(height: 4),
                Text(
                  'Editar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // ── Deslizar izquierda → Eliminar ─────────────────────────────────────
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.22,
        dismissible: DismissiblePane(
          onDismissed: () {
            HapticFeedback.mediumImpact();
            state.removeMicroExpense(index);
          },
        ),
        children: [
          CustomSlidableAction(
            onPressed: (_) {
              HapticFeedback.mediumImpact();
              state.removeMicroExpense(index);
            },
            backgroundColor: kDanger,
            borderRadius: BorderRadius.only(
              bottomRight: isLastInGroup
                  ? const Radius.circular(16)
                  : Radius.zero,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(
                  PhosphorIconsLight.trash,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(height: 4),
                Text(
                  'Eliminar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => showAddExpenseSheet(context, state, editIndex: index),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: kSurface,
            border: Border(top: BorderSide(color: kLineSoft)),
            borderRadius: borderRadius,
          ),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        color: kTextMain,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const PhosphorIcon(
                          PhosphorIconsLight.wallet,
                          size: 12,
                          color: kTextSoft,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.paymentMethod.isEmpty
                                ? 'Sin método de pago'
                                : item.paymentMethod,
                            style: const TextStyle(
                              color: kTextSoft,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const PhosphorIcon(
                          PhosphorIconsLight.calendarBlank,
                          size: 11,
                          color: kTextSoft,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatExpenseDate(context, item.createdAt),
                          style: TextStyle(
                            color: kTextSoft.withOpacity(0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                formatCurrencyFull(item.amount),
                style: const TextStyle(
                  color: kTextMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add / Edit expense bottom sheet ──────────────────────────────────────────
