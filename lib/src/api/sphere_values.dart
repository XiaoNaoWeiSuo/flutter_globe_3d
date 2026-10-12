import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A geographic coordinate in degrees.
///
/// Latitude must be finite and between -90 and 90 degrees. Longitude is
/// normalized to the half-open range -180 to 180 degrees when read.
@immutable
class SphereCoordinate {
  final double latitude;
  final double _longitude;

  const SphereCoordinate({required this.latitude, required double longitude})
      : _longitude = longitude,
        assert(latitude >= -90 && latitude <= 90),
        assert(
            longitude > double.negativeInfinity && longitude < double.infinity);

  /// Normalized longitude in degrees, from -180 inclusive to 180 exclusive.
  double get longitude {
    final wrapped = (_longitude + 180) % 360;
    return (wrapped < 0 ? wrapped + 360 : wrapped) - 180;
  }

  /// Position on the unit sphere in right-handed world XYZ coordinates.
  SphereVector3 toWorldPoint() {
    _validate();
    final latitudeRadians = latitude * math.pi / 180;
    final longitudeRadians = longitude * math.pi / 180;
    return SphereVector3(
      math.cos(latitudeRadians) * math.sin(longitudeRadians),
      math.sin(latitudeRadians),
      math.cos(latitudeRadians) * math.cos(longitudeRadians),
    );
  }

