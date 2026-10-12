import 'dart:math' as math;
import 'package:flutter/animation.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../models/globe_vector3.dart';

/// Internal camera state. Local +Z is the direction from the target to the
/// eye, +X is screen right, and +Y is screen up. Orientation is interpolated
/// as one quaternion, never as independent forward/up vectors.
class GlobeCamera {
  v.Quaternion _orientation = v.Quaternion.identity();
  v.Vector3 _target = v.Vector3.zero();
  double zoom = 1;
  double radius = 0.375;
  _Transition? _transition;

  bool get isAnimating => _transition != null;
  v.Vector3 _axis(double x, double y, double z) =>
      _orientation.asRotationMatrix().transformed(v.Vector3(x, y, z));
  GlobeVector3 get right => _public(_axis(1, 0, 0));
  GlobeVector3 get up => _public(_axis(0, 1, 0));
  GlobeVector3 get forward => _public(-_axis(0, 0, 1));

  /// Unit-sphere focus point in fixed world coordinates.
  GlobeVector3 get target => _public(_target);

  // Preserve overview zoom while moving the pivot onto the surface for focus.
  // The clearance guard prevents zoom/layout changes from putting the eye
  // inside the sphere, including during transitions across hemispheres.
  double get distance {
    final back = _axis(0, 0, 1);
    final pivot = _target * radius;
    final along = pivot.dot(back);
    final exit = -along +
        math.sqrt(math.max(
          0,
          along * along + radius * radius - pivot.length2,
        ));
    return math.max(5 / zoom - radius * _target.length,
        exit + math.max(radius * 0.02, 0.001));
  }

  GlobeVector3 get position =>
      _public(_target * radius + _axis(0, 0, 1) * distance);

