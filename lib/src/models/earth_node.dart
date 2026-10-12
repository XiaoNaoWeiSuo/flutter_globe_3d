import 'package:flutter/material.dart';
import 'sphere_annotation.dart';

/// A geographic marker and its Flutter widget.
///
/// IDs must be unique within a controller. The widget stays a regular
/// interactive Flutter overlay; [type] selects whether it follows the surface
/// projection or is arranged as an external annotation.
class GlobeNode {
  /// Stable unique ID used to update a node and address connection endpoints.
  final String id;

  /// Geographic latitude in degrees, from -90 (south pole) to 90 (north pole).
  final double latitude;

  /// Geographic longitude in degrees; finite values wrap around the sphere.
  final double longitude;

  /// Interactive Flutter widget shown for this marker.
  final Widget child;

  /// Placement mode. Defaults to a widget centered at its projected surface
  /// point; annotation modes place it in a viewport-side column.
  final SphereNodeType type;

  /// Per-node annotation appearance and packing priority. Used by annotation
  /// modes; ignored for [SphereNodeType.surface].
  final SphereAnnotationStyle annotationStyle;

  /// Creates a marker at [latitude] and [longitude].
  ///
  /// Coordinate validity is checked when the controller computes the
  /// geographic position. Keep [id] stable when updating the node.
  GlobeNode({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.child,
    this.type = SphereNodeType.surface,
    this.annotationStyle = const SphereAnnotationStyle(),
  });

  /// Copies this node, preserving its [id] and any field not supplied.
  ///
  /// A non-null [child] replaces the current widget; use a stable Flutter key
  /// if its state should survive a type-preserving update.
  GlobeNode copyWith({
    double? latitude,
    double? longitude,
    Widget? child,
    SphereNodeType? type,
    SphereAnnotationStyle? annotationStyle,
  }) =>
      GlobeNode(
        id: id,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        child: child ?? this.child,
        type: type ?? this.type,
        annotationStyle: annotationStyle ?? this.annotationStyle,
      );
}

/// Legacy API compatibility alias.
///
/// @deprecated Use [GlobeNode] instead. This alias is retained for backward
/// compatibility.
@Deprecated('Use GlobeNode instead.')
typedef EarthNode = GlobeNode;

/// Compatibility alias for the Sphere-prefixed API.
typedef SphereNode = GlobeNode;
