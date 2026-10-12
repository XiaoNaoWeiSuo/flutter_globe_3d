import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/sphere_shader.dart';
import '../models/sphere_quality.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';
import 'package:flutter_globe_3d/src/models/earth_node.dart';
import '../models/sphere_annotation.dart';
import '../api/sphere_values.dart' show SphereGestureOptions;
import '../core/sphere_annotation_layout.dart';
import 'package:flutter_globe_3d/src/painter/earth_painter.dart';

final Map<String, Future<ui.FragmentProgram>> _fragmentPrograms = {};

Future<ui.FragmentProgram> _loadFragmentProgram(String asset) {
  return _fragmentPrograms.putIfAbsent(asset, () async {
    try {
      return await ui.FragmentProgram.fromAsset(asset);
    } catch (_) {
      _fragmentPrograms.remove(asset);
      rethrow;
    }
  });
}

/// Renders an interactive, textured sphere with Flutter widget overlays.
///
/// The sphere surface is drawn by a fragment shader. Nodes are ordinary
/// two-dimensional Flutter widgets positioned by geographic projection; they
/// are not warped onto the sphere. Supply finite layout constraints, register
/// [routeObserver] with the app's navigator to pause rendering when covered,
/// and dispose the [controller] from the code that owns it.
class Globe3D extends StatefulWidget {
  /// Shared observer used to pause this widget's ticker when its route is
  /// covered. Register it in `MaterialApp.navigatorObservers`.
  static final RouteObserver<ModalRoute<dynamic>> routeObserver =
      RouteObserver<ModalRoute<dynamic>>();

  /// Fragment shader asset implementing the renderer's uniform protocol.
  /// The resource is reloaded when this value changes.
  final String shaderAsset;

  /// Color texture in equirectangular (longitude/latitude) projection.
  /// The resource is reloaded when this value changes.
  final ImageProvider texture;

  /// Optional night-lights texture in the same projection. Set to `null` to
  /// disable it. The resource is reloaded when this value changes.
  final ImageProvider? nightTexture;

  /// Camera, lighting, marker, connection and quality state for this sphere.
  final GlobeController controller;

  /// Legacy layout scale, multiplied by viewport width / height before
  /// rendering. Must be finite; for a desired effective scale `s`, pass
  /// `s * height / width`.
  final double initialScale;

  /// Viewport spacing and hysteresis used by external annotation nodes.
  final SphereAnnotationLayout annotationLayout;

  /// Optional logical dimensions, still constrained by the parent.
  final Size? size;

  /// Latitude initially focused after resources initialize. Takes effect only
  /// when [initialLongitude] is also provided.
  final double? initialLatitude;

  /// Longitude initially focused after resources initialize. Takes effect
  /// only when [initialLatitude] is also provided.
  final double? initialLongitude;

  /// Gesture policy configured by the public Sphere view.
  final SphereGestureOptions gestures;

  /// Whether this view should advance visual animation.
  final bool active;

  /// Internal callback for camera and spin coordination.
  final VoidCallback? onInteractionStart;

  /// Reports app/route/TickerMode visibility to the public controller.
  final ValueChanged<bool>? onVisibilityChanged;

  /// Creates an interactive textured sphere.
  ///
  /// [controller] is required and remains owned by the caller. Texture and
  /// shader resources reload in-place when their properties change.
  const Globe3D({
    super.key,
    this.shaderAsset = defaultSphereShaderAsset,
    this.texture = const AssetImage(
      "packages/flutter_globe_3d/assets/images/earth.jpg",
    ),
    this.nightTexture = const AssetImage(
      "packages/flutter_globe_3d/assets/images/earth_night.jpg",
    ),
    required this.controller,
    this.initialScale = 0.75,
    this.annotationLayout = const SphereAnnotationLayout(),
    this.size,
    this.initialLatitude,
    this.initialLongitude,
    this.gestures = const SphereGestureOptions(),
    this.active = true,
    this.onInteractionStart,
    this.onVisibilityChanged,
  });

