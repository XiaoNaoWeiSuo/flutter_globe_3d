import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';

class EarthShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ui.Image texture;
  final ui.Image? nightTexture; // 夜景纹理
  final bool hasNightTexture;
  final Size resolution;
  final Offset offset;
  final double zoom;
  final double time;
  final double scale;
  final double lightDirX;
  final double lightDirY;
  final double lightDirZ;

  EarthShaderPainter({
    required this.program,
    required this.texture,
    this.nightTexture,
    this.hasNightTexture = false,
    required this.resolution,
    required this.offset,
    required this.zoom,
    required this.time,
    required this.scale,
    required this.lightDirX,
    required this.lightDirY,
    required this.lightDirZ,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    
    // Uniforms 0-9
    shader.setFloat(0, resolution.width);
    shader.setFloat(1, resolution.height);
    shader.setFloat(2, offset.dx);
    shader.setFloat(3, offset.dy);
    shader.setFloat(4, zoom);
    shader.setFloat(5, time);
    shader.setFloat(6, scale);
    shader.setFloat(7, lightDirX);
    shader.setFloat(8, lightDirY);
    shader.setFloat(9, lightDirZ);
    
    // [Index 10] 是否有夜景贴图
    shader.setFloat(10, hasNightTexture ? 1.0 : 0.0);

    // [Sampler 0] 白天纹理
    shader.setImageSampler(0, texture);
    
    // [Sampler 1] 夜景纹理
    // 注意：即使 hasNightTexture 为 false，也要传一个占位纹理以防 Shader 崩溃
    shader.setImageSampler(1, nightTexture ?? texture);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant EarthShaderPainter old) => true;
}

// LinesPainter 保持不变...
class LinesPainter extends CustomPainter {
  final EarthController controller;
  final double time;
  LinesPainter({required this.controller, required this.time});
  @override
  void paint(Canvas canvas, Size size) {
    // ... 原有的连线绘制逻辑 ...
      final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var entry in controller.connectionPaths.entries) {
      final conn = entry.key;
      final path = entry.value;

      paint.color = conn.color;
      paint.strokeWidth = conn.width;

      if (conn.isDashed) {
        _drawDashedPath(canvas, path, paint, time);
      } else {
        canvas.drawPath(path, paint);
      }

      if (conn.showArrow) {
        _drawArrowOnPath(canvas, path, paint.color);
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path originalPath, Paint paint, double time) {
      const double dashWidth = 5;
    const double dashSpace = 5;
    final double phase = (time * 20) % (dashWidth + dashSpace);

    final ui.PathMetrics metrics = originalPath.computeMetrics();
    for (ui.PathMetric metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        double start = distance - phase;
        double end = start + dashWidth;

        if (end > 0 && start < metric.length) {
          final drawStart = start < 0 ? 0.0 : start;
          final drawEnd = end > metric.length ? metric.length : end;

          if (drawEnd > drawStart) {
            final extract = metric.extractPath(drawStart, drawEnd);
            canvas.drawPath(extract, paint);
          }
        }
        distance += dashWidth + dashSpace;
      }
    }
  }

  void _drawArrowOnPath(Canvas canvas, Path path, Color color) {
       final ui.PathMetrics metrics = path.computeMetrics();
    for (ui.PathMetric metric in metrics) {
      if (metric.length == 0) continue;
      // 在路径的 66% 处获取位置和切线
      final double targetDist = metric.length * 0.66;
      final ui.Tangent? tangent = metric.getTangentForOffset(targetDist);

      if (tangent != null) {
        final Offset pos = tangent.position;
        final Offset dir = tangent.vector;
        final Offset norm = Offset(-dir.dy, dir.dx);

        Path arrow = Path();
        arrow.moveTo(pos.dx + dir.dx * 5, pos.dy + dir.dy * 5);
        arrow.lineTo(
          pos.dx - dir.dx * 5 + norm.dx * 5,
          pos.dy - dir.dy * 5 + norm.dy * 5,
        );
        arrow.lineTo(
          pos.dx - dir.dx * 5 - norm.dx * 5,
          pos.dy - dir.dy * 5 - norm.dy * 5,
        );
        arrow.close();

        canvas.drawPath(
          arrow,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant LinesPainter old) => true;
}