  static GlobeVector3 geographic(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite || latitude.abs() > 90) {
      throw ArgumentError(
          'Latitude must be in [-90, 90]; coordinates must be finite.');
    }
    final lat = latitude * math.pi / 180;
    final lon = longitude * math.pi / 180;
    // Greenwich is +Z; east turns toward +X. North stays up and east right.
    return GlobeVector3(math.cos(lat) * math.sin(lon), math.sin(lat),
        math.cos(lat) * math.cos(lon));
  }

  void focus(
      double lat,
      double lon,
      GlobeVector3 viewDirection,
      GlobeVector3? tangent,
      double targetZoom,
      Duration duration,
      Curve curve) {
    final rotation = _geographicOrientation(lat, lon, viewDirection, tangent);
    final normal = _native(geographic(lat, lon));
    _move(rotation, normal, targetZoom, duration, curve);
  }

  /// Applies an arbitrary world-space target, camera-back direction, and up
  /// reference. Targets use unit-sphere coordinates, matching [focus].
  void focusWorld(
    GlobeVector3 target,
    GlobeVector3 direction,
    GlobeVector3 up,
    double targetZoom,
    Duration duration,
    Curve curve,
  ) {
    if (!target.x.isFinite ||
        !target.y.isFinite ||
        !target.z.isFinite ||
        !direction.x.isFinite ||
        !direction.y.isFinite ||
        !direction.z.isFinite ||
        !up.x.isFinite ||
        !up.y.isFinite ||
        !up.z.isFinite ||
        direction.length == 0 ||
        up.length == 0) {
      throw ArgumentError('World camera vectors must be finite and nonzero.');
    }
    final back = _native(direction)..normalize();
    final upCandidate = _native(up);
    final correctedUp = upCandidate - back * upCandidate.dot(back);
    if (correctedUp.length2 < 1e-12) {
      throw ArgumentError(
          'The world up vector cannot be parallel to direction.');
    }
    final unitUp = correctedUp..normalize();
    final right = unitUp.cross(back)..normalize();
    final orthogonalUp = back.cross(right)..normalize();
    final rotation = v.Matrix3.columns(right, orthogonalUp, back);
    _move(v.Quaternion.fromRotation(rotation)..normalize(), _native(target),
        targetZoom, duration, curve);
  }

  v.Quaternion _geographicOrientation(
    double lat,
    double lon,
    GlobeVector3 viewDirection,
    GlobeVector3? tangent,
  ) {
    if (!viewDirection.x.isFinite ||
        !viewDirection.y.isFinite ||
        !viewDirection.z.isFinite ||
        viewDirection.z <= 0) {
      throw ArgumentError('viewDirection must be finite and have z > 0.');
    }
    final normal = _native(geographic(lat, lon));
    final longitude = lon * math.pi / 180;
    final east = v.Vector3(math.cos(longitude), 0, -math.sin(longitude));
    final north = normal.cross(east)..normalize();
    final back = (east * viewDirection.x +
        north * viewDirection.y +
        normal * viewDirection.z)
      ..normalize();
    var up = tangent == null ? north : _native(tangent);
    if (!up.x.isFinite || !up.y.isFinite || !up.z.isFinite) {
      throw ArgumentError('tangent must be finite.');
    }
    up = up - back * up.dot(back);
    if (up.length2 < 1e-12) up = east - back * east.dot(back);
    up.normalize();
    final right = up.cross(back)..normalize();
    up = back.cross(right)..normalize();
    final rotation = v.Matrix3.columns(right, up, back);
    return v.Quaternion.fromRotation(rotation)..normalize();
  }

  void overview(double targetZoom, Duration duration, Curve curve) => _move(
      _orientation.clone(), v.Vector3.zero(), targetZoom, duration, curve);

  void overviewFacing(
    double latitude,
    double longitude,
    GlobeVector3 direction,
    GlobeVector3? tangent,
    double targetZoom,
    Duration duration,
    Curve curve,
  ) =>
      _move(
        _geographicOrientation(latitude, longitude, direction, tangent),
        v.Vector3.zero(),
        targetZoom,
        duration,
        curve,
      );

  void _move(v.Quaternion orientation, v.Vector3 target, double targetZoom,
      Duration duration, Curve curve) {
    if (duration <= Duration.zero) {
      _orientation = orientation;
      _target = target;
      zoom = targetZoom;
      _transition = null;
    } else {
      _transition = _Transition(_orientation.clone(), orientation,
          _target.clone(), target, zoom, targetZoom, duration, curve);
    }
  }

  void advance(Duration delta) {
    final transition = _transition;
    if (transition == null || delta <= Duration.zero) return;
    transition.elapsed += delta;
    final progress =
        (transition.elapsed.inMicroseconds / transition.duration.inMicroseconds)
            .clamp(0.0, 1.0);
    if (progress >= 1) {
      _orientation = transition.end;
      _target = transition.targetEnd;
      zoom = transition.zoomEnd;
      _transition = null;
      return;
    }
    double t;
    try {
      t = transition.curve.transform(progress);
      if (!t.isFinite) {
        throw ArgumentError('Camera curve must return a finite value.');
      }
      t = t.clamp(0.0, 1.0);
    } catch (_) {
      _transition = null;
      rethrow;
    }
    _orientation = _slerp(transition.start, transition.end, t);
    _target = transition.targetStart * (1 - t) + transition.targetEnd * t;
    // Log interpolation produces an even apparent change in magnification.
    zoom = math.exp(math.log(transition.zoomStart) * (1 - t) +
        math.log(transition.zoomEnd) * t);
  }

  void cancel() => _transition = null;

  static v.Quaternion _slerp(v.Quaternion a, v.Quaternion b, double t) {
    var dot = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
    final sign = dot < 0 ? -1.0 : 1.0;
    dot = dot.abs().clamp(0.0, 1.0);
    var first = 1 - t;
    var second = t;
    if (dot < 0.9995) {
      final angle = math.acos(dot);
      final denominator = math.sin(angle);
      first = math.sin((1 - t) * angle) / denominator;
      second = math.sin(t * angle) / denominator;
    }
    second *= sign;
    return v.Quaternion(a.x * first + b.x * second, a.y * first + b.y * second,
        a.z * first + b.z * second, a.w * first + b.w * second)
      ..normalize();
  }

  void orbit(double yaw, double pitch) {
    cancel();
    final rotation = v.Quaternion.axisAngle(_axis(0, 1, 0), yaw) *
        v.Quaternion.axisAngle(_axis(1, 0, 0), pitch);
    _orientation = rotation * _orientation
      ..normalize();
    _target = rotation.asRotationMatrix().transformed(_target);
  }

  static v.Vector3 _native(GlobeVector3 value) =>
      v.Vector3(value.x, value.y, value.z);
  static GlobeVector3 _public(v.Vector3 value) =>
      GlobeVector3(value.x, value.y, value.z);
}

class _Transition {
  final v.Quaternion start, end;
  final v.Vector3 targetStart, targetEnd;
  final double zoomStart, zoomEnd;
  final Duration duration;
  final Curve curve;
  Duration elapsed = Duration.zero;
  _Transition(this.start, this.end, this.targetStart, this.targetEnd,
      this.zoomStart, this.zoomEnd, this.duration, this.curve);
}
