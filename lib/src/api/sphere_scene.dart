import 'package:flutter/material.dart';
import '../models/sphere_annotation.dart' show SphereAnnotationStyle;
import 'sphere_values.dart';

/// Placement for a geographic widget marker.
enum SphereNodePlacement {
  /// Keep the widget centered on its visible sphere projection.
  surface,

  /// Pack the widget into the left or right viewport column.
  annotation,

  /// Pack the widget into one of four viewport corners.
  denseAnnotation,
}

/// A Flutter widget attached to a geographic point on the sphere.
///
/// The widget remains a normal interactive Flutter child. Surface placement
/// projects it over the sphere; annotation placements arrange it beside the
/// sphere without changing its geographic anchor.
class SphereNode {
  /// Stable unique identifier used by connections and incremental updates.
  final String id;

  /// Geographic location in degrees.
  final SphereCoordinate coordinate;

  /// Interactive Flutter widget to display.
  final Widget child;

  /// Surface, external, or dense external placement.
  final SphereNodePlacement placement;

  /// Per-node line appearance and overflow priority for annotation placement.
  final SphereAnnotationStyle annotationStyle;

  const SphereNode._({
    required this.id,
    required this.coordinate,
    required this.child,
    required this.placement,
    required this.annotationStyle,
  });

  /// Creates a widget centered on the projected surface point.
  const SphereNode.surface({
    required String id,
    required SphereCoordinate coordinate,
    required Widget child,
  }) : this._(
          id: id,
          coordinate: coordinate,
          child: child,
          placement: SphereNodePlacement.surface,
          annotationStyle: const SphereAnnotationStyle(),
        );

  /// Creates a viewport-column label with a leader line to the surface point.
  const SphereNode.annotation({
    required String id,
    required SphereCoordinate coordinate,
    required Widget child,
    SphereAnnotationStyle style = const SphereAnnotationStyle(),
  }) : this._(
          id: id,
          coordinate: coordinate,
          child: child,
          placement: SphereNodePlacement.annotation,
          annotationStyle: style,
        );

  /// Creates a label packed into one of the four viewport corners.
  const SphereNode.denseAnnotation({
    required String id,
    required SphereCoordinate coordinate,
    required Widget child,
    SphereAnnotationStyle style = const SphereAnnotationStyle(),
  }) : this._(
          id: id,
          coordinate: coordinate,
          child: child,
          placement: SphereNodePlacement.denseAnnotation,
          annotationStyle: style,
        );

  /// Copies this node, retaining [id] and every field not supplied.
  SphereNode copyWith({
    SphereCoordinate? coordinate,
    Widget? child,
    SphereNodePlacement? placement,
    SphereAnnotationStyle? annotationStyle,
  }) =>
      SphereNode._(
        id: id,
        coordinate: coordinate ?? this.coordinate,
        child: child ?? this.child,
        placement: placement ?? this.placement,
        annotationStyle: annotationStyle ?? this.annotationStyle,
      );
}

/// A curved connection between two node identifiers.
class SphereConnection {
  /// Stable unique connection identifier.
  final String id;

  /// ID of the node at the start of the arc.
  final String fromId;

  /// ID of the node at the end of the arc; an arrow points toward it.
  final String toId;

  /// Stroke color.
  final Color color;

  /// Stroke width in logical pixels.
  final double width;

  /// Whether to draw an animated dashed stroke.
  final bool isDashed;

  /// Whether to draw a direction arrow.
  final bool showArrow;

  /// Creates a connection. Both endpoint IDs must exist in the submitted node
  /// collection.
  const SphereConnection({
    required this.id,
    required this.fromId,
    required this.toId,
    this.color = Colors.cyanAccent,
    this.width = 1,
    this.isDashed = false,
    this.showArrow = false,
  });
}
