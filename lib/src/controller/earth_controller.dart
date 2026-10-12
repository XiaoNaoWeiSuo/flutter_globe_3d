import 'dart:math' as math;
import 'dart:collection';
import 'package:flutter/material.dart';
import '../models/earth_connection.dart';
import '../models/earth_node.dart';
import '../models/globe_vector3.dart';
import '../models/sphere_glow.dart';
import '../models/sphere_quality.dart';
import '../models/sphere_annotation.dart';
import 'globe_camera.dart';

/// Selects how the sphere's light direction is determined.
enum GlobeLightMode {
  /// Places the light toward the camera's upper-left to emphasize shape.
  followCamera,

  /// Approximates the subsolar point from the current UTC time.
  realTime,

  /// Uses coordinates last supplied to [GlobeController.setFixedLightCoordinates].
  fixedCoordinates,
}

/// Legacy API compatibility alias.
///
/// @deprecated Use [GlobeLightMode] instead. This alias is retained for
/// backward compatibility.
@Deprecated('Use GlobeLightMode instead.')
typedef EarthLightMode = GlobeLightMode;

/// Mutable state and commands for a [Globe3D] sphere.
///
/// The controller notifies listeners when a rendered property changes.
/// Create and dispose it with the owning application/widget State. Camera
/// coordinates and projected diagnostic maps use the sphere's world/view
/// conventions documented by [GlobeVector3] and [Globe3D].
class GlobeController extends ChangeNotifier {
  /// Lower clamp for programmatic and gesture zoom. Must remain finite and
  /// positive, and no greater than [maxZoom].
  double minZoom = 0.5;

  /// Upper clamp for programmatic and gesture zoom. Must be finite and at
  /// least [minZoom].
  double maxZoom = 3.0;
  bool _enableAutoRotate = true;

  /// Whether the sphere rotates horizontally while otherwise idle.
  /// Changing this value notifies listeners and starts/stops the widget ticker.
  bool get enableAutoRotate => _enableAutoRotate;

  /// Notifies the view so idle rendering can stop and resume its ticker.
  set enableAutoRotate(bool value) {
    if (_enableAutoRotate == value) return;
    _enableAutoRotate = value;
    notifyListeners();
  }

  /// Legacy rotation speed. One unit equals 60 logical pixels per second of
  /// orbit input; it is not an angular speed in degrees or radians per second.
  double rotateSpeed = 1.0;

  /// Whether user orbit input and inertial motion ignore vertical movement.
  bool lockNorthSouth = false;

  /// Whether zoom changes from gestures, [setZoom], focus, and overview are
  /// ignored (focus/overview retain the current zoom).
  bool lockZoom = false;

  SphereQuality _quality = SphereQuality.medium;

  /// Current shader sampling preset.
  SphereQuality get quality => _quality;

  /// Changes shader sampling quality immediately without resetting the camera.
  void setQuality(SphereQuality quality) {
    if (_quality == quality) return;
    _quality = quality;
    notifyListeners();
  }

  GlobeLightMode _lightMode = GlobeLightMode.realTime;

  double _fixedLightLat = 0.0;
  double _fixedLightLon = 0.0;

  /// Current light mode. Defaults to [GlobeLightMode.realTime].
  GlobeLightMode get lightMode => _lightMode;

  /// Latitude used by [GlobeLightMode.fixedCoordinates], in degrees.
  double get fixedLightLat => _fixedLightLat;

  /// Longitude used by [GlobeLightMode.fixedCoordinates], in degrees.
  double get fixedLightLon => _fixedLightLon;

  SphereGlowMode _glowMode = SphereGlowMode.automatic;
  SphereGlowStyle _glowStyle = const SphereGlowStyle();

  /// Current automatic/custom atmosphere mode.
  SphereGlowMode get glowMode => _glowMode;

  /// Stored custom appearance, retained when switching to automatic mode.
  SphereGlowStyle get glowStyle => _glowStyle;

