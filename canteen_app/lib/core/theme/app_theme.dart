import 'package:flutter/material.dart';

/// Material 3 inspired theme for Canteen App
/// Consistent design system with proper spacing, typography, and colors
class AppTheme {
  // ============================================================================
  // COLOR PALETTE
  // ============================================================================
  
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color deepOrange = Color(0xFFE55934);
  static const Color lightOrange = Color(0xFFFFF4F0);
  
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningAmber = Color(0xFFFFA726);
  static const Color errorRed = Color(0xFFE53935);
  static const Color infoBlue = Color(0xFF2196F3);
  
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);
  
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceGrey = Color(0xFFF5F5F5);
  static const Color borderGrey = Color(0xFFE0E0E0);
  
  // ============================================================================
  // SPACING SYSTEM
  // ============================================================================
  
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;
  
  // ============================================================================
  // BORDER RADIUS
  // ============================================================================
  
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusFull = 999.0;
  
  // ============================================================================
  // ELEVATION
  // ============================================================================
  
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  
  // ============================================================================
  // THEME DATA
  // ============================================================================
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    
    // Color Scheme
    colorScheme: const ColorScheme.light(
      primary: primaryOrange,
      primaryContainer: lightOrange,
      secondary: deepOrange,
      surface: surfaceWhite,
      error: errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      onError: Colors.white,
    ),
    
    // Scaffold
    scaffoldBackgroundColor: surfaceGrey,
    
    // App Bar
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: surfaceWhite,
      foregroundColor: textPrimary,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
    ),
    
    // Card
    cardTheme: CardThemeData(
      elevation: elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      color: surfaceWhite,
      margin: const EdgeInsets.symmetric(
        horizontal: space16,
        vertical: space8,
      ),
    ),
    
    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: elevationNone,
        padding: const EdgeInsets.symmetric(
          horizontal: space24,
          vertical: space16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    
    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: space16,
          vertical: space12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        foregroundColor: primaryOrange,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    
    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: space24,
          vertical: space16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        side: const BorderSide(color: primaryOrange, width: 1.5),
        foregroundColor: primaryOrange,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceWhite,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: space16,
        vertical: space16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: borderGrey, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: borderGrey, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: primaryOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: errorRed, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: errorRed, width: 2),
      ),
      labelStyle: const TextStyle(
        fontSize: 14,
        color: textSecondary,
      ),
      hintStyle: const TextStyle(
        fontSize: 14,
        color: textHint,
      ),
    ),
    
    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: surfaceGrey,
      selectedColor: lightOrange,
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: space12,
        vertical: space8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusFull),
      ),
    ),
    
    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: elevationMedium,
      backgroundColor: primaryOrange,
      foregroundColor: Colors.white,
    ),
    
    // Bottom Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceWhite,
      selectedItemColor: primaryOrange,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: elevationHigh,
      selectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),
    
    // Dialog
    dialogTheme: DialogThemeData(
      elevation: elevationHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
      ),
      backgroundColor: surfaceWhite,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    ),
    
    // Divider
    dividerTheme: const DividerThemeData(
      color: borderGrey,
      thickness: 1,
      space: space16,
    ),
  );
  
  // ============================================================================
  // TEXT STYLES
  // ============================================================================
  
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -1,
    height: 1.2,
  );
  
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  static const TextStyle titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.5,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.25,
  );
  
  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );
  
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.5,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.5,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: textHint,
    letterSpacing: 0.5,
  );
  
  // ============================================================================
  // SHADOWS
  // ============================================================================
  
  static List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> shadowStrong = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}
