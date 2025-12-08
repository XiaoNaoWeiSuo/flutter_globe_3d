import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/earth_connection.dart';
import '../models/earth_node.dart';

/// `EarthController` 是一个 `ChangeNotifier`，用于管理 3D 地球的交互状态和行为。
/// 它处理地球的旋转、缩放、节点（标记）和连线。
class EarthController extends ChangeNotifier {
  /// 最小缩放级别。
  double minZoom = 0.5;

  /// 最大缩放级别。
  double maxZoom = 3.0;

  /// 是否启用地球自动旋转。
  bool enableAutoRotate = true;

  /// 自动旋转的速度。
  double rotateSpeed = 1.0;

  /// 是否锁定南北方向的旋转（即只允许水平旋转）。
  bool lockNorthSouth = false;

  /// 是否锁定缩放功能。
  bool lockZoom = false;

  Offset _offset = Offset.zero;
  double _zoom = 1.0;

  final List<EarthNode> _nodes = [];
  final List<EarthConnection> _connections = [];
  final Map<String, Offset> projectedPositions = {};
  final Map<String, bool> nodeVisibility = {};

  // [新增] 存储计算好的连线路径 (Key: Connection, Value: Screen Path)
  final Map<EarthConnection, Path> _connectionPaths = {};

  /// 获取当前的缩放级别。
  double get zoom => _zoom;

  /// 获取当前的地球偏移量（用于旋转）。
  Offset get offset => _offset;

  /// 获取当前添加到地球上的所有节点（标记）。
  List<EarthNode> get nodes => _nodes;

  /// 获取当前添加到地球上的所有连线。
  List<EarthConnection> get connections => _connections;

  /// 获取所有连线的屏幕路径。
  Map<EarthConnection, Path> get connectionPaths => _connectionPaths;

  /// 添加一个地球节点（标记）。
  /// 调用此方法后会通知监听器更新 UI。
  void addNode(EarthNode node) {
    _nodes.add(node);
    notifyListeners();
  }

  /// 添加一个地球连线。
  /// 调用此方法后会通知监听器更新 UI。
  void connect(EarthConnection connection) {
    _connections.add(connection);
    notifyListeners();
  }

  /// 设置地球的缩放级别。
  /// 如果 `lockZoom` 为 true，则此方法无效。
  /// 缩放级别会被限制在 `minZoom` 和 `maxZoom` 之间。
  void setZoom(double z) {
    if (lockZoom) return;
    _zoom = z.clamp(minZoom, maxZoom);
    notifyListeners();
  }

  /// 设置地球的偏移量（用于旋转）。
  /// 如果 `lockNorthSouth` 为 true，则会锁定南北方向的移动。
  /// 垂直偏移量会被限制在 -300.0 到 300.0 之间。
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

