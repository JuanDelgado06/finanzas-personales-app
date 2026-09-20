import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

class MonthInput extends StatefulWidget {
  final AppState state;
  const MonthInput({required this.state});
  @override
  State<MonthInput> createState() => MonthInputState();
}

class MonthInputState extends State<MonthInput> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5, 1),
      lastDate: DateTime(now.year + 5, 12),
      helpText: 'Selecciona la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
    );
    if (picked == null) return;
    widget.state.setMonthFromDate(picked);
  }

  @override
  void initState() {
    super.initState();
    widget.state.ensureCurrentMonthLoaded();
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
  void didUpdateWidget(covariant MonthInput oldWidget) {
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
          colors: [kSurface, isFocused ? kSurfaceHover : kSurfaceSoft],
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
                    widget.state.setMonthFromDate(DateTime.now());
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
              widget.state.markBudgetDirty();
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
          const SizedBox(height: 6),
          Text(
            'Dia seleccionado: ${widget.state.selectedDayLabel}',
            style: const TextStyle(
              color: kTextSoft,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickMonth,
              icon: const PhosphorIcon(
                PhosphorIconsLight.calendarDots,
                size: 15,
              ),
              label: const Text('Elegir mes'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kLine),
                foregroundColor: kTextSoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
