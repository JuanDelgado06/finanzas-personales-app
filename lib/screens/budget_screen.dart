import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/budget_item.dart';
import '../theme/app_theme.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final availableById = state.availableAmountByItemId;
    final monthKey = state.monthName.trim().toLowerCase();
    final hasExistingBudget =
        monthKey.isNotEmpty &&
        state.savedBudgets.any(
          (b) => b.monthName.trim().toLowerCase() == monthKey,
        );
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
              subtitle: 'Ingresa cuentas, efectivo o ahorro disponible.',
              iconData: PhosphorIconsLight.wallet,
              iconColor: kAccent,
              onAdd: state.addAsset,
              child: Column(
                children: state.assets
                    .asMap()
                    .entries
                    .map(
                      (e) => _AssetRow(
                        index: e.key,
                        item: e.value,
                        availableAmount: availableById[e.value.id] ?? e.value.amount,
                        onRemove: () => state.removeAsset(e.key),
                        onChanged: (name, amount) => state.updateAsset(
                          e.key,
                          name: name,
                          amount: amount,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Me Deben',
              subtitle: 'Registra dinero pendiente por cobrar.',
              iconData: PhosphorIconsLight.bank,
              iconColor: const Color(0xFF22C55E),
              onAdd: state.addOwed,
              child: Column(
                children: state.owed
                    .asMap()
                    .entries
                    .map(
                      (e) => _AssetRow(
                        index: e.key,
                        item: e.value,
                        availableAmount: availableById[e.value.id] ?? e.value.amount,
                        onRemove: () => state.removeOwed(e.key),
                        onChanged: (name, amount) =>
                            state.updateOwed(e.key, name: name, amount: amount),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Gastos Fijos',
              subtitle: 'Pagos recurrentes como servicios, arriendos, etc.',
              iconData: PhosphorIconsLight.receipt,
              iconColor: kDanger,
              onAddLabel: '+ Agregar',
              onAdd: state.addLiability,
              child: Column(
                children: state.liabilities.asMap().entries.map((e) {
                  final l = e.value as Liability;
                  return _LiabilityRow(
                    index: e.key,
                    item: l,
                    onRemove: () => state.removeLiability(e.key),
                  );
                }).toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Tarjetas de Crédito',
              subtitle: 'Créditos activos, cupos y pagos pendientes.',
              iconData: PhosphorIconsLight.creditCard,
              iconColor: const Color(0xFFF59E0B),
              onAddLabel: '+ Nueva Tarjeta',
              onAdd: state.addCreditCard,
              child: Column(
                children: state.creditCards.asMap().entries.map((e) {
                  final card = e.value;
                  return _CreditCardRow(
                    index: e.key,
                    item: card,
                    onRemove: () => state.removeCreditCard(e.key),
                  );
                }).toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ElevatedButton.icon(
                onPressed: () => _saveBudget(context, state),
                icon: const PhosphorIcon(PhosphorIconsLight.cloudArrowUp),
                label: Text(
                  hasExistingBudget
                      ? 'Actualizar presupuesto'
                      : 'Guardar presupuesto',
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                onPressed: () => _confirmReset(context, state),
                icon: const PhosphorIcon(
                  PhosphorIconsLight.arrowClockwise,
                  color: kTextSoft,
                ),
                label: const Text(
                  'Nuevo mes',
                  style: TextStyle(color: kTextSoft),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kLine),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Future<void> _saveBudget(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await state.saveBudget();
    if (!context.mounted || !messenger.mounted) return;
    final queued = state.hasPendingSync;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (queued
                    ? 'Guardado local. Pendiente de sincronizar'
                    : 'Presupuesto guardado ✓')
              : 'Error al guardar',
        ),
        backgroundColor: ok ? (queued ? kAccent : kSuccess) : kDanger,
      ),
    );
  }

  void _confirmReset(BuildContext context, AppState state) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Nuevo mes', style: TextStyle(color: kTextMain)),
        content: const Text(
          '¿Limpiar todos los datos del formulario para empezar un nuevo mes?\n\nLos presupuestos guardados no se eliminarán.',
          style: TextStyle(color: kTextSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: kTextSoft)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              state.resetForm();
              if (!context.mounted || !messenger.mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Formulario limpiado para nuevo mes'),
                  backgroundColor: kAccent,
                ),
              );
            },
            child: const Text('Limpiar', style: TextStyle(color: kAccent)),
          ),
        ],
      ),
    );
  }
}

// ── Summary card ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final AppState state;
  const _SummaryCard({required this.state});

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
                child: CustomPaint(painter: _SummaryTexturePainter()),
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
                          _SummaryTile(
                            label: 'Activos',
                            value: state.totalAssets,
                            color: kSuccess,
                          ),
                          _SummaryDivider(),
                          _SummaryTile(
                            label: 'Gastos fijos',
                            value: state.totalLiabilitiesWithoutMicro,
                            color: kDanger,
                          ),
                          _SummaryDivider(),
                          _SummaryTile(
                            label: 'Gastos hormiga',
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

class _SummaryDivider extends StatelessWidget {
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

class _SummaryTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SummaryTile({
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

class _SummaryTexturePainter extends CustomPainter {
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

// ── Month input ───────────────────────────────────────────────────────────────
class _MonthInput extends StatefulWidget {
  final AppState state;
  const _MonthInput({required this.state});
  @override
  State<_MonthInput> createState() => _MonthInputState();
}

class _MonthInputState extends State<_MonthInput> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.state.monthName);
    _focusNode = FocusNode()..addListener(() => setState(() {}));
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MonthInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.state.monthName;
    if (_ctrl.text == nextText) return;
    _ctrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _ctrl.text.trim().isNotEmpty;
    final isFocused = _focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kSurface,
            isFocused ? kSurfaceHover : kSurfaceSoft,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused ? kAccent.withOpacity(0.45) : kLineSoft,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: kAccent.withOpacity(0.18)),
                ),
                child: const Center(
                  child: PhosphorIcon(
                    PhosphorIconsLight.calendarBlank,
                    color: kAccent,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Periodo del presupuesto',
                  style: TextStyle(
                    color: kTextSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (hasText)
                GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    widget.state.monthName = '';
                    widget.state.notifyListeners();
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: PhosphorIcon(
                        PhosphorIconsLight.x,
                        color: kTextSoft,
                        size: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            focusNode: _focusNode,
            onChanged: (v) {
              widget.state.monthName = v;
              widget.state.notifyListeners();
            },
            style: const TextStyle(
              color: kTextMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            decoration: const InputDecoration(
              hintText: 'Ej: Mayo 2026',
              hintStyle: TextStyle(
                color: kTextSoft,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              isDense: true,
              filled: false,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Generic section (accordion) ──────────────────────────────────────────────
class _Section extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData iconData;
  final Color iconColor;
  final VoidCallback onAdd;
  final String onAddLabel;
  final VoidCallback? onAddExtra;
  final String? onAddExtraLabel;
  final Widget child;
  final bool initiallyExpanded;

  const _Section({
    required this.title,
    this.subtitle,
    required this.iconData,
    required this.iconColor,
    required this.onAdd,
    this.onAddLabel = '+ Agregar',
    this.onAddExtra,
    this.onAddExtraLabel,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, color: widget.iconColor.withOpacity(0.7)),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            PhosphorIcon(widget.iconData, color: widget.iconColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: kTextMain,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            if (widget.onAddExtra != null)
                              _AddBtn(
                                label: widget.onAddExtraLabel!,
                                onTap: widget.onAddExtra!,
                              ),
                            const SizedBox(width: 4),
                            _AddBtn(label: widget.onAddLabel, onTap: widget.onAdd),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => setState(() => _expanded = !_expanded),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: kSurfaceHover,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: kLineSoft),
                                ),
                                child: AnimatedRotation(
                                  turns: _expanded ? 0 : -0.25,
                                  duration: const Duration(milliseconds: 180),
                                  child: const PhosphorIcon(
                                    PhosphorIconsLight.caretDown,
                                    color: kTextSoft,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              color: kTextSoft,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: _expanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Column(
                      children: [
                        const Divider(height: 1, color: kLineSoft),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                          child: widget.child,
                        ),
                      ],
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        child: Text(
          label,
          style: const TextStyle(
            color: kAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Row widgets ───────────────────────────────────────────────────────────────
class _AmountInput extends StatefulWidget {
  final double initial;
  final ValueChanged<double> onChanged;
  final bool compact;
  const _AmountInput({
    required this.initial,
    required this.onChanged,
    this.compact = false,
  });
  @override
  State<_AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<_AmountInput> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initial == 0 ? '' : widget.initial.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AmountInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText =
        widget.initial == 0 ? '' : widget.initial.toStringAsFixed(0);
    if (_ctrl.text == nextText) return;
    _ctrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      style: TextStyle(color: kTextMain, fontSize: widget.compact ? 13 : 14),
      textAlign: TextAlign.right,
      onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: const TextStyle(color: kTextSoft),
        prefixText: '\$ ',
        prefixStyle: const TextStyle(color: kTextSoft, fontSize: 13),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: widget.compact ? 10 : 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAccent),
        ),
      ),
    );
  }
}

class _NameInput extends StatefulWidget {
  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;
  const _NameInput({
    required this.initial,
    required this.hint,
    required this.onChanged,
  });
  @override
  State<_NameInput> createState() => _NameInputState();
}

class _NameInputState extends State<_NameInput> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _NameInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.initial;
    if (_ctrl.text == nextText) return;
    _ctrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAccent),
        ),
      ),
    );
  }
}

class _DayInput extends StatefulWidget {
  final int? initial;
  final String hint;
  final ValueChanged<int?> onChanged;
  const _DayInput({
    required this.initial,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_DayInput> createState() => _DayInputState();
}

class _DayInputState extends State<_DayInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial?.toString() ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DayInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.initial?.toString() ?? '';
    if (_ctrl.text == nextText) return;
    _ctrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: const TextStyle(color: kTextMain, fontSize: 13),
      onChanged: (v) {
        final parsed = int.tryParse(v);
        if (parsed == null || parsed < 1 || parsed > 31) {
          widget.onChanged(null);
          return;
        }
        widget.onChanged(parsed);
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: kTextSoft, fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAccent),
        ),
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: kDanger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kDanger.withOpacity(0.25)),
        ),
        child: const PhosphorIcon(
          PhosphorIconsLight.trash,
          color: kDanger,
          size: 16,
        ),
      ),
    );
  }
}