  /// 更新所有节点和连线的 3D 投影到 2D 屏幕坐标。
  /// 此方法在每次渲染帧时调用，以确保标记和连线位置的准确性。
  /// [screenSize] 屏幕的尺寸。
  /// [scale] 地球的缩放比例。
  /// [renderTime] 当前渲染时间，用于动画效果。
  void updateProjections(Size screenSize, double scale, double renderTime) {
    projectedPositions.clear();
    nodeVisibility.clear();
    _connectionPaths.clear();

    final double camDist = 5.0 / math.max(_zoom, 0.01);
    final double yaw = -_offset.dx / 200.0;
    final double pitch = _offset.dy / 200.0; // 修正后的 Pitch

    final double sphereRadius = scale * 0.5;

    // 相机参数
    _Vector3 ro = _Vector3(0, 0, -camDist);
    ro = ro.rotateX(pitch).rotateY(yaw);

    _Vector3 target = _Vector3(0, 0, 0);
    _Vector3 fwd = (target - ro).normalize();
    _Vector3 upWorld = _Vector3(0, 1, 0);
    _Vector3 right = upWorld.cross(fwd).normalize();
    _Vector3 up = fwd.cross(right);

    // --- 1. 投影节点 ---
    // 建立 ID -> 3D 坐标的映射，方便连线使用
    final Map<String, _Vector3> node3DPos = {};

    for (var node in _nodes) {
      double radLat = node.latitude * math.pi / 180.0;
      double radLon = -node.longitude * math.pi / 180.0;

      double y = math.sin(radLat) * sphereRadius;
      double r = math.cos(radLat) * sphereRadius;
      double x = math.cos(radLon) * r;
      double z = math.sin(radLon) * r;

      _Vector3 pWorld = _Vector3(x, y, z);
      node3DPos[node.id] = pWorld;

      // 投影并检查可见性
      // 使用简单的表面法线剔除 (Surface Culling)
      bool isSurfaceVisible =
          pWorld.normalize().dot((ro - pWorld).normalize()) > 0;

      Offset? screenPos;
      // 只有表面可见时才投影，减少计算 (但如果需要透明地球，可以都计算)
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

    // --- 2. 生成 3D 连线路径 ---
    for (var conn in _connections) {
      final p1 = node3DPos[conn.fromId];
      final p2 = node3DPos[conn.toId];
      if (p1 == null || p2 == null) continue;

      // 3D 贝塞尔曲线计算
      // 控制点：两点中点向外延伸
      // 延伸高度取决于两点距离
      double dist = (p1 - p2).length;
      _Vector3 mid = (p1 + p2) * 0.5;

      // 拱起高度因子 (0.5 means arch height is 50% of distance)
      double archFactor = 1.0 + dist / sphereRadius * 0.8;
      // 确保控制点在球体外
      if (mid.length < 0.001) mid = p1; // 防止重合点异常
      _Vector3 control = mid.normalize() * (sphereRadius * archFactor);

      Path path = Path();
      bool isFirstPoint = true;

      // 采样精度
      const int steps = 30;

      for (int i = 0; i <= steps; i++) {
        double t = i / steps;
        // Quadratic Bezier: (1-t)^2 * P0 + 2(1-t)t * P1 + t^2 * P2
        double a = (1 - t) * (1 - t);
        double b = 2 * (1 - t) * t;
        double c = t * t;

        _Vector3 pCurve = p1 * a + control * b + p2 * c;

        // 遮挡剔除 (Occlusion Culling)
        // 检查这个 3D 点是否被地球挡住了
        // 1. 点必须在相机前方
        // 2. 射线检测：相机到点的连线是否穿过球体
        if (_isOccluded(pCurve, ro, sphereRadius)) {
          isFirstPoint = true; // 路径中断
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

  /// 辅助方法：将 3D 点投影到 2D 屏幕坐标。
  /// 返回 `null` 如果点在相机后面或无法投影。
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
    if (dist <= 0) return null; // Behind camera

    double u = pRel.dot(right) / dist;
    double v = pRel.dot(up) / dist;

    double x = (u * size.height) + size.width / 2;
    double y = size.height / 2 - (v * size.height); // Flip Y

    return Offset(x, y);
  }

  /// 辅助方法：检查 3D 点是否被球体遮挡。
  /// [p] 要检查的 3D 点。
  /// [ro] 相机的位置。
  /// [radius] 球体的半径。
  /// 返回 `true` 如果点被遮挡，否则返回 `false`。
  bool _isOccluded(_Vector3 p, _Vector3 ro, double radius) {
    // 向量：相机 -> 点
    _Vector3 dir = p - ro;
    double distToPoint = dir.length;
    dir = dir.normalize();

    // 射线-球体相交测试 (Center at 0,0,0)
    // OC = RO - 0
    // b = dot(-RO, dir) -> dot(ro, dir) * -1 (Direction is ro->p)
    // Simplify: dot(ro, dir)
    // Ray: P(t) = ro + t*dir
    // |ro + t*dir|^2 = r^2

    // Standard solution:
    // oc = ro
    // a = 1
    // b = 2 * dot(dir, ro)
    // c = dot(ro, ro) - r^2
    // delta = b*b - 4*a*c

    // Geometric solution (optimized):
    // tca = dot(-ro, dir)
    // d2 = dot(ro, ro) - tca * tca
    // if d2 > r*r return false (miss)
    // thc = sqrt(r*r - d2)
    // t0 = tca - thc
    // t1 = tca + thc

    // Check intersection
    _Vector3 L = _Vector3(0, 0, 0) - ro; // Vector to center
    double tca = L.dot(dir);
    if (tca < 0) return false; // Center is behind camera ray

    double d2 = L.dot(L) - tca * tca;
    if (d2 > radius * radius - 0.01) {
      return false; // Miss sphere (with slight bias)
    }

    double thc = math.sqrt(radius * radius - d2);
    double t0 = tca - thc;
    // double t1 = tca + thc;

    // 如果交点在相机和目标点之间 ( t0 > 0 && t0 < distToPoint )
    // 且 目标点不在球面上 (tolerance)
    if (t0 > 0.1 && t0 < distToPoint - 0.1) {
      return true; // Occluded
    }

    return false;
  }
}

/// 内部使用的 3D 向量类，提供基本的向量运算。
class _Vector3 {
  final double x, y, z;
  _Vector3(this.x, this.y, this.z);

  /// 向量加法。
  _Vector3 operator +(_Vector3 o) => _Vector3(x + o.x, y + o.y, z + o.z);

  /// 向量减法。
  _Vector3 operator -(_Vector3 o) => _Vector3(x - o.x, y - o.y, z - o.z);

  /// 向量与标量乘法。
  _Vector3 operator *(double s) => _Vector3(x * s, y * s, z * s);

  /// 向量点积。
  double dot(_Vector3 o) => x * o.x + y * o.y + z * o.z;

  /// 向量叉积。
  _Vector3 cross(_Vector3 o) =>
      _Vector3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  /// 向量的长度（模）。
  double get length => math.sqrt(x * x + y * y + z * z);

  /// 返回单位向量。
  _Vector3 normalize() {
    double l = length;
    return l == 0 ? this : _Vector3(x / l, y / l, z / l);
  }

  /// 绕 X 轴旋转。
  _Vector3 rotateX(double angle) {
    double c = math.cos(angle);
    double s = math.sin(angle);
    return _Vector3(x, y * c - z * s, y * s + z * c);
  }

  /// 绕 Y 轴旋转。
  _Vector3 rotateY(double angle) {
    double c = math.cos(angle);
    double s = math.sin(angle);
    return _Vector3(x * c - z * s, y, x * s + z * c);
  }
}
