
import 'package:flutter/material.dart';

/// `EarthConnection` 表示地球上两个节点之间的连线。
/// 它定义了连线的起始节点、结束节点、颜色、样式等属性。
class EarthConnection {
  /// 连线的起始节点 ID。
  final String fromId;

  /// 连线的结束节点 ID。
  final String toId;

  /// 连线的颜色。默认为 `Colors.cyanAccent`。
  final Color color;

  /// 连线是否为虚线。默认为 `false`。
  final bool isDashed;

  /// 是否显示连线箭头。默认为 `false`。
  final bool showArrow;

  /// 连线的宽度。默认为 `1.0`。
  final double width;

  /// 构造函数，用于创建 `EarthConnection` 实例。
  EarthConnection({
    required this.fromId,
    required this.toId,
    this.color = Colors.cyanAccent,
    this.isDashed = false,
    this.showArrow = false,
    this.width = 1.0,
  });
}