// ── Card texture painter (silk diagonal lines) ───────────────────────────────
class _CardTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const spacing = 22.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }

    // Reflejo luminoso diagonal superior
    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.07),
          Colors.transparent,
          Colors.transparent,
          Colors.white.withOpacity(0.03),
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(16),
      ),
      sheen,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AssetRow extends StatelessWidget {
  final int index;
  final BudgetItem item;
  final double availableAmount;
  final VoidCallback onRemove;
  final void Function(String name, double amount) onChanged;

  const _AssetRow({
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
                child: _NameInput(
                  initial: item.name,
                  hint: 'Nombre',
                  onChanged: (v) => onChanged(v, item.amount),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _AmountInput(
                  initial: item.amount,
                  onChanged: (v) => onChanged(item.name, v),
                ),
              ),
              const SizedBox(width: 8),
              _RemoveBtn(onTap: onRemove),
            ],
          ),
          if (hasSpend)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text(
                'Disponible: ${formatCurrencyFull(availableAmount)} · Gastado: ${formatCurrencyFull(spentFromThisAsset)}',
                style: const TextStyle(color: kTextSoft, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiabilityRow extends StatelessWidget {
  final int index;
  final Liability item;
  final VoidCallback onRemove;

  const _LiabilityRow({
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
            child: _NameInput(
              initial: item.name,
              hint: 'Gasto fijo',
              onChanged: (v) {
                item.name = v;
                state.notifyListeners();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: _AmountInput(
              initial: item.amount,
              onChanged: (v) {
                item.amount = v;
                state.notifyListeners();
              },
            ),
          ),
          const SizedBox(width: 8),
          _RemoveBtn(onTap: onRemove),
        ],
      ),
    );
  }
}

class _CreditCardRow extends StatefulWidget {
  final int index;
  final CreditCard item;
  final VoidCallback onRemove;

  const _CreditCardRow({
    required this.index,
    required this.item,
    required this.onRemove,
  });

  @override
  State<_CreditCardRow> createState() => _CreditCardRowState();
}

class _CreditCardRowState extends State<_CreditCardRow> {
  late bool _expanded;

  double _derivedBalance() {
    final value = widget.item.creditLimit - widget.item.paymentTotal;
    return value > 0 ? value : 0;
  }

  void _syncDerivedBalance() {
    widget.item.balance = _derivedBalance();
  }

  @override
  void initState() {
    super.initState();
    _expanded = false;
    _syncDerivedBalance();
  }

  @override
  void didUpdateWidget(covariant _CreditCardRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDerivedBalance();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final cardName = widget.item.name.trim();
    final hasName = cardName.isNotEmpty;
    final currentBalance = _derivedBalance();
    widget.item.balance = currentBalance;
    final utilization = widget.item.creditLimit > 0
      ? (widget.item.paymentTotal / widget.item.creditLimit * 100).clamp(0, 100)
        : 0;
    final numericId = widget.item.id.replaceAll(RegExp(r'[^0-9]'), '');
    final last4 = numericId.length >= 4
        ? numericId.substring(numericId.length - 4)
        : numericId.padLeft(4, '0');
    const plateDark = Color(0xFF050607);
    const plateMid = Color(0xFF121417);
    const metal = Color(0xFFBAC1CB);
    const softMetal = Color(0xFF7D8592);
    const whiteInk = Color(0xFFECEFF3);

    return Column(
      children: [
        // ── Credit Card Visual ──────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0E0E0E),
                  Color(0xFF1C1C1E),
                  Color(0xFF111113),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Textura: líneas diagonales tipo seda
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(
                    painter: _CardTexturePainter(),
                    size: const Size(double.infinity, 190),
                  ),
                ),
                // Contenido
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: nombre + botón eliminar + logo
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            hasName ? cardName : 'Nueva Tarjeta',
                            style: const TextStyle(
                              color: Color(0xFFECEFF3),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: widget.onRemove,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Center(
                                child: PhosphorIcon(
                                  PhosphorIconsLight.trash,
                                  color: Colors.red.shade200,
                                  size: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Logo doble círculo (estilo red de pago)
                          SizedBox(
                            width: 36,
                            height: 22,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFEB001B),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFF79E1B).withOpacity(0.85),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Número de tarjeta
                      Text(
                        '••••  ••••  ••••  $last4',
                        style: const TextStyle(
                          color: Color(0xFFECEFF3),
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.8,
                        ),
                      ),
                      const Spacer(),
                      // Fecha de validez
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'VALID\nTHRU',
                                style: TextStyle(
                                  color: Color(0xFF7D8592),
                                  fontSize: 7,
                                  height: 1.3,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.item.paymentDay != null
                                    ? '${widget.item.cutoffDay ?? '--'}/${widget.item.paymentDay}'
                                    : '--/--',
                                style: const TextStyle(
                                  color: Color(0xFFECEFF3),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CUPO',
                                style: TextStyle(
                                  color: const Color(0xFF7D8592),
                                  fontSize: 8,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatCurrencyFull(widget.item.creditLimit),
                                style: const TextStyle(
                                  color: Color(0xFFECEFF3),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'SALDO',
                                style: TextStyle(
                                  color: const Color(0xFF7D8592),
                                  fontSize: 8,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatCurrencyFull(widget.item.balance),
                                style: const TextStyle(
                                  color: Color(0xFFECEFF3),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Barra de utilización
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (utilization / 100).toDouble(),
                                minHeight: 3,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  utilization > 80
                                      ? Colors.red.shade400
                                      : const Color(0xFFBAC1CB),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'USO ${utilization.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Color(0xFF7D8592),
                              fontSize: 9,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Expanded Editor ────────────────────────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Container(
            margin: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kSurfaceHover,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kLine),
            ),
            child: Column(
              children: [
                // Nombre
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nombre de tarjeta',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          _NameInput(
                            initial: widget.item.name,
                            hint: 'Ej: Visa, Mastercard, Amex',
                            onChanged: (v) {
                              widget.item.name = v;
                              state.notifyListeners();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Cupo y Saldo
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cupo',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          _AmountInput(
                            initial: widget.item.creditLimit,
                            compact: true,
                            onChanged: (v) {
                              widget.item.creditLimit = v;
                              _syncDerivedBalance();
                              state.notifyListeners();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saldo',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x11FFFFFF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kLine),
                            ),
                            child: Text(
                              formatCurrencyFull(currentBalance),
                              style: const TextStyle(
                                color: kTextMain,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Pagos
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pago mínimo',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          _AmountInput(
                            initial: widget.item.minimum,
                            compact: true,
                            onChanged: (v) {
                              widget.item.minimum = v;
                              state.notifyListeners();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pago total',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          _AmountInput(
                            initial: widget.item.paymentTotal,
                            compact: true,
                            onChanged: (v) {
                              widget.item.paymentTotal = v;
                              _syncDerivedBalance();
                              state.notifyListeners();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Fechas
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Día de corte',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          _DayInput(
                            initial: widget.item.cutoffDay,
                            hint: '1-31',
                            onChanged: (v) {
                              widget.item.cutoffDay = v;
                              state.notifyListeners();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Día de pago',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          _DayInput(
                            initial: widget.item.paymentDay,
                            hint: '1-31',
                            onChanged: (v) {
                              widget.item.paymentDay = v;
                              state.notifyListeners();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