  @override
  State<Globe3D> createState() => _Globe3DState();
}

class _Globe3DState extends State<Globe3D>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  ui.FragmentShader? _shader;
  SphereQuality? _activeShaderQuality;
  final Map<SphereQuality, ui.FragmentShader> _qualityShaders = {};
  final Map<SphereQuality, Future<ui.FragmentShader>> _loadingShaders = {};
  Future<ui.FragmentShader>? _loadingCustomShader;
  ui.Image? _textureImage;
  ui.Image? _nightTextureImage; // [新增] 夜景纹理对象
  ImageStream? _textureStream;
  ImageStreamListener? _textureListener;
  ImageStream? _nightTextureStream;
  ImageStreamListener? _nightTextureListener;
  int _resourceGeneration = 0;
  int _shaderGeneration = 0;
  late Ticker _ticker;
  late final ValueNotifier<double> _timeNotifier;
  late final _SceneRepaintNotifier _repaintNotifier;
  Offset _lastFocalPoint = Offset.zero;
  double _baseZoom = 1.0;
  bool _isInteracting = false;
  Offset _velocity = Offset.zero;
  Duration _lastTickerElapsed = Duration.zero;
  int _lastCameraFocusRevision = 0;
  Timer? _sunTimer;

  // --- 性能优化状态标志 ---
  bool _isAppResumed = true; // App 是否在前台
  bool _isRouteVisible = true; // 当前页面是否可见（未被其他页面覆盖）
  bool _isTickerModeEnabled = true;
  bool? _reportedVisibility;

  @override
  void initState() {
    super.initState();
    // 1. 注册 App 生命周期监听
    WidgetsBinding.instance.addObserver(this);

    _timeNotifier = ValueNotifier<double>(0.0);
    _repaintNotifier = _SceneRepaintNotifier(
      controller: widget.controller,
      timeListenable: _timeNotifier,
    );

    _loadResources();

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      widget.controller.setCameraFocus(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    }

    _lastCameraFocusRevision = widget.controller.cameraFocusRevision;
    widget.controller.addListener(_handleControllerChanged);

    _ticker = createTicker((elapsed) {
      final delta = elapsed >= _lastTickerElapsed
          ? elapsed - _lastTickerElapsed
          : elapsed;
      _lastTickerElapsed = elapsed;
      final dt = elapsed.inMilliseconds / 1000.0;

      final seconds = delta.inMicroseconds / Duration.microsecondsPerSecond;
      widget.controller.advanceCameraAnimation(delta);
      if (!_isInteracting && !widget.controller.isCameraAnimating) {
        if (_velocity.distance > 1) {
          final decay = math.exp(-5 * seconds);
          widget.controller.orbit(_velocity * ((1 - decay) / 5));
          _velocity *= decay;
        } else if (widget.controller.enableAutoRotate) {
          // Legacy speed units at 60 Hz, now independent of device refresh rate.
          widget.controller
              .orbit(Offset(widget.controller.rotateSpeed * 60 * seconds, 0));
        }
      }
      // Camera updates already notify the painter. Only time-based effects
      // need an additional animation signal.
      if (_hasTimeAnimation) _timeNotifier.value = dt;
      _checkAnimationStatus();
    });

    // 初始启动检查
    _checkAnimationStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isTickerModeEnabled = TickerMode.valuesOf(context).enabled;
    // 2. 注册路由监听 (用于检测页面切换)
    final route = ModalRoute.of(context);
    if (route != null) {
      Globe3D.routeObserver.subscribe(this, route);
    }
    _checkAnimationStatus();
  }

  @override
  void dispose() {
    // 清理监听器
    WidgetsBinding.instance.removeObserver(this);
    Globe3D.routeObserver.unsubscribe(this);
    widget.controller.removeListener(_handleControllerChanged);
    _removeTextureListeners();
    _resourceGeneration++;
    _shaderGeneration++;

    _ticker.dispose();
    _sunTimer?.cancel();

    _repaintNotifier.dispose();
    _timeNotifier.dispose();
    for (final shader in _qualityShaders.values) {
      shader.dispose();
    }
    if (widget.shaderAsset != defaultSphereShaderAsset && _shader != null) {
      _shader?.dispose();
    }
    super.dispose();
  }

  // --- 核心优化逻辑：智能控制动画启停 ---

  /// 根据当前 App 和 路由的状态，决定是否暂停 Ticker
  void _checkAnimationStatus() {
    final visible = _isAppResumed &&
        _isRouteVisible &&
        _isTickerModeEnabled &&
        widget.active &&
        mounted;
    if (_reportedVisibility != visible) {
      _reportedVisibility = visible;
      widget.onVisibilityChanged?.call(visible);
    }
    final motion = widget.controller.isCameraAnimating ||
        (!_isInteracting &&
            (_velocity.distance > 1 || widget.controller.enableAutoRotate)) ||
        _hasTimeAnimation;
    final shouldAnimate = visible && motion;

    if (shouldAnimate) {
      if (!_ticker.isTicking) {
        _lastTickerElapsed = Duration.zero;
        _ticker.start();
      }
    } else {
      if (_ticker.isTicking) {
        _ticker.stop();
      }
    }
    // Static real-time lighting changes only once a second. It must not keep
    // a vsync loop alive when the sphere itself is stationary.
    if (visible &&
        !shouldAnimate &&
        widget.controller.lightMode == GlobeLightMode.realTime) {
      _sunTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        _timeNotifier.value += 1;
      });
    } else {
      _sunTimer?.cancel();
      _sunTimer = null;
    }
  }

  bool get _hasTimeAnimation =>
      widget.shaderAsset != defaultSphereShaderAsset ||
      widget.controller.connections.any((connection) => connection.isDashed);

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

  @override
  void didUpdateWidget(covariant Globe3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _checkAnimationStatus();
    if (oldWidget.texture != widget.texture ||
        oldWidget.nightTexture != widget.nightTexture) {
      _loadTextures();
    }
    if (oldWidget.shaderAsset != widget.shaderAsset) {
      _replaceShaderAsset(
        oldWasCustom: oldWidget.shaderAsset != defaultSphereShaderAsset,
      );
    }
    if (oldWidget.controller.quality != widget.controller.quality) {
      _updateQualityShader();
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      _repaintNotifier.updateController(widget.controller);
      _lastCameraFocusRevision = widget.controller.cameraFocusRevision;
      widget.controller.addListener(_handleControllerChanged);
      _updateQualityShader();
      _checkAnimationStatus();
    }
  }

  void _handleControllerChanged() {
    if (widget.shaderAsset == defaultSphereShaderAsset &&
        _activeShaderQuality != widget.controller.quality &&
        !_loadingShaders.containsKey(widget.controller.quality)) {
      _updateQualityShader();
    } else if (_qualityShaders.containsKey(widget.controller.quality) &&
        _activeShaderQuality != widget.controller.quality) {
      _updateQualityShader();
    }
    final revision = widget.controller.cameraFocusRevision;
    if (revision == _lastCameraFocusRevision) {
      _checkAnimationStatus();
      return;
    }

    _lastCameraFocusRevision = revision;
    _velocity = Offset.zero;
    _isInteracting = false;
    _checkAnimationStatus();
  }

  Future<void> _loadResources() async {
    await _updateQualityShader();
    _loadTextures();
  }

  void _removeTextureListeners() {
    if (_textureStream != null && _textureListener != null) {
      _textureStream!.removeListener(_textureListener!);
    }
    if (_nightTextureStream != null && _nightTextureListener != null) {
      _nightTextureStream!.removeListener(_nightTextureListener!);
    }
    _textureStream = null;
    _textureListener = null;
    _nightTextureStream = null;
    _nightTextureListener = null;
  }

  void _loadTextures() {
    _removeTextureListeners();
    final generation = ++_resourceGeneration;
    if (widget.nightTexture == null) _nightTextureImage = null;
    _textureStream = widget.texture.resolve(
      createLocalImageConfiguration(context),
    );
    _textureListener = ImageStreamListener((info, _) {
      if (!mounted || generation != _resourceGeneration) return;
      setState(() => _textureImage = info.image);
    }, onError: (Object error, StackTrace? stackTrace) {
      if (generation == _resourceGeneration) {
        debugPrint('Sphere texture load failed: $error');
      }
    });
    _textureStream!.addListener(_textureListener!);

    final nightTexture = widget.nightTexture;
    if (nightTexture == null) return;
    _nightTextureStream = nightTexture.resolve(
      createLocalImageConfiguration(context),
    );
    _nightTextureListener = ImageStreamListener((info, _) {
      if (!mounted || generation != _resourceGeneration) return;
      setState(() => _nightTextureImage = info.image);
    }, onError: (Object error, StackTrace? stackTrace) {
      if (generation == _resourceGeneration) {
        debugPrint('Sphere night texture load failed: $error');
      }
    });
    _nightTextureStream!.addListener(_nightTextureListener!);
  }

  void _replaceShaderAsset({required bool oldWasCustom}) {
    _shaderGeneration++;
    _loadingShaders.clear();
    _loadingCustomShader = null;
    if (oldWasCustom) {
      _shader?.dispose();
    }
    _shader = null;
    _activeShaderQuality = null;
    _updateQualityShader();
  }

  Future<void> _updateQualityShader() async {
    final builtIn = widget.shaderAsset == defaultSphereShaderAsset;
    final quality = widget.controller.quality;
    if (builtIn && _activeShaderQuality == quality) return;
    if (!builtIn && _shader != null) return;
    final generation = _shaderGeneration;
    try {
      if (builtIn) {
        final cached = _qualityShaders[quality];
        if (cached != null) {
          _shader = cached;
          _activeShaderQuality = quality;
          setState(() {});
          return;
        }
        final pending = _loadingShaders.putIfAbsent(quality, () async {
          final program =
              await _loadFragmentProgram(sphereShaderAsset(quality));
          final shader = program.fragmentShader();
          if (mounted && generation == _shaderGeneration) {
            _qualityShaders[quality] = shader;
          } else {
            shader.dispose();
          }
          return shader;
        });
        ui.FragmentShader shader;
        try {
          shader = await pending;
        } finally {
          if (identical(_loadingShaders[quality], pending)) {
            _loadingShaders.remove(quality);
          }
        }
        if (mounted &&
            generation == _shaderGeneration &&
            widget.controller.quality == quality &&
            _activeShaderQuality != quality) {
          // Keep the current image while a new variant loads; no blank frame.
          setState(() {
            _shader = shader;
            _activeShaderQuality = quality;
          });
        }
      } else {
        final pending = _loadingCustomShader ??= () async {
          final program = await _loadFragmentProgram(widget.shaderAsset);
          final shader = program.fragmentShader();
          if (!mounted || generation != _shaderGeneration) shader.dispose();
          return shader;
        }();
        ui.FragmentShader shader;
        try {
          shader = await pending;
        } finally {
          if (identical(_loadingCustomShader, pending)) {
            _loadingCustomShader = null;
          }
        }
        if (mounted && generation == _shaderGeneration) {
          setState(() => _shader = shader);
        }
      }
    } catch (e) {
      debugPrint("Shader load failed: $e");
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    widget.onInteractionStart?.call();
    widget.controller.cancelCameraAnimation();
    _isInteracting = true;
    _velocity = Offset.zero;
    _checkAnimationStatus();
    _lastFocalPoint = details.localFocalPoint;
    _baseZoom = widget.controller.zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (widget.gestures.zoomEnabled) {
      widget.controller.setZoom(_baseZoom * details.scale);
    }
    if (widget.gestures.orbitEnabled) {
      final delta = details.localFocalPoint - _lastFocalPoint;
      widget.controller.orbit(Offset(
        delta.dx,
        widget.gestures.verticalOrbitEnabled ? delta.dy : 0,
      ));
    }
    _lastFocalPoint = details.localFocalPoint;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _isInteracting = false;
    _velocity = widget.gestures.inertiaEnabled
        ? details.velocity.pixelsPerSecond
        : Offset.zero;
    _checkAnimationStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_shader == null || _textureImage == null) {
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
        final w = constraints
            .constrainWidth(widget.size?.width ?? constraints.maxWidth);
        final h = constraints.constrainHeight(widget.size?.height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : w));
        final size = Size(w, h);
        final shaderScale =
            h == 0 ? widget.initialScale : (w / h) * widget.initialScale;

        final hasGesture =
            widget.gestures.orbitEnabled || widget.gestures.zoomEnabled;
        return GestureDetector(
          onScaleStart: hasGesture ? _onScaleStart : null,
          onScaleUpdate: hasGesture ? _onScaleUpdate : null,
          onScaleEnd: hasGesture ? _onScaleEnd : null,
          child: SizedBox(
            width: w,
            height: h,
            child: ClipRect(
                child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: EarthScenePainter(
                      shader: _shader!,
                      shaderQuality: _activeShaderQuality,
                      texture: _textureImage!,
                      trimEarthTextureEdges: widget.texture ==
                          const AssetImage(
                            'packages/flutter_globe_3d/assets/images/earth.jpg',
                          ),
                      nightTexture: _nightTextureImage,
                      hasNightTexture: _nightTextureImage != null,
                      resolution: size,
                      scale: shaderScale,
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                      controller: widget.controller,
                      timeListenable: _timeNotifier,
                      repaint: _repaintNotifier,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: _SphereNodeLayer(
                    controller: widget.controller,
                    initialScale: widget.initialScale,
                    annotationLayout: widget.annotationLayout,
                  ),
                ),
              ],
            )),
          ),
        );
      },
    );
  }
}

