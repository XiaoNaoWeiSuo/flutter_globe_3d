import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/earth_connection.dart';
import '../models/earth_node.dart';

/// 光源模式枚举
enum EarthLightMode {
  /// 跟随相机（光源位于相机左上角，增强立体感）
  followCamera,

  /// 真实世界时间（根据 UTC 时间计算太阳直射点，模拟昼夜交替）
  realTime,

  /// 固定经纬度（光源固定在地球某个特定的经纬度上）
  fixedCoordinates,
}

class EarthController extends ChangeNotifier {
  // ... (保留原有的缩放、旋转等变量)
  double minZoom = 0.5;
  double maxZoom = 3.0;
  bool enableAutoRotate = true;
  double rotateSpeed = 1.0;
  bool lockNorthSouth = false;
  bool lockZoom = false;

  // --- 新增光源控制参数 ---
  EarthLightMode _lightMode = EarthLightMode.realTime;

  // 固定光源的经纬度 (默认为 (0,0))
  double _fixedLightLat = 0.0;
  double _fixedLightLon = 0.0;

  EarthLightMode get lightMode => _lightMode;
  double get fixedLightLat => _fixedLightLat;
  double get fixedLightLon => _fixedLightLon;

  Offset _offset = Offset.zero;
  double _zoom = 1.0;

  Offset get offset => _offset;
  double get zoom => _zoom;
  final List<EarthNode> _nodes = [];
  final List<EarthConnection> _connections = [];
  final Map<String, Offset> projectedPositions = {};
  final Map<String, bool> nodeVisibility = {};
  final Map<EarthConnection, Path> _connectionPaths = {};

  List<EarthNode> get nodes => _nodes;
  List<EarthConnection> get connections => _connections;
  Map<EarthConnection, Path> get connectionPaths => _connectionPaths;

  // --- 新增设置方法 ---

  /// 设置光源模式
  void setLightMode(EarthLightMode mode) {
    if (_lightMode == mode) return;
    _lightMode = mode;
    notifyListeners();
  }

  /// 设置固定光源的经纬度
  /// 仅在 [EarthLightMode.fixedCoordinates] 下生效
  void setFixedLightCoordinates(double lat, double lon) {
    _fixedLightLat = lat;
    _fixedLightLon = lon;
    if (_lightMode == EarthLightMode.fixedCoordinates) {
      notifyListeners();
    }
  }

  /// [修正] 直接将相机聚焦到指定的经纬度
  /// [lat] 纬度 (-90 到 90)
  /// [lon] 经度 (-180 到 180)
  void setCameraFocus(double lat, double lon) {
    // Shader 逻辑: yaw = -uOffset.x / 200.0
    // 我们需要 yaw 对应经度。
    // 根据纹理映射和 Node 计算逻辑，经度 0 对应纹理的 90W (-90)，
    // 所以需要 +90 度修正，才能让相机正对目标经度。

    double radLat = lat * math.pi / 180.0;

    // [关键修正] 增加 90 度偏移，与 Node/Light 逻辑对齐
    double radLon = (lon + 90.0) * math.pi / 180.0;

    // 计算对应的 Offset
    // targetDx = -yaw * 200.0
    double targetDx = -radLon * 200.0;
    double targetDy = radLat * 200.0;

    // 限制纬度范围，防止相机翻转
    if (lockNorthSouth) {
      targetDy = 0;
    } else {
      targetDy = targetDy.clamp(-300.0, 300.0);
    }

    _offset = Offset(targetDx, targetDy);
    notifyListeners();
  }

  void addNode(EarthNode node) {
    _nodes.add(node);
    notifyListeners();
  }

  void connect(EarthConnection connection) {
    _connections.add(connection);
    notifyListeners();
  }

  void setZoom(double z) {
    if (lockZoom) return;
    _zoom = z.clamp(minZoom, maxZoom);
    notifyListeners();
  }

  void setOffset(Offset o) {
    double newX = o.dx;
    double newY = o.dy;
    if (lockNorthSouth) {
      newY = 0;
    } else {
      newY = newY.clamp(-300.0, 300.0);
    }
    _offset = Offset(newX, newY);
    notifyListeners();
  }

