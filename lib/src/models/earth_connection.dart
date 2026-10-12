import 'package:flutter/material.dart';

/// A rendered elevated curve between two geographic node IDs.
///
/// The renderer caches a curved path, hides portions occluded by the sphere,
/// and optionally animates dashes or draws a direction arrow. Connections
/// whose endpoint IDs do not resolve to nodes are not drawn.
class GlobeConnection {
  /// Stable ID used to retain cached curve geometry across scene updates.
  final String id;

  /// ID of the node where the arc starts.
  final String fromId;

  /// ID of the node where the arc ends; the arrow points toward this endpoint.
  final String toId;

  /// Stroke color, defaulting to [Colors.cyanAccent].
  final Color color;

  /// Whether the stroke is a moving dashed line. Defaults to `false`.
  final bool isDashed;

  /// Whether to draw a direction arrow toward [toId]. Defaults to `false`.
  final bool showArrow;

  /// Stroke width in logical pixels. Defaults to 1.
  final double width;

  /// Creates a connection from [fromId] to [toId].
  ///
  /// Endpoint existence is checked during projection rather than at
  /// construction time.
  GlobeConnection({
    this.id = '',
    required this.fromId,
    required this.toId,
    this.color = Colors.cyanAccent,
    this.isDashed = false,
    this.showArrow = false,
    this.width = 1.0,
  });
}

/// Legacy API compatibility alias.
///
/// @deprecated Use [GlobeConnection] instead. This alias is retained for
/// backward compatibility.
@Deprecated('Use GlobeConnection instead.')
typedef EarthConnection = GlobeConnection;

/// Compatibility alias for the Sphere-prefixed API.
typedef SphereConnection = GlobeConnection;
