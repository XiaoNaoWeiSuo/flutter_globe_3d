import 'package:flutter/material.dart';

/// A visual marker placed on the globe at a given latitude/longitude.
///
/// Provide a unique `id` so markers can be referenced by `EarthConnection`.
class EarthMarker {
  /// Unique identifier for this marker.
  final String id;

  /// Latitude in degrees (-90..90).
  final double latitude;

  /// Longitude in degrees (-180..180).
  final double longitude;

  /// Widget used to render the marker (e.g. a small circle).
  final Widget child;

  /// Optional text label shown under the marker when visible.
  final String? label;

  /// Optional tap callback when the marker is tapped.
  final VoidCallback? onTap;

  /// Creates an [EarthMarker].
  const EarthMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.child,
    this.label,
    this.onTap,
  });
}
