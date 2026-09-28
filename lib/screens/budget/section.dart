import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../theme/app_theme.dart';

class Section extends StatefulWidget {
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

  const Section({
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
  State<Section> createState() => SectionState();
}

class SectionState extends State<Section> {
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
                            PhosphorIcon(
                              widget.iconData,
                              color: widget.iconColor,
                              size: 18,
                            ),
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
                                onTap: () {
                                  setState(() => _expanded = true);
                                  widget.onAddExtra!();
                                },
                              ),
                            const SizedBox(width: 4),
                            _AddBtn(
                              label: widget.onAddLabel,
                              onTap: () {
                                setState(() => _expanded = true);
                                widget.onAdd();
                              },
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _expanded = !_expanded),
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
