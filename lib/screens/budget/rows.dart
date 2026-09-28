import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/budget_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'form_inputs.dart';

class AssetRow extends StatelessWidget {
  final int index;
  final BudgetItem item;
  final double availableAmount;
  final VoidCallback onRemove;
  final void Function(String name, double amount) onChanged;

  const AssetRow({
    super.key,
    required this.index,
    required this.item,
    required this.availableAmount,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final spentFromThisAsset = item.amount - availableAmount;
    final hasSpend = spentFromThisAsset > 0.009;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
                child: NameInput(
                  initial: item.name,
                  hint: 'Nombre',
                  onChanged: (v) => onChanged(v, item.amount),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: AmountInput(
                  initial: item.amount,
                  onChanged: (v) => onChanged(item.name, v),
                ),
              ),
              const SizedBox(width: 8),
              RemoveBtn(onTap: onRemove),
            ],
          ),
          if (hasSpend)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text(
                availableAmount < 0
                    ? 'Te pasaste: ${formatCurrencyFull(availableAmount)} · Gastado: ${formatCurrencyFull(spentFromThisAsset)}'
                    : 'Disponible: ${formatCurrencyFull(availableAmount)} · Gastado: ${formatCurrencyFull(spentFromThisAsset)}',
                style: TextStyle(
                  color: availableAmount < 0 ? kDanger : kTextSoft,
                  fontWeight: availableAmount < 0
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LiabilityRow extends StatelessWidget {
  final int index;
  final Liability item;
  final VoidCallback onRemove;

  const LiabilityRow({
    required this.index,
    required this.item,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: NameInput(
              initial: item.name,
              hint: 'Gasto fijo',
              onChanged: (v) {
                item.name = v;
                state.markBudgetDirty();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: AmountInput(
              initial: item.amount,
              onChanged: (v) {
                item.amount = v;
                state.markBudgetDirty();
              },
            ),
          ),
          const SizedBox(width: 8),
          RemoveBtn(onTap: onRemove),
        ],
      ),
    );
  }
}

