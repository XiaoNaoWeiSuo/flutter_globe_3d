import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';
import 'package:flutter_globe_3d/flutter_globe_3d_shader.dart' as shader_api;

void main() {
  group('public coordinate and vector values', () {
    test('coordinates normalize longitude and map to the documented axes', () {
      const coordinate = SphereCoordinate(latitude: 35, longitude: 450);
      expect(coordinate.longitude, 90);
      final point = coordinate.toWorldPoint();
      expect(point.length, closeTo(1, 1e-12));
      expect(point.y, closeTo(math.sin(35 * math.pi / 180), 1e-12));
      expect(
        const SphereCoordinate(latitude: 0, longitude: 360).toWorldPoint(),
        const SphereVector3(0, 0, 1),
      );
    });

    test('vectors support stable arithmetic and tangent projection', () {
      const a = SphereVector3(3, 4, 0);
      expect(a.length, 5);
      expect(a.normalized().length, closeTo(1, 1e-12));
      expect(const SphereVector3(1e300, 0, 0).normalized(),
          const SphereVector3(1, 0, 0));
      expect(a + const SphereVector3(1, 1, 1), const SphereVector3(4, 5, 1));
      expect(a - const SphereVector3(1, 1, 1), const SphereVector3(2, 3, -1));
      expect(-a, const SphereVector3(-3, -4, 0));
      expect(a * 2, const SphereVector3(6, 8, 0));
      expect(a / 2, const SphereVector3(1.5, 2, 0));
      expect(const SphereVector3(1, 0, 0).cross(const SphereVector3(0, 1, 0)),
          const SphereVector3(0, 0, 1));
      expect(
          const SphereVector3(2, 3, 4)
              .projectOnPlane(const SphereVector3(0, 0, 1)),
          const SphereVector3(2, 3, 0));
      expect(SphereVector3.zero.projectOnPlane(SphereVector3.zero),
          SphereVector3.zero);
    });

    test('view angles round-trip local directions and preserve roll', () {
      const angle = SphereViewAngle(
        tiltDegrees: 60,
        bearingDegrees: -45,
        rollDegrees: 370,
      );
      final direction = angle.localDirection;
      final rebuilt = SphereViewAngle.fromLocalVector(
        direction,
        rollDegrees: 10,
      );
      expect(rebuilt.tiltDegrees, closeTo(60, 1e-12));
      expect(rebuilt.bearingDegrees, closeTo(-45, 1e-12));
      expect(const SphereViewAngle(bearingDegrees: 0),
          const SphereViewAngle(bearingDegrees: 360));
      expect(
        () => SphereViewAngle.fromLocalVector(SphereVector3.zero),
        throwsArgumentError,
      );
      expect(
        () => SphereViewAngle.fromLocalVector(const SphereVector3(0, 0, -1)),
        throwsArgumentError,
      );
      final up = angle.localUpHint(
        const SphereCoordinate(latitude: 0, longitude: 0),
      );
      expect(up.isFinite, isTrue);
      expect(up.length, closeTo(1, 1e-12));
    });
  });

  group('public configuration values', () {
    test('camera poses validate geographic and world forms', () {
      const target = SphereCoordinate(latitude: 10, longitude: 20);
      const overview = SphereCameraPose.overview(facing: target, zoom: 2);
      const focus = SphereCameraPose.focus(target: target, zoom: 1.5);
      const world = SphereCameraPose.world(
        target: SphereVector3.zero,
        direction: SphereVector3(0, 0, 1),
        up: SphereVector3(0, 1, 0),
      );
      overview.validate();
      focus.validate();
      world.validate();
      expect(overview.facing, target);
      expect(focus.focusPoint, target);
      expect(world.worldDirection, const SphereVector3(0, 0, 1));
      expect(
        () => const SphereCameraPose.world(
          target: SphereVector3.zero,
          direction: SphereVector3(0, 0, 1),
          up: SphereVector3(0, 0, 2),
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => const SphereCameraPose.overview(zoom: 0).validate(),
        throwsArgumentError,
      );
    });

    test('lighting, glow, gestures, quality and limits expose stable values',
        () {
      const coordinate = SphereCoordinate(latitude: 12, longitude: 34);
      expect(const SphereLighting.followCamera().mode,
          SphereLightingMode.followCamera);
      expect(
          const SphereLighting.solarTime().mode, SphereLightingMode.solarTime);
      expect(const SphereLighting.fixed(coordinate: coordinate).coordinate,
          coordinate);
      expect(const SphereGlow.automatic().style, isNull);
      expect(const SphereGlow.none().style, SphereGlowStyle.none);
      expect(const SphereGlow.custom(width: 0.2, intensity: 0.4).style,
          const SphereGlowStyle(width: 0.2, intensity: 0.4));
      expect(
          const SphereGestureOptions(resumeAfterGesture: true)
              .resumeAfterGesture,
          isTrue);
      expect(const SphereSpinOptions(degreesPerSecond: -2),
          const SphereSpinOptions(degreesPerSecond: -2));
      expect(
        const SphereSpinState(
          running: true,
          suspended: false,
          options: SphereSpinOptions(),
        ),
        const SphereSpinState(
          running: true,
          suspended: false,
          options: SphereSpinOptions(),
        ),
      );
      expect(const SphereAnnotationLayout(rowGap: 12).rowGap, 12);
      expect(SphereQuality.low.samplesPerAxis, 1);
      expect(SphereQuality.medium.samplesPerAxis, 2);
      expect(SphereQuality.high.samplesPerAxis, 3);
      expect(SphereQuality.ultra.samplesPerAxis, 4);
      expect(const SphereCameraLimits(minZoom: 0.5, maxZoom: 2),
          const SphereCameraLimits(minZoom: 0.5, maxZoom: 2));
    });

    test('scene values keep IDs and copy only requested fields', () {
      const node = SphereNode.annotation(
        id: 'shanghai',
        coordinate: SphereCoordinate(latitude: 31, longitude: 121),
        child: Text('Shanghai'),
      );
      final moved = node.copyWith(
        coordinate: const SphereCoordinate(latitude: 35, longitude: 139),
      );
      expect(moved.id, node.id);
      expect(moved.child, same(node.child));
      expect(moved.placement, SphereNodePlacement.annotation);
      expect(moved.coordinate.latitude, 35);
      const connection = SphereConnection(
        id: 'flight',
        fromId: 'shanghai',
        toId: 'tokyo',
        isDashed: true,
        showArrow: true,
      );
      expect(connection.isDashed, isTrue);
      expect(connection.showArrow, isTrue);
      expect(const SphereAnnotationStyle(priority: 2),
          const SphereAnnotationStyle(priority: 2));
    });
  });

  group('controller facade', () {
    test('camera limits, state snapshots and listeners are observable', () {
      final controller = SphereController(
        limits: const SphereCameraLimits(minZoom: 0.75, maxZoom: 2),
        spinOptions: const SphereSpinOptions(degreesPerSecond: -2),
      );
      addTearDown(controller.dispose);
      var cameraChanges = 0;
      controller.camera.addListener(() => cameraChanges++);
      controller.camera.setZoom(99);
      expect(controller.camera.zoom, 2);
      expect(controller.camera.state.zoom, 2);
      expect(controller.camera.state.distance, greaterThan(0));
      expect(controller.camera.state.forward.length, closeTo(1, 1e-12));
      expect(cameraChanges, greaterThan(0));
      controller.camera.limits =
          const SphereCameraLimits(minZoom: 0.5, maxZoom: 1);
      expect(controller.camera.zoom, 1);
      expect(controller.isDisposed, isFalse);
    });

    test('spin configuration and camera commands have explicit lifecycle',
        () async {
      final controller = SphereController();
      addTearDown(controller.dispose);
      var spinChanges = 0;
      controller.spin.addListener(() => spinChanges++);
      expect(controller.spin.state.running, isFalse);
      controller.spin.configure(const SphereSpinOptions(degreesPerSecond: 3));
      controller.spin.start();
      expect(controller.spin.state.running, isTrue);
      controller.camera.setPose(const SphereCameraPose.overview());
      expect(controller.spin.state.running, isFalse);
      controller.spin.start();
      controller.spin.stop();
      expect(spinChanges, greaterThanOrEqualTo(3));
      await expectLater(
        controller.camera.animateTo(
          const SphereCameraPose.world(
            target: SphereVector3(0, 0, 0.25),
            direction: SphereVector3(0, 0, 1),
            up: SphereVector3(0, 1, 0),
          ),
          duration: Duration.zero,
        ),
        completion(SphereCameraResult.completed),
      );
    });

    test('camera rejects invalid public commands', () {
      final controller = SphereController();
      addTearDown(controller.dispose);
      expect(() => controller.camera.setZoom(double.nan), throwsArgumentError);
      expect(
        () => controller.camera.setPose(const SphereCameraPose.world(
          target: SphereVector3.zero,
          direction: SphereVector3(0, 0, 1),
          up: SphereVector3(0, 0, 1),
        )),
        throwsArgumentError,
      );
    });
  });

  test('public view constructors preserve declarative configuration', () {
    final controller = SphereController();
    addTearDown(controller.dispose);
    final view = SphereView(
      texture: const AssetImage('assets/planet.png'),
      nightTexture: const AssetImage('assets/night.png'),
      controller: controller,
      diameterFactor: 0.9,
      quality: SphereQuality.high,
      lighting: const SphereLighting.solarTime(),
      glow: const SphereGlow.none(),
      gestures: const SphereGestureOptions(zoomEnabled: false),
      active: false,
    );
    expect(view.controller, same(controller));
    expect(view.diameterFactor, 0.9);
    expect(view.quality, SphereQuality.high);
    expect(view.lighting.mode, SphereLightingMode.solarTime);
    expect(view.glow.mode, SphereGlowMode.custom);
    expect(view.gestures.zoomEnabled, isFalse);
    expect(view.active, isFalse);
  });

  test('standalone shader entry point remains constructible', () {
    expect(
      const shader_api.UnifiedShaderCanvas(
          shaderAssetPath: 'assets/shader.frag'),
      isA<Widget>(),
    );
    expect(const shader_api.GirdShader(), isA<Widget>());
  });
}
