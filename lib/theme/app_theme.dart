import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeType {
  neumorphismWhite,
  darkSlate,
}

extension AppThemeTypeExtension on AppThemeType {
  String get displayName {
    switch (this) {
      case AppThemeType.neumorphismWhite:
        return 'White';
      case AppThemeType.darkSlate:
        return 'Dark';
    }
  }

  /// Representative background colour shown as a swatch in the toolbar.
  Color get previewColor {
    switch (this) {
      case AppThemeType.neumorphismWhite:
        return const Color(0xFFE0E5EC);
      case AppThemeType.darkSlate:
        return const Color(0xFF222222);
    }
  }
}

/// Centralised IDE theme that provides colours and neumorphic box decorations.
class AppTheme {
  final AppThemeType type;
  final Brightness brightness;

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color panelBorder;
  final Color accent;
  final Color accentLight;
  final Color success;
  final Color error;
  final Color warning;
  final Color info;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color editorBackground;
  final Color editorLineHighlight;
  final Color editorLineNumber;
  final Color terminalBackground;

  final Color outerShadowDark;
  final Color outerShadowLight;
  final Color innerShadowDark;

  const AppTheme({
    required this.type,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.panelBorder,
    required this.accent,
    required this.accentLight,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.editorBackground,
    required this.editorLineHighlight,
    required this.editorLineNumber,
    required this.terminalBackground,
    required this.outerShadowDark,
    required this.outerShadowLight,
    required this.innerShadowDark,
  });

  // ─── Theme Factories ──────────────────────────────────────────────

  static AppTheme neumorphismWhite() {
    return const AppTheme(
      type: AppThemeType.neumorphismWhite,
      brightness: Brightness.light,
      background: Color(0xFFE0E5EC),
      surface: Color(0xFFE0E5EC),
      surfaceVariant: Color(0xFFD1D9E6),
      panelBorder: Color(0xFFC0C9DB),
      accent: Color(0xFF5C6BC0),
      accentLight: Color(0xFF7986CB),
      success: Color(0xFF4CAF50),
      error: Color(0xFFF44336),
      warning: Color(0xFFFF9800),
      info: Color(0xFF03A9F4),
      textPrimary: Color(0xFF4A4A5A),
      textSecondary: Color(0xFF7A7A8A),
      textMuted: Color(0xFFA0A0B0),
      editorBackground: Color(0xFFE0E5EC),
      editorLineHighlight: Color(0xFFD1D9E6),
      editorLineNumber: Color(0xFFA0A0B0),
      terminalBackground: Color(0xFFE0E5EC),
      outerShadowDark: Color(0x99A3B1C6),
      outerShadowLight: Color(0xCCFFFFFF),
      innerShadowDark: Color(0x4DA3B1C6),
    );
  }

  static AppTheme darkSlate() {
    return const AppTheme(
      type: AppThemeType.darkSlate,
      brightness: Brightness.dark,
      background: Color(0xFF222222),
      surface: Color(0xFF222222),
      surfaceVariant: Color(0xFF1C1C1C),
      panelBorder: Color(0xFF333333),
      accent: Color(0xFF00E5FF),
      accentLight: Color(0xFF66EDFF),
      success: Color(0xFF00FF87),
      error: Color(0xFFFF2A5F),
      warning: Color(0xFFFFB000),
      info: Color(0xFF9D4EDD),
      textPrimary: Color(0xFFF1F5F9),
      textSecondary: Color(0xFFA1A1AA),
      textMuted: Color(0xFF52525B),
      editorBackground: Color(0xFF1E1E1E),
      editorLineHighlight: Color(0xFF2A2A2A),
      editorLineNumber: Color(0xFF666666),
      terminalBackground: Color(0xFF1A1A1A),
      outerShadowDark: Color(0x99000000),
      outerShadowLight: Color(0x1AFFFFFF),
      innerShadowDark: Color(0x66000000),
    );
  }




  static AppTheme fromType(AppThemeType type) {
    switch (type) {
      case AppThemeType.neumorphismWhite: return neumorphismWhite();
      case AppThemeType.darkSlate: return darkSlate();
    }
  }

  // ─── Neumorphism Helpers ────────────────────────────────────────
  
  BoxDecoration neumorphicOuter({double radius = 12}) => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: outerShadowDark,
        offset: const Offset(4, 4),
        blurRadius: 10,
      ),
      BoxShadow(
        color: outerShadowLight,
        offset: const Offset(-4, -4),
        blurRadius: 10,
      ),
    ],
  );

  BoxDecoration neumorphicInner({double radius = 12}) => BoxDecoration(
    color: surfaceVariant,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: outerShadowLight.withValues(alpha: 0.1)),
    boxShadow: [
      BoxShadow(
        color: innerShadowDark,
        offset: const Offset(2, 2),
        blurRadius: 6,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: outerShadowLight.withValues(alpha: 0.05),
        offset: const Offset(-2, -2),
        blurRadius: 4,
      )
    ],
  );

  // ─── Text styles ────────────────────────────────────────────────
  TextStyle get monoStyle => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        height: 1.5,
        color: textPrimary,
      );

  TextStyle get monoSmall => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        height: 1.4,
        color: textPrimary,
      );

  TextStyle get uiText => GoogleFonts.inter(
        fontSize: 13,
        color: textPrimary,
      );

  TextStyle get uiTextSmall => GoogleFonts.inter(
        fontSize: 12,
        color: textSecondary,
      );

  TextStyle get uiLabel => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: textMuted,
      );

  // ─── ThemeData ──────────────────────────────────────────────────
  ThemeData get themeData => ThemeData(
        brightness: brightness,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme(
          brightness: brightness,
          primary: accent,
          onPrimary: Colors.white,
          secondary: accentLight,
          onSecondary: Colors.white,
          error: error,
          onError: Colors.white,
          surface: surface,
          onSurface: textPrimary,
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
        dividerTheme: DividerThemeData(
          color: panelBorder,
          thickness: 1,
          space: 1,
        ),
        iconTheme: IconThemeData(color: textSecondary, size: 18),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: textPrimary,
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: uiTextSmall.copyWith(color: background),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(panelBorder),
          radius: const Radius.circular(4),
          thickness: WidgetStateProperty.all(6),
        ),
      );
}
