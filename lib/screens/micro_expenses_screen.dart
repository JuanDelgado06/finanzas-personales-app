import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/budget_item.dart';
import '../theme/app_theme.dart';

class MicroExpensesScreen extends StatelessWidget {
  const MicroExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final total = state.totalMicroExpenses;

    return Scaffold(
      backgroundColor: kAppBg,
      body: CustomScrollView(
        slivers: [
          // Header summary
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: cardDecoration(borderColor: kWarning.withOpacity(0.3)),
              child: Row(
                children: [
                  const Icon(Icons.coffee_outlined, color: kWarning, size: 22),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gastos Hormiga', style: TextStyle(color: kTextSoft, fontSize: 13)),
                      Text(formatCurrencyFull(total),
                          style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w700, fontSize: 22)),
                    ],
                  ),
                  const Spacer(),
                  Text('${state.microExpenses.length} items',
                      style: const TextStyle(color: kTextSoft, fontSize: 12)),
                ],
              ),
            ),
          ),
          // Categories
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _CategoriesRow(state: state),
            ),
          ),
          // Items list
          SliverList.builder(
            itemCount: state.microExpenses.length,
            itemBuilder: (context, index) {
              return _MicroExpenseRow(index: index, state: state);
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: state.addMicroExpense,
                icon: const Icon(Icons.add, size: 18, color: kAccent),
                label: const Text('Agregar gasto', style: TextStyle(color: kAccent)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: kAccent, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── Category chips ────────────────────────────────────────────────────────────
class _CategoriesRow extends StatelessWidget {
  final AppState state;
  const _CategoriesRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Categorías', style: TextStyle(color: kTextMain, fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showAddCategory(context, state),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('+ Nueva', style: TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: state.microExpenseCategories.map((cat) {
              final isDefault = kDefaultCategories.contains(cat);
              return GestureDetector(
                onLongPress: !isDefault ? () => state.removeCategory(cat) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kSurfaceHover,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kLine),
                  ),
                  child: Text(cat, style: const TextStyle(color: kTextMain, fontSize: 12)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showAddCategory(BuildContext context, AppState state) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Nueva categoría', style: TextStyle(color: kTextMain)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: kTextMain),
          decoration: const InputDecoration(hintText: 'Nombre de la categoría'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: kTextSoft))),
          TextButton(
            onPressed: () {
              state.addCategory(ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('Agregar', style: TextStyle(color: kAccent)),
          ),
        ],
      ),
    );
  }
}

// ── Micro expense row ─────────────────────────────────────────────────────────
class _MicroExpenseRow extends StatelessWidget {
  final int index;
  final AppState state;
  const _MicroExpenseRow({required this.index, required this.state});

  @override
  Widget build(BuildContext context) {
    final item = state.microExpenses[index];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kLineSoft),
      ),
      child: Column(
        children: [
          // Row 1: category + delete
          Row(
            children: [
              Expanded(
                child: _DropdownField<String>(
                  value: state.microExpenseCategories.contains(item.category)
                      ? item.category
                      : state.microExpenseCategories.first,
                  items: state.microExpenseCategories,
                  onChanged: (v) => state.updateMicroExpense(index, category: v),
                  icon: Icons.label_outline,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => state.removeMicroExpense(index),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: kDanger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close, color: kDanger, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: payment method + amount
          Row(
            children: [
              Expanded(
                child: _DropdownField<String>(
                  value: state.assetNames.contains(item.paymentMethod)
                      ? item.paymentMethod
                      : (state.assetNames.isNotEmpty ? state.assetNames.first : ''),
                  items: state.assetNames.isNotEmpty ? state.assetNames : ['Efectivo'],
                  onChanged: (v) => state.updateMicroExpense(index, paymentMethod: v),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MicroAmountInput(
                  initial: item.amount,
                  onChanged: (v) => state.updateMicroExpense(index, amount: v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final IconData icon;
  const _DropdownField({required this.value, required this.items, required this.onChanged, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kLine),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
          isExpanded: true,
          dropdownColor: kSurfaceSoft,
          icon: const Icon(Icons.expand_more, color: kTextSoft, size: 18),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i.toString(), style: const TextStyle(color: kTextMain, fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
          hint: Row(children: [Icon(icon, color: kTextSoft, size: 14), const SizedBox(width: 4)]),
        ),
      ),
    );
  }
}

class _MicroAmountInput extends StatefulWidget {
  final double initial;
  final ValueChanged<double> onChanged;
  const _MicroAmountInput({required this.initial, required this.onChanged});
  @override
  State<_MicroAmountInput> createState() => _MicroAmountInputState();
}

class _MicroAmountInputState extends State<_MicroAmountInput> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial == 0 ? '' : widget.initial.toStringAsFixed(0));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
      style: const TextStyle(color: kTextMain, fontSize: 13),
      textAlign: TextAlign.right,
      onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: const TextStyle(color: kTextSoft),
        prefixText: '\$ ',
        prefixStyle: const TextStyle(color: kTextSoft, fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kAccent)),
      ),
    );
  }
}