  /// Selects how the atmosphere is rendered and notifies listeners on change.
  void setGlowMode(SphereGlowMode mode) {
    if (_glowMode == mode) return;
    _glowMode = mode;
    notifyListeners();
  }

  /// Updates the custom appearance without changing [glowMode].
  /// Width and intensity must be finite values from 0 to 1, inclusive.
  ///
  /// The style is retained when switching back to automatic mode. Updating it
  /// only triggers a repaint while custom mode is active.
  void setGlowStyle(SphereGlowStyle style) {
    if (!style.width.isFinite ||
        style.width < 0 ||
        style.width > 1 ||
        !style.intensity.isFinite ||
        style.intensity < 0 ||
        style.intensity > 1) {
      throw ArgumentError(
          'Glow width and intensity must be finite and between 0 and 1.');
    }
    if (_glowStyle == style) return;
    _glowStyle = style;
    if (_glowMode == SphereGlowMode.custom) notifyListeners();
  }

  final GlobeCamera _camera = GlobeCamera();
  Object? _cameraAnimationError;
  StackTrace? _cameraAnimationStackTrace;
  Offset _offset = Offset.zero;
  int _cameraFocusRevision = 0;
  int _cameraStateRevision = 0;

  /// Accumulated orbit input in logical pixels; not geographic coordinates.
  Offset get offset => _offset;

  /// Current camera zoom, clamped to [minZoom] and [maxZoom].
  double get zoom => _camera.zoom;

  /// Current camera position in world coordinates.
  GlobeVector3 get cameraPosition => _camera.position;

  /// Current world-space point at the center of the view.
  GlobeVector3 get cameraTarget => _camera.target;

  /// Current rendered sphere radius, used to normalize camera snapshots.
  double get cameraWorldRadius => _camera.radius;

  /// Takes the most recent animation error, if any.
  (Object, StackTrace?)? takeCameraAnimationError() {
    final error = _cameraAnimationError;
    if (error == null) return null;
    final result = (error, _cameraAnimationStackTrace);
    _cameraAnimationError = null;
    _cameraAnimationStackTrace = null;
    return result;
  }

  /// Current camera forward direction in world coordinates.
  GlobeVector3 get cameraForward => _camera.forward;

  /// Current camera right direction in world coordinates.
  GlobeVector3 get cameraRight => _camera.right;

  /// Current camera up direction in world coordinates.
  GlobeVector3 get cameraUp => _camera.up;

  /// Distance from [cameraPosition] to [cameraTarget].
  double get cameraDistance => _camera.distance;

  /// Whether a focus/overview camera transition is in progress.
  bool get isCameraAnimating => _camera.isAnimating;

  /// Increments for each focus or overview request; useful to identify a new
  /// camera command while observing controller changes.
  int get cameraFocusRevision => _cameraFocusRevision;

  /// Advances only when observable camera pose or animation state changes.
  int get cameraStateRevision => _cameraStateRevision;

  /// Mutable node list. Prefer [addNode] and [updateNode], which invalidate
  /// geometry caches and notify listeners; direct mutation is unsupported.
  final List<GlobeNode> _nodes = [];

  /// Mutable connection list. Prefer [connect]; direct mutation is unsupported.
  final List<GlobeConnection> _connections = [];

  /// Latest projected positions in viewport logical pixels (diagnostics).
  final Map<String, Offset> projectedPositions = {};

  /// Whether each node's geographic anchor is visible, not whether its label
  /// survived annotation packing (diagnostics).
  final Map<String, bool> nodeVisibility = {};
  final Map<String, SphereAnnotationPlacement> _annotationPlacements = {};

  /// Unmodifiable snapshot view of the latest annotation layout, in viewport
  /// logical pixels. An absent ID means the annotation is not currently shown.
  late final Map<String, SphereAnnotationPlacement> annotationPlacements =
      UnmodifiableMapView(_annotationPlacements);

