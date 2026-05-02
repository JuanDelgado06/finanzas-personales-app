import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/budget_item.dart';
import '../theme/app_theme.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: kAppBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _SummaryCard(state: state)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _MonthInput(state: state),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Activos',
              iconData: Icons.savings_outlined,
              iconColor: kAccent,
              onAdd: state.addAsset,
              child: Column(
                children: state.assets
                    .asMap()
                    .entries
                    .map((e) => _AssetRow(index: e.key, item: e.value, onRemove: () => state.removeAsset(e.key),
                        onChanged: (name, amount) => state.updateAsset(e.key, name: name, amount: amount)))
                    .toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Me Deben',
              iconData: Icons.arrow_downward_rounded,
              iconColor: const Color(0xFF22C55E),
              onAdd: state.addOwed,
              child: Column(
                children: state.owed
                    .asMap()
                    .entries
                    .map((e) => _AssetRow(index: e.key, item: e.value, onRemove: () => state.removeOwed(e.key),
                        onChanged: (name, amount) => state.updateOwed(e.key, name: name, amount: amount)))
                    .toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Gastos Fijos',
              iconData: Icons.receipt_long_outlined,
              iconColor: kDanger,
              onAddLabel: '+ Gasto',
              onAdd: state.addLiability,
              onAddExtra: state.addCreditCard,
              onAddExtraLabel: '+ Tarjeta',
              child: Column(
                children: state.liabilities
                    .asMap()
                    .entries
                    .map((e) {
                      final item = e.value;
                      if (item is CreditCard) {
                        return _CreditCardRow(
                          index: e.key,
                          item: item,
                          onRemove: () => state.removeLiability(e.key),
                        );
                      }
                      final l = item as Liability;
                      return _LiabilityRow(
                        index: e.key,
                        item: l,
                        onRemove: () => state.removeLiability(e.key),
                      );
                    })
                    .toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => _saveBudget(context, state),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Guardar presupuesto'),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Future<void> _saveBudget(BuildContext context, AppState state) async {
    final ok = await state.saveBudget();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Presupuesto guardado ✓' : 'Error al guardar'),
      backgroundColor: ok ? kSuccess : kDanger,
    ));
  }
}

// ── Summary card ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final AppState state;
  const _SummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final netFull = formatCurrencyFull(state.netWorth);
    final isPositive = state.netWorth >= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(borderColor: isPositive ? kSuccess.withOpacity(0.3) : kDanger.withOpacity(0.3)),
      child: Column(
        children: [
          Text(
            state.monthName.isEmpty ? 'Presupuesto Mensual' : state.monthName,
            style: const TextStyle(color: kTextSoft, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            netFull,
            style: TextStyle(
              color: isPositive ? kSuccess : kDanger,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          const Text('Balance neto', style: TextStyle(color: kTextSoft, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryTile(label: 'Activos', value: state.totalAssets, color: kSuccess),
              _SummaryTile(label: 'Gastos fijos', value: state.totalLiabilitiesWithoutMicro, color: kDanger),
              _SummaryTile(label: 'Gastos hormiga', value: state.totalMicroExpenses, color: kWarning),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SummaryTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(formatCurrency(value), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: kTextSoft, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Month input ───────────────────────────────────────────────────────────────
class _MonthInput extends StatefulWidget {
  final AppState state;
  const _MonthInput({required this.state});
  @override
  State<_MonthInput> createState() => _MonthInputState();
}

class _MonthInputState extends State<_MonthInput> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.state.monthName);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: (v) { widget.state.monthName = v; },
      style: const TextStyle(color: kTextMain),
      decoration: const InputDecoration(
        hintText: 'Nombre del mes (ej. Enero 2025)',
        prefixIcon: Icon(Icons.calendar_today_outlined, color: kTextSoft, size: 18),
      ),
    );
  }
}

// ── Generic section ───────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData iconData;
  final Color iconColor;
  final VoidCallback onAdd;
  final String onAddLabel;
  final VoidCallback? onAddExtra;
  final String? onAddExtraLabel;
  final Widget child;

  const _Section({
    required this.title,
    required this.iconData,
    required this.iconColor,
    required this.onAdd,
    this.onAddLabel = '+ Agregar',
    this.onAddExtra,
    this.onAddExtraLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Icon(iconData, color: iconColor, size: 18),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                if (onAddExtra != null)
                  _AddBtn(label: onAddExtraLabel!, onTap: onAddExtra!),
                const SizedBox(width: 4),
                _AddBtn(label: onAddLabel, onTap: onAdd),
              ],
            ),
          ),
          const Divider(height: 1, color: kLineSoft),
          Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), child: child),
        ],
      ),
    );
  }
}