/// Combines controller changes and animation time into one repaint signal.
class _SceneRepaintNotifier extends ChangeNotifier {
  GlobeController _controller;
  final Listenable _timeListenable;

  _SceneRepaintNotifier({
    required GlobeController controller,
    required Listenable timeListenable,
  })  : _controller = controller,
        _timeListenable = timeListenable {
    _controller.addListener(_notify);
    _timeListenable.addListener(_notify);
  }

  void updateController(GlobeController controller) {
    if (identical(_controller, controller)) return;
    _controller.removeListener(_notify);
    _controller = controller;
    _controller.addListener(_notify);
    notifyListeners();
  }

  void _notify() {
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.removeListener(_notify);
    _timeListenable.removeListener(_notify);
    super.dispose();
  }
}

/// Keeps real Flutter widgets interactive while only relaying their positions
/// during camera movement. The children themselves are not rebuilt every
/// frame; the layout delegate is invalidated by the controller instead.
class _SphereNodeLayer extends StatefulWidget {
  final GlobeController controller;
  final double initialScale;
  final SphereAnnotationLayout annotationLayout;

  const _SphereNodeLayer({
    required this.controller,
    required this.initialScale,
    required this.annotationLayout,
  });

  @override
  State<_SphereNodeLayer> createState() => _SphereNodeLayerState();
}

