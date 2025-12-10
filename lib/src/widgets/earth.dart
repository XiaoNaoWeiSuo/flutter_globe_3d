import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';
import 'package:flutter_globe_3d/src/painter/earth_painter.dart';

/// 3D 地球组件
class Earth3D extends StatefulWidget {
  /// 全局路由观察者
  /// 请务必在 MaterialApp 的 navigatorObservers 中注册此对象：
  /// `navigatorObservers: [Earth3D.routeObserver]`
  static final RouteObserver<ModalRoute<dynamic>> routeObserver =
      RouteObserver<ModalRoute<dynamic>>();

  final String shaderAsset;
  final ImageProvider texture;
  final ImageProvider? nightTexture; // [新增] 夜景纹理参数
  final EarthController controller;
  final double initialScale;
  final Size? size;

  final double? initialLatitude;
  final double? initialLongitude;

  const Earth3D({
    super.key,
    this.shaderAsset = "packages/flutter_globe_3d/assets/shaders/earth.frag",
    this.texture =
        const AssetImage("packages/flutter_globe_3d/assets/images/earth.jpg"),
    this.nightTexture = const AssetImage(
        "packages/flutter_globe_3d/assets/images/earth_night.jpg"),
    required this.controller,
    this.initialScale = 0.75,
    this.size,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<Earth3D> createState() => _Earth3DState();
}

class _Earth3DState extends State<Earth3D>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  ui.FragmentProgram? _program;
  ui.Image? _textureImage;
  ui.Image? _nightTextureImage; // [新增] 夜景纹理对象
  late Ticker _ticker;
  double _time = 0.0;
  Offset _lastFocalPoint = Offset.zero;
  double _baseZoom = 1.0;
  bool _isInteracting = false;
  late AnimationController _animationController;
  Animation<Offset>? _offsetAnimation;
  Timer? _resetTimer;

  // --- 性能优化状态标志 ---
  bool _isAppResumed = true; // App 是否在前台
  bool _isRouteVisible = true; // 当前页面是否可见（未被其他页面覆盖）

  @override
  void initState() {
    super.initState();
    // 1. 注册 App 生命周期监听
    WidgetsBinding.instance.addObserver(this);

    _loadResources();
    widget.controller.addListener(_onControllerUpdate);

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      widget.controller
          .setCameraFocus(widget.initialLatitude!, widget.initialLongitude!);
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.addListener(() {
      if (_offsetAnimation != null) {
        widget.controller.setOffset(_offsetAnimation!.value);
      }
    });

    _ticker = createTicker((elapsed) {
      double dt = elapsed.inMilliseconds / 1000.0;

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

    // 初始启动检查
    _checkAnimationStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 2. 注册路由监听 (用于检测页面切换)
    final route = ModalRoute.of(context);
    if (route != null) {
      Earth3D.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    // 清理监听器
    WidgetsBinding.instance.removeObserver(this);
    Earth3D.routeObserver.unsubscribe(this);

    _ticker.dispose();
    _animationController.dispose();
    _resetTimer?.cancel();
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  // --- 核心优化逻辑：智能控制动画启停 ---

  /// 根据当前 App 和 路由的状态，决定是否暂停 Ticker
  void _checkAnimationStatus() {
    // 只有当 App 在前台 且 页面可见 且 组件挂载中 时，才运行动画
    bool shouldAnimate = _isAppResumed && _isRouteVisible && mounted;

    if (shouldAnimate) {
      if (!_ticker.isTicking) {
        _ticker.start();
        debugPrint("Earth3D: Animation Resumed (Visible)");
      }
    } else {
      if (_ticker.isTicking) {
        _ticker.stop();
        debugPrint("Earth3D: Animation Paused (Hidden/Background)");
      }
    }
  }

  // 1. App 生命周期回调 (Home 键/切后台)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
    _checkAnimationStatus();
  }

  // 2. RouteAware 回调 (页面导航)

  @override
  void didPushNext() {
    // 当进入下一个页面，当前页面被覆盖 -> 暂停
    _isRouteVisible = false;
    _checkAnimationStatus();
  }

  @override
  void didPopNext() {
    // 当上一个页面被 pop，当前页面重新显示 -> 恢复
    _isRouteVisible = true;
    _checkAnimationStatus();
  }

  @override
  void didPop() {
    // 当前页面被 pop -> 暂停 (随后会 dispose)
    _isRouteVisible = false;
    _checkAnimationStatus();
  }

  // ------------------------------------

  void _onControllerUpdate() {
    // 如果动画已暂停（不可见），则不响应控制器的重绘请求，节省资源
    if (mounted && _isAppResumed && _isRouteVisible) {
      setState(() {});
    }
  }

  Future<void> _loadResources() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(widget.shaderAsset);
      _program = program;
    } catch (e) {
      debugPrint("Shader load failed: $e");
    }

    // 加载白天纹理
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

    // [新增] 加载夜景纹理 (如果有的话)
    if (widget.nightTexture != null) {
      final ImageStream nightStream =
          widget.nightTexture!.resolve(ImageConfiguration.empty);
      nightStream.addListener(
        ImageStreamListener((info, _) {
          if (mounted) {
            setState(() {
              _nightTextureImage = info.image;
            });
          }
        }, onError: (exception, stackTrace) {
          debugPrint("Night texture load failed: $exception");
        }),
      );
    }
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
    double c = math.cos(pitch);
    double s = math.sin(pitch);
    double y1 = y * c - z * s;
    double z1 = y * s + z * c;
    double x1 = x;

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

    // 如果不可见，直接返回占位，或者返回 RepaintBoundary 缓存的图像（这里为了简化直接渲染，但 Ticker 已停）
    // 注意：即使 Ticker 停了，build 仍可能被父组件触发。
    // 为了极致优化，这里可以判断是否可见，不可见时返回 SizedBox()
    // 但为了避免恢复时黑屏闪烁，我们保留渲染结构，依靠停止 Ticker 来停止 GPU 刷新。

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = widget.size?.width ?? constraints.maxWidth;
        final h = widget.size?.height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : w);
        final size = Size(w, h);
        double shaderScale = (w / h) * widget.initialScale;

        // 仅在可见时更新投影计算
        if (_isRouteVisible && _isAppResumed) {
          widget.controller.updateProjections(size, shaderScale, _time);
        }

        // --- 计算光照向量 ---
        double lx = 0, ly = 0, lz = 1.0;

        switch (widget.controller.lightMode) {
          case EarthLightMode.realTime:
            final now = DateTime.now().toUtc();
            double hourOffset =
                now.hour + now.minute / 60.0 + now.second / 3600.0;
            double sunAngle = (hourOffset - 12.0) * 15.0 * (math.pi / 180.0);
            lx = math.cos(sunAngle);
            ly = 0.1;
            lz = -math.sin(sunAngle);
            break;

          case EarthLightMode.fixedCoordinates:
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
            final double yaw = -widget.controller.offset.dx / 200.0;
            final double pitch = widget.controller.offset.dy / 200.0;
            var (rx, ry, rz) = _rotateVector(-1.5, 1.5, -1.0, pitch, yaw);
            lx = rx;
            ly = ry;
            lz = rz;
            break;
        }

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
                      // [新增] 传递夜景纹理和标志
                      nightTexture: _nightTextureImage,
                      hasNightTexture: _nightTextureImage != null,
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
