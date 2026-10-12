import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controller/earth_controller.dart' as engine;
import '../models/earth_connection.dart' as engine;
import '../models/earth_node.dart' as engine;
import '../models/sphere_annotation.dart';
import '../models/globe_vector3.dart' as vector_engine;
import '../models/sphere_glow.dart' as glow_engine;
import '../models/sphere_quality.dart';
import '../widgets/earth.dart' as engine;
import 'sphere_scene.dart';
import 'sphere_values.dart';

class _ScopedNotifier extends ChangeNotifier {
  void emit() => notifyListeners();
}

/// Owns camera and spin controls for one sphere view.
///
/// A controller can be attached to one [SphereView] at a time. Dispose a
/// controller you create; a view creates and disposes its own when none is
/// supplied.
class SphereController {
  /// Creates a controller with an initial camera pose and spin configuration.
  SphereController({
    SphereCameraPose initialPose = const SphereCameraPose.overview(),
    SphereCameraLimits limits = const SphereCameraLimits(),
    SphereSpinOptions spinOptions = const SphereSpinOptions(),
  })  : _engine = engine.GlobeController(),
        _camera = SphereCamera._(),
        _spin = SphereSpin._(spinOptions) {
    _validateLimits(limits);
    _validateSpinOptions(spinOptions);
    _camera._owner = this;
    _camera._limits = limits;
    _spin._owner = this;
    _engine
      ..enableAutoRotate = false
      ..minZoom = limits.minZoom
      ..maxZoom = limits.maxZoom
      ..addListener(_camera._onEngineChanged);
    _camera.setPose(initialPose);
  }

  final engine.GlobeController _engine;
  final SphereCamera _camera;
  final SphereSpin _spin;
  bool _disposed = false;

  /// Camera pose commands and read-only camera state.
  SphereCamera get camera => _camera;

  /// Automatic rotation controls and state.
  SphereSpin get spin => _spin;

  /// Whether this controller has been disposed.
  bool get isDisposed => _disposed;

  /// Releases camera, spin, and rendering state.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _camera._dispose();
    _spin._dispose();
    _engine.removeListener(_camera._onEngineChanged);
    _engine.cancelCameraAnimation();
    _engine.dispose();
  }
}

/// Camera controls and state for a [SphereController].
///
/// This object is owned by its root controller and cannot be constructed
/// independently.
class SphereCamera implements Listenable {
  SphereCamera._();

  final _ScopedNotifier _notifier = _ScopedNotifier();

  late SphereController _owner;
  SphereCameraLimits _limits = const SphereCameraLimits();
  Completer<SphereCameraResult>? _activeAnimation;
  Object? _attachedView;
  int? _lastNotifiedRevision;

  engine.GlobeController get _engine => _owner._engine;

  /// Current immutable pose snapshot in right-handed sphere world coordinates.
  SphereCameraState get state => SphereCameraState(
        target: _convert(_engine.cameraTarget),
        position: _convert(_engine.cameraPosition) / _engine.cameraWorldRadius,
        forward: _convert(_engine.cameraForward),
        right: _convert(_engine.cameraRight),
        up: _convert(_engine.cameraUp),
        distance: _engine.cameraDistance / _engine.cameraWorldRadius,
        zoom: _engine.zoom,
        isAnimating: _engine.isCameraAnimating,
      );

  /// Current view zoom.
  double get zoom => _engine.zoom;

  /// Current zoom limits. Updating them clamps the present zoom.
  SphereCameraLimits get limits => _limits;
  set limits(SphereCameraLimits value) {
    _checkOwner();
    _validateLimits(value);
    if (_limits == value) return;
    final revision = _engine.cameraStateRevision;
    _completeActive(SphereCameraResult.interrupted);
    _engine.cancelCameraAnimation();
    _limits = value;
    _engine
      ..minZoom = value.minZoom
      ..maxZoom = value.maxZoom
      ..setZoom(_clamp(_engine.zoom));
    if (_engine.cameraStateRevision == revision) _notifier.emit();
  }

  /// Whether a camera transition is active.
  bool get isAnimating => _engine.isCameraAnimating;

  /// Immediately applies [pose]. Stops spin and cancels an active animation.
  void setPose(SphereCameraPose pose) {
    _checkOwner();
    pose.validate();
    _completeActive(SphereCameraResult.cancelled);
    _owner._spin._stopForCameraCommand();
    _apply(pose, Duration.zero, Curves.easeInOutCubic);
  }