  /// Updates an internal layout result. This is called by [Globe3D]; ordinary
  /// application code should read [annotationPlacements] instead.
  void updateAnnotationPlacements(
      Map<String, SphereAnnotationPlacement> placements) {
    _annotationPlacements
      ..clear()
      ..addAll(placements);
  }

  final Map<GlobeConnection, Path> _connectionPaths = {};

  // Static geometry cache. Node coordinates and connection control points do
  // not change while the camera is moving, so keep them in unit-sphere space
  // and only apply the current radius during projection.
  Map<String, (double, double)> _cachedNodeCoordinates = const {};
  Map<String, (String, String)> _cachedConnectionEndpoints = const {};
  bool _geometryCacheDirty = true;
  final Map<String, _Vector3> _unitNodePositions = {};
  final Map<String, List<_Vector3>> _unitConnectionCurves = {};

  /// Current nodes. Treat as read-only; use [addNode] and [updateNode] to make
  /// changes observable and refresh cached geometry.
  List<GlobeNode> get nodes => _nodes;

  /// Current connections. Treat as read-only; add connections with [connect].
  List<GlobeConnection> get connections => _connections;

  /// Latest projected connection paths in viewport logical pixels. This is a
  /// mutable rendering diagnostic; do not alter it.
  Map<GlobeConnection, Path> get connectionPaths => _connectionPaths;

  /// Selects the lighting mode and notifies listeners when it changes.
  void setLightMode(GlobeLightMode mode) {
    if (_lightMode == mode) return;
    _lightMode = mode;
    notifyListeners();
  }

  /// Sets the fixed light source's geographic coordinates, in degrees.
  ///
  /// The values are used only in [GlobeLightMode.fixedCoordinates].
  void setFixedLightCoordinates(double lat, double lon) {
    _fixedLightLat = lat;
    _fixedLightLon = lon;
    if (_lightMode == GlobeLightMode.fixedCoordinates) {
      notifyListeners();
    }
  }

  /// Immediately focuses the given surface point at the viewport center.
  ///
  /// Coordinates are degrees. [viewDirection] is local east/north/outward;
  /// [tangent], when supplied, is a world-space screen-up hint. If [zoom] is
  /// omitted, the current zoom is retained. This stops auto-rotation and
  /// clears any in-progress camera transition.
  void setCameraFocus(
    double lat,
    double lon, {
    GlobeVector3? tangent,
    GlobeVector3 viewDirection = const GlobeVector3(0, 0, 1),
    double? zoom,
  }) =>
      focusOnCoordinates(lat, lon,
          tangent: tangent,
          viewDirection: viewDirection,
          zoom: zoom,
          duration: Duration.zero);

  /// Applies an overview camera pose. Internal adapter used by Sphere API.
  void setCameraOverviewPose(
    double latitude,
    double longitude, {
    required GlobeVector3 viewDirection,
    GlobeVector3? tangent,
    required double zoom,
    required Duration duration,
    required Curve curve,
  }) {
    _camera.overviewFacing(
      latitude,
      longitude,
      viewDirection,
      tangent,
      lockZoom ? this.zoom : _clampZoom(zoom),
      duration,
      curve,
    );
    _cameraFocusRevision++;
    _cameraStateRevision++;
    enableAutoRotate = false;
    notifyListeners();
  }

  /// Applies an arbitrary world-space camera pose. Internal Sphere adapter.
  void setCameraWorldPose(
    GlobeVector3 target,
    GlobeVector3 direction,
    GlobeVector3 up, {
    required double zoom,
    required Duration duration,
    required Curve curve,
  }) {
    _camera.focusWorld(
      target,
      direction,
      up,
      lockZoom ? this.zoom : _clampZoom(zoom),
      duration,
      curve,
    );
    _cameraFocusRevision++;
    _cameraStateRevision++;
    enableAutoRotate = false;
    notifyListeners();
  }

