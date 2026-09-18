import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../state/app_state.dart';
import '../models/budget_item.dart';
import '../models/monthly_budget.dart';
import '../theme/app_theme.dart';
import 'budget/summary_card.dart';
import 'budget/month_input.dart';
import 'budget/section.dart';
import 'budget/rows.dart';
import 'budget/credit_card_row.dart';

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
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SummaryCard(state: state)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: MonthInput(state: state),
                ),
              ),
              SliverToBoxAdapter(
                child: Section(
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
                          (e) => AssetRow(
                            index: e.key,
                            item: e.value,
                            availableAmount:
                                availableById[e.value.id] ?? e.value.amount,
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
                child: Section(
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
                          (e) => AssetRow(
                            index: e.key,
                            item: e.value,
                            availableAmount:
                                availableById[e.value.id] ?? e.value.amount,
                            onRemove: () => state.removeOwed(e.key),
                            onChanged: (name, amount) => state.updateOwed(
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
                child: Section(
                  title: 'Gastos Fijos',
                  subtitle: 'Pagos recurrentes como servicios, arriendos, etc.',
                  iconData: PhosphorIconsLight.receipt,
                  iconColor: kDanger,
                  onAddLabel: '+ Agregar',
                  onAdd: state.addLiability,
                  child: Column(
                    children: state.liabilities.asMap().entries.map((e) {
                      final l = e.value as Liability;
                      return LiabilityRow(
                        index: e.key,
                        item: l,
                        onRemove: () => state.removeLiability(e.key),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Section(
                  title: 'Tarjetas de Crédito',
                  subtitle: 'Créditos activos, cupos y pagos pendientes.',
                  iconData: PhosphorIconsLight.creditCard,
                  iconColor: const Color(0xFFF59E0B),
                  onAddLabel: '+ Nueva Tarjeta',
                  onAdd: state.addCreditCard,
                  child: Column(
                    children: state.creditCards.asMap().entries.map((e) {
                      final card = e.value;
                      return CreditCardRow(
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
                    onPressed: () => _shareCurrentBudget(context, state),
                    icon: const PhosphorIcon(
                      PhosphorIconsLight.shareNetwork,
                      color: kAccent,
                    ),
                    label: const Text(
                      'Compartir presupuesto',
                      style: TextStyle(color: kAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
          if (state.hasUnsavedBudgetChanges)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _saveBudget(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xEE10233F),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kAccent.withOpacity(0.45)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIconsLight.floppyDisk,
                            color: kAccent,
                            size: 17,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cambios sin guardar · Toca para actualizar',
                              style: TextStyle(
                                color: kTextMain,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          PhosphorIcon(
                            PhosphorIconsLight.caretRight,
                            color: kAccent,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
              : 'No se pudo guardar en la nube. Quedó guardado localmente.',
        ),
        backgroundColor: ok ? (queued ? kAccent : kSuccess) : kDanger,
        action: (!ok && state.lastSaveError != null)
            ? SnackBarAction(
                label: 'Ver detalle',
                textColor: Colors.white,
                onPressed: () => _showSaveErrorDetail(context, state),
              )
            : null,
      ),
    );
  }

  void _showSaveErrorDetail(BuildContext context, AppState state) {
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

  void _confirmReset(BuildContext context, AppState state) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Nuevo mes', style: TextStyle(color: kTextMain)),
        content: const Text(
          '¿Limpiar todos los datos del formulario para empezar un nuevo mes?\n\n'
          'Los presupuestos guardados no se eliminarán: se te asignará automáticamente '
          'el primer mes que todavía no tengas guardado.',
          style: TextStyle(color: kTextSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: kTextSoft)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Refresca la lista de presupuestos guardados antes de elegir el
              // mes nuevo, para no chocar con datos obsoletos en caché.
              await state.loadBudgets();
              state.resetForm();
              if (!context.mounted || !messenger.mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Formulario listo para ${state.monthName}'),
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

  Future<void> _shareCurrentBudget(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final budget = MonthlyBudget(
        monthName: state.monthName,
        assets: state.assets,
        owed: state.owed,
        liabilities: state.liabilities,
        creditCards: state.creditCards,
        microExpenses: state.microExpenses,
        microExpenseCategories: state.microExpenseCategories,
        totalAssets: state.totalAssets,
        totalLiabilities: state.totalLiabilities,
        netWorth: state.netWorth,
        partialNetWorth: state.partialNetWorth,
        createdAt: DateTime.now().toIso8601String(),
        authorId: state.authService.currentUser?.uid,
        authorName: state.authService.currentUser?.displayName,
        authorEmail: state.authService.currentUser?.email,
      );

      // Se comparte como archivo JSON (no texto) para poder reimportarlo
      // sin ambigüedad: exportBudgetToJson/importBudgetFromJson usan el
      // mismo toJson/fromJson de los modelos, a diferencia del formato de
      // texto que había que parsear a mano.
      final jsonData = state.exportBudgetToJson(budget);
      final fileSlug = state.monthName.trim().toLowerCase().replaceAll(' ', '_');
      final fileName = 'presupuesto_$fileSlug.json';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(jsonData)),
              name: fileName,
              mimeType: 'application/json',
            ),
          ],
          // XFile.fromData ignora `name` en todas las plataformas menos web,
          // así que se fuerza el nombre real del archivo con este override.
          fileNameOverrides: [fileName],
          subject: 'Presupuesto: ${state.monthName}',
        ),
      );
    } catch (e) {
      if (!context.mounted || !messenger.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al compartir: $e'),
          backgroundColor: kDanger,
        ),
      );
    }
  }
}