  /// Animates from the current pose to [pose].
  ///
  /// A replacement animation or user gesture completes the previous request as
  /// [SphereCameraResult.interrupted]. Explicit cancellation completes it as
  /// [SphereCameraResult.cancelled]. Detaching the view and disposing the
  /// controller complete pending work with their respective results.
  Future<SphereCameraResult> animateTo(
    SphereCameraPose pose, {
    Duration duration = const Duration(milliseconds: 900),
    Curve curve = Curves.easeInOutCubic,
  }) {
    _checkOwner();
    try {
      pose.validate();
      if (duration < Duration.zero) {
        throw ArgumentError.value(duration, 'duration', 'Cannot be negative.');
      }
      if (duration > Duration.zero && _attachedView == null) {
        throw StateError('An animated camera command requires a mounted view.');
      }
    } catch (error, stackTrace) {
      return Future<SphereCameraResult>.error(error, stackTrace);
    }
    if (duration == Duration.zero) {
      setPose(pose);
      return Future.value(SphereCameraResult.completed);
    }

    _completeActive(SphereCameraResult.interrupted);
    final completer = Completer<SphereCameraResult>();
    _activeAnimation = completer;
    _owner._spin._stopForCameraCommand();
    try {
      _apply(pose, duration, curve);
    } catch (error, stackTrace) {
      if (identical(_activeAnimation, completer)) {
        _activeAnimation = null;
      }
      completer.completeError(error, stackTrace);
    }
    return completer.future;
  }

  /// Animates to a surface point and keeps it at viewport center.
  Future<SphereCameraResult> focus({
    required SphereCoordinate target,
    SphereViewAngle view = const SphereViewAngle.front(),
    double zoom = 1,
    Duration duration = const Duration(milliseconds: 900),
    Curve curve = Curves.easeInOutCubic,
  }) =>
      animateTo(
        SphereCameraPose.focus(target: target, view: view, zoom: zoom),
        duration: duration,
        curve: curve,
      );

  /// Animates to a centered overview with an explicit geographic facing.
  Future<SphereCameraResult> overview({
    SphereCoordinate facing = const SphereCoordinate(latitude: 0, longitude: 0),
    SphereViewAngle view = const SphereViewAngle.front(),
    double zoom = 1,
    Duration duration = const Duration(milliseconds: 900),
    Curve curve = Curves.easeInOutCubic,
  }) =>
      animateTo(
        SphereCameraPose.overview(facing: facing, view: view, zoom: zoom),
        duration: duration,
        curve: curve,
      );

  /// Cancels the current transition while retaining its current pose.
  void cancel() {
    _checkOwner();
    if (!_engine.isCameraAnimating) return;
    _completeActive(SphereCameraResult.cancelled);
    _engine.cancelCameraAnimation();
  }

