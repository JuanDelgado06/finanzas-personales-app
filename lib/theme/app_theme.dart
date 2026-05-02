import 'package:flutter/material.dart';

const Color kAppBg = Color(0xFF05070D);
const Color kSurface = Color(0xFF0C1424);
const Color kSurfaceSoft = Color(0xFF101B30);
const Color kSurfaceHover = Color(0xFF16233A);
const Color kLine = Color(0x1AFFFFFF);
const Color kLineSoft = Color(0x0FFFFFFF);
const Color kTextMain = Color(0xFFE6EDF7);
const Color kTextSoft = Color(0xFFA8B5C4);
const Color kAccent = Color(0xFF4F8CFF);
const Color kDanger = Color(0xFFFF5F7A);
const Color kSuccess = Color(0xFF22C55E);
const Color kWarning = Color(0xFFA78BFA);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kAppBg,
    colorScheme: const ColorScheme.dark(
      primary: kAccent,
      surface: kSurface,
      error: kDanger,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: kTextMain, fontFamily: 'Inter'),
      bodySmall: TextStyle(color: kTextSoft, fontFamily: 'Inter'),
      titleMedium: TextStyle(color: kTextMain, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
      titleLarge: TextStyle(color: kTextMain, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x0DFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: kTextSoft),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFA050910),
      selectedItemColor: Colors.white,
      unselectedItemColor: kTextSoft,
      type: BottomNavigationBarType.fixed,
    ),
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kLineSoft),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
  );
}

// Shared card decoration
BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xF010192B), Color(0xF0090E1A)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor ?? kLineSoft),
    );

// Currency formatter
String formatCurrency(double value) {
  if (value.abs() >= 1000000) {
    return '\$${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value.abs() >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(0)}K';
  }
  return '\$${value.toStringAsFixed(0)}';
}

String formatCurrencyFull(double value) {
  final abs = value.abs();
  final formatted = abs.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
  return value < 0 ? '-\$$formatted' : '\$$formatted';
}
