import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/budget_item.dart';
import '../theme/app_theme.dart';

// ── Category icon helper ──────────────────────────────────────────────────────
IconData _categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'comida':
      return PhosphorIconsLight.forkKnife;
    case 'transporte':
      return PhosphorIconsLight.bus;
    case 'mercado':
      return PhosphorIconsLight.shoppingCartSimple;
    case 'salud':
      return PhosphorIconsLight.heartbeat;
    case 'hogar':
      return PhosphorIconsLight.houseLine;
    default:
      return PhosphorIconsLight.tag;
  }
}

void _showAddExpenseSheet(
  BuildContext context,
  AppState state, {
  int? editIndex,
}) {
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
            _GroupedExpenseList(state: state),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showAddExpenseSheet(context, state);
                },
                icon: const PhosphorIcon(PhosphorIconsLight.plus, size: 18),
                label: const Text('Nuevo gasto'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _SaveStatusBar(state: state)),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Save status bar ───────────────────────────────────────────────────────────
class _SaveStatusBar extends StatelessWidget {
  final AppState state;
  const _SaveStatusBar({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.microExpenses.isEmpty) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: state.isSaving
          ? _statusRow(
              key: const ValueKey('saving'),
              icon: const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: kTextSoft,
                ),
              ),
              label: 'Guardando…',
              color: kTextSoft,
            )
          : state.isSyncingPendingOps
          ? _statusRow(
              key: const ValueKey('syncing_pending'),
              icon: const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: kAccent,
                ),
              ),
              label: 'Sincronizando pendientes…',
              color: kAccent,
            )
          : state.hasPendingSync
          ? _statusRow(
              key: const ValueKey('pending_sync'),
              icon: const PhosphorIcon(
                PhosphorIconsLight.cloudArrowUp,
                color: kAccent,
                size: 14,
              ),
              label: 'Guardado local, pendiente de sincronizar',
              color: kAccent,
            )
          : state.lastSaveOk
          ? _statusRow(
              key: const ValueKey('ok'),
              icon: const PhosphorIcon(
                PhosphorIconsLight.checkCircle,
                color: kSuccess,
                size: 14,
              ),
              label: 'Guardado',
              color: kSuccess,
            )
          : _statusRow(
              key: const ValueKey('err'),
              icon: const PhosphorIcon(
                PhosphorIconsLight.warningCircle,
                color: kDanger,
                size: 14,
              ),
              label: 'Error al guardar',
              color: kDanger,
            ),
    );
  }

  Widget _statusRow({
    required Key key,
    required Widget icon,
    required String label,
    required Color color,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
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
              _showAddExpenseSheet(context, state);
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

class _ExpenseListEntry {
  final String keyValue;
  final String category;
  final bool isHeader;
  final int count;
  final double total;
  final bool isCollapsed;
  final bool isFirstSection;
  final int? index;
  final MicroExpense? item;
  final bool isLastInGroup;

  const _ExpenseListEntry.header({
    required this.keyValue,
    required this.category,
    required this.count,
    required this.total,
    required this.isCollapsed,
    required this.isFirstSection,
  }) : isHeader = true,
       index = null,
       item = null,
       isLastInGroup = false;

  const _ExpenseListEntry.item({
    required this.keyValue,
    required this.category,
    required this.index,
    required this.item,
    required this.isLastInGroup,
  }) : isHeader = false,
       count = 0,
       total = 0,
       isCollapsed = false,
       isFirstSection = false;
}

List<_ExpenseListEntry> _buildExpenseEntries(
  AppState state,
  Set<String> collapsedCategories,
) {
  final Map<String, List<(int, MicroExpense)>> groups = {};
  for (var i = 0; i < state.microExpenses.length; i++) {
    final expense = state.microExpenses[i];
    groups.putIfAbsent(expense.category, () => []).add((i, expense));
  }

  final entries = <_ExpenseListEntry>[];
  var sectionIndex = 0;
  for (final group in groups.entries) {
    final items = group.value;
    final collapsed = collapsedCategories.contains(group.key);
    final total = items.fold(0.0, (sum, item) => sum + item.$2.amount);
    entries.add(
      _ExpenseListEntry.header(
        keyValue: 'header:${group.key}',
        category: group.key,
        count: items.length,
        total: total,
        isCollapsed: collapsed,
        isFirstSection: sectionIndex == 0,
      ),
    );
    if (!collapsed) {
      for (var i = 0; i < items.length; i++) {
        final record = items[i];
        entries.add(
          _ExpenseListEntry.item(
            keyValue: 'item:${record.$2.id}',
            category: group.key,
            index: record.$1,
            item: record.$2,
            isLastInGroup: i == items.length - 1,
          ),
        );
      }
    }
    sectionIndex++;
  }
  return entries;
}

bool _isSubsequence(List<String> smaller, List<String> bigger) {
  var smallIndex = 0;
  for (final value in bigger) {
    if (smallIndex < smaller.length && smaller[smallIndex] == value) {
      smallIndex++;
    }
  }
  return smallIndex == smaller.length;
}

bool _sameKeyOrder(List<_ExpenseListEntry> a, List<_ExpenseListEntry> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].keyValue != b[i].keyValue) return false;
  }
  return true;
}