  /// Sets zoom immediately, clipped to [limits].
  void setZoom(double value) {
    _checkOwner();
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(
          value, 'value', 'Zoom must be finite and positive.');
    }
    final next = _clamp(value);
    if (next == _engine.zoom) return;
    _completeActive(SphereCameraResult.interrupted);
    _engine.setZoom(next);
  }

  void _apply(SphereCameraPose pose, Duration duration, Curve curve) {
    final zoom = _clamp(pose.zoom);
    if (pose.worldTarget case final target?) {
      _engine.setCameraWorldPose(
        _toEngine(target),
        _toEngine(pose.worldDirection!),
        _toEngine(pose.worldUp!),
        zoom: zoom,
        duration: duration,
        curve: curve,
      );
    } else if (pose.focusPoint case final target?) {
      final view = pose.view;
      _engine.focusOnCoordinates(
        target.latitude,
        target.longitude,
        viewDirection: _toEngine(view.localDirection),
        tangent: _toEngine(view.localUpHint(target)),
        zoom: zoom,
        duration: duration,
        curve: curve,
      );
    } else {
      final target = pose.facing!;
      final view = pose.view;
      _engine.setCameraOverviewPose(
        target.latitude,
        target.longitude,
        viewDirection: _toEngine(view.localDirection),
        tangent: _toEngine(view.localUpHint(target)),
        zoom: zoom,
        duration: duration,
        curve: curve,
      );
    }
  }

  double _clamp(double value) => value.clamp(_limits.minZoom, _limits.maxZoom);

  void _onEngineChanged() {
    if (_activeAnimation != null && !_engine.isCameraAnimating) {
      final error = _engine.takeCameraAnimationError();
      if (error != null) {
        final (exception, stackTrace) = error;
        final active = _activeAnimation;
        _activeAnimation = null;
        if (active != null && !active.isCompleted) {
          active.completeError(exception, stackTrace);
        }
      } else {
        _completeActive(SphereCameraResult.completed);
      }
    }
    final revision = _engine.cameraStateRevision;
    if (_lastNotifiedRevision == revision) return;
    _lastNotifiedRevision = revision;
    _notifier.emit();
  }

  void _onGestureStart() {
    if (_activeAnimation != null) {
      _completeActive(SphereCameraResult.interrupted);
    }
  }

  void _attach(Object view) {
    if (_attachedView != null && !identical(_attachedView, view)) {
      throw StateError('A SphereController can be attached to only one view.');
    }
    _attachedView = view;
  }

  void _detach(Object view) {
    if (!identical(_attachedView, view)) return;
    _attachedView = null;
    _completeActive(SphereCameraResult.detached);
    if (!_owner.isDisposed) _engine.cancelCameraAnimation();
  }

  void _dispose() {
    _completeActive(SphereCameraResult.disposed);
    _notifier.dispose();
  }

  @override
  void addListener(VoidCallback listener) => _notifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _notifier.removeListener(listener);

  void _completeActive(SphereCameraResult result) {
    final active = _activeAnimation;
    if (active == null) return;
    _activeAnimation = null;
    if (!active.isCompleted) active.complete(result);
  }

  void _checkOwner() {
    if (_owner.isDisposed) throw StateError('SphereController is disposed.');
  }

  static SphereVector3 _convert(vector_engine.GlobeVector3 value) =>
      SphereVector3(value.x, value.y, value.z);

  static vector_engine.GlobeVector3 _toEngine(SphereVector3 value) =>
      vector_engine.GlobeVector3(value.x, value.y, value.z);
}

/// Automatic spin controls and observable state.
class SphereSpin implements Listenable {
  SphereSpin._(SphereSpinOptions options) : _options = options;

  final _ScopedNotifier _notifier = _ScopedNotifier();

  SphereController? _owner;
  SphereSpinOptions _options;
  bool _running = false;
  bool _suspended = false;

  /// Current immutable spin state.
  SphereSpinState get state => SphereSpinState(
        running: _running,
        suspended: _suspended,
        options: _options,
      );

  /// Replaces spin settings atomically.
  void configure(SphereSpinOptions options) {
    _validateSpinOptions(options);
    if (_options.degreesPerSecond == options.degreesPerSecond) return;
    _options = options;
    _sync();
    _notifier.emit();
  }

  /// Starts or resumes rotation.
  void start() {
    if (_running) return;
    _running = true;
    _sync();
    _notifier.emit();
  }

  /// Stops rotation. Lifecycle resume does not restart a stopped spin.
  void stop() {
    if (!_running) return;
    _running = false;
    _sync();
    _notifier.emit();
  }

  void _setSuspended(bool value) {
    if (_suspended == value) return;
    _suspended = value;
    _sync();
    _notifier.emit();
  }

  void _dispose() => _notifier.dispose();

  @override
  void addListener(VoidCallback listener) => _notifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _notifier.removeListener(listener);

  void _stopForCameraCommand() => stop();

  void _sync() {
    final owner = _owner;
    if (owner == null || owner.isDisposed) return;
    final active = _running && !_suspended && _options.degreesPerSecond != 0;
    owner._engine
      ..rotateSpeed = _options.degreesPerSecond * math.pi / 54
      ..enableAutoRotate = active;
  }
}

/// Renders a textured interactive sphere and declarative marker scene.
///
/// A general sphere requires an equirectangular [texture]. Use
/// [SphereView.earth] for the package's bundled day/night textures. Widget
/// dimensions come from normal Flutter layout constraints.
class SphereView extends StatefulWidget {
  /// Shared observer to register with a MaterialApp navigator.
  static final RouteObserver<ModalRoute<dynamic>> routeObserver =
      engine.Globe3D.routeObserver;

  /// General color texture in longitude/latitude projection.
  final ImageProvider texture;

  /// Optional night-lights texture. Defaults to no night layer.
  final ImageProvider? nightTexture;

  /// Camera and spin controller. If omitted, this widget creates and owns one.
  final SphereController? controller;

