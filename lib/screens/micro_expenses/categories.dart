import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

class CategoriesRow extends StatelessWidget {
  final AppState state;
  const CategoriesRow({required this.state});

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
                    trailing: GestureDetector(
                      onTap: () {
                        final removed = state.removeCategory(cat);
                        if (!removed) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Debes conservar al menos una categoría',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
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
