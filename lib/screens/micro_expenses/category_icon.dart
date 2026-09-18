import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ── Category icon helper ──────────────────────────────────────────────────────
IconData categoryIcon(String category) {
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