  /// Fraction of the viewport's shorter side occupied by the sphere at
  /// overview zoom 1.
  final double diameterFactor;

  /// Shader sampling quality.
  final SphereQuality quality;

  /// Lighting configuration.
  final SphereLighting lighting;

  /// Atmosphere configuration.
  final SphereGlow glow;

  /// User gesture behavior.
  final SphereGestureOptions gestures;

  /// Annotation viewport spacing.
  final SphereAnnotationLayout annotationLayout;

  /// Marker widgets and their geographic anchors.
  final List<SphereNode> nodes;

  /// Curved connections between marker IDs.
  final List<SphereConnection> connections;

  /// Whether this view is active. Inactive views pause animated work.
  final bool active;

  /// Creates a general textured sphere.
  const SphereView({
    super.key,
    required this.texture,
    this.nightTexture,
    this.controller,
    this.diameterFactor = 0.85,
    this.quality = SphereQuality.medium,
    this.lighting = const SphereLighting.followCamera(),
    this.glow = const SphereGlow.automatic(),
    this.gestures = const SphereGestureOptions(),
    this.annotationLayout = const SphereAnnotationLayout(),
    this.nodes = const [],
    this.connections = const [],
    this.active = true,
  });

  /// Creates a sphere with the package's bundled Earth day/night textures.
  const SphereView.earth({
    super.key,
    this.controller,
    this.diameterFactor = 0.85,
    this.quality = SphereQuality.medium,
    this.lighting = const SphereLighting.followCamera(),
    this.glow = const SphereGlow.automatic(),
    this.gestures = const SphereGestureOptions(),
    this.annotationLayout = const SphereAnnotationLayout(),
    this.nodes = const [],
    this.connections = const [],
    this.active = true,
  })  : texture = const AssetImage(
          'packages/flutter_globe_3d/assets/images/earth.jpg',
        ),
        nightTexture = const AssetImage(
          'packages/flutter_globe_3d/assets/images/earth_night.jpg',
        );

  @override
  State<SphereView> createState() => _SphereViewState();
}

