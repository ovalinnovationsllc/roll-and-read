import 'package:flutter/material.dart';

/// App color palette
class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF0556BA);        // Primary blue
  static const Color lightGray = Color(0xFFD5D5DC);      // Light gray
  static const Color darkBlue = Color(0xFF0F1D37);       // Dark blue
  static const Color mediumBlue = Color(0xFF789CC8);     // Medium blue
  static const Color white = Color(0xFFFFFFFF);          // White

  // Semantic Colors (derived from brand colors)
  static const Color background = white;
  static const Color surface = lightGray;
  static const Color onPrimary = white;
  static const Color onSurface = darkBlue;
  static const Color onBackground = darkBlue;
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);        // Green for success
  static const Color warning = Color(0xFFFF9800);        // Orange for warnings
  static const Color error = Color(0xFFF44336);          // Red for errors
  static const Color info = mediumBlue;                  // Medium blue for info
  
  // Text Colors
  static const Color textPrimary = darkBlue;
  static const Color textSecondary = Color(0xFF5A6B8C);  // Lighter version of dark blue
  static const Color textDisabled = Color(0xFF9E9E9E);   // Gray for disabled text
  
  // Card and Container Colors
  static const Color cardBackground = white;
  static const Color containerBackground = lightGray;
  
  // Teacher Colors (using primary palette)
  static const Color adminPrimary = primary;
  static const Color adminBackground = Color(0xFFF8F9FF);  // Very light blue
  static const Color adminCard = white;
  
  // Student Colors (using medium blue)
  static const Color studentPrimary = mediumBlue;
  static const Color studentBackground = Color(0xFFF0F4FB); // Very light blue-gray
  static const Color studentCard = white;
  
  // Game Colors
  static const Color gamePrimary = primary;
  static const Color gameBackground = background;
  static const Color gameCard = cardBackground;
  static const Color gameAccent = mediumBlue;
  
  /// Create MaterialColor from primary color for ColorScheme
  static const MaterialColor primaryMaterialColor = MaterialColor(
    0xFF0556BA,
    <int, Color>{
      50: Color(0xFFE8F0FD),
      100: Color(0xFFC6DAFB),
      200: Color(0xFF9FC1F8),
      300: Color(0xFF78A8F5),
      400: Color(0xFF5C95F3),
      500: Color(0xFF0556BA), // Primary
      600: Color(0xFF044FA8),
      700: Color(0xFF034594),
      800: Color(0xFF023B80),
      900: Color(0xFF01295E),
    },
  );
  
  /// Light color scheme
  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
    primary: primary,
    secondary: mediumBlue,
    surface: lightGray,
    background: background,
    onPrimary: onPrimary,
    onSecondary: white,
    onSurface: onSurface,
    onBackground: onBackground,
  );
  
  /// Dark color scheme
  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.dark,
    primary: mediumBlue,
    secondary: primary,
    surface: darkBlue,
    background: Color(0xFF121212),
    onPrimary: white,
    onSecondary: white,
    onSurface: lightGray,
    onBackground: lightGray,
  );
}