  /// Focus a surface point and stop auto rotation until explicitly re-enabled.
  ///
  /// Animates until the given surface point is centered, then leaves
  /// auto-rotation disabled until explicitly re-enabled.
  ///
  /// Coordinates are degrees. [viewDirection] uses the target's local
  /// east/north/outward frame: `(0, 0, 1)` is front-on and `(-1, 0, 1)` is a
  /// 45-degree view from the west. [tangent] is an optional world-space
  /// screen-up hint controlling roll. The default [duration] is 900 ms and
  /// [curve] is [Curves.easeInOutCubic]. A new request retargets from the
  /// current pose. Invalid coordinates/vectors or zoom bounds throw
  /// [ArgumentError].
  void focusOnCoordinates(
    double lat,
    double lon, {
    GlobeVector3? tangent,
    GlobeVector3 viewDirection = const GlobeVector3(0, 0, 1),
    double? zoom,
    Duration duration = const Duration(milliseconds: 900),
    Curve curve = Curves.easeInOutCubic,
  }) {
    final targetZoom = lockZoom ? this.zoom : _clampZoom(zoom ?? this.zoom);
    _camera.focus(
        lat, lon, viewDirection, tangent, targetZoom, duration, curve);
    _cameraFocusRevision++;
    _cameraStateRevision++;
    enableAutoRotate = false;
    notifyListeners();
  }

  /// Moves the view target to the sphere center without restarting rotation.
  ///
  /// The current camera orientation is retained. Defaults to zoom 1, 900 ms,
  /// and [Curves.easeInOutCubic]. The command stops auto-rotation and clears
  /// prior inertia.
  void showOverview(
      {double zoom = 1,
      Duration duration = const Duration(milliseconds: 900),
      Curve curve = Curves.easeInOutCubic}) {
    _camera.overview(lockZoom ? this.zoom : _clampZoom(zoom), duration, curve);
    _cameraFocusRevision++;
    _cameraStateRevision++;
    enableAutoRotate = false;
    notifyListeners();
  }

  /// Advances an active camera transition by [delta].
  ///
  /// [Globe3D] calls this from its ticker; applications should not call it
  /// while the widget is mounted.
  void advanceCameraAnimation(Duration delta) {
    if (!_camera.isAnimating || delta <= Duration.zero) return;
    try {
      _camera.advance(delta);
    } catch (error, stackTrace) {
      _cameraAnimationError = error;
      _cameraAnimationStackTrace = stackTrace;
    }
    _cameraStateRevision++;
    notifyListeners();
  }

  /// Cancels a camera transition at its current pose. Does not restart
  /// auto-rotation.
  void cancelCameraAnimation() {
    if (!_camera.isAnimating) return;
    _camera.cancel();
    _cameraStateRevision++;
    notifyListeners();
  }

  /// Returns the unit-sphere world position for geographic coordinates in
  /// degrees. Latitude must be between -90 and 90; finite longitudes wrap
  /// around the sphere.
  GlobeVector3 worldPointForCoordinates(double lat, double lon) =>
      GlobeCamera.geographic(lat, lon);

  _Vector3 _coordinateToUnit(double lat, double lon) =>
      _native(worldPointForCoordinates(lat, lon));

  _Vector3 _native(GlobeVector3 value) => _Vector3(value.x, value.y, value.z);

  double _clampZoom(double value) {
    if (!value.isFinite ||
        !minZoom.isFinite ||
        !maxZoom.isFinite ||
        minZoom <= 0 ||
        maxZoom < minZoom) {
      throw ArgumentError('Zoom must be finite, with 0 < minZoom <= maxZoom.');
    }
    return value.clamp(minZoom, maxZoom);
  }