class _SphereViewState extends State<SphereView> {
  late SphereController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? SphereController();
    _controller.camera._attach(this);
    _applyConfiguration();
  }

  @override
  void didUpdateWidget(covariant SphereView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.camera._detach(this);
      if (_ownsController) _controller.dispose();
      _ownsController = widget.controller == null;
      _controller = widget.controller ?? SphereController();
      _controller.camera._attach(this);
      _applyConfiguration();
      return;
    }
    if (oldWidget.diameterFactor != widget.diameterFactor ||
        oldWidget.quality != widget.quality ||
        oldWidget.lighting != widget.lighting ||
        oldWidget.glow != widget.glow ||
        oldWidget.gestures != widget.gestures ||
        oldWidget.annotationLayout != widget.annotationLayout ||
        !identical(oldWidget.nodes, widget.nodes) ||
        !identical(oldWidget.connections, widget.connections)) {
      _applyConfiguration();
    }
  }

  void _applyConfiguration() {
    _validateView();
    _validateScene(widget.nodes, widget.connections);
    final light = widget.lighting;
    light.coordinate?.toWorldPoint();
    final glowStyle = widget.glow.style;
    if (glowStyle != null) _validateGlowStyle(glowStyle);
    final nodes = <engine.GlobeNode>[
      for (final node in widget.nodes)
        engine.GlobeNode(
          id: node.id,
          latitude: node.coordinate.latitude,
          longitude: node.coordinate.longitude,
          child: node.child,
          type: switch (node.placement) {
            SphereNodePlacement.surface => SphereNodeType.surface,
            SphereNodePlacement.annotation => SphereNodeType.annotation,
            SphereNodePlacement.denseAnnotation =>
              SphereNodeType.denseAnnotation,
          },
          annotationStyle: node.annotationStyle,
        ),
    ];
    final connections = <engine.GlobeConnection>[
      for (final connection in widget.connections)
        engine.GlobeConnection(
          id: connection.id,
          fromId: connection.fromId,
          toId: connection.toId,
          color: connection.color,
          width: connection.width,
          isDashed: connection.isDashed,
          showArrow: connection.showArrow,
        ),
    ];
    _controller._engine
      ..replaceScene(nodes, connections)
      ..setQuality(widget.quality)
      ..lockNorthSouth = !widget.gestures.verticalOrbitEnabled
      ..lockZoom = !widget.gestures.zoomEnabled;

    _controller._engine.setLightMode(switch (light.mode) {
      SphereLightingMode.followCamera => engine.GlobeLightMode.followCamera,
      SphereLightingMode.solarTime => engine.GlobeLightMode.realTime,
      SphereLightingMode.fixed => engine.GlobeLightMode.fixedCoordinates,
    });
    if (light.coordinate case final coordinate?) {
      _controller._engine.setFixedLightCoordinates(
        coordinate.latitude,
        coordinate.longitude,
      );
    }

    final glow = widget.glow;
    if (glow.style case final style?) {
      _controller._engine.setGlowStyle(glow_engine.SphereGlowStyle(
        color: style.color,
        width: style.width,
        intensity: style.intensity,
      ));
    }
    _controller._engine.setGlowMode(glow.mode == SphereGlowMode.automatic
        ? glow_engine.SphereGlowMode.automatic
        : glow_engine.SphereGlowMode.custom);
    _controller._spin._sync();
  }

  void _validateView() {
    if (!widget.diameterFactor.isFinite ||
        widget.diameterFactor <= 0 ||
        widget.diameterFactor > 1) {
      throw ArgumentError.value(
        widget.diameterFactor,
        'diameterFactor',
        'Must be greater than 0 and no greater than 1.',
      );
    }
  }

  static void _validateScene(
    List<SphereNode> nodes,
    List<SphereConnection> connections,
  ) {
    final ids = <String>{};
    for (final node in nodes) {
      if (node.id.isEmpty || !ids.add(node.id)) {
        throw ArgumentError.value(node.id, 'nodes', 'Node IDs must be unique.');
      }
      node.coordinate.toWorldPoint();
    }
    final connectionIds = <String>{};
    for (final connection in connections) {
      if (connection.id.isEmpty || !connectionIds.add(connection.id)) {
        throw ArgumentError.value(
            connection.id, 'connections', 'Connection IDs must be unique.');
      }
      if (!connection.width.isFinite || connection.width < 0) {
        throw ArgumentError.value(
            connection.width, 'width', 'Must be finite and non-negative.');
      }
      if (!ids.contains(connection.fromId) || !ids.contains(connection.toId)) {
        throw ArgumentError(
            'Connection endpoints must reference nodes in this scene.');
      }
    }
  }

  void _onInteractionStart() {
    _controller.camera._onGestureStart();
    if (!widget.gestures.resumeAfterGesture ||
        !_controller.spin.state.running) {
      _controller.spin.stop();
    }
  }

  void _onVisibilityChanged(bool visible) {
    _controller.spin._setSuspended(!visible || !widget.active);
  }

  @override
  void dispose() {
    _controller.camera._detach(this);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          var width = constraints.maxWidth;
          var height = constraints.maxHeight;
          if (!width.isFinite) width = 300;
          if (!height.isFinite) height = width;
          if (width <= 0 || height <= 0) return const SizedBox.shrink();
          width = constraints.constrainWidth(width);
          height = constraints.constrainHeight(height);
          final scale = widget.diameterFactor * math.min(width, height) / width;
          return SizedBox(
            width: width,
            height: height,
            child: engine.Globe3D(
              controller: _controller._engine,
              texture: widget.texture,
              nightTexture: widget.nightTexture,
              initialScale: scale,
              annotationLayout: widget.annotationLayout,
              active: widget.active,
              gestures: widget.gestures,
              onInteractionStart: _onInteractionStart,
              onVisibilityChanged: _onVisibilityChanged,
            ),
          );
        },
      );
}

void _validateLimits(SphereCameraLimits value) {
  if (!value.minZoom.isFinite ||
      !value.maxZoom.isFinite ||
      value.minZoom <= 0 ||
      value.maxZoom < value.minZoom) {
    throw ArgumentError('Zoom limits must satisfy 0 < minZoom <= maxZoom.');
  }
}

void _validateSpinOptions(SphereSpinOptions options) {
  if (!options.degreesPerSecond.isFinite) {
    throw ArgumentError.value(
        options.degreesPerSecond, 'degreesPerSecond', 'Must be finite.');
  }
}

void _validateGlowStyle(SphereGlowStyle style) {
  if (!style.width.isFinite ||
      style.width < 0 ||
      style.width > 1 ||
      !style.intensity.isFinite ||
      style.intensity < 0 ||
      style.intensity > 1) {
    throw ArgumentError('Glow width and intensity must be between 0 and 1.');
  }
}
