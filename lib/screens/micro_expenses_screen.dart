import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/budget_item.dart';
import '../theme/app_theme.dart';

// ── Category icon helper ──────────────────────────────────────────────────────
IconData _categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'comida': return Icons.restaurant_outlined;
    case 'transporte': return Icons.directions_bus_outlined;
    case 'mercado': return Icons.shopping_cart_outlined;
    case 'salud': return Icons.favorite_border;
    case 'hogar': return Icons.home_outlined;
    default: return Icons.label_outline;
  }
}

void _showAddExpenseSheet(BuildContext context, AppState state, {int? editIndex}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AddExpenseSheet(state: state, editIndex: editIndex),
  );
}

// ── Main screen ───────────────────────────────────────────────────────────────
class MicroExpensesScreen extends StatelessWidget {
  const MicroExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: kAppBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _MiniBalanceCard(state: state)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _CategoriesRow(state: state),
            ),
          ),
          if (state.microExpenses.isEmpty)
            SliverToBoxAdapter(child: _EmptyMicroState(state: state))
          else
            SliverList.builder(
              itemCount: state.microExpenses.length,
              itemBuilder: (context, index) =>
                  _MicroExpenseRow(index: index, state: state),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ElevatedButton.icon(
                onPressed: () => _showAddExpenseSheet(context, state),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo gasto'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyMicroState extends StatelessWidget {
  final AppState state;
  const _EmptyMicroState({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.receipt_long_outlined, color: kAccent, size: 26),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sin gastos por ahora',
            style: TextStyle(color: kTextMain, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text(
            'Registra tus gastos del día para ver cómo impactan tu balance.',
            style: TextStyle(color: kTextSoft, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _showAddExpenseSheet(context, state),
            icon: const Icon(Icons.add, size: 16, color: kAccent),
            label: const Text('Agregar primer gasto', style: TextStyle(color: kAccent)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expense row (read-only, tap to edit) ──────────────────────────────────────
class _MicroExpenseRow extends StatelessWidget {
  final int index;
  final AppState state;
  const _MicroExpenseRow({required this.index, required this.state});

  @override
  Widget build(BuildContext context) {
    final item = state.microExpenses[index];
    return GestureDetector(
      onTap: () => _showAddExpenseSheet(context, state, editIndex: index),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kLineSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_categoryIcon(item.category), size: 18, color: kAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category,
                    style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    item.paymentMethod.isEmpty ? '—' : item.paymentMethod,
                    style: const TextStyle(color: kTextSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              formatCurrencyFull(item.amount),
              style: const TextStyle(color: kWarning, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => state.removeMicroExpense(index),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: kDanger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline, color: kDanger, size: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit expense bottom sheet ──────────────────────────────────────────
class _AddExpenseSheet extends StatefulWidget {
  final AppState state;
  final int? editIndex;
  const _AddExpenseSheet({required this.state, this.editIndex});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  late final TextEditingController _amountCtrl;
  late String _selectedCategory;
  late String _selectedPayment;

  @override
  void initState() {
    super.initState();
    final cats = widget.state.microExpenseCategories;
    final pays = widget.state.assetNames.isNotEmpty ? widget.state.assetNames : ['Efectivo'];
    if (widget.editIndex != null) {
      final item = widget.state.microExpenses[widget.editIndex!];
      _amountCtrl = TextEditingController(
        text: item.amount == 0 ? '' : item.amount.toStringAsFixed(0),
      );
      _selectedCategory = cats.contains(item.category) ? item.category : cats.first;
      _selectedPayment = pays.contains(item.paymentMethod) ? item.paymentMethod : pays.first;
    } else {
      _amountCtrl = TextEditingController();
      _selectedCategory = cats.isNotEmpty ? cats.first : 'Otros';
      _selectedPayment = pays.first;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un monto válido'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (widget.editIndex != null) {
      widget.state.updateMicroExpenseDirect(
        widget.editIndex!,
        amount: amount,
        category: _selectedCategory,
        paymentMethod: _selectedPayment,
      );
    } else {
      widget.state.addMicroExpenseDirect(
        amount: amount,
        category: _selectedCategory,
        paymentMethod: _selectedPayment,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editIndex != null;
    final cats = widget.state.microExpenseCategories;
    final pays = widget.state.assetNames.isNotEmpty ? widget.state.assetNames : ['Efectivo'];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: kLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isEdit ? 'Editar gasto' : 'Nuevo gasto',
                style: const TextStyle(color: kTextMain, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 28),

              // ── Amount hero ──────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    const Text(
                      'MONTO',
                      style: TextStyle(color: kTextSoft, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            '\$',
                            style: TextStyle(color: kTextSoft, fontSize: 22, fontWeight: FontWeight.w400),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IntrinsicWidth(
                          child: TextField(
                            controller: _amountCtrl,
                            autofocus: !isEdit,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            style: const TextStyle(
                              color: kTextMain,
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -2,
                            ),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: Color(0xFF2E3E50),
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 2, width: 120,
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Category ─────────────────────────────────────────────────
              const Text(
                'CATEGORÍA',
                style: TextStyle(color: kTextSoft, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cats.map((cat) {
                  final selected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? kAccent : kSurfaceHover,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? kAccent : kLine),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _categoryIcon(cat),
                            size: 14,
                            color: selected ? Colors.white : kTextSoft,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat,
                            style: TextStyle(
                              color: selected ? Colors.white : kTextMain,
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ── Payment method ────────────────────────────────────────────
              const Text(
                'PAGADO CON',
                style: TextStyle(color: kTextSoft, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: pays.map((pay) {
                    final selected = pay == _selectedPayment;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPayment = pay),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: selected ? kSurface : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: selected ? kAccent : kLine),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 13,
                                color: selected ? kAccent : kTextSoft,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                pay,
                                style: TextStyle(
                                  color: selected ? kAccent : kTextMain,
                                  fontSize: 13,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),

              // ── Confirm ───────────────────────────────────────────────────
              ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isEdit ? 'Guardar cambios' : 'Agregar gasto',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category manager (compact button → bottom sheet) ─────────────────────────
class _CategoriesRow extends StatelessWidget {
  final AppState state;
  const _CategoriesRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final customCount = state.microExpenseCategories
        .where((c) => !kDefaultCategories.contains(c))
        .length;
    return GestureDetector(
      onTap: () => _showCategoriesSheet(context, state),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.label_outline, color: kAccent, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Categorías', style: TextStyle(color: kTextMain, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                    customCount > 0
                        ? '${state.microExpenseCategories.length} categorías ($customCount personalizadas)'
                        : '${state.microExpenseCategories.length} categorías',
                    style: const TextStyle(color: kTextSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kTextSoft, size: 18),
          ],
        ),
      ),
    );
  }

  void _showCategoriesSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoriesSheet(state: state),
    );
  }
}

class _CategoriesSheet extends StatelessWidget {
  final AppState state;
  const _CategoriesSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('Categorías', style: TextStyle(color: kTextMain, fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showAddCategory(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('+ Nueva', style: TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: kLineSoft),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: state.microExpenseCategories.map((cat) {
                  final isDefault = kDefaultCategories.contains(cat);
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: kSurfaceHover,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.label_outline, color: kTextSoft, size: 15),
                    ),
                    title: Text(cat, style: const TextStyle(color: kTextMain, fontSize: 14)),
                    trailing: isDefault
                        ? const Text('por defecto', style: TextStyle(color: kTextSoft, fontSize: 11))
                        : GestureDetector(
                            onTap: () {
                              state.removeCategory(cat);
                              Navigator.pop(context);
                            },
                            child: const Icon(Icons.delete_outline, color: kDanger, size: 18),
                          ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
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

// ── Mini balance card (same style as BudgetScreen) ────────────────────────────
class _MiniBalanceCard extends StatelessWidget {
  final AppState state;
  const _MiniBalanceCard({required this.state});

  @override
  Widget build(BuildContext context) {
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
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: state.netWorth, end: state.netWorth),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text(
              formatCurrencyFull(value),
              style: TextStyle(
                color: isPositive ? kSuccess : kDanger,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Text('Balance neto', style: TextStyle(color: kTextSoft, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              _BalTile(label: 'Activos', value: state.totalAssets, color: kSuccess),
              _BalTile(label: 'Gastos fijos', value: state.totalLiabilitiesWithoutMicro, color: kDanger),
              _BalTile(label: 'Gastos diarios', value: state.totalMicroExpenses, color: kWarning),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _BalTile({required this.label, required this.value, required this.color});

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
