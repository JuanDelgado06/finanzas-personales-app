import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

class SaveStatusBar extends StatelessWidget {
  final AppState state;
  const SaveStatusBar({required this.state});

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
              label: state.lastSaveOk
                  ? 'Guardado local, pendiente de sincronizar'
                  : 'No se pudo guardar en la nube',
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
              label: 'Error al guardar · toca para ver detalle',
              color: kDanger,
              onTap: () => _showSaveErrorDetail(context),
            ),
    );
  }

  void _showSaveErrorDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text(
          'Error al guardar en la nube',
          style: TextStyle(color: kTextMain),
        ),
        content: SingleChildScrollView(
          child: Text(
            state.lastSaveError ?? 'Sin detalle disponible',
            style: const TextStyle(color: kTextSoft, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: kAccent)),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required Key key,
    required Widget icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final content = Padding(
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
    if (onTap == null) return KeyedSubtree(key: key, child: content);
    return GestureDetector(key: key, onTap: onTap, child: content);
  }
}