class _AddBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Row widgets ───────────────────────────────────────────────────────────────
class _AmountInput extends StatefulWidget {
  final double initial;
  final ValueChanged<double> onChanged;
  final bool compact;
  const _AmountInput({required this.initial, required this.onChanged, this.compact = false});
  @override
  State<_AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<_AmountInput> {
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
      style: TextStyle(color: kTextMain, fontSize: widget.compact ? 13 : 14),
      textAlign: TextAlign.right,
      onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: const TextStyle(color: kTextSoft),
        prefixText: '\$ ',
        prefixStyle: const TextStyle(color: kTextSoft, fontSize: 13),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: widget.compact ? 10 : 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kAccent)),
      ),
    );
  }
}

class _NameInput extends StatefulWidget {
  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;
  const _NameInput({required this.initial, required this.hint, required this.onChanged});
  @override
  State<_NameInput> createState() => _NameInputState();
}

class _NameInputState extends State<_NameInput> {
  late final TextEditingController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: widget.initial); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      style: const TextStyle(color: kTextMain, fontSize: 13),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: kTextSoft, fontSize: 13),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLine)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kAccent)),
      ),
    );
  }
}

class _RemoveBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: kDanger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.close, color: kDanger, size: 16),
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  final int index;
  final BudgetItem item;
  final VoidCallback onRemove;
  final void Function(String name, double amount) onChanged;

  const _AssetRow({required this.index, required this.item, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _NameInput(initial: item.name, hint: 'Nombre', onChanged: (v) => onChanged(v, item.amount)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: _AmountInput(initial: item.amount, onChanged: (v) => onChanged(item.name, v)),
          ),
          const SizedBox(width: 8),
          _RemoveBtn(onTap: onRemove),
        ],
      ),
    );
  }
}

class _LiabilityRow extends StatelessWidget {
  final int index;
  final Liability item;
  final VoidCallback onRemove;

  const _LiabilityRow({required this.index, required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _NameInput(
              initial: item.name,
              hint: 'Gasto fijo',
              onChanged: (v) { item.name = v; state.notifyListeners(); },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: _AmountInput(
              initial: item.amount,
              onChanged: (v) { item.amount = v; state.notifyListeners(); },
            ),
          ),
          const SizedBox(width: 8),
          _RemoveBtn(onTap: onRemove),
        ],
      ),
    );
  }
}

class _CreditCardRow extends StatelessWidget {
  final int index;
  final CreditCard item;
  final VoidCallback onRemove;

  const _CreditCardRow({required this.index, required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kWarning.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWarning.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card, color: kWarning, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: _NameInput(
                  initial: item.name,
                  hint: 'Tarjeta de crédito',
                  onChanged: (v) { item.name = v; state.notifyListeners(); },
                ),
              ),
              const SizedBox(width: 8),
              _RemoveBtn(onTap: onRemove),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total deuda', style: TextStyle(color: kTextSoft, fontSize: 11)),
                    const SizedBox(height: 4),
                    _AmountInput(
                      initial: item.total,
                      compact: true,
                      onChanged: (v) { item.total = v; state.notifyListeners(); },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pago mínimo', style: TextStyle(color: kTextSoft, fontSize: 11)),
                    const SizedBox(height: 4),
                    _AmountInput(
                      initial: item.minimum,
                      compact: true,
                      onChanged: (v) { item.minimum = v; state.notifyListeners(); },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
