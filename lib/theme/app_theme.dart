import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised IDE theme — VS Code-inspired dark palette.
///
/// All colours, text styles, and component themes live here so they can be
/// referenced from any widget without scattering magic values.
class AppTheme {
  AppTheme._();

  // ─── Core palette ───────────────────────────────────────────────
  static const Color background = Color(0xFF1E1E2E);
  static const Color surface = Color(0xFF252536);
  static const Color surfaceVariant = Color(0xFF2D2D44);
  static const Color panelBorder = Color(0xFF3B3B54);
  static const Color accent = Color(0xFF7C3AED);      // vibrant purple
  static const Color accentLight = Color(0xFF9F67FF);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF06B6D4);         // cyan – used for AI output
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // ─── Editor-specific colours ────────────────────────────────────
  static const Color editorBackground = Color(0xFF1A1A2E);
  static const Color editorLineHighlight = Color(0xFF2A2A3E);
  static const Color editorLineNumber = Color(0xFF64748B);
  static const Color terminalBackground = Color(0xFF0F0F1A);

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
