import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

void main() {
  test('3.0 exposes named geographic coordinates and a unified world frame',
      () {
    const greenwich = SphereCoordinate(latitude: 0, longitude: 0);
    const east = SphereCoordinate(latitude: 0, longitude: 90);
    expect(greenwich.toWorldPoint(), const SphereVector3(0, 0, 1));
    expect(east.toWorldPoint().x, closeTo(1, 1e-12));
    expect(const SphereCoordinate(latitude: 0, longitude: 540).longitude, -180);

    const view = SphereViewAngle.upperLeft(tiltDegrees: 60);
    expect(view.localDirection.x, closeTo(-math.sqrt(3 / 8), 1e-12));
    expect(view.localDirection.y, closeTo(math.sqrt(3 / 8), 1e-12));
    expect(view.localDirection.z, closeTo(0.5, 1e-12));
  });

  test('camera commands use explicit pose and bounded zoom', () async {
    final controller = SphereController(
      limits: const SphereCameraLimits(minZoom: 0.75, maxZoom: 2.5),
    );
    addTearDown(controller.dispose);
    const target = SphereCoordinate(latitude: 31.2, longitude: 121.4);

    controller.camera.setPose(const SphereCameraPose.focus(
      target: target,
      view: SphereViewAngle.upperLeft(tiltDegrees: 60),
      zoom: 9,
    ));
    expect(controller.camera.state.zoom, 2.5);
    final actualTarget = controller.camera.state.target;
    final expectedTarget = target.toWorldPoint();
    expect(actualTarget.x, closeTo(expectedTarget.x, 1e-12));
    expect(actualTarget.y, closeTo(expectedTarget.y, 1e-12));
    expect(actualTarget.z, closeTo(expectedTarget.z, 1e-12));

    expect(
      await controller.camera.animateTo(
        const SphereCameraPose.overview(),
        duration: Duration.zero,
      ),
      SphereCameraResult.completed,
    );
  });

  test('scene is declared on SphereView with stable endpoint IDs', () {
    final controller = SphereController();
    addTearDown(controller.dispose);
    final view = SphereView.earth(
      controller: controller,
      nodes: const [
        SphereNode.annotation(
          id: 'shanghai',
          coordinate: SphereCoordinate(latitude: 31.2, longitude: 121.4),
          child: Text('Shanghai'),
        ),
        SphereNode.surface(
          id: 'tokyo',
          coordinate: SphereCoordinate(latitude: 35.7, longitude: 139.7),
          child: Icon(Icons.location_on),
        ),
      ],
      connections: const [
        SphereConnection(id: 'flight', fromId: 'shanghai', toId: 'tokyo'),
      ],
    );
    expect(view.nodes, hasLength(2));
    expect(view.connections.single.id, 'flight');
    expect(SphereView.routeObserver, isA<RouteObserver<ModalRoute<dynamic>>>());
  });

  test('runtime validation rejects invalid values in release-safe methods', () {
    expect(
      () => SphereViewAngle.fromLocalVector(SphereVector3.zero),
      throwsArgumentError,
    );
    final controller = SphereController();
    addTearDown(controller.dispose);
    expect(() => controller.camera.setZoom(double.nan), throwsArgumentError);
  });
}
