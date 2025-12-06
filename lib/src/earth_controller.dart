import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class EarthConfig {
  final double maxZoom;
  final double minZoom;
  final double initialZoom;
  final double initialLat;
  final double initialLon;
  final double autoRotateSpeed;
  final double dragSensitivity; // 拖拽灵敏度调整

  const EarthConfig({
    this.maxZoom = 2.5,
    this.minZoom = 0.8,
    this.initialZoom = 1.0,
    this.initialLat = 0.2,
    this.initialLon = -2.0,
    this.autoRotateSpeed = 0.0005,
    this.dragSensitivity = 1.0,
  });
}

class EarthController extends ChangeNotifier {
  final EarthConfig config;

  double _rotationX;
  double _rotationY;
  double _zoom;
  double _velocityX = 0.0;
  double _velocityY = 0.0;
  bool _isDragging = false;
  bool autoRotate;

  Ticker? _physicsTicker;
  final double _friction = 0.92;

  EarthController({this.config = const EarthConfig(), bool autoRotate = true})
    : _rotationY = config.initialLat,
      _rotationX = config.initialLon,
      _zoom = config.initialZoom,
      this.autoRotate = autoRotate;

  double get rotationX => _rotationX;
  double get rotationY => _rotationY;
  double get zoom => _zoom;

  set zoom(double val) {
    _zoom = max(config.minZoom, min(config.maxZoom, val));
    notifyListeners();
  }

  void startPhysics(TickerProvider vsync) {
    _physicsTicker?.dispose();
    _physicsTicker = vsync.createTicker(_onPhysicsTick)..start();
  }

  void stopPhysics() {
    _physicsTicker?.dispose();
    _physicsTicker = null;
  }

  void onDragStart() {
    _isDragging = true;
    _velocityX = 0;
    _velocityY = 0;
    autoRotate = false; // 用户交互时暂停自动旋转
    notifyListeners();
  }

  void onDragUpdate(double dx, double dy, double sensitivity) {
    final finalSense = sensitivity * config.dragSensitivity;
    _rotationX += dx * finalSense;
    _rotationY += dy * finalSense;
    _rotationY = max(-1.4, min(1.4, _rotationY));
    notifyListeners();
  }

  void onDragEnd(Offset velocity, double pixelRatio) {
    _isDragging = false;
    double factor = 0.00002 / pixelRatio;
    _velocityX = velocity.dx * factor;
    _velocityY = velocity.dy * factor;
  }

  void _onPhysicsTick(Duration elapsed) {
    if (_isDragging) return;
    bool dirty = false;

    // 惯性处理
    if (_velocityX.abs() > 0.00001 || _velocityY.abs() > 0.00001) {
      _rotationX += _velocityX;
      _rotationY += _velocityY;

      // 极点回弹
      if (_rotationY > 1.4) {
        _rotationY = 1.4;
        _velocityY *= -0.5;
      } else if (_rotationY < -1.4) {
        _rotationY = -1.4;
        _velocityY *= -0.5;
      }

      _velocityX *= _friction;
      _velocityY *= _friction;
      dirty = true;
    } else if (autoRotate) {
      _rotationX += config.autoRotateSpeed;
      dirty = true;
    }

    if (dirty) notifyListeners();
  }

  // 获取用于 Shader 的 3x3 矩阵数据
  Float32List getMatrix33() {
    final mat = vm.Matrix4.identity();
    mat.rotateX(_rotationY);
    mat.rotateY(_rotationX);
    final s = mat.storage;
    // 提取 Matrix4 的左上角 3x3 部分
    return Float32List.fromList([
      s[0],
      s[1],
      s[2],
      s[4],
      s[5],
      s[6],
      s[8],
      s[9],
      s[10],
    ]);
  }

  vm.Matrix4 getRotationMatrix() {
    final mat = vm.Matrix4.identity();
    mat.rotateX(_rotationY);
    mat.rotateY(_rotationX);
    return mat;
  }
}
