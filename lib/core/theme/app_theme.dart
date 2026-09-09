import 'package:flutter/material.dart';

/// Shared visual language for Android and iOS.
///
/// Design language: "Neon Mint" — a rich dark canvas with vibrant neon accents,
/// subtle glassmorphism surfaces, and generous spacing for a premium feel.
class AppColors {
  const AppColors._();

  // ── Canvas ──────────────────────────────────────────────────────────────
  static const ink = Color(0xFF060A0D);
  static const surface = Color(0xFF0D1117);
  static const surfaceRaised = Color(0xFF151B23);
  static const surfaceBright = Color(0xFF1C2430);
  static const surfaceGlass = Color(0x1AFFFFFF); // 10 % white overlay
  static const outline = Color(0xFF2A3441);
  static const outlineSubtle = Color(0xFF1E2732);

  // ── Neon Accent Palette ─────────────────────────────────────────────────
  static const neonMint = Color(0xFF00F5A0); // primary CTA
  static const neonMintDeep = Color(0xFF00C97B); // pressed / gradient end
  static const neonMintMuted = Color(0xFF7EDCB5); // secondary text
  static const neonCyan = Color(0xFF00D4FF); // info / links
  static const neonPurple = Color(0xFFB388FF); // charts accent 2
  static const neonPink = Color(0xFFFF6B9D); // charts accent 3
  static const neonAmber = Color(0xFFFFD166); // warnings

  // ── Legacy aliases (keeps existing references compiling) ────────────────
  static const green = neonMint;
  static const greenDeep = neonMintDeep;
  static const greenMuted = neonMintMuted;

  // ── Text ────────────────────────────────────────────────────────────────
  static const text = Color(0xFFF0F6FC);
  static const textMuted = Color(0xFF8B949E);
  static const textSubtle = Color(0xFF6E7681);

  // ── Semantic ────────────────────────────────────────────────────────────
  static const danger = Color(0xFFFF7B72);
  static const success = neonMint;
  static const warning = neonAmber;

  // ── Gradients ───────────────────────────────────────────────────────────
  static const mintGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonMint, neonCyan],
  );
  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF151B23), Color(0xFF0D1117)],
  );
  static const surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF111820), Color(0xFF0D1117)],
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: AppColors.neonMint,
      onPrimary: AppColors.ink,
      primaryContainer: Color(0xFF0A3D2A),
      onPrimaryContainer: Color(0xFFB6F4D3),
      secondary: AppColors.neonCyan,
      onSecondary: AppColors.ink,
      secondaryContainer: Color(0xFF0A2A3D),
      onSecondaryContainer: Color(0xFFB6E8F4),
      tertiary: AppColors.neonPurple,
      onTertiary: AppColors.ink,
      tertiaryContainer: Color(0xFF2A1A4D),
      onTertiaryContainer: Color(0xFFE0D0FF),
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.surfaceRaised,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineSubtle,
      error: AppColors.danger,
      onError: AppColors.ink,
      errorContainer: Color(0xFF4D1F1F),
      onErrorContainer: Color(0xFFFFDAD7),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ink,
      canvasColor: AppColors.ink,
      fontFamily: 'Noto Sans',
      textTheme: Typography.whiteMountainView.apply(
        fontFamily: 'Noto Sans',
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Noto Sans',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.outline.withValues(alpha: 0.6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.outline.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.neonMint, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        floatingLabelStyle: const TextStyle(color: AppColors.neonMint),
        hintStyle: TextStyle(
          color: AppColors.textMuted.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.neonMint,
          foregroundColor: AppColors.ink,
          disabledBackgroundColor: AppColors.surfaceBright,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size(double.infinity, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.neonMint,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: AppColors.neonMint.withValues(alpha: 0.4)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.neonCyan,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.neonMint,
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.neonMint : AppColors.textMuted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.ink : AppColors.textMuted,
            size: 22,
          );
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.neonMint,
        foregroundColor: AppColors.ink,
        elevation: 0,
        shape: CircleBorder(),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.outline.withValues(alpha: 0.4),
        thickness: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceBright,
        contentTextStyle: const TextStyle(color: AppColors.text, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceBright,
        selectedColor: AppColors.neonMint.withValues(alpha: 0.15),
        side: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
        labelStyle: const TextStyle(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.neonMint,
        linearTrackColor: Color(0xFF1C2430),
        linearMinHeight: 6,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textMuted,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        minVerticalPadding: 12,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
