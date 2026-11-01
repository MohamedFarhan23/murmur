import 'package:flutter/material.dart';

/// Murmur's colours, taken from the launcher icon (branding/legacy.svg), and
/// the app theme built from them. Refer to these instead of hard-coding
/// colours elsewhere.
abstract final class Brand {
  /// The icon's wave and sparkle: the main accent.
  static const violet = Color(0xFFA78BFA);

  /// The icon's lips.
  static const mist = Color(0xFFECE8F6);

  /// The icon's background: text on [violet], and the dark theme's surface.
  static const ink = Color(0xFF110E1C);

  /// Recording, and destructive actions in the dark theme: a warm coral-red
  /// that stands apart from [violet].
  static const red = Color(0xFFFF5A4F);

  /// [red] darkened enough to read as text on a light background.
  static const redDeep = Color(0xFFC8352B);

  static ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    // Fidelity keeps the generated tones close to the violet; on white, violet
    // itself is too light for text, so the light theme keeps the darker
    // generated primary and uses violet only where it fills a shape.
    var colors = ColorScheme.fromSeed(
      seedColor: violet,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    colors = dark
        ? colors.copyWith(
            primary: violet,
            onPrimary: ink,
            surface: ink,
            error: red,
            onError: ink,
          )
        : colors.copyWith(error: redDeep, onError: Colors.white);
    return ThemeData(
      colorScheme: colors,
      fontFamily: 'Inter',
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
