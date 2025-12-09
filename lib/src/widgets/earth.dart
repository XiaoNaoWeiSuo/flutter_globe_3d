import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';
import 'package:flutter_globe_3d/src/painter/earth_painter.dart';

class Earth3D extends StatefulWidget {
  final String shaderAsset;
  final ImageProvider texture;
  final EarthController controller;
  final double initialScale;
  final Size? size;

  // [新增] 初始相机直射点经纬度
  final double? initialLatitude;
  final double? initialLongitude;

  const Earth3D({
    super.key,
    this.shaderAsset = "packages/flutter_globe_3d/assets/shaders/earth.frag",
    this.texture =
        const AssetImage("packages/flutter_globe_3d/assets/images/earth.jpg"),
    required this.controller,
    this.initialScale = 0.75,
    this.size,
    // [新增] 参数
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<Earth3D> createState() => _Earth3DState();
}

class _Earth3DState extends State<Earth3D> with TickerProviderStateMixin {
  ui.FragmentProgram? _program;
  ui.Image? _textureImage;
  late Ticker _ticker;
  double _time = 0.0;
  Offset _lastFocalPoint = Offset.zero;
  double _baseZoom = 1.0;
  bool _isInteracting = false;
  late AnimationController _animationController;
  Animation<Offset>? _offsetAnimation;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _loadResources();
    widget.controller.addListener(_onControllerUpdate);

    // [新增] 如果设置了初始经纬度，在初始化时定位相机
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      widget.controller
          .setCameraFocus(widget.initialLatitude!, widget.initialLongitude!);
    }

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

  // --- 手势交互逻辑 (保持不变) ---
  void _onScaleStart(ScaleStartDetails details) {
    _isInteracting = true;
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
    final velocity = details.velocity.pixelsPerSecond;
    final speed = velocity.distance;
    if (speed > 50) {
      _runInertiaAnimation(velocity);
    } else {
      _startResetTimer();
    }
  }

  void _runInertiaAnimation(Offset velocity) {
    final inertiaTarget = widget.controller.offset + velocity * 0.3;
    _offsetAnimation = Tween<Offset>(
      begin: widget.controller.offset,
      end: inertiaTarget,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.decelerate,
    ));
    _animationController.duration = const Duration(milliseconds: 800);
    _animationController.reset();
    _animationController.forward().whenComplete(() {
      _startResetTimer();
    });
  }

  void _startResetTimer() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _runResetAnimation();
      }
    });
  }

  void _runResetAnimation() {
    final current = widget.controller.offset;
    final target = Offset(current.dx, 0);
    if ((current.dy).abs() < 1.0) {
      _isInteracting = false;
      return;
    }
    _offsetAnimation = Tween<Offset>(
      begin: current,
      end: target,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
    _animationController.duration = const Duration(milliseconds: 1000);
    _animationController.reset();
    _animationController.forward().whenComplete(() {
      _isInteracting = false;
    });
  }

  // --- 辅助方法：3D 向量旋转 ---
  (double, double, double) _rotateVector(
      double x, double y, double z, double pitch, double yaw) {
    // Rotate X (Pitch)
    double c = math.cos(pitch);
    double s = math.sin(pitch);
    double y1 = y * c - z * s;
    double z1 = y * s + z * c;
    double x1 = x;

    // Rotate Y (Yaw)
    c = math.cos(yaw);
    s = math.sin(yaw);
    double x2 = x1 * c - z1 * s;
    double y2 = y1;
    double z2 = x1 * s + z1 * c;

    return (x2, y2, z2);
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

        // --- 计算光照向量 ---
        double lx = 0, ly = 0, lz = 1.0;

        switch (widget.controller.lightMode) {
          case EarthLightMode.realTime:
            // 保持原样
            final now = DateTime.now().toUtc();
            double hourOffset =
                now.hour + now.minute / 60.0 + now.second / 3600.0;
            double sunAngle = (hourOffset - 12.0) * 15.0 * (math.pi / 180.0);
            lx = math.cos(sunAngle);
            ly = 0.1;
            lz = -math.sin(sunAngle);
            break;

          case EarthLightMode.fixedCoordinates:
            // 保持原样
            double latRad = widget.controller.fixedLightLat * math.pi / 180.0;
            double lonRad =
                (widget.controller.fixedLightLon + 90.0) * math.pi / 180.0;
            double y = math.sin(latRad);
            double r = math.cos(latRad);
            lx = math.sin(lonRad) * r;
            lz = -math.cos(lonRad) * r;
            ly = y;
            break;

          case EarthLightMode.followCamera:
            // [关键修改] 光源不再完全跟随相机 (0, 0, -1)
            // 为了产生立体感，将光源移至相机视角的 "左上角"
            // 相机空间坐标:
            // x: -1.0 (左)
            // y:  1.0 (上)
            // z: -0.5 (稍微靠前，不用完全平行，增加深度)
            //
            // 这样光线从左上方打下来，右下角会有阴影。

            final double yaw = -widget.controller.offset.dx / 200.0;
            final double pitch = widget.controller.offset.dy / 200.0;

            // 调用旋转函数，确保光照向量跟随相机一起旋转
            var (rx, ry, rz) = _rotateVector(-1.5, 1.5, -1.0, pitch, yaw);

            lx = rx;
            ly = ry;
            lz = rz;
            break;
        }

        // 归一化
        double len = math.sqrt(lx * lx + ly * ly + lz * lz);
        if (len > 0) {
          lx /= len;
          ly /= len;
          lz /= len;
        }

        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
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
                      lightDirX: lx,
                      lightDirY: ly,
                      lightDirZ: lz,
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
