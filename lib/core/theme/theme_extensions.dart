import 'package:flutter/material.dart';

extension ThemeExtensions on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  
  Color get textColor => isDarkMode ? Colors.white : Colors.black87;
  Color get textColorSecondary => isDarkMode ? Colors.white70 : Colors.black54;
  Color get textColorTertiary => isDarkMode ? Colors.white54 : Colors.black38;
  Color get backgroundColor => isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
  Color get surfaceColor => isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get cardColor => isDarkMode ? const Color(0xFF2D2D2D) : Colors.white;
  Color get dividerColor => isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300;
}
