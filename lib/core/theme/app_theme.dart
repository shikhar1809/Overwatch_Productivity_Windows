import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const seed = Colors.blue;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: seed.withValues(alpha: 0.15),
        selectedIconTheme: const IconThemeData(color: seed),
        selectedLabelTextStyle: const TextStyle(color: seed, fontWeight: FontWeight.bold),
        unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
        unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade600),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black87),
        bodyMedium: TextStyle(color: Colors.black87),
        titleLarge: TextStyle(color: Colors.black),
        headlineLarge: TextStyle(color: Colors.black),
        headlineMedium: TextStyle(color: Colors.black),
        headlineSmall: TextStyle(color: Colors.black),
        titleMedium: TextStyle(color: Colors.black),
        titleSmall: TextStyle(color: Colors.black),
        bodySmall: TextStyle(color: Colors.black54),
        labelLarge: TextStyle(color: Colors.black87),
        labelMedium: TextStyle(color: Colors.black87),
        labelSmall: TextStyle(color: Colors.black54),
      ),
      dividerColor: Colors.grey.shade300,
      iconTheme: const IconThemeData(color: Colors.black87),
    );
  }

  static ThemeData dark() {
    const seed = Colors.blue;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
        surface: const Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        indicatorColor: seed.withValues(alpha: 0.3),
        selectedIconTheme: IconThemeData(color: seed.shade200),
        selectedLabelTextStyle: TextStyle(color: seed.shade200, fontWeight: FontWeight.bold),
        unselectedIconTheme: const IconThemeData(color: Colors.white70),
        unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF2D2D2D),
        elevation: 2,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        headlineLarge: TextStyle(color: Colors.white),
        headlineMedium: TextStyle(color: Colors.white),
        headlineSmall: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white70),
        labelLarge: TextStyle(color: Colors.white),
        labelMedium: TextStyle(color: Colors.white),
        labelSmall: TextStyle(color: Colors.white70),
      ),
      dividerColor: Colors.grey.shade800,
      iconTheme: const IconThemeData(color: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: const Color(0xFF2D2D2D),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: seed.shade200),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return seed.shade200;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return seed.withValues(alpha: 0.5);
          }
          return Colors.grey.shade700;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: seed.shade200,
        thumbColor: seed.shade200,
        overlayColor: seed.withValues(alpha: 0.2),
        inactiveTrackColor: Colors.grey.shade700,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2D2D2D),
        labelStyle: const TextStyle(color: Colors.white),
        secondaryLabelStyle: const TextStyle(color: Colors.white70),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF2D2D2D),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2D2D2D),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: seed.shade200,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: seed.shade200,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return seed.shade200;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: Colors.white70, width: 2),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white54),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed.shade200,
          foregroundColor: Colors.black,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seed.shade200,
        ),
      ),
    );
  }
}
