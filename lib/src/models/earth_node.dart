import 'package:flutter/material.dart';

/// `EarthNode` 表示地球上的一个标记点。
/// 每个节点都有一个唯一的 ID、经纬度坐标和一个用于显示的子 widget。
class EarthNode {
  /// 节点的唯一标识符。
  final String id;

  /// 节点的纬度。
  final double latitude;

  /// 节点的经度。
  final double longitude;

  /// 用于显示节点的 widget。
  final Widget child;

  /// 构造函数，用于创建 `EarthNode` 实例。
  EarthNode({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.child,
  });
}
