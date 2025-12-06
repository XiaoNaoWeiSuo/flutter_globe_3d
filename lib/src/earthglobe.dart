import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'earth_controller.dart';
import 'models/earth_connection.dart';
import 'models/earth_maker.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class Flutter3DGlobe extends StatefulWidget {
  final EarthController controller;
  final ImageProvider texture;
  final String shaderAssetPath;
  final List<EarthMarker> markers;
  final List<EarthConnection> connections;
  final double radius;
  final Color backgroundColor;

  const Flutter3DGlobe({
    super.key,
    required this.controller,
    required this.texture,
    this.shaderAssetPath = 'assets/shaders/earth.frag',
    this.markers = const [],
    this.connections = const [],
    this.radius = 150,
    this.backgroundColor = Colors.transparent,
  });

  @override
  State<Flutter3DGlobe> createState() => _Flutter3DGlobeState();
}

class _Flutter3DGlobeState extends State<Flutter3DGlobe>
    with TickerProviderStateMixin {
  FragmentProgram? _fragmentProgram;
  ui.Image? _earthImage;
  String? _errorMessage;
  late AnimationController _animController;
  double _baseScale = 1.0;
  bool _hasLoadingStarted = false;

  // [新增] 自动旋转相关的变量
  Timer? _autoRotateTimer; // 空闲检测计时器
  bool _isAutoRotating = true; // 默认一开始是自转的
  final int _idleSeconds = 3; // 松手后几秒开始恢复

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // [新增] 监听动画帧，用于驱动自动旋转
    _animController.addListener(_autoRotateTick);

    widget.controller.startPhysics(this);
    widget.controller.addListener(_update);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadingStarted) {
      _hasLoadingStarted = true;
      _loadResources();
    }
  }

  @override
  void dispose() {
    widget.controller.stopPhysics();
    widget.controller.removeListener(_update);
    
    // [新增] 清理监听和计时器
    _animController.removeListener(_autoRotateTick);
    _autoRotateTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  // [新增] 每一帧动画的回调：处理自动旋转
  void _autoRotateTick() {
    if (_isAutoRotating) {
      // 模拟微小的向左滑动信号，让地球自转
      // 参数1 (dx): 1.5 表示水平旋转速度
      // 参数2 (dy): 0 表示垂直不旋转
      // 参数3 (sensitivity): 灵敏度，根据半径调整
      widget.controller.onDragUpdate(1.5, 0, 1.0 / widget.radius);
    }
  }

  Future<void> _loadResources() async {
    try {
      final programFuture = FragmentProgram.fromAsset(widget.shaderAssetPath);
      final imageFuture = _resolveImage(widget.texture);

      final results = await Future.wait([programFuture, imageFuture]);

      if (mounted) {
        setState(() {
          _fragmentProgram = results[0] as FragmentProgram;
          _earthImage = results[1] as ui.Image;
        });
      }
    } catch (e) {
      debugPrint("Flutter3DGlobe Load Error: $e");
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  Future<ui.Image> _resolveImage(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final config = createLocalImageConfiguration(context);
    final stream = provider.resolve(config);

    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(info.image);
        }
        stream.removeListener(listener);
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        debugPrint("Texture Load Error: $exception");
        if (!completer.isCompleted) {
          completer.completeError(exception);
        }
      },
    );

    stream.addListener(listener);
    return completer.future;
  }

  @override
  void didUpdateWidget(Flutter3DGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_update);
      widget.controller.addListener(_update);
    }
    if (widget.texture != oldWidget.texture) {
      _hasLoadingStarted = false;
      _loadResources();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Text(
          "Error: $_errorMessage",
          style: const TextStyle(color: Colors.red, fontSize: 10),
        ),
      );
    }
    if (_fragmentProgram == null || _earthImage == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      color: widget.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final dpr = MediaQuery.of(context).devicePixelRatio;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // [修改] 开始拖拽：取消计时器，停止自动旋转
            onScaleStart: (d) {
              _autoRotateTimer?.cancel();
              _isAutoRotating = false;

              _baseScale = widget.controller.zoom;
              widget.controller.onDragStart();
            },
            onScaleUpdate: (d) {
              if (d.scale != 1.0) {
                widget.controller.zoom = _baseScale * d.scale;
              }
              final sensitivity = 3.0 / size.width;
              widget.controller.onDragUpdate(
                d.focalPointDelta.dx,
                d.focalPointDelta.dy,
                sensitivity,
              );
            },
            // [修改] 结束拖拽：启动计时器，准备恢复自动旋转
            onScaleEnd: (d) {
              widget.controller.onDragEnd(d.velocity.pixelsPerSecond, dpr);

              _autoRotateTimer = Timer(Duration(seconds: _idleSeconds), () {
                if (mounted) {
                  // 这里只恢复了水平自转开关
                  // 如果需要“垂直归正”，可以在 _autoRotateTick 中添加垂直方向的阻尼逻辑
                  _isAutoRotating = true;
                }
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  size: size,
                  painter: _GlobePainter(
                    fragmentProgram: _fragmentProgram!,
                    image: _earthImage!,
                    controller: widget.controller,
                    markers: widget.markers,
                    connections: widget.connections,
                    animValue: _animController.value,
                    pixelRatio: dpr,
                  ),
                ),
                ..._buildMarkers(size),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildMarkers(Size size) {
    final List<Widget> widgets = [];
    final matrix = widget.controller.getRotationMatrix();
    final double visualCameraDist = 1.4 / max(0.1, widget.controller.zoom);
    final minRes = min(size.width, size.height);

    for (var marker in widget.markers) {
      final pos3D = _GlobeMath.latLonToCartesian(
        marker.latitude,
        marker.longitude,
      );
      final rotatedPos = matrix.transform3(pos3D);

      if (rotatedPos.z <= 0.1) continue;

      final screenPos = _GlobeMath.projectToScreen(
        rotatedPos,
        size,
        visualCameraDist,
        minRes,
      );

      widgets.add(
        Positioned(
          left: screenPos.dx - 24,
          top: screenPos.dy - 24,
          child: GestureDetector(
            onTap: marker.onTap,
            child: Transform.scale(
              scale: 0.8 + (0.2 * widget.controller.zoom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  marker.child,
                  if (marker.label != null && marker.label!.isNotEmpty)
                    Text(
                      marker.label!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

class _GlobePainter extends CustomPainter {
  final FragmentProgram fragmentProgram;
  final ui.Image image;
  final EarthController controller;
  final List<EarthMarker> markers;
  final List<EarthConnection> connections;
  final double animValue;
  final double pixelRatio;

  _GlobePainter({
    required this.fragmentProgram,
    required this.image,
    required this.controller,
    required this.markers,
    required this.connections,
    required this.animValue,
    required this.pixelRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = fragmentProgram.fragmentShader();

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, pixelRatio);
    shader.setFloat(3, animValue * 100);
    shader.setImageSampler(0, image);

    final mat3 = controller.getMatrix33();
    for (int i = 0; i < 9; i++) {
      shader.setFloat(4 + i, mat3[i]);
    }
    shader.setFloat(13, controller.zoom);

    final transform = canvas.getTransform();
    final mat = vm.Matrix4.fromFloat64List(transform);
    mat.invert();
    final invStorage = mat.storage;

    for (int i = 0; i < 16; i++) {
      shader.setFloat(14 + i, invStorage[i]);
    }

    // [关键修改]
    // 增加 filterQuality: FilterQuality.high
    // 增加 isAntiAlias: true
    // 这会让 Shader 在采样纹理时使用更平滑的插值算法
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high, 
    );
    _drawConnections(canvas, size);
  }

  void _drawConnections(Canvas canvas, Size size) {
    final matrix = controller.getRotationMatrix();
    final cameraDist = 1.4 / max(0.1, controller.zoom);
    final minRes = min(size.width, size.height);

    final Map<String, vm.Vector3> posMap = {
      for (var m in markers)
        m.id: _GlobeMath.latLonToCartesian(m.latitude, m.longitude),
    };

    for (var conn in connections) {
      final p1 = posMap[conn.startId];
      final p2 = posMap[conn.endId];
      if (p1 == null || p2 == null) continue;

      final mid = (p1 + p2).normalized();
      if (matrix.transform3(mid).z < -0.4) continue;

      final path = Path();
      bool isFirst = true;
      bool hasSegment = false;

      for (double t = 0; t <= 1.0; t += 0.04) {
        var p = _slerp(p1.normalized(), p2.normalized(), t);
        p = p * (0.5 + sin(t * pi) * 0.05);

        final rP = matrix.transform3(p);
        if (rP.z > 0) {
          hasSegment = true;
          final sPos = _GlobeMath.projectToScreen(rP, size, cameraDist, minRes);
          if (isFirst) {
            path.moveTo(sPos.dx, sPos.dy);
            isFirst = false;
          } else {
            path.lineTo(sPos.dx, sPos.dy);
          }
        } else {
          isFirst = true;
        }
      }

      if (hasSegment) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true; // 线条也开启抗锯齿

        canvas.drawPath(
          path,
          paint
            ..color = conn.color.withOpacity(0.3)
            ..strokeWidth = conn.width + 2,
        );
        canvas.drawPath(
          path,
          paint
            ..color = conn.color.withOpacity(0.8)
            ..strokeWidth = conn.width,
        );
      }
    }
  }

  vm.Vector3 _slerp(vm.Vector3 start, vm.Vector3 end, double t) {
    double dot = start.dot(end).clamp(-1.0, 1.0);
    double theta = acos(dot) * t;
    vm.Vector3 relative = (end - start * dot).normalized();
    return start * cos(theta) + relative * sin(theta);
  }

  @override
  bool shouldRepaint(covariant _GlobePainter old) => true;
}

class _GlobeMath {
  static const double rEarth = 0.5;

  static vm.Vector3 latLonToCartesian(double lat, double lon) {
    final latRad = lat * pi / 180.0;
    final lonRad = lon * pi / 180.0;
    return vm.Vector3(
      rEarth * cos(latRad) * sin(lonRad),
      rEarth * sin(latRad),
      rEarth * cos(latRad) * cos(lonRad),
    );
  }

  static Offset projectToScreen(
    vm.Vector3 p,
    Size size,
    double cameraDist,
    double minDimension,
  ) {
    final perspective = 1.0 - (p.z / cameraDist);
    final safePerspective = max(0.01, perspective);

    final scale = (minDimension / 2.0) / safePerspective;
    return Offset(
      size.width / 2.0 + p.x * scale,
      size.height / 2.0 - p.y * scale,
    );
  }
}