  void updateProjections(Size screenSize, double scale, double renderTime) {
    projectedPositions.clear();
    nodeVisibility.clear();
    _connectionPaths.clear();

    final double camDist = 5.0 / math.max(_zoom, 0.01);
    final double yaw = -_offset.dx / 200.0;
    final double pitch = _offset.dy / 200.0;

    final double sphereRadius = scale * 0.5;

    _Vector3 ro = _Vector3(0, 0, -camDist);
    ro = ro.rotateX(pitch).rotateY(yaw);

    _Vector3 target = _Vector3(0, 0, 0);
    _Vector3 fwd = (target - ro).normalize();
    _Vector3 upWorld = _Vector3(0, 1, 0);
    _Vector3 right = upWorld.cross(fwd).normalize();
    _Vector3 up = fwd.cross(right);

    final Map<String, _Vector3> node3DPos = {};

    for (var node in _nodes) {
      double radLat = node.latitude * math.pi / 180.0;
      // 注意：这里原本就有 +90.0，证明我们的修正方向是正确的
      double radLon = (node.longitude + 90.0) * math.pi / 180.0;

      double y = math.sin(radLat) * sphereRadius;
      double r = math.cos(radLat) * sphereRadius;
      double x = math.sin(radLon) * r;
      double z = -math.cos(radLon) * r;

      _Vector3 pWorld = _Vector3(x, y, z);
      node3DPos[node.id] = pWorld;

      bool isSurfaceVisible =
          pWorld.normalize().dot((ro - pWorld).normalize()) > 0;

      Offset? screenPos;
      if (isSurfaceVisible) {
        screenPos = _project3DPoint(pWorld, ro, fwd, right, up, screenSize);
      }

      if (screenPos != null) {
        projectedPositions[node.id] = screenPos;
        nodeVisibility[node.id] = true;
      } else {
        nodeVisibility[node.id] = false;
      }
    }

    for (var conn in _connections) {
      final p1 = node3DPos[conn.fromId];
      final p2 = node3DPos[conn.toId];
      if (p1 == null || p2 == null) continue;
      double dist = (p1 - p2).length;
      _Vector3 mid = (p1 + p2) * 0.5;
      double archFactor = 1.0 + dist / sphereRadius * 0.8;
      if (mid.length < 0.001) mid = p1;
      _Vector3 control = mid.normalize() * (sphereRadius * archFactor);

      Path path = Path();
      bool isFirstPoint = true;
      const int steps = 30;

      for (int i = 0; i <= steps; i++) {
        double t = i / steps;
        double a = (1 - t) * (1 - t);
        double b = 2 * (1 - t) * t;
        double c = t * t;
        _Vector3 pCurve = p1 * a + control * b + p2 * c;
        if (_isOccluded(pCurve, ro, sphereRadius)) {
          isFirstPoint = true;
          continue;
        }
        Offset? sPos = _project3DPoint(pCurve, ro, fwd, right, up, screenSize);
        if (sPos != null) {
          if (isFirstPoint) {
            path.moveTo(sPos.dx, sPos.dy);
            isFirstPoint = false;
          } else {
            path.lineTo(sPos.dx, sPos.dy);
          }
        } else {
          isFirstPoint = true;
        }
      }
      _connectionPaths[conn] = path;
    }
  }

  Offset? _project3DPoint(
    _Vector3 p,
    _Vector3 ro,
    _Vector3 fwd,
    _Vector3 right,
    _Vector3 up,
    Size size,
  ) {
    _Vector3 pRel = p - ro;
    double dist = pRel.dot(fwd);
    if (dist <= 0) return null;
    double u = pRel.dot(right) / dist;
    double v = pRel.dot(up) / dist;
    double x = (u * size.height) + size.width / 2;
    double y = size.height / 2 - (v * size.height);
    return Offset(x, y);
  }

  bool _isOccluded(_Vector3 p, _Vector3 ro, double radius) {
    _Vector3 dir = p - ro;
    double distToPoint = dir.length;
    dir = dir.normalize();
    _Vector3 L = _Vector3(0, 0, 0) - ro;
    double tca = L.dot(dir);
    if (tca < 0) return false;
    double d2 = L.dot(L) - tca * tca;
    if (d2 > radius * radius - 0.01) {
      return false;
    }
    double thc = math.sqrt(radius * radius - d2);
    double t0 = tca - thc;
    if (t0 > 0.1 && t0 < distToPoint - 0.1) {
      return true;
    }
    return false;
  }
}

class _Vector3 {
  final double x, y, z;
  _Vector3(this.x, this.y, this.z);
  _Vector3 operator +(_Vector3 o) => _Vector3(x + o.x, y + o.y, z + o.z);
  _Vector3 operator -(_Vector3 o) => _Vector3(x - o.x, y - o.y, z - o.z);
  _Vector3 operator *(double s) => _Vector3(x * s, y * s, z * s);
  double dot(_Vector3 o) => x * o.x + y * o.y + z * o.z;
  _Vector3 cross(_Vector3 o) =>
      _Vector3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  _Vector3 normalize() {
    double l = length;
    return l == 0 ? this : _Vector3(x / l, y / l, z / l);
  }

  _Vector3 rotateX(double angle) {
    double c = math.cos(angle);
    double s = math.sin(angle);
    return _Vector3(x, y * c - z * s, y * s + z * c);
  }

  _Vector3 rotateY(double angle) {
    double c = math.cos(angle);
    double s = math.sin(angle);
    return _Vector3(x * c - z * s, y, x * s + z * c);
  }
}
