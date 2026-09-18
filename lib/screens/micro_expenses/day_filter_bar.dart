import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../theme/app_theme.dart';

class DayFilterBar extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;
  final VoidCallback onShowAll;
  final bool showAll;
  final bool canGoPrevious;
  final bool canGoNext;

  const DayFilterBar({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
    required this.onShowAll,
    required this.showAll,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kLineSoft),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Día anterior',
              onPressed: canGoPrevious ? onPrevious : null,
              icon: const PhosphorIcon(PhosphorIconsLight.caretLeft, size: 18),
              color: kTextSoft,
            ),
            Expanded(
              child: InkWell(
                onTap: onPickDate,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsLight.calendar,
                        color: kAccent,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: kTextMain,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: showAll ? null : onShowAll,
              style: TextButton.styleFrom(
                foregroundColor: kAccent,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                'Todos',
                style: TextStyle(
                  color: showAll ? kTextSoft : kAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Día siguiente',
              onPressed: canGoNext ? onNext : null,
              icon: const PhosphorIcon(PhosphorIconsLight.caretRight, size: 18),
              color: kTextSoft,
            ),
          ],
        ),
      ),
    );
  }
}

