
import 'package:flutter/material.dart';

class EarthMarker {
  final String id;
  final double latitude;
  final double longitude;
  final Widget child;
  final String? label;
  final VoidCallback? onTap;

  const EarthMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.child,
    this.label,
    this.onTap,
  });
}