  /// Orbits by a screen-relative delta in logical pixels (positive X right,
  /// positive Y down). Preserves the current roll and focus pivot. Obeys
  /// [lockNorthSouth], cancels an active camera transition, and notifies
  /// listeners when movement is non-zero.
  void orbit(Offset delta) {
    if (!delta.dx.isFinite || !delta.dy.isFinite) return;
    final movement = Offset(delta.dx, lockNorthSouth ? 0 : delta.dy);
    if (movement == Offset.zero) return;
    // Screen Y points down, while a positive right-axis camera rotation
    // moves the visible surface up. Negate pitch so it follows the drag.
    _camera.orbit(-movement.dx / 200, -movement.dy / 200);
    _offset += movement;
    _cameraStateRevision++;
    notifyListeners();
  }

  /// Adds a node. IDs must be unique; a duplicate throws [ArgumentError].
  void addNode(GlobeNode node) {
    if (_nodes.any((existing) => existing.id == node.id)) {
      throw ArgumentError.value(node.id, 'node.id', 'Node IDs must be unique.');
    }
    _nodes.add(node);
    _invalidateGeometryCache();
    notifyListeners();
  }

  /// Replaces the complete declarative scene in one cache invalidation.
  void replaceScene(
    List<GlobeNode> nodes,
    List<GlobeConnection> connections,
  ) {
    final changed = !_sameScene(_nodes, nodes, _connections, connections);
    final pathsById = <String, Path>{
      for (final entry in _connectionPaths.entries) entry.key.id: entry.value,
    };
    _nodes
      ..clear()
      ..addAll(nodes);
    _connections
      ..clear()
      ..addAll(connections);
    _connectionPaths
      ..clear()
      ..addEntries(connections.map((connection) => MapEntry(
            connection,
            pathsById[connection.id] ?? Path(),
          )));
    if (!changed) return;
    _geometryCacheDirty = true;
    notifyListeners();
  }

  static bool _sameScene(
    List<GlobeNode> oldNodes,
    List<GlobeNode> newNodes,
    List<GlobeConnection> oldConnections,
    List<GlobeConnection> newConnections,
  ) {
    if (oldNodes.length != newNodes.length ||
        oldConnections.length != newConnections.length) {
      return false;
    }
    for (var i = 0; i < oldNodes.length; i++) {
      final a = oldNodes[i];
      final b = newNodes[i];
      final x = a.annotationStyle;
      final y = b.annotationStyle;
      if (a.id != b.id ||
          a.latitude != b.latitude ||
          a.longitude != b.longitude ||
          a.child != b.child ||
          a.type != b.type ||
          x.side != y.side ||
          x.maxWidth != y.maxWidth ||
          x.lineColor != y.lineColor ||
          x.lineWidth != y.lineWidth ||
          x.anchorRadius != y.anchorRadius ||
          x.priority != y.priority) {
        return false;
      }
    }
    for (var i = 0; i < oldConnections.length; i++) {
      final a = oldConnections[i];
      final b = newConnections[i];
      if (a.id != b.id ||
          a.fromId != b.fromId ||
          a.toId != b.toId ||
          a.color != b.color ||
          a.width != b.width ||
          a.isDashed != b.isDashed ||
          a.showArrow != b.showArrow) {
        return false;
      }
    }
    return true;
  }

  /// Replaces a node without changing its ID or the keyed child identity.
  /// Throws [ArgumentError] when the ID is not already present.
  void updateNode(GlobeNode node) {
    final index = _nodes.indexWhere((existing) => existing.id == node.id);
    if (index < 0) {
      throw ArgumentError.value(node.id, 'node.id', 'Unknown node.');
    }
    _nodes[index] = node;
    _invalidateGeometryCache();
    notifyListeners();
  }

  /// Adds a connection. Endpoints are resolved against current node IDs during
  /// projection; a connection with a missing endpoint is not drawn.
  void connect(GlobeConnection connection) {
    _connections.add(connection);
    _invalidateGeometryCache();
    notifyListeners();
  }

