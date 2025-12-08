import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';
import 'package:flutter_globe_3d/src/painter/earth_painter.dart';

/// `Earth3D` 是一个 Flutter widget，用于渲染一个交互式的 3D 地球。
/// 它使用 GPU 片段着色器进行高性能渲染，支持纹理、控制器、初始缩放和自定义大小。
class Earth3D extends StatefulWidget {
  /// 着色器资产的路径。默认为 `packages/flutter_globe_3d/assets/shaders/earth.frag`。
  final String shaderAsset;

  /// 地球的纹理图像提供者。
  final ImageProvider texture;

  /// 控制地球行为的控制器，例如旋转、缩放和标记。
  final EarthController controller;

  /// 地球的初始缩放比例。
  final double initialScale;

  /// widget 的可选大小。如果未提供，则会根据父级约束自动调整。
  final Size? size;

  /// 构造函数，用于创建 `Earth3D` widget。
  const Earth3D({
    super.key,
    this.shaderAsset = "packages/flutter_globe_3d/assets/shaders/earth.frag",
    required this.texture,
    required this.controller,
    this.initialScale = 0.75,
    this.size,
  });

  @override
  State<Earth3D> createState() => _Earth3DState();
}

class _Earth3DState extends State<Earth3D> with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  ui.Image? _textureImage;
  late Ticker _ticker;
  double _time = 0.0;
  Offset _lastFocalPoint = Offset.zero;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _loadResources();
    widget.controller.addListener(_onControllerUpdate);

    _ticker = createTicker((elapsed) {
      double dt = elapsed.inMilliseconds / 1000.0;
      if (widget.controller.enableAutoRotate) {
        double speed = widget.controller.rotateSpeed;
        Offset current = widget.controller.offset;
        widget.controller.setOffset(
          Offset(current.dx + speed * 1.0, current.dy),
        );
      }
      setState(() {
        _time = dt;
      });
    });
    _ticker.start();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  Future<void> _loadResources() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(widget.shaderAsset);
      _program = program;
    } catch (e) {
      debugPrint("Shader load failed: $e");
    }

    final ImageStream stream = widget.texture.resolve(ImageConfiguration.empty);
    stream.addListener(
      ImageStreamListener((info, _) {
        if (mounted) {
          setState(() {
            _textureImage = info.image;
          });
        }
      }),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _baseZoom = widget.controller.zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.controller.lockZoom) {
      widget.controller.setZoom(_baseZoom * details.scale);
    }
    final delta = details.localFocalPoint - _lastFocalPoint;
    Offset current = widget.controller.offset;
    widget.controller.setOffset(current + delta);
    _lastFocalPoint = details.localFocalPoint;
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null || _textureImage == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = widget.size?.width ?? constraints.maxWidth;
        final h =
            widget.size?.height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : w);
        final size = Size(w, h);
        double shaderScale = (w / h) * widget.initialScale;

        widget.controller.updateProjections(size, shaderScale, _time);

        final now = DateTime.now().toUtc();
        double hourOffset = now.hour + now.minute / 60.0 + now.second / 3600.0;
        double sunAngle = (hourOffset - 12.0) * 15.0 * (math.pi / 180.0);

        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: EarthShaderPainter(
                      program: _program!,
                      texture: _textureImage!,
                      resolution: size,
                      offset: widget.controller.offset,
                      zoom: widget.controller.zoom,
                      time: _time,
                      scale: shaderScale,
                      sunAngle: sunAngle,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: LinesPainter(
                      controller: widget.controller,
                      time: _time,
                    ),
                  ),
                ),
                ...widget.controller.nodes.map((node) {
                  final pos = widget.controller.projectedPositions[node.id];
                  final visible =
                      widget.controller.nodeVisibility[node.id] ?? false;
                  if (!visible || pos == null) return const SizedBox.shrink();
                  return Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, -0.5),
                      child: node.child,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