// ── Grouped expense list ─────────────────────────────────────────────────────
class _GroupedExpenseList extends StatefulWidget {
  final AppState state;
  const _GroupedExpenseList({required this.state});

  @override
  State<_GroupedExpenseList> createState() => _GroupedExpenseListState();
}

class _GroupedExpenseListState extends State<_GroupedExpenseList> {
  final _listKey = GlobalKey<SliverAnimatedListState>();
  final Set<String> _collapsedCategories = <String>{};
  late List<_ExpenseListEntry> _entries;

  void _syncCollapsedCategories() {
    final categories = widget.state.microExpenses
        .map((expense) => expense.category)
        .toSet();

    _collapsedCategories.removeWhere((c) => !categories.contains(c));
    _collapsedCategories.addAll(categories);
  }

  @override
  void initState() {
    super.initState();
    _syncCollapsedCategories();
    _entries = _buildExpenseEntries(widget.state, _collapsedCategories);
  }

  @override
  void didUpdateWidget(covariant _GroupedExpenseList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCollapsedCategories();
    _applyEntries(_buildExpenseEntries(widget.state, _collapsedCategories));
  }

  void _toggleCategory(String category) {
    setState(() {
      if (!_collapsedCategories.add(category)) {
        _collapsedCategories.remove(category);
      }
    });
    _applyEntries(_buildExpenseEntries(widget.state, _collapsedCategories));
  }

  void _applyEntries(List<_ExpenseListEntry> nextEntries) {
    if (!mounted) return;
    if (_listKey.currentState == null || _sameKeyOrder(_entries, nextEntries)) {
      setState(() => _entries = nextEntries);
      return;
    }

    final oldKeys = _entries.map((entry) => entry.keyValue).toList();
    final newKeys = nextEntries.map((entry) => entry.keyValue).toList();

    if (_isSubsequence(oldKeys, newKeys)) {
      var oldIndex = 0;
      for (var newIndex = 0; newIndex < newKeys.length; newIndex++) {
        if (oldIndex < oldKeys.length &&
            oldKeys[oldIndex] == newKeys[newIndex]) {
          oldIndex++;
          continue;
        }
        _entries.insert(newIndex, nextEntries[newIndex]);
        _listKey.currentState!.insertItem(
          newIndex,
          duration: const Duration(milliseconds: 260),
        );
      }
      setState(() => _entries = nextEntries);
      return;
    }

    if (_isSubsequence(newKeys, oldKeys)) {
      for (var oldIndex = oldKeys.length - 1; oldIndex >= 0; oldIndex--) {
        if (newKeys.contains(oldKeys[oldIndex])) continue;
        final removedEntry = _entries.removeAt(oldIndex);
        _listKey.currentState!.removeItem(
          oldIndex,
          (context, animation) => _AnimatedExpenseEntry(
            animation: animation,
            child: _buildEntry(removedEntry),
          ),
          duration: const Duration(milliseconds: 220),
        );
      }
      setState(() => _entries = nextEntries);
      return;
    }

    setState(() => _entries = nextEntries);
  }

  Widget _buildEntry(_ExpenseListEntry entry) {
    return entry.isHeader
        ? _CategoryHeaderTile(
            category: entry.category,
            count: entry.count,
            total: entry.total,
            isCollapsed: entry.isCollapsed,
            isFirstSection: entry.isFirstSection,
            onTap: () => _toggleCategory(entry.category),
          )
        : _MicroExpenseRow(
            index: entry.index!,
            item: entry.item!,
            state: widget.state,
            category: entry.category,
            isLastInGroup: entry.isLastInGroup,
          );
  }

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      sliver: SliverAnimatedList(
        key: _listKey,
        initialItemCount: _entries.length,
        itemBuilder: (context, index, animation) => _AnimatedExpenseEntry(
          animation: animation,
          child: _buildEntry(_entries[index]),
        ),
      ),
    );
  }
}

class _AnimatedExpenseEntry extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _AnimatedExpenseEntry({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SizeTransition(
        sizeFactor: curved,
        axisAlignment: -1,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

class _CategoryHeaderTile extends StatelessWidget {
  final String category;
  final int count;
  final double total;
  final bool isCollapsed;
  final bool isFirstSection;
  final VoidCallback onTap;
  const _CategoryHeaderTile({
    required this.category,
    required this.count,
    required this.total,
    required this.isCollapsed,
    required this.isFirstSection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = kAccent;
    return Container(
      margin: EdgeInsets.fromLTRB(16, isFirstSection ? 0 : 10, 16, 0),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLineSoft),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: PhosphorIcon(
                  _categoryIcon(category),
                  size: 17,
                  color: kAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        color: kTextMain,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$count ${count == 1 ? 'gasto' : 'gastos'}',
                      style: const TextStyle(color: kTextSoft, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                formatCurrencyFull(total),
                style: const TextStyle(
                  color: kWarning,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isCollapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: const PhosphorIcon(
                  PhosphorIconsLight.caretDown,
                  color: kTextSoft,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicroExpenseRow extends StatelessWidget {
  final int index;
  final MicroExpense item;
  final String category;
  final bool isLastInGroup;
  final AppState state;
  const _MicroExpenseRow({
    required this.index,
    required this.item,
    required this.category,
    required this.isLastInGroup,
    required this.state,
  });

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
              _showAddExpenseSheet(context, state, editIndex: index);
            },
            backgroundColor: kAccent,
            borderRadius: BorderRadius.only(
              bottomLeft: isLastInGroup ? const Radius.circular(16) : Radius.zero,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(PhosphorIconsLight.pencilSimple,
                    color: Colors.white, size: 18),
                SizedBox(height: 4),
                Text('Editar',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
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
              bottomRight: isLastInGroup ? const Radius.circular(16) : Radius.zero,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(PhosphorIconsLight.trash,
                    color: Colors.white, size: 18),
                SizedBox(height: 4),
                Text('Eliminar',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => _showAddExpenseSheet(context, state, editIndex: index),
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
    final pays = widget.state.paymentMethodNames.isNotEmpty
      ? widget.state.paymentMethodNames
        : ['Efectivo'];
    if (widget.editIndex != null) {
      final item = widget.state.microExpenses[widget.editIndex!];
      _amountCtrl = TextEditingController(
        text: item.amount == 0 ? '' : item.amount.toStringAsFixed(0),
      );
      _selectedCategory = cats.contains(item.category)
          ? item.category
          : cats.first;
      _selectedPayment = pays.contains(item.paymentMethod)
          ? item.paymentMethod
          : pays.first;
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
    final pays = widget.state.paymentMethodNames.isNotEmpty
      ? widget.state.paymentMethodNames
        : ['Efectivo'];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isEdit ? 'Editar gasto' : 'Nuevo gasto',
                style: const TextStyle(
                  color: kTextMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),

              // ── Amount hero ──────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    const Text(
                      'MONTO',
                      style: TextStyle(
                        color: kTextSoft,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
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
                            style: TextStyle(
                              color: kTextSoft,
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IntrinsicWidth(
                          child: TextField(
                            controller: _amountCtrl,
                            autofocus: !isEdit,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
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
                      height: 2,
                      width: 120,
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
                style: TextStyle(
                  color: kTextSoft,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
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
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
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
                style: TextStyle(
                  color: kTextSoft,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? kSurface : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? kAccent : kLine,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIconsLight.wallet,
                                size: 13,
                                color: selected ? kAccent : kTextSoft,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                pay,
                                style: TextStyle(
                                  color: selected ? kAccent : kTextMain,
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isEdit ? 'Guardar cambios' : 'Agregar gasto',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const PhosphorIcon(
                PhosphorIconsLight.tag,
                color: kAccent,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Categorías',
                    style: TextStyle(
                      color: kTextMain,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    customCount > 0
                        ? '${state.microExpenseCategories.length} categorías ($customCount personalizadas)'
                        : '${state.microExpenseCategories.length} categorías',
                    style: const TextStyle(color: kTextSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
            const PhosphorIcon(
              PhosphorIconsLight.caretRight,
              color: kTextSoft,
              size: 18,
            ),
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Categorías',
                    style: TextStyle(
                      color: kTextMain,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showAddCategory(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhosphorIcon(
                            PhosphorIconsLight.plus,
                            color: kAccent,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '+ Nueva',
                            style: TextStyle(
                              color: kAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: state.microExpenseCategories.map((cat) {
                  final isDefault = kDefaultCategories.contains(cat);
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kSurfaceHover,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const PhosphorIcon(
                        PhosphorIconsLight.tag,
                        color: kTextSoft,
                        size: 15,
                      ),
                    ),
                    title: Text(
                      cat,
                      style: const TextStyle(color: kTextMain, fontSize: 14),
                    ),
                    trailing: isDefault
                        ? const Text(
                            'por defecto',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          )
                        : GestureDetector(
                            onTap: () {
                              state.removeCategory(cat);
                              Navigator.pop(context);
                            },
                            child: const PhosphorIcon(
                              PhosphorIconsLight.trash,
                              color: kDanger,
                              size: 18,
                            ),
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
        title: const Text(
          'Nueva categoría',
          style: TextStyle(color: kTextMain),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: kTextMain),
          decoration: const InputDecoration(hintText: 'Nombre de la categoría'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: kTextSoft)),
          ),
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
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.985, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kSurface, Color(0xFF0A1220), Color(0xFF090F1A)],
            stops: [0.0, 0.52, 1.0],
          ),
          border: Border.all(
            color: isPositive
                ? kLine
                : kDanger.withOpacity(0.26),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.34),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color: kAccent.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _BalanceTexturePainter()),
              ),
              Positioned(
                top: -42,
                right: -28,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.white.withOpacity(0.08), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  children: [
                    Text(
                      state.monthName.isEmpty ? 'Presupuesto Mensual' : state.monthName,
                      style: const TextStyle(color: kTextSoft, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: state.netWorth, end: state.netWorth),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        formatCurrencyFull(value),
                        style: TextStyle(
                          color: isPositive ? const Color(0xFF23D47E) : const Color(0xFFFF6F7D),
                          fontSize: 41,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.3,
                          height: 0.95,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Balance neto',
                      style: TextStyle(color: kTextSoft, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: kSurfaceSoft.withOpacity(0.32),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kLineSoft),
                      ),
                      child: Row(
                        children: [
                          _BalTile(
                            label: 'Activos',
                            value: state.totalAssets,
                            color: kSuccess,
                          ),
                          _MiniDivider(),
                          _BalTile(
                            label: 'Gastos fijos',
                            value: state.totalLiabilitiesWithoutMicro,
                            color: kDanger,
                          ),
                          _MiniDivider(),
                          _BalTile(
                            label: 'Gastos diarios',
                            value: state.totalMicroExpenses,
                            color: kWarning,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: kLine,
    );
  }
}

class _BalTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _BalTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            formatCurrency(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: kTextSoft, fontSize: 10.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _BalanceTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.018)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 18.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        linePaint,
      );
    }

    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.035),
          Colors.transparent,
          Colors.transparent,
          Colors.white.withOpacity(0.02),
        ],
        stops: const [0.0, 0.3, 0.68, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sheenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
