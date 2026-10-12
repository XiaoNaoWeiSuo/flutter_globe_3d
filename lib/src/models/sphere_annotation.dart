import 'package:flutter/painting.dart';

/// Controls where a node's Flutter widget is placed. All modes retain the same
/// geographic anchor for visibility and connection geometry.
enum SphereNodeType {
  /// Centers the widget on its projected point on the visible sphere.
  surface,

  /// Places widgets in a left or right viewport column with a leader line.
  annotation,

  /// Packs widgets into one of four viewport corners, with routed leader lines.
  denseAnnotation,
}

/// Preferred viewport side for an external annotation.
enum SphereAnnotationSide {
  /// Chooses a side from the anchor's position, with a center dead zone.
  automatic,

  /// Places the label in the left column/corners.
  left,

  /// Places the label in the right column/corners.
  right,
}

/// Per-node appearance and priority for external annotation placement.
class SphereAnnotationStyle {
  /// Preferred viewport side. Defaults to automatic selection.
  final SphereAnnotationSide side;

  /// Maximum label width in logical pixels. The actual available width may be
  /// smaller due to viewport bounds and column spacing.
  final double maxWidth;

  /// Color of the leader line and anchor marker.
  final Color lineColor;

  /// Leader-line stroke width in logical pixels; zero hides the line.
  final double lineWidth;

  /// Anchor marker radius in logical pixels; zero hides the marker.
  final double anchorRadius;

  /// Higher values are retained first when a column/corner lacks room.
  final int priority;

  /// Creates an annotation style. Width must be positive; line width and
  /// anchor radius must be non-negative. These constraints are debug asserts.
  const SphereAnnotationStyle({
    this.side = SphereAnnotationSide.automatic,
    this.maxWidth = 120,
    this.lineColor = const Color(0xFF55D6D2),
    this.lineWidth = 1,
    this.anchorRadius = 2.5,
    this.priority = 0,
  })  : assert(maxWidth > 0 && maxWidth < double.infinity),
        assert(lineWidth >= 0 && lineWidth < double.infinity),
        assert(anchorRadius >= 0 && anchorRadius < double.infinity);

  @override
  bool operator ==(Object other) =>
      other is SphereAnnotationStyle &&
      other.side == side &&
      other.maxWidth == maxWidth &&
      other.lineColor == lineColor &&
      other.lineWidth == lineWidth &&
      other.anchorRadius == anchorRadius &&
      other.priority == priority;

  @override
  int get hashCode =>
      Object.hash(side, maxWidth, lineColor, lineWidth, anchorRadius, priority);
}

/// Viewport-relative spacing for annotation labels, in logical pixels.
class SphereAnnotationLayout {
  /// Insets labels from the viewport edges.
  final EdgeInsets padding;

  /// Minimum vertical space between packed label rows.
  final double rowGap;

  /// Minimum horizontal gap between left and right label columns.
  final double columnGap;

  /// Hysteresis in logical pixels around the viewport center before automatic
  /// side/corner assignment switches. Prevents flicker near the center line.
  final double sideSwitchThreshold;

  /// Creates annotation spacing. Gaps and side threshold must be non-negative;
  /// these constraints are debug asserts.
  const SphereAnnotationLayout({
    this.padding = const EdgeInsets.all(12),
    this.rowGap = 8,
    this.columnGap = 16,
    this.sideSwitchThreshold = 16,
  })  : assert(rowGap >= 0 && rowGap < double.infinity),
        assert(columnGap >= 0 && columnGap < double.infinity),
        assert(
            sideSwitchThreshold >= 0 && sideSwitchThreshold < double.infinity);

  @override
  bool operator ==(Object other) =>
      other is SphereAnnotationLayout &&
      other.padding == padding &&
      other.rowGap == rowGap &&
      other.columnGap == columnGap &&
      other.sideSwitchThreshold == sideSwitchThreshold;

  @override
  int get hashCode =>
      Object.hash(padding, rowGap, columnGap, sideSwitchThreshold);
}

/// Last computed viewport placement for an annotation node.
///
/// Coordinates are logical pixels local to the sphere widget. A node without
/// a placement entry is currently hidden, occluded, outside the viewport, or
/// omitted because of packing overflow.
class SphereAnnotationPlacement {
  /// Projected geographic anchor in viewport coordinates.
  final Offset anchor;

  /// Bounding rectangle of the label widget in viewport coordinates.
  final Rect labelRect;

  /// Assigned side or side class for this label.
  final SphereAnnotationSide side;

  /// Immutable points of the leader polyline in viewport coordinates.
  final List<Offset> leaderPoints;

  /// Creates a placement snapshot. [leaderPoints] is copied and made
  /// unmodifiable.
  SphereAnnotationPlacement({
    required this.anchor,
    required this.labelRect,
    required this.side,
    required List<Offset> leaderPoints,
  }) : leaderPoints = List.unmodifiable(leaderPoints);
}