  void _validate() {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'Must be in [-90, 90].');
    }
    if (!_longitude.isFinite) {
      throw ArgumentError.value(_longitude, 'longitude', 'Must be finite.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SphereCoordinate &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() =>
      'SphereCoordinate(latitude: $latitude, longitude: $longitude)';
}

/// A vector in the sphere's right-handed world XYZ coordinates.
///
/// +X points to the equator at east longitude 90°, +Y to the north pole, and
/// +Z to the equator at longitude 0° (Greenwich).
@immutable
class SphereVector3 {
  /// X component.
  final double x;

  /// Y component.
  final double y;

  /// Z component.
  final double z;

  /// Creates a world-space vector.
  const SphereVector3(this.x, this.y, this.z);

  /// Zero vector.
  static const zero = SphereVector3(0, 0, 0);

  /// Whether every component is finite.
  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;

  /// Euclidean length.
  double get length => math.sqrt(x * x + y * y + z * z);

  /// Returns a normalized vector; a zero vector remains zero.
  SphereVector3 normalized() {
    final largest = math.max(x.abs(), math.max(y.abs(), z.abs()));
    if (largest == 0) return this;
    final sx = x / largest;
    final sy = y / largest;
    final sz = z / largest;
    final scaledLength = math.sqrt(sx * sx + sy * sy + sz * sz);
    return SphereVector3(
        sx / scaledLength, sy / scaledLength, sz / scaledLength);
  }

  /// Dot product.
  double dot(SphereVector3 other) => x * other.x + y * other.y + z * other.z;

  /// Right-handed cross product.
  SphereVector3 cross(SphereVector3 other) => SphereVector3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  /// Removes the component parallel to [normal].
  SphereVector3 projectOnPlane(SphereVector3 normal) {
    final unit = normal.normalized();
    return this - unit * dot(unit);
  }

  /// Vector addition.
  SphereVector3 operator +(SphereVector3 other) =>
      SphereVector3(x + other.x, y + other.y, z + other.z);

  /// Vector subtraction.
  SphereVector3 operator -(SphereVector3 other) =>
      SphereVector3(x - other.x, y - other.y, z - other.z);

  /// Reverses the vector.
  SphereVector3 operator -() => SphereVector3(-x, -y, -z);

  /// Scales all components.
  SphereVector3 operator *(double scalar) =>
      SphereVector3(x * scalar, y * scalar, z * scalar);

  /// Divides all components.
  SphereVector3 operator /(double scalar) =>
      SphereVector3(x / scalar, y / scalar, z / scalar);

  @override
  bool operator ==(Object other) =>
      other is SphereVector3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'SphereVector3($x, $y, $z)';
}

/// A camera direction relative to a surface point.
///
/// Bearing is clockwise from local north: north 0°, east 90°, south 180°,
/// west 270°. Tilt is measured away from the outward surface normal. Positive
/// roll turns the view clockwise on screen.
@immutable
class SphereViewAngle {
  /// Angle away from the surface normal. Zero is front-on; must be in
  /// [0, 90) degrees.
  final double tiltDegrees;

  /// Bearing in the target's local tangent plane. Values wrap by 360°.
  final double bearingDegrees;

  /// Clockwise screen roll in degrees. Values wrap by 360°.
  final double rollDegrees;

  /// Creates an angle from degrees. The tilt must be finite and in [0, 90).
  const SphereViewAngle({
    this.tiltDegrees = 0,
    this.bearingDegrees = 0,
    this.rollDegrees = 0,
  })  : assert(tiltDegrees >= 0 && tiltDegrees < 90),
        assert(bearingDegrees > double.negativeInfinity &&
            bearingDegrees < double.infinity),
        assert(rollDegrees > double.negativeInfinity &&
            rollDegrees < double.infinity);

  /// Front-on view, north-up.
  const SphereViewAngle.front({this.rollDegrees = 0})
      : tiltDegrees = 0,
        bearingDegrees = 0;

  /// View from the west/left of the target.
  const SphereViewAngle.left({
    required this.tiltDegrees,
    this.rollDegrees = 0,
  }) : bearingDegrees = 270;

  /// View from the northwest/upper-left of the target.
  const SphereViewAngle.upperLeft({
    required this.tiltDegrees,
    this.rollDegrees = 0,
  }) : bearingDegrees = 315;

  /// Creates an angle from a local east/north/outward direction vector.
  factory SphereViewAngle.fromLocalVector(
    SphereVector3 direction, {
    double rollDegrees = 0,
  }) {
    if (!direction.isFinite || direction.length == 0 || direction.z <= 0) {
      throw ArgumentError.value(direction, 'direction',
          'Must be finite, nonzero, and point outward.');
    }
    final unit = direction.normalized();
    final tilt = math.acos(unit.z.clamp(-1.0, 1.0)) * 180 / math.pi;
    final bearing = math.atan2(unit.x, unit.y) * 180 / math.pi;
    return SphereViewAngle(
      tiltDegrees: tilt,
      bearingDegrees: bearing,
      rollDegrees: rollDegrees,
    );
  }

  /// Unit direction in the target's local east/north/outward frame.
  SphereVector3 get localDirection {
    _validate();
    final tilt = tiltDegrees * math.pi / 180;
    final bearing = _wrap(bearingDegrees) * math.pi / 180;
    final horizontal = math.sin(tilt);
    return SphereVector3(
      horizontal * math.sin(bearing),
      horizontal * math.cos(bearing),
      math.cos(tilt),
    );
  }

  /// Creates the local tangent-plane up hint for this roll.
  SphereVector3 localUpHint(SphereCoordinate target) {
    _validate();
    target._validate();
    final longitude = target.longitude * math.pi / 180;
    final east = SphereVector3(math.cos(longitude), 0, -math.sin(longitude));
    final normal = target.toWorldPoint();
    final north = normal.cross(east).normalized();
    final roll = _wrap(rollDegrees) * math.pi / 180;
    return north * math.cos(roll) - east * math.sin(roll);
  }

  void _validate() {
    if (!tiltDegrees.isFinite || tiltDegrees < 0 || tiltDegrees >= 90) {
      throw ArgumentError.value(
          tiltDegrees, 'tiltDegrees', 'Must be in [0, 90).');
    }
    if (!bearingDegrees.isFinite || !rollDegrees.isFinite) {
      throw ArgumentError('Bearing and roll must be finite.');
    }
  }

  static double _wrap(double value) {
    final wrapped = value % 360;
    return wrapped < 0 ? wrapped + 360 : wrapped;
  }

  @override
  bool operator ==(Object other) =>
      other is SphereViewAngle &&
      other.tiltDegrees == tiltDegrees &&
      _wrap(other.bearingDegrees) == _wrap(bearingDegrees) &&
      _wrap(other.rollDegrees) == _wrap(rollDegrees);

  @override
  int get hashCode =>
      Object.hash(tiltDegrees, _wrap(bearingDegrees), _wrap(rollDegrees));
}

/// An immutable target pose for the sphere camera.
@immutable
class SphereCameraPose {
  /// Geographic point to face when this is an overview pose.
  final SphereCoordinate? facing;

  /// Geographic point to keep at the viewport center for a surface-focus pose.
  final SphereCoordinate? focusPoint;

  /// Local view angle for a geographic pose.
  final SphereViewAngle view;

  /// World-space target used by an explicit XYZ pose.
  final SphereVector3? worldTarget;

  /// World-space direction from target to camera for an explicit XYZ pose.
  final SphereVector3? worldDirection;

  /// World-space screen-up reference for an explicit XYZ pose.
  final SphereVector3? worldUp;

  /// Relative magnification, clamped by [SphereCameraLimits].
  final double zoom;

  /// Creates an overview centered on the sphere, with [facing] toward the
  /// camera. Defaults to the Greenwich equator and zoom 1.
  const SphereCameraPose.overview({
    this.facing = const SphereCoordinate(latitude: 0, longitude: 0),
    this.view = const SphereViewAngle.front(),
    this.zoom = 1,
  })  : focusPoint = null,
        worldTarget = null,
        worldDirection = null,
        worldUp = null;

  /// Creates a surface-focus pose. The [target] is projected to viewport
  /// center and remains the view pivot.
  const SphereCameraPose.focus({
    required SphereCoordinate target,
    this.view = const SphereViewAngle.front(),
    this.zoom = 1,
  })  : focusPoint = target,
        facing = null,
        worldTarget = null,
        worldDirection = null,
        worldUp = null;

  /// Creates an advanced pose expressed entirely in world XYZ coordinates.
  /// [direction] points from [target] toward the camera. [up] defines screen
  /// up and cannot be parallel to [direction].
  const SphereCameraPose.world({
    required SphereVector3 target,
    required SphereVector3 direction,
    required SphereVector3 up,
    this.zoom = 1,
  })  : worldTarget = target,
        worldDirection = direction,
        worldUp = up,
        facing = null,
        focusPoint = null,
        view = const SphereViewAngle.front();

  /// Validates the active target representation and zoom.
  void validate() {
    if (!zoom.isFinite || zoom <= 0) {
      throw ArgumentError.value(zoom, 'zoom', 'Must be finite and positive.');
    }
    if (worldTarget case final target?) {
      final direction = worldDirection!;
      final up = worldUp!;
      if (!target.isFinite ||
          !direction.isFinite ||
          !up.isFinite ||
          direction.length == 0 ||
          up.length == 0 ||
          direction.normalized().cross(up.normalized()).length < 1e-9) {
        throw ArgumentError(
            'World pose vectors must be finite and nonparallel.');
      }
      return;
    }
    (focusPoint ?? facing!)._validate();
    view._validate();
  }
}

/// Camera pose update outcome.
enum SphereCameraResult {
  /// The requested target pose was reached.
  completed,

  /// The active animation was explicitly cancelled or replaced with an
  /// immediate pose.
  cancelled,

  /// A new animated command or user gesture interrupted the animation.
  interrupted,

  /// The sphere view was removed while the animation was active.
  detached,

  /// The owning controller was disposed.
  disposed,
}

/// Read-only snapshot of a camera's current world-space state.
@immutable
class SphereCameraState {
  /// Camera target in sphere world coordinates.
  final SphereVector3 target;

  /// Camera eye position in sphere world coordinates.
  final SphereVector3 position;

  /// Camera forward direction in world coordinates.
  final SphereVector3 forward;

  /// Camera right direction in world coordinates.
  final SphereVector3 right;

  /// Camera up direction in world coordinates.
  final SphereVector3 up;

  /// Camera-to-target distance.
  final double distance;

  /// Relative magnification.
  final double zoom;

  /// Whether an animated pose change is active.
  final bool isAnimating;

  /// Creates a state snapshot.
  const SphereCameraState({
    required this.target,
    required this.position,
    required this.forward,
    required this.right,
    required this.up,
    required this.distance,
    required this.zoom,
    required this.isAnimating,
  });

  @override
  bool operator ==(Object other) =>
      other is SphereCameraState &&
      other.target == target &&
      other.position == position &&
      other.forward == forward &&
      other.right == right &&
      other.up == up &&
      other.distance == distance &&
      other.zoom == zoom &&
      other.isAnimating == isAnimating;

  @override
  int get hashCode => Object.hash(
      target, position, forward, right, up, distance, zoom, isAnimating);
}

/// Camera zoom bounds shared by gesture and programmatic control.
@immutable
class SphereCameraLimits {
  /// Smallest zoom value; finite and positive.
  final double minZoom;

  /// Largest zoom value; finite and no smaller than [minZoom].
  final double maxZoom;

  /// Creates zoom limits. Runtime setters validate the same constraints.
  const SphereCameraLimits({this.minZoom = 0.5, this.maxZoom = 3})
      : assert(minZoom > 0 && minZoom < double.infinity),
        assert(maxZoom >= minZoom && maxZoom < double.infinity);

  @override
  bool operator ==(Object other) =>
      other is SphereCameraLimits &&
      other.minZoom == minZoom &&
      other.maxZoom == maxZoom;

  @override
  int get hashCode => Object.hash(minZoom, maxZoom);
}

/// A directional lighting configuration.
@immutable
class SphereLighting {
  /// Selected mode.
  final SphereLightingMode mode;

  /// Fixed source position; required only by [SphereLighting.fixed].
  final SphereCoordinate? coordinate;

  const SphereLighting._(this.mode, this.coordinate);

  /// Places light toward the view's upper-left.
  const SphereLighting.followCamera()
      : this._(SphereLightingMode.followCamera, null);

  /// Approximates the Sun's subsolar point from UTC time.
  const SphereLighting.solarTime() : this._(SphereLightingMode.solarTime, null);

  /// Places light at [coordinate].
  const SphereLighting.fixed({required SphereCoordinate coordinate})
      : this._(SphereLightingMode.fixed, coordinate);

  @override
  bool operator ==(Object other) =>
      other is SphereLighting &&
      other.mode == mode &&
      other.coordinate == coordinate;

  @override
  int get hashCode => Object.hash(mode, coordinate);
}

/// Modes accepted by [SphereLighting].
enum SphereLightingMode {
  /// Uses the current camera basis to place the light.
  followCamera,

  /// Approximates the Sun's direction from UTC time.
  solarTime,

  /// Uses the explicit geographic coordinate.
  fixed,
}

/// Atmosphere rendering mode.
enum SphereGlowMode {
  /// Adapts the built-in color and intensity to lighting and zoom.
  automatic,

  /// Uses the explicitly supplied custom style.
  custom,
}

/// Atmosphere configuration.
@immutable
class SphereGlow {
  /// Rendering mode.
  final SphereGlowMode mode;

  /// Custom RGBA color.
  final Color color;

  /// Custom outer thickness relative to sphere radius.
  final double width;

  /// Custom atmosphere strength.
  final double intensity;

  const SphereGlow._(this.mode, this.color, this.width, this.intensity);

  /// Adapts the built-in atmosphere to lighting and magnification.
  const SphereGlow.automatic()
      : this._(SphereGlowMode.automatic, const Color(0xFF6699FF), 0.6, 0.8);

  /// Uses the supplied custom appearance.
  const SphereGlow.custom({
    Color color = const Color(0xFF6699FF),
    double width = 0.6,
    double intensity = 0.8,
  }) : this._(SphereGlowMode.custom, color, width, intensity);

  /// Disables atmosphere and rim lighting.
  const SphereGlow.none()
      : this._(SphereGlowMode.custom, const Color(0xFF6699FF), 0.6, 0);

  /// Complete custom style; null for automatic mode.
  SphereGlowStyle? get style => mode == SphereGlowMode.custom
      ? SphereGlowStyle(color: color, width: width, intensity: intensity)
      : null;

  @override
  bool operator ==(Object other) =>
      other is SphereGlow &&
      other.mode == mode &&
      other.color == color &&
      other.width == width &&
      other.intensity == intensity;

  @override
  int get hashCode => Object.hash(mode, color, width, intensity);
}

/// Appearance of a custom atmosphere.
@immutable
class SphereGlowStyle {
  /// RGBA color.
  final Color color;

  /// Outer thickness relative to sphere radius, from 0 to 1.
  final double width;

  /// Atmosphere intensity from 0 to 1. Zero also disables the surface rim.
  final double intensity;

  const SphereGlowStyle({
    this.color = const Color(0xFF6699FF),
    this.width = 0.6,
    this.intensity = 0.8,
  });

  static const none = SphereGlowStyle(intensity: 0);

  @override
  bool operator ==(Object other) =>
      other is SphereGlowStyle &&
      other.color == color &&
      other.width == width &&
      other.intensity == intensity;

  @override
  int get hashCode => Object.hash(color, width, intensity);
}

/// User input options for an interactive sphere.
@immutable
class SphereGestureOptions {
  /// Enables one-finger orbit gestures.
  final bool orbitEnabled;

  /// Allows orbit gestures to tilt vertically.
  final bool verticalOrbitEnabled;

  /// Enables pinch-to-zoom gestures.
  final bool zoomEnabled;

  /// Applies release velocity after a drag.
  final bool inertiaEnabled;

  /// Restarts spin after gesture inertia only when spin was running before
  /// the gesture began.
  final bool resumeAfterGesture;

  /// Creates gesture options. All gesture controls default to enabled;
  /// automatic spin resumption defaults to false.
  const SphereGestureOptions({
    this.orbitEnabled = true,
    this.verticalOrbitEnabled = true,
    this.zoomEnabled = true,
    this.inertiaEnabled = true,
    this.resumeAfterGesture = false,
  });

  @override
  bool operator ==(Object other) =>
      other is SphereGestureOptions &&
      other.orbitEnabled == orbitEnabled &&
      other.verticalOrbitEnabled == verticalOrbitEnabled &&
      other.zoomEnabled == zoomEnabled &&
      other.inertiaEnabled == inertiaEnabled &&
      other.resumeAfterGesture == resumeAfterGesture;

  @override
  int get hashCode => Object.hash(orbitEnabled, verticalOrbitEnabled,
      zoomEnabled, inertiaEnabled, resumeAfterGesture);
}

/// Automatic sphere rotation settings, in degrees per second.
@immutable
class SphereSpinOptions {
  /// Rotation rate in degrees per second. Negative values reverse direction.
  final double degreesPerSecond;

  /// Creates spin settings. A zero rate keeps spin stopped without an idle
  /// ticker.
  const SphereSpinOptions({this.degreesPerSecond = 1.5});

  @override
  bool operator ==(Object other) =>
      other is SphereSpinOptions && other.degreesPerSecond == degreesPerSecond;

  @override
  int get hashCode => degreesPerSecond.hashCode;
}

/// Observable automatic rotation state.
@immutable
class SphereSpinState {
  /// Whether the user has requested rotation to run.
  final bool running;

  /// Whether rotation is temporarily suspended by app/route visibility.
  final bool suspended;

  /// Current rotation settings.
  final SphereSpinOptions options;

  /// Creates a state snapshot.
  const SphereSpinState({
    required this.running,
    required this.suspended,
    required this.options,
  });

  @override
  bool operator ==(Object other) =>
      other is SphereSpinState &&
      other.running == running &&
      other.suspended == suspended &&
      other.options == options;

  @override
  int get hashCode => Object.hash(running, suspended, options);
}
