import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Advanced Modern Design System for Marketplace-Level Expense Tracker
///
/// Features:
/// - Fintech-first color palette
/// - Glassmorphism support
/// - Sophisticated typography system
/// - Premium spacing and shape tokens
class AppDesignSystem {
  AppDesignSystem._();

  // ============================================================================
  // COLORS - PREMIUM PALETTE (Neo-Banking & Fintech)
  // ============================================================================

  // Core Brand Colors
  static const Color brandPrimary = Color(0xFF6366F1); // Electric Indigo
  static const Color brandSecondary = Color(0xFF10B981); // Emerald Mint
  static const Color brandAccent = Color(0xFFF59E0B); // Amber Sun
  static const Color brandInfo = Color(0xFF3B82F6); // Royal Blue

  // Functional Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Dark Neutrals (Fintech Dark Mode)
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkCanvas = Color(0xFF1E293B);
  static const Color darkSurface = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF475569);

  // Light Neutrals (Modern SaaS Look)
  static const Color lightBg = Color(
    0xFFF1F5F9,
  ); // Slightly deeper for contrast
  static const Color lightCanvas = Colors.white;
  static const Color lightSurface = Colors.white; // Use white for cards
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Text Colors
  static const Color textHigh = Color(0xFF1E293B);
  static const Color textMed = Color(0xFF64748B);
  static const Color textLow = Color(0xFF94A3B8);

  static const Color darkTextHigh = Color(0xFFF8FAFC);
  static const Color darkTextMed = Color(0xFFCBD5E1);
  static const Color darkTextLow = Color(0xFF64748B);

  // ============================================================================
  // GRADIENTS - LUXURY FINISH
  // ============================================================================

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0x1FFFFFFF), Color(0x0FFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================================
  // TYPOGRAPHY - MODERN HUD
  // ============================================================================

  static TextTheme createTextTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color color = isDark ? darkTextHigh : textHigh;
    final Color subColor = isDark ? darkTextMed : textMed;

    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -1.0,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: subColor,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: subColor,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  // ============================================================================
  // SPACING & RADIUS
  // ============================================================================

  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s48 = 48.0;

  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r24 = 24.0;
  static const double rFull = 99.0;

  static const double maxContentWidth =
      500.0; // Optimized for mobile-first feel on web/desktop

  // ============================================================================
  // SHADOWS - DEPTH & LAYERING
  // ============================================================================

  static List<BoxShadow> softShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.04),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];

  // ============================================================================
  // THEME DEFINITIONS
  // ============================================================================

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color background = isDark ? darkBg : lightBg;
    final Color canvas = isDark ? darkCanvas : lightCanvas;
    final Color primary = brandPrimary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: brandSecondary,
        onSecondary: Colors.white,
        error: error,
        onError: Colors.white,
        surface: canvas,
        onSurface: isDark ? darkTextHigh : textHigh,
        outline: isDark ? darkBorder : lightBorder,
      ),
      scaffoldBackgroundColor: background,
      textTheme: createTextTheme(brightness),
      cardTheme: CardThemeData(
        color: canvas,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r16),
          side: BorderSide(
            color: (isDark ? darkBorder : lightBorder).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
              ),
        iconTheme: IconThemeData(color: isDark ? darkTextHigh : textHigh),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? darkTextHigh : textHigh,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: canvas,
        selectedItemColor: primary,
        unselectedItemColor: isDark ? darkTextLow : textLow,
        type: BottomNavigationBarType.fixed,
        elevation: 20,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r16)),
      ),
    );
  }

  // LEGACY COMPATIBILITY (Temporary)
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static final BorderRadius borderRadiusMD = BorderRadius.circular(12);
  static final BorderRadius borderRadiusLG = BorderRadius.circular(16);
  static final BorderRadius borderRadiusXL = BorderRadius.circular(24);
  static final BorderRadius borderRadiusRound = BorderRadius.circular(99);
  static const double iconSizeSM = 20.0;
  static const double iconSizeMD = 24.0;
  static const double iconSizeLG = 32.0;
  static const double iconSizeXL = 48.0;
  static const EdgeInsets paddingMD = EdgeInsets.all(16);
  static const EdgeInsets paddingLG = EdgeInsets.all(24);
  static const EdgeInsets paddingVerticalMD = EdgeInsets.symmetric(
    vertical: 16,
  );
  static final List<BoxShadow> shadowMD = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}
