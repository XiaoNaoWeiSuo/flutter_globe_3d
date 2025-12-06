import 'package:flutter/material.dart';

class EarthConnection {
  final String startId;
  final String endId;
  final Color color;
  final double width;
  final bool isArrows; // 预留扩展：是否显示箭头

  const EarthConnection({
    required this.startId,
    required this.endId,
    this.color = Colors.lightBlueAccent,
    this.width = 1.5,
    this.isArrows = false,
  });
}
