import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';
import '../models/sphere_glow.dart';
import '../models/sphere_quality.dart';

/// Paints the globe and all connection paths in one render layer.
///
/// The painter reads dynamic values from the controller and time listenable at
/// paint time. This allows Flutter to repaint the render layer without
/// rebuilding the surrounding widget tree on every animation tick.
class EarthScenePainter extends CustomPainter {
  final ui.FragmentShader shader;

  /// Actual compiled preset while a newly requested variant is loading.
  final SphereQuality? shaderQuality;
  final ui.Image texture;

  /// Excludes the damaged trailing column/row of the built-in Earth JPEG.
  /// Custom textures retain their complete UV range.
  final bool trimEarthTextureEdges;
  final ui.Image? nightTexture;
  final bool hasNightTexture;
  final Size resolution;
  final double scale;
  final double devicePixelRatio;
  final GlobeController controller;
  final ValueListenable<double> timeListenable;

  EarthScenePainter({
    required this.shader,
    this.shaderQuality,
    required this.texture,
    this.trimEarthTextureEdges = false,
    this.nightTexture,
    this.hasNightTexture = false,
    required this.resolution,
    required this.scale,
    this.devicePixelRatio = 1,
    required this.controller,
    required this.timeListenable,
    required Listenable repaint,
  }) : super(repaint: repaint);

  // Weak keys let bindings be reused across painter rebuilds, while allowing
  // disposed shaders and their image references to be garbage collected.
  static final _samplers = Expando<_SamplerBindings>();

  @override
  void paint(Canvas canvas, Size size) {
    final time = timeListenable.value;
    final (lightDirX, lightDirY, lightDirZ) = _lightDirection(controller);

    // Float uniforms 0-10.
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, controller.offset.dx);
    shader.setFloat(3, controller.offset.dy);
    shader.setFloat(4, controller.zoom);
    shader.setFloat(5, time);
    shader.setFloat(6, scale);
    shader.setFloat(7, lightDirX);
    shader.setFloat(8, lightDirY);
    shader.setFloat(9, lightDirZ);

    // Float uniform 10: whether a night texture is available.
    shader.setFloat(10, hasNightTexture ? 1.0 : 0.0);

    // Float uniforms 11-22: the shared XYZ camera basis.
    final cameraPosition = controller.cameraPosition;
    final cameraForward = controller.cameraForward;
    final cameraRight = controller.cameraRight;
    final cameraUp = controller.cameraUp;
    shader.setFloat(11, cameraPosition.x);
    shader.setFloat(12, cameraPosition.y);
    shader.setFloat(13, cameraPosition.z);
    shader.setFloat(14, cameraForward.x);
    shader.setFloat(15, cameraForward.y);
    shader.setFloat(16, cameraForward.z);
    shader.setFloat(17, cameraRight.x);
    shader.setFloat(18, cameraRight.y);
    shader.setFloat(19, cameraRight.z);
    shader.setFloat(20, cameraUp.x);
    shader.setFloat(21, cameraUp.y);
    shader.setFloat(22, cameraUp.z);

    // Float uniforms 23-29: RGBA, radius-relative width, strength, auto mode.
    final automatic = controller.glowMode == SphereGlowMode.automatic;
    final glow = automatic ? const SphereGlowStyle() : controller.glowStyle;
    final zoomAttenuation =
        automatic ? 1 / math.sqrt(math.max(controller.zoom, 1.0)) : 1.0;
    shader.setFloat(23, glow.color.r);
    shader.setFloat(24, glow.color.g);
    shader.setFloat(25, glow.color.b);
    shader.setFloat(26, glow.color.a);
    shader.setFloat(27, glow.width * zoomAttenuation);
    shader.setFloat(28, glow.intensity * zoomAttenuation);
    shader.setFloat(29, automatic ? 1.0 : 0.0);