class _SphereNodeLayerState extends State<_SphereNodeLayer> {
  late List<GlobeNode> _nodes;
  SphereAnnotationLayoutEngine _annotations = SphereAnnotationLayoutEngine();

  @override
  void initState() {
    super.initState();
    _nodes = List<GlobeNode>.of(widget.controller.nodes);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _SphereNodeLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _nodes = List<GlobeNode>.of(widget.controller.nodes);
      _annotations = SphereAnnotationLayoutEngine();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final currentNodes = widget.controller.nodes;
    if (currentNodes.length == _nodes.length &&
        currentNodes.asMap().entries.every(
              (entry) => identical(entry.value, _nodes[entry.key]),
            )) {
      return;
    }

    setState(() {
      _nodes = List<GlobeNode>.of(currentNodes);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: _SphereNodeLayoutDelegate(
        controller: widget.controller,
        initialScale: widget.initialScale,
        nodes: _nodes,
        annotationLayout: widget.annotationLayout,
        annotations: _annotations,
      ),
      children: [
        for (final node in _nodes)
          LayoutId(
            id: node.id,
            child: KeyedSubtree(
              key: ValueKey<String>(node.id),
              child: node.child,
            ),
          ),
      ],
    );
  }
}

class _SphereNodeLayoutDelegate extends MultiChildLayoutDelegate {
  final GlobeController controller;
  final double initialScale;
  final List<GlobeNode> nodes;
  final SphereAnnotationLayout annotationLayout;
  final SphereAnnotationLayoutEngine annotations;

