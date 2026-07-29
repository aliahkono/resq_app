import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ResQTheme {
  ResQTheme._();

  // ==========================================
  // 🎨 COLOR PALETTE TOKENS (FROM LOGO & FIGMA)
  // ==========================================

  // Primary Logo & Header Colors
  static const Color logoDeepMaroon = Color(0xFF5A080C); // Deep Maroon (Headers & Dark Splash)
  static const Color primaryCrimson = Color(0xFF9B1B20); // Primary CTAs, Buttons & Active Nav
  static const Color primaryCrimsonLight = Color(0xFF8B1218); // Darker Crimson for pressed states

  // Background & Card Surfaces
  static const Color bgOffWhite     = Color(0xFFF2F2F2); // App Scaffold Background
  static const Color surfaceWhite   = Color(0xFFFFFFFF); // Card & Input surface containers
  static const Color lightPinkTint  = Color(0xFFFDF0F0); // Subtle Crimson Tint for banners

  // Text & Border Colors
  static const Color textDark       = Color(0xFF1E1E1E); // Main body & headings
  static const Color textMuted      = Color(0xFF757575); // Subtitles & placeholders
  static const Color lightBorder    = Color(0xFFE0E0E0); // Card & Input borders

  // Status & Badge Colors
  static const Color statusGreen    = Color(0xFF059669); // "Eligible" status green
  static const Color statusGreenBg  = Color(0xFFE6F4EA); // Soft green pill background
  static const Color statusAmber    = Color(0xFFD97706); // "Ineligible / Rest Period" amber
  static const Color statusAmberBg  = Color(0xFFFEF3C7); // Soft amber pill background
  static const Color statusBlue     = Color(0xFF0284C7); // Information banner blue
  static const Color statusBlueBg   = Color(0xFFE0F2FE); // Soft blue banner background

  // ==========================================
  // 📐 SPACING & RADIUS CONSTANTS
  // ==========================================

  static const double cardRadius   = 16.0;
  static const double buttonRadius = 12.0;
  static const double inputRadius  = 12.0;
  static const String fontFamily   = 'Poppins'; // Using Poppins font

  // ==========================================
  // 🌊 GRADIENTS (HOW IT WORKS & SPLASH)
  // ==========================================

  /// Gradient background for the "How It Works" wavy banner behind illustrations
  static const LinearGradient howItWorksGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF8B1218), // Darker Crimson
      Color(0xFFC8232B), // Vibrant Crimson
      Color(0xFF7A0B10), // Deep Maroon tail
    ],
  );

  /// Dark Splash Screen Background Gradient (Phase 1 & Phase 2)
  static const LinearGradient splashDarkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF3B0306),
      Color(0xFF240003),
    ],
  );

  // ==========================================
  // 🔤 TYPOGRAPHY STYLES (POPPINS)
  // ==========================================

  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22.0,
    fontWeight: FontWeight.bold,
    color: textDark,
    height: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18.0,
    fontWeight: FontWeight.bold,
    color: textDark,
    height: 1.3,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    color: textDark,
  );

  static const TextStyle bodyText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.0,
    fontWeight: FontWeight.normal,
    color: textDark,
    height: 1.4,
  );

  static const TextStyle subText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.0,
    fontWeight: FontWeight.normal,
    color: textMuted,
  );

  // ==========================================
  // 🖼️ CUSTOM CARD DECORATIONS
  // ==========================================

  /// Standard white elevated card style
  static BoxDecoration cardDecoration = BoxDecoration(
    color: surfaceWhite,
    borderRadius: BorderRadius.circular(cardRadius),
    border: Border.all(color: lightBorder, width: 1.0),
    boxShadow: const [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.03),
        blurRadius: 10.0,
        offset: Offset(0, 4),
      ),
    ],
  );

  /// Crimson Hero Card Decoration (e.g. First-Time Donor Priority Banner)
  static BoxDecoration heroCrimsonCardDecoration = BoxDecoration(
    color: primaryCrimson,
    borderRadius: BorderRadius.circular(cardRadius),
    boxShadow: const [
      BoxShadow(
        color: Color.fromRGBO(155, 27, 32, 0.25),
        blurRadius: 12.0,
        offset: Offset(0, 4),
      ),
    ],
  );

  // ==========================================
  // 🔘 FLUTTER THEMEDATA CONFIGURATION
  // ==========================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryCrimson,
      scaffoldBackgroundColor: bgOffWhite,

      textTheme: GoogleFonts.poppinsTextTheme(),

      fontFamily: fontFamily,

      // App Bar Styling (Maroon header with white title & back icon)
      appBarTheme: const AppBarTheme(
        backgroundColor: logoDeepMaroon,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: surfaceWhite),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: surfaceWhite,
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
        ),
      ),

      // TextField & Form Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        hintStyle: const TextStyle(fontFamily: fontFamily, color: textMuted, fontSize: 13.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: lightBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: lightBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: primaryCrimson, width: 2.0),
        ),
      ),

      // Primary Button Styling (Crimson Red)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCrimson,
          foregroundColor: surfaceWhite,
          minimumSize: const Size(double.infinity, 48.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Secondary Button Styling
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryCrimson,
          minimumSize: const Size(double.infinity, 48.0),
          side: const BorderSide(color: primaryCrimson, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Bottom Navigation Bar Styling
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceWhite,
        selectedItemColor: primaryCrimson,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 10.0,
        selectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 11.0,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.normal,
          fontSize: 11.0,
        ),
      ),
    );
  }
}