    // Physical-pixel sampling: Retina screens must not blur a logical pixel.
    shader.setFloat(30, devicePixelRatio);
    final quality = shaderQuality ?? controller.quality;
    shader.setFloat(31, quality.samplesPerAxis.toDouble());
    shader.setFloat(32, texture.width.toDouble());
    shader.setFloat(33, texture.height.toDouble());
    final night = nightTexture ?? texture;
    shader.setFloat(34, night.width.toDouble());
    shader.setFloat(35, night.height.toDouble());
    // Custom shaders keep the original 36-float protocol. Only the built-in
    // variants declare the appended source-crop uniform.
    if (shaderQuality != null) {
      shader.setFloat(36, trimEarthTextureEdges ? 1 : 0);
    }

    final filter =
        quality == SphereQuality.low ? FilterQuality.low : FilterQuality.medium;
    // Set sampler quality explicitly; Paint.filterQuality does not configure
    // FragmentShader samplers. Keep a valid night sampler even when absent.
    final bindings = _samplers[shader];
    if (bindings == null ||
        bindings.texture != texture ||
        bindings.night != night ||
        bindings.filter != filter) {
      shader.setImageSampler(0, texture, filterQuality: filter);
      shader.setImageSampler(1, night, filterQuality: filter);
      _samplers[shader] = _SamplerBindings(texture, night, filter);
    }

    // All presets draw only a conservative projected sphere/glow bound. This
    // also avoids invoking the fragment program over a wide empty viewport.
    final radius = scale * 0.5;
    final extent = radius *
        (1 +
            (glow.intensity > 0 && glow.color.a > 0
                ? glow.width * zoomAttenuation
                : 0));
    final bound = _projectedBounds(size, extent);
    if (!bound.isEmpty) canvas.drawRect(bound, Paint()..shader = shader);

    _paintConnections(canvas, time);
    _paintAnnotations(canvas);
  }

  void _paintAnnotations(Canvas canvas) {
    final placements = controller.annotationPlacements;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final node in controller.nodes) {
      final placement = placements[node.id];
      if (placement == null) continue;
      final style = node.annotationStyle;
      paint
        ..color = style.lineColor
        ..strokeWidth = style.lineWidth
        ..style = PaintingStyle.stroke;
      final points = placement.leaderPoints;
      if (points.isNotEmpty && style.lineWidth > 0) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
      if (style.anchorRadius > 0) {
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(placement.anchor, style.anchorRadius, paint);
      }
    }
  }

  Rect _projectedBounds(Size size, double radius) {
    final center = controller.cameraPosition * -1;
    final depth = center.dot(controller.cameraForward);
    if (depth <= radius) return Offset.zero & size;
    final cx = center.dot(controller.cameraRight);
    final cy = center.dot(controller.cameraUp);
    (double, double) interval(double coordinate) {
      final a = (coordinate - radius) / (depth - radius);
      final b = (coordinate - radius) / (depth + radius);
      final c = (coordinate + radius) / (depth - radius);
      final d = (coordinate + radius) / (depth + radius);
      return (
        math.min(math.min(a, b), math.min(c, d)),
        math.max(math.max(a, b), math.max(c, d)),
      );
    }

    final (left, right) = interval(cx);
    final (bottom, top) = interval(cy);
    return Rect.fromLTRB(
      size.width / 2 + left * size.height,
      size.height / 2 - top * size.height,
      size.width / 2 + right * size.height,
      size.height / 2 - bottom * size.height,
    ).inflate(1 / devicePixelRatio).intersect(Offset.zero & size);
  }

  void _paintConnections(Canvas canvas, double time) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final entry in controller.connectionPaths.entries) {
      final connection = entry.key;
      final path = entry.value;

      paint.color = connection.color;
      paint.strokeWidth = connection.width;

      if (connection.isDashed) {
        _drawDashedPath(canvas, path, paint, time);
      } else {
        canvas.drawPath(path, paint);
      }

      if (connection.showArrow) {
        _drawArrowOnPath(canvas, path, paint.color);
      }
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path originalPath,
    Paint paint,
    double time,
  ) {
    const double dashWidth = 5;
    const double dashSpace = 5;
    final double phase = (time * 20) % (dashWidth + dashSpace);

    for (final metric in originalPath.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double start = distance - phase;
        final double end = start + dashWidth;

        if (end > 0 && start < metric.length) {
          final double drawStart = start < 0 ? 0.0 : start;
          final double drawEnd = end > metric.length ? metric.length : end;

          if (drawEnd > drawStart) {
            canvas.drawPath(metric.extractPath(drawStart, drawEnd), paint);
          }
        }
        distance += dashWidth + dashSpace;
      }
    }
  }

  void _drawArrowOnPath(Canvas canvas, Path path, Color color) {
    for (final metric in path.computeMetrics()) {
      if (metric.length == 0) continue;

      final tangent = metric.getTangentForOffset(metric.length * 0.66);
      if (tangent == null) continue;

      final position = tangent.position;
      final direction = tangent.vector;
      final normal = Offset(-direction.dy, direction.dx);

      final arrow = Path()
        ..moveTo(position.dx + direction.dx * 5, position.dy + direction.dy * 5)
        ..lineTo(
          position.dx - direction.dx * 5 + normal.dx * 5,
          position.dy - direction.dy * 5 + normal.dy * 5,
        )
        ..lineTo(
          position.dx - direction.dx * 5 - normal.dx * 5,
          position.dy - direction.dy * 5 - normal.dy * 5,
        )
        ..close();

      canvas.drawPath(
        arrow,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  (double, double, double) _lightDirection(GlobeController controller) {
    double lx = 0;
    double ly = 0;
    double lz = 1.0;

    switch (controller.lightMode) {
      case GlobeLightMode.realTime:
        final now = DateTime.now().toUtc();
        final hourOffset = now.hour + now.minute / 60.0 + now.second / 3600.0;
        final sunAngle = (hourOffset - 12.0) * 15.0 * (math.pi / 180.0);
        lx = -math.sin(sunAngle);
        ly = 0.1;
        lz = math.cos(sunAngle);
        break;

      case GlobeLightMode.fixedCoordinates:
        final light = controller.worldPointForCoordinates(
            controller.fixedLightLat, controller.fixedLightLon);
        lx = light.x;
        ly = light.y;
        lz = light.z;
        break;

      case GlobeLightMode.followCamera:
        final cameraForward = controller.cameraForward;
        final cameraRight = controller.cameraRight;
        final cameraUp = controller.cameraUp;
        lx = -cameraRight.x * 0.35 + cameraUp.x * 0.6 - cameraForward.x;
        ly = -cameraRight.y * 0.35 + cameraUp.y * 0.6 - cameraForward.y;
        lz = -cameraRight.z * 0.35 + cameraUp.z * 0.6 - cameraForward.z;
        break;
    }

    final length = math.sqrt(lx * lx + ly * ly + lz * lz);
    if (length > 0) {
      lx /= length;
      ly /= length;
      lz /= length;
    }

    return (lx, ly, lz);
  }

  @override
  bool shouldRepaint(covariant EarthScenePainter old) {
    return old.shader != shader ||
        old.shaderQuality != shaderQuality ||
        old.texture != texture ||
        old.trimEarthTextureEdges != trimEarthTextureEdges ||
        old.nightTexture != nightTexture ||
        old.hasNightTexture != hasNightTexture ||
        old.resolution != resolution ||
        old.scale != scale ||
        old.devicePixelRatio != devicePixelRatio ||
        old.controller != controller ||
        old.timeListenable != timeListenable;
  }
}

class _SamplerBindings {
  const _SamplerBindings(this.texture, this.night, this.filter);
  final ui.Image texture;
  final ui.Image night;
  final FilterQuality filter;
}
