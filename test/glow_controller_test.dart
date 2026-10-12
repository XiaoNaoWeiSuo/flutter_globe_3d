import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';
import 'package:flutter_globe_3d/src/models/sphere_glow.dart';

void main() {
  test('custom glow survives automatic mode and notifies visible changes', () {
    final controller = SphereController();
    addTearDown(controller.dispose);
    var changes = 0;
    controller.addListener(() => changes++);
    expect(controller.glowMode, SphereGlowMode.automatic);
    const custom =
        SphereGlowStyle(color: Colors.purple, width: 0.25, intensity: 0.5);
    controller.setGlowStyle(custom);
    expect(changes, 0);
    controller.setGlowMode(SphereGlowMode.custom);
    expect(changes, 1);
    controller.setGlowStyle(custom.copyWith(intensity: 0));
    expect(changes, 2);
    controller.setGlowMode(SphereGlowMode.automatic);
    controller.setGlowMode(SphereGlowMode.custom);
    expect(controller.glowStyle.color, Colors.purple);
    expect(controller.glowStyle.width, 0.25);
    expect(controller.glowStyle.intensity, 0);
    controller.setGlowStyle(controller.glowStyle.copyWith());
    expect(changes, 4);
  });

  test('invalid glow settings cannot reach the shader', () {
    final controller = SphereController();
    addTearDown(controller.dispose);
    for (final style in [
      const SphereGlowStyle(width: -0.1),
      const SphereGlowStyle(width: double.nan),
      const SphereGlowStyle(width: 1.1),
      const SphereGlowStyle(intensity: double.infinity),
      const SphereGlowStyle(intensity: -1),
      const SphereGlowStyle(intensity: 2),
    ]) {
      expect(() => controller.setGlowStyle(style), throwsArgumentError);
      expect(controller.glowStyle, const SphereGlowStyle());
    }
  });
}
