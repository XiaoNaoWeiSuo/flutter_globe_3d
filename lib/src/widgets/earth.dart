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

class _Earth3DState extends State<Earth3D> with TickerProviderStateMixin {
  ui.FragmentProgram? _program;
  ui.Image? _textureImage;
  late Ticker _ticker;
  double _time = 0.0;
  
  // 交互状态
  Offset _lastFocalPoint = Offset.zero;
  double _baseZoom = 1.0;
  bool _isInteracting = false; // 是否正在交互（触摸或惯性运动中）

  // 动画控制器
  late AnimationController _animationController;
  Animation<Offset>? _offsetAnimation;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _loadResources();
    widget.controller.addListener(_onControllerUpdate);

    // 初始化动画控制器（用于惯性和复位）
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.addListener(() {
      if (_offsetAnimation != null) {
        widget.controller.setOffset(_offsetAnimation!.value);
      }
    });

    // 渲染循环 & 自动自转逻辑
    _ticker = createTicker((elapsed) {
      double dt = elapsed.inMilliseconds / 1000.0;
      
      // 只有在非交互状态下才自动旋转
      if (widget.controller.enableAutoRotate && !_isInteracting) {
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
    _animationController.dispose();
    _resetTimer?.cancel();
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

  // --- 手势交互逻辑 ---

  void _onScaleStart(ScaleStartDetails details) {
    // 1. 用户开始触摸，标记为交互中，停止自动自转
    _isInteracting = true;
    
    // 2. 停止任何正在进行的惯性或复位动画
    _animationController.stop();
    _resetTimer?.cancel();

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

  void _onScaleEnd(ScaleEndDetails details) {
    // 3. 用户手指离开，计算惯性
    final velocity = details.velocity.pixelsPerSecond;
    final speed = velocity.distance;

    // 如果速度足够大，执行惯性滑动
    if (speed > 50) {
      _runInertiaAnimation(velocity);
    } else {
      // 否则直接进入复位倒计时
      _startResetTimer();
    }
  }

  /// 执行惯性动画
  void _runInertiaAnimation(Offset velocity) {
    // 简单的减速模拟：根据速度计算一个目标点
    // 0.5 是一个阻尼系数，决定滑动的距离
    final inertiaTarget = widget.controller.offset + velocity * 0.3;
    
    _offsetAnimation = Tween<Offset>(
      begin: widget.controller.offset,
      end: inertiaTarget,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.decelerate, // 减速曲线模拟摩擦力
    ));

    // 动画时长也可以根据速度动态调整，这里简化为固定时长
    _animationController.duration = const Duration(milliseconds: 800);
    _animationController.reset();
    _animationController.forward().whenComplete(() {
      // 惯性结束后，启动复位倒计时
      _startResetTimer();
    });
  }

  /// 启动自动复位倒计时（1秒）
  void _startResetTimer() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _runResetAnimation();
      }
    });
  }

  /// 执行南北极平滑复位动画
  void _runResetAnimation() {
    final current = widget.controller.offset;
    // 目标：保持当前的 X 轴旋转（经度），将 Y 轴旋转（纬度/南北）复位为 0
    final target = Offset(current.dx, 0);

    // 如果已经很接近 0，则不需要动画，直接恢复自转
    if ((current.dy).abs() < 1.0) {
      _isInteracting = false;
      return;
    }

    _offsetAnimation = Tween<Offset>(
      begin: current,
      end: target,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic, // 平滑的缓动曲线
    ));

    _animationController.duration = const Duration(milliseconds: 1000);
    _animationController.reset();
    _animationController.forward().whenComplete(() {
      // 动画完成，恢复自动自转
      _isInteracting = false;
    });
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
        final h = widget.size?.height ??
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
          onScaleEnd: _onScaleEnd, // 绑定 ScaleEnd 事件
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