import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised IDE theme — VS Code-inspired dark palette.
///
/// All colours, text styles, and component themes live here so they can be
/// referenced from any widget without scattering magic values.
class AppTheme {
  AppTheme._();

  // ─── Core palette ───────────────────────────────────────────────
  static const Color background = Color(0xFF0D0D14); // Ultra-deep space black/blue
  static const Color surface = Color(0xFF161622);    // Slightly elevated surface
  static const Color surfaceVariant = Color(0xFF1C1C2A); // Hover states and active items
  static const Color panelBorder = Color(0xFF26263B);
  static const Color accent = Color(0xFF00E5FF);     // Vibrant cyan/neon blue
  static const Color accentLight = Color(0xFF66EDFF);
  static const Color success = Color(0xFF00FF87);    // Neon green
  static const Color error = Color(0xFFFF2A5F);      // Vibrant pink/red
  static const Color warning = Color(0xFFFFB000);
  static const Color info = Color(0xFF9D4EDD);       // Deep purple
  
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF52525B);

  // ─── Editor-specific colours ────────────────────────────────────
  static const Color editorBackground = Color(0xFF09090E); // Darkest shade for focus
  static const Color editorLineHighlight = Color(0xFF13131D);
  static const Color editorLineNumber = Color(0xFF47475A);
  static const Color terminalBackground = Color(0xFF0A0A10);
  
  // ─── Glassmorphism Helpers ──────────────────────────────────────
  static Color get glassSurface => surface.withValues(alpha: 0.7);
  static Color get glassBorder => Colors.white.withValues(alpha: 0.05);

  // ─── Text styles ────────────────────────────────────────────────
  static TextStyle get monoStyle => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        height: 1.5,
        color: textPrimary,
      );

  static TextStyle get monoSmall => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        height: 1.4,
        color: textPrimary,
      );

  static TextStyle get uiText => GoogleFonts.inter(
        fontSize: 13,
        color: textPrimary,
      );

  static TextStyle get uiTextSmall => GoogleFonts.inter(
        fontSize: 12,
        color: textSecondary,
      );

  static TextStyle get uiLabel => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: textMuted,
      );

  // ─── ThemeData ──────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accentLight,
          surface: surface,
          error: error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: textPrimary,
          onError: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: surface,
          foregroundColor: textPrimary,
          elevation: 0,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: panelBorder,
          thickness: 1,
          space: 1,
        ),
        iconTheme: const IconThemeData(color: textSecondary, size: 18),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: panelBorder),
          ),
          textStyle: uiTextSmall,
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(panelBorder),
          radius: const Radius.circular(4),
          thickness: WidgetStateProperty.all(6),
        ),
      );
}
