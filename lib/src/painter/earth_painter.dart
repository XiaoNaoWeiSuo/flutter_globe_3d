import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';

/// `EarthShaderPainter` 是一个 `CustomPainter`，负责使用片段着色器绘制 3D 地球。
/// 它将纹理、分辨率、偏移量、缩放、时间和太阳角度等参数传递给着色器。
class EarthShaderPainter extends CustomPainter {
  /// 用于渲染地球的片段着色器程序。
  final ui.FragmentProgram program;

  /// 地球的纹理图像。
  final ui.Image texture;

  /// 渲染区域的分辨率。
  final Size resolution;

  /// 地球的偏移量（用于旋转）。
  final Offset offset;

  /// 地球的缩放级别。
  final double zoom;

  /// 当前渲染时间，用于着色器中的动画效果。
  final double time;

  /// 地球的缩放比例。
  final double scale;

  /// 太阳的角度，用于计算光照。
  final double sunAngle;

  /// 构造函数，用于创建 `EarthShaderPainter` 实例。
  EarthShaderPainter({
    required this.program,
    required this.texture,
    required this.resolution,
    required this.offset,
    required this.zoom,
    required this.time,
    required this.scale,
    required this.sunAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader.setFloat(0, resolution.width);
    shader.setFloat(1, resolution.height);
    shader.setFloat(2, offset.dx);
    shader.setFloat(3, offset.dy);
    shader.setFloat(4, zoom);
    shader.setFloat(5, time);
    shader.setFloat(6, scale);
    shader.setFloat(7, sunAngle);
    shader.setImageSampler(0, texture);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant EarthShaderPainter old) => true;
}

/// `LinesPainter` 是一个 `CustomPainter`，负责绘制地球上的连线和箭头。
/// 它使用 `EarthController` 中的数据来获取连线路径和样式。
class LinesPainter extends CustomPainter {
  /// 地球控制器，提供连线数据。
  final EarthController controller;

  /// 当前渲染时间，用于虚线动画。
  final double time;

  /// 构造函数，用于创建 `LinesPainter` 实例。
  LinesPainter({required this.controller, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var entry in controller.connectionPaths.entries) {
      final conn = entry.key;
      final path = entry.value;

      paint.color = conn.color;
      paint.strokeWidth = conn.width;

      // --- 3. 绘制路径（实线或虚线）---
      if (conn.isDashed) {
        _drawDashedPath(canvas, path, paint, time);
      } else {
        canvas.drawPath(path, paint);
      }

      // --- 4. 绘制箭头 ---
      if (conn.showArrow) {
        _drawArrowOnPath(canvas, path, paint.color);
      }
    }
  }

  /// 绘制流动的虚线路径。
  /// [canvas] 画布。
  /// [originalPath] 原始路径。
  /// [paint] 绘制虚线使用的画笔。
  /// [time] 当前时间，用于计算虚线动画的相位。
  void _drawDashedPath(
    Canvas canvas,
    Path originalPath,
    Paint paint,
    double time,
  ) {
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

  /// 在路径上绘制箭头。
  /// [canvas] 画布。
  /// [path] 绘制箭头的路径。
  /// [color] 箭头的颜色。
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
