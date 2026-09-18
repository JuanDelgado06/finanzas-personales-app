import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/budget_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'category_icon.dart';
import 'expense_row.dart';

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
  List<int> expenseIndexes,
) {
  final Map<String, List<(int, MicroExpense)>> groups = {};
  for (final i in expenseIndexes) {
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
class GroupedExpenseList extends StatefulWidget {
  final AppState state;
  final List<int> expenseIndexes;
  const GroupedExpenseList({
    required this.state,
    required this.expenseIndexes,
  });

  @override
  State<GroupedExpenseList> createState() => GroupedExpenseListState();
}

class GroupedExpenseListState extends State<GroupedExpenseList> {
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
    _entries = _buildExpenseEntries(
      widget.state,
      _collapsedCategories,
      widget.expenseIndexes,
    );
  }

  @override
  void didUpdateWidget(covariant GroupedExpenseList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCollapsedCategories();
    _applyEntries(
      _buildExpenseEntries(
        widget.state,
        _collapsedCategories,
        widget.expenseIndexes,
      ),
    );
  }

  void _toggleCategory(String category) {
    setState(() {
      if (!_collapsedCategories.add(category)) {
        _collapsedCategories.remove(category);
      }
    });
    _applyEntries(
      _buildExpenseEntries(
        widget.state,
        _collapsedCategories,
        widget.expenseIndexes,
      ),
    );
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
        : MicroExpenseRow(
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
                  categoryIcon(category),
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

