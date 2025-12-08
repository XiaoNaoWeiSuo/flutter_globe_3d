import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// `UnifiedShaderCanvas` 是一个通用的 Flutter widget，用于加载和渲染片段着色器。
/// 它处理布局约束、手势交互（平移、缩放）并将标准化的 Uniform 变量传递给着色器。
class UnifiedShaderCanvas extends StatefulWidget {
  /// Shader 文件路径，必须在 `pubspec.yaml` 中声明。
  final String shaderAssetPath;

  /// 初始缩放比例。默认为 `1.0`。
  final double initialZoom;

  /// 构造函数，用于创建 `UnifiedShaderCanvas` 实例。
  const UnifiedShaderCanvas({
    super.key,
    required this.shaderAssetPath,
    this.initialZoom = 1.0,
  });

  @override
  State<UnifiedShaderCanvas> createState() => _UnifiedShaderCanvasState();
}

class _UnifiedShaderCanvasState extends State<UnifiedShaderCanvas>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  late Ticker _ticker;

  // --- 标准坐标系状态 ---
  Offset _panOffset = Offset.zero; // 像素偏移
  double _zoom = 1.0; // 缩放因子
  double _time = 0.0; // 运行时间 (秒)

  // 交互临时状态
  Offset _lastFocalPoint = Offset.zero;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _zoom = widget.initialZoom;
    _loadShader();

    // 启动时间循环，用于驱动 uTime
    _ticker = createTicker((elapsed) {
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
      });
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        widget.shaderAssetPath,
      );
      if (mounted) {
        setState(() => _program = program);
      }
    } catch (e) {
      debugPrint('Shader load error: $e');
    }
  }

  // --- 手势处理 (支持平移和双指缩放) ---
  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _baseZoom = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // 1. 处理缩放
      _zoom = (_baseZoom * details.scale).clamp(0.1, 10.0);

      // 2. 处理平移 (累加偏移量)
      final delta = details.localFocalPoint - _lastFocalPoint;
      _panOffset += delta;
      _lastFocalPoint = details.localFocalPoint;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            "Loading Shader...",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // 智能布局适配器
    return LayoutBuilder(
      builder: (context, constraints) {
        double w = constraints.maxWidth;
        double h = constraints.maxHeight;

        // 1. 处理无限约束 (如在 ListView 中)
        if (!h.isFinite) {
          // 如果宽度有限，则默认正方形；否则给默认值
          h = w.isFinite ? w : 300.0;
        }
        if (!w.isFinite) w = 300.0;

        // 2. 兜底保护
        if (w <= 0) w = 1.0;
        if (h <= 0) h = 1.0;

        return SizedBox(
          width: w,
          height: h,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 使用 ScaleGestureRecognizer 同时处理拖动和缩放
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: CustomPaint(
              painter: _StandardShaderPainter(
                program: _program!,
                resolution: Size(w, h),
                offset: _panOffset,
                zoom: _zoom,
                time: _time,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// `_StandardShaderPainter` 是一个 `CustomPainter`，负责将 Dart 状态打包成标准 Uniform 协议发送给 GPU。
class _StandardShaderPainter extends CustomPainter {
  /// 片段着色器程序。
  final ui.FragmentProgram program;

  /// 渲染区域的分辨率。
  final Size resolution;

  /// 交互偏移量。
  final Offset offset;

  /// 缩放级别。
  final double zoom;

  /// 运行时间，用于动画。
  final double time;

  /// 构造函数，用于创建 `_StandardShaderPainter` 实例。
  _StandardShaderPainter({
    required this.program,
    required this.resolution,
    required this.offset,
    required this.zoom,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    // --- 标准 Uniform 协议 ---
    // index 0, 1: uResolution (屏幕尺寸)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // index 2, 3: uOffset (交互偏移)
    shader.setFloat(2, offset.dx);
    shader.setFloat(3, offset.dy);

    // index 4: uZoom (缩放级别)
    shader.setFloat(4, zoom);

    // index 5: uTime (时间，用于动画)
    shader.setFloat(5, time);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _StandardShaderPainter old) {
    return old.offset != offset ||
        old.zoom != zoom ||
        old.time != time ||
        old.resolution != resolution;
  }
}
