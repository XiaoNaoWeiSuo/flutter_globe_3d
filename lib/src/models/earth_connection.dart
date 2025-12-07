import 'package:flutter/material.dart';

/// Represents a visual connection (line) between two markers on the globe.
///
/// Use `startId` and `endId` to reference `EarthMarker.id` values.
class EarthConnection {
  /// ID of the start marker.
  final String startId;

  /// ID of the end marker.
  final String endId;

  /// Color of the connection line.
  final Color color;

  /// Stroke width of the connection line.
  final double width;

  /// Reserved for future support for arrows.
  final bool isArrows; // 预留扩展：是否显示箭头

  /// Creates an [EarthConnection].
  const EarthConnection({
    required this.startId,
    required this.endId,
    this.color = Colors.lightBlueAccent,
    this.width = 1.5,
    this.isArrows = false,
  });
}
