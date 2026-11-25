import 'package:material_ui/material_ui.dart';

/// Palet dari spesifikasi desain Lenggang.
class LColors {
  LColors._();

  static const primary = Color(0xFF4D3A67); // Regal Amethyst
  static const accent = Color(0xFFF9D565); // Buttercream Yellow
  static const pink = Color(0xFFFFB6CD); // Blush Sakura Pink
  static const base = Color(0xFF181420);
  static const deep = Color(0xFF120F17);
  static const card = Color(0xFF231C2D);
  static const elevated = Color(0xFF2B2338);
  static const border = Color(0xFF382C49);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFFB5A9C7);
  static const dimmed = Color(0xFF7A6F8A);
  static const danger = Color(0xFFFF3B3B);
  static const safe = Color(0xFF7BE495);
  static const stageFloor = Color(0xFF221B2C);
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: LColors.primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: LColors.accent,
        onPrimary: LColors.base,
        secondary: LColors.pink,
        onSecondary: LColors.base,
        surface: LColors.base,
        onSurface: LColors.text,
        surfaceContainerLowest: LColors.deep,
        surfaceContainerLow: LColors.card,
        surfaceContainer: LColors.card,
        surfaceContainerHigh: LColors.elevated,
        surfaceContainerHighest: LColors.elevated,
        outline: LColors.border,
        outlineVariant: LColors.border,
        error: LColors.danger,
        primaryContainer: LColors.primary,
        onPrimaryContainer: LColors.text,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LColors.base,
    appBarTheme: const AppBarTheme(
      backgroundColor: LColors.base,
      foregroundColor: LColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: LColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: LColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: LColors.accent,
        foregroundColor: LColors.base,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: LColors.text,
        side: const BorderSide(color: LColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LColors.border),
      ),
      labelStyle: const TextStyle(color: LColors.muted),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: LColors.card,
      side: BorderSide(color: LColors.border),
      labelStyle: TextStyle(color: LColors.text),
    ),
    dividerTheme: const DividerThemeData(color: LColors.border, space: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Format angka Indonesia (koma desimal).
String fmtNum(double v, [int digits = 1]) =>
    v.toStringAsFixed(digits).replaceAll('.', ',');

String fmtMeters(double v, [int digits = 2]) => '${fmtNum(v, digits)} m';

/// Ukuran panggung tanpa ",0" yang tidak perlu: 8 → "8", 8.5 → "8,5".
String fmtSize(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : fmtNum(v);