  _SphereNodeLayoutDelegate({
    required this.controller,
    required this.initialScale,
    required this.nodes,
    required this.annotationLayout,
    required this.annotations,
  }) : super(relayout: controller);

  @override
  void performLayout(Size size) {
    final height = size.height == 0 ? 1.0 : size.height;
    final scale = (size.width / height) * initialScale;

    // Layout happens before paint, so the painter sees paths generated for
    // this camera state in the same frame.
    controller.updateProjections(size, scale, 0.0);

    final annotationEntries = <SphereAnnotationEntry>[];
    final measured = <String, Size>{};
    final maxColumnWidth = math.max(
        0.0,
        (size.width -
                annotationLayout.padding.horizontal -
                annotationLayout.columnGap) /
            2);

    for (final node in nodes) {
      if (!hasChild(node.id)) continue;

      final isAnnotation = node.type != SphereNodeType.surface;
      final childSize = layoutChild(
          node.id,
          isAnnotation
              ? BoxConstraints(
                  maxWidth:
                      math.min(maxColumnWidth, node.annotationStyle.maxWidth),
                  maxHeight: size.height)
              : BoxConstraints.loose(size));
      measured[node.id] = childSize;
      final position = controller.projectedPositions[node.id];
      final isVisible = controller.nodeVisibility[node.id] ?? false;

      if (!isVisible || position == null) {
        positionChild(
          node.id,
          Offset(-childSize.width * 2, -childSize.height * 2),
        );
        continue;
      }

      if (isAnnotation) {
        annotationEntries.add(SphereAnnotationEntry(node, position, childSize));
        continue;
      }

      positionChild(
        node.id,
        Offset(
          position.dx - childSize.width / 2,
          position.dy - childSize.height / 2,
        ),
      );
    }
    annotations.retainIds(nodes.map((node) => node.id).toSet());
    final placements =
        annotations.layout(size, annotationEntries, annotationLayout);
    controller.updateAnnotationPlacements(placements);
    for (final node in nodes) {
      if (node.type == SphereNodeType.surface || !hasChild(node.id)) continue;
      final rect = placements[node.id]?.labelRect;
      final childSize = measured[node.id]!;
      positionChild(
          node.id,
          rect?.topLeft ??
              Offset(-childSize.width * 2 - 1, -childSize.height * 2 - 1));
    }
  }

  @override
  bool shouldRelayout(covariant _SphereNodeLayoutDelegate oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.initialScale != initialScale ||
        oldDelegate.annotationLayout != annotationLayout ||
        !identical(oldDelegate.nodes, nodes);
  }
}

/// Legacy API compatibility alias.
///
/// @deprecated Use [Globe3D] instead. This alias is retained for backward
/// compatibility.
@Deprecated('Use Globe3D instead.')
typedef Earth3D = Globe3D;

/// Compatibility alias for the Sphere-prefixed API.
typedef Sphere3D = Globe3D;