  /// Sets zoom, clamped to [minZoom] and [maxZoom]. Does nothing when
  /// [lockZoom] is true. Non-finite values or invalid bounds throw
  /// [ArgumentError]; a changed zoom cancels a camera transition.
  void setZoom(double value) {
    if (lockZoom) return;
    final next = _clampZoom(value);
    if (next == zoom) return;
    _camera.cancel();
    _camera.zoom = next;
    _cameraStateRevision++;
    notifyListeners();
  }

  /// Legacy orbit setter. Applies the difference from the current [offset] as
  /// a screen-relative orbit delta; it is not a geographic coordinate setter.
  void setOffset(Offset value) => orbit(value - _offset);

  /// Recomputes node projections and connection paths for a viewport.
  ///
  /// Called by [Globe3D] as part of rendering/layout. This advanced internal
  /// hook is not intended for normal application code; its results are
  /// available through the diagnostic projection maps.
  void updateProjections(Size screenSize, double scale, double renderTime) {
    projectedPositions.clear();
    nodeVisibility.clear();

    _ensureGeometryCache();

    final double sphereRadius = scale * 0.5;
    _camera.radius = sphereRadius;

    // CPU projection and the fragment shader consume the exact same camera
    // basis. This keeps interactive widgets and GPU pixels aligned while
    // allowing the camera to point at any world-space focus direction.
    final _Vector3 ro = _native(cameraPosition);
    final _Vector3 fwd = _native(cameraForward);
    final _Vector3 right = _native(cameraRight);
    final _Vector3 up = _native(cameraUp);

    for (var node in _nodes) {
      final unitPosition = _unitNodePositions[node.id];
      if (unitPosition == null) continue;

      final _Vector3 pWorld = unitPosition * sphereRadius;

      bool isSurfaceVisible =
          pWorld.normalize().dot((ro - pWorld).normalize()) > 0;

      Offset? screenPos;
      if (isSurfaceVisible) {
        screenPos = _project3DPoint(pWorld, ro, fwd, right, up, screenSize);
      }

      if (screenPos != null) {
        projectedPositions[node.id] = screenPos;
        nodeVisibility[node.id] = true;
      } else {
        nodeVisibility[node.id] = false;
      }
    }

    for (var conn in _connections) {
      final curve = _unitConnectionCurves[conn.id];
      if (curve == null) continue;

      final path = _connectionPaths[conn] ?? Path();
      path.reset();
      _connectionPaths[conn] = path;
      bool isFirstPoint = true;
      for (final unitPoint in curve) {
        final _Vector3 pCurve = unitPoint * sphereRadius;
        if (_isOccluded(pCurve, ro, sphereRadius)) {
          isFirstPoint = true;
          continue;
        }
        Offset? sPos = _project3DPoint(pCurve, ro, fwd, right, up, screenSize);
        if (sPos != null) {
          if (isFirstPoint) {
            path.moveTo(sPos.dx, sPos.dy);
            isFirstPoint = false;
          } else {
            path.lineTo(sPos.dx, sPos.dy);
          }
        } else {
          isFirstPoint = true;
        }
      }
    }
  }

  void _invalidateGeometryCache() {
    _cachedNodeCoordinates = const {};
    _cachedConnectionEndpoints = const {};
    _unitNodePositions.clear();
    _unitConnectionCurves.clear();
    _geometryCacheDirty = true;
  }

  void _ensureGeometryCache() {
    if (!_geometryCacheDirty) return;
    _geometryCacheDirty = false;
    final coordinates = <String, (double, double)>{
      for (final node in _nodes) node.id: (node.latitude, node.longitude),
    };
    final nodeGeometryChanged = coordinates.length !=
            _cachedNodeCoordinates.length ||
        coordinates.entries
            .any((entry) => _cachedNodeCoordinates[entry.key] != entry.value);
    if (nodeGeometryChanged) {
      _unitNodePositions
        ..clear()
        ..addEntries(_nodes.map((node) => MapEntry(
              node.id,
              _coordinateToUnit(node.latitude, node.longitude),
            )));
      _unitConnectionCurves.clear();
      _cachedConnectionEndpoints = const {};
      _cachedNodeCoordinates = coordinates;
    }

    final endpoints = <String, (String, String)>{
      for (final connection in _connections)
        connection.id: (connection.fromId, connection.toId),
    };
    _unitConnectionCurves.removeWhere((id, _) => !endpoints.containsKey(id));
    final previousEndpoints = _cachedConnectionEndpoints;
    for (final connection in _connections) {
      if (previousEndpoints[connection.id] == endpoints[connection.id] &&
          _unitConnectionCurves.containsKey(connection.id)) {
        continue;
      }
      final p1 = _unitNodePositions[connection.fromId];
      final p2 = _unitNodePositions[connection.toId];
      if (p1 == null || p2 == null) {
        _unitConnectionCurves.remove(connection.id);
        continue;
      }

      final distance = (p1 - p2).length;
      var midpoint = (p1 + p2) * 0.5;
      final archFactor = 1.0 + distance * 0.8;
      if (midpoint.length < 0.001) midpoint = p1;
      final control = midpoint.normalize() * archFactor;
      const steps = 30;
      _unitConnectionCurves[connection.id] =
          List<_Vector3>.generate(steps + 1, (i) {
        final t = i / steps;
        final a = (1 - t) * (1 - t);
        final b = 2 * (1 - t) * t;
        final c = t * t;
        return p1 * a + control * b + p2 * c;
      }, growable: false);
    }
    _cachedConnectionEndpoints = endpoints;
  }

  Offset? _project3DPoint(
    _Vector3 p,
    _Vector3 ro,
    _Vector3 fwd,
    _Vector3 right,
    _Vector3 up,
    Size size,
  ) {
    _Vector3 pRel = p - ro;
    double dist = pRel.dot(fwd);
    if (dist <= 0) return null;
    double u = pRel.dot(right) / dist;
    double v = pRel.dot(up) / dist;
    double x = (u * size.height) + size.width / 2;
    double y = size.height / 2 - (v * size.height);
    return Offset(x, y);
  }

  bool _isOccluded(_Vector3 p, _Vector3 ro, double radius) {
    final delta = p - ro;
    final distance = delta.length;
    if (distance == 0) return false;
    final direction = delta.normalize();
    final b = ro.dot(direction);
    final h = b * b - ro.dot(ro) + radius * radius;
    if (h <= 0) return false;
    final hit = -b - math.sqrt(h);
    final epsilon = math.max(radius * 1e-5, 1e-7);
    return hit > epsilon && hit < distance - epsilon;
  }
}

/// Legacy API compatibility alias.
///
/// @deprecated Use [GlobeController] instead. This alias is retained for
/// backward compatibility.
@Deprecated('Use GlobeController instead.')
typedef EarthController = GlobeController;

class _Vector3 {
  final double x, y, z;
  _Vector3(this.x, this.y, this.z);
  _Vector3 operator +(_Vector3 o) => _Vector3(x + o.x, y + o.y, z + o.z);
  _Vector3 operator -(_Vector3 o) => _Vector3(x - o.x, y - o.y, z - o.z);
  _Vector3 operator *(double s) => _Vector3(x * s, y * s, z * s);
  double dot(_Vector3 o) => x * o.x + y * o.y + z * o.z;
  _Vector3 cross(_Vector3 o) =>
      _Vector3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  _Vector3 normalize() {
    double l = length;
    return l == 0 ? this : _Vector3(x / l, y / l, z / l);
  }
}

/// Compatibility alias for the Sphere-prefixed controller API.
typedef SphereController = GlobeController;

/// Compatibility alias for [GlobeLightMode].
typedef SphereLightMode = GlobeLightMode;
