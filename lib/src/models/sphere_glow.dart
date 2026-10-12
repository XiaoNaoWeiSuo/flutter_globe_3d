import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Selects automatic or explicitly configured sphere atmosphere rendering.
enum SphereGlowMode {
  /// Blue atmosphere that adapts to magnification and sunlight.
  automatic,

  /// Uses the configured color, width and intensity without automatic tuning.
  custom,
}

/// Appearance of a custom atmosphere used by the renderer's configuration
/// adapter while [SphereGlowMode.custom] is selected.
@immutable
class SphereGlowStyle {
  /// Atmosphere color, including opacity.
  final Color color;

  /// Outer glow thickness as a fraction of the sphere radius, from 0 to 1.
  /// Zero removes the outer glow; the surface rim can still be visible.
  final double width;

  /// Atmosphere strength from 0 to 1. Zero disables both glow and surface rim.
  final double intensity;

  /// Creates a custom appearance. Range checking is performed when the style
  /// is submitted to a [SphereView], not by this value constructor.
  const SphereGlowStyle({
    this.color = const Color(0xFF6699FF),
    this.width = 0.6,
    this.intensity = 0.8,
  });

  /// Returns a copy, retaining every field whose argument is `null`.
  SphereGlowStyle copyWith({Color? color, double? width, double? intensity}) =>
      SphereGlowStyle(
        color: color ?? this.color,
        width: width ?? this.width,
        intensity: intensity ?? this.intensity,
      );

  /// Whether all style fields are equal.
  @override
  bool operator ==(Object other) =>
      other is SphereGlowStyle &&
      other.color == color &&
      other.width == width &&
      other.intensity == intensity;

  /// Hash consistent with [operator ==].
  @override
  int get hashCode => Object.hash(color, width, intensity);
}
