import 'package:flutter/material.dart';

/// Murmur's colours, taken from the launcher icon (branding/legacy.svg), and
/// the app theme built from them. Refer to these instead of hard-coding
/// colours elsewhere.
abstract final class Brand {
  /// The icon's art: the main accent.
  static const lime = Color(0xFFD7FF3D);

  /// The icon's background: text on [lime], and the dark theme's surface.
  static const ink = Color(0xFF0F1012);

  /// Recording, and destructive actions in the dark theme: a warm coral-red
  /// with the same brightness as [lime].
  static const red = Color(0xFFFF5A4F);

  /// [red] darkened enough to read as text on a light background.
  static const redDeep = Color(0xFFC8352B);

  static ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    // Fidelity keeps the generated tones close to the lime; on white, lime
    // itself is too light for text, so the light theme keeps the darker
    // generated primary and uses lime only where it fills a shape.
    var colors = ColorScheme.fromSeed(
      seedColor: lime,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    colors = dark
        ? colors.copyWith(
            primary: lime,
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
