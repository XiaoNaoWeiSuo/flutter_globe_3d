import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';
import 'package:flutter_globe_3d/src/models/earth_node.dart';
import 'package:flutter_globe_3d/src/models/globe_vector3.dart';

const _size = Size(400, 400);

void main() {
  for (final pose in ['overview', 'front', 'oblique-roll']) {
    for (final drag in [
      const Offset(40, 0),
      const Offset(-40, 0),
      const Offset(0, 40),
      const Offset(0, -40),
    ]) {
      test('$pose: a visible surface point follows drag $drag', () {
        final controller = _controllerForPose(pose);
        addTearDown(controller.dispose);
        final before = controller.projectedPositions['target']!;
        controller.orbit(drag);
        controller.updateProjections(_size, 3, 0);
        expect(controller.nodeVisibility['target'], isTrue);
        final movement = controller.projectedPositions['target']! - before;
        if (drag.dx != 0) expect(movement.dx * drag.dx, greaterThan(0));
        if (drag.dy != 0) expect(movement.dy * drag.dy, greaterThan(0));
      });
    }
  }

  test('north-south lock stops vertical motion without reversing horizontal',
      () {
    final controller = _controllerForPose('front');
    addTearDown(controller.dispose);
    controller.lockNorthSouth = true;
    final before = controller.projectedPositions['target']!;
    controller.orbit(const Offset(0, 40));
    controller.updateProjections(_size, 3, 0);
    expect(controller.projectedPositions['target'], before);
    controller.orbit(const Offset(40, 0));
    controller.updateProjections(_size, 3, 0);
    expect(controller.projectedPositions['target']!.dx, greaterThan(before.dx));
  });
}

SphereController _controllerForPose(String pose) {
  final controller = SphereController();
  controller.addNode(SphereNode(
    id: 'target',
    latitude: 31.23,
    longitude: 121.47,
    child: const SizedBox.shrink(),
  ));
  controller.setCameraFocus(
    31.23,
    121.47,
    zoom: 1.6,
    viewDirection: pose == 'oblique-roll'
        ? const GlobeVector3(-1, 0, 1)
        : const GlobeVector3(0, 0, 1),
    tangent: pose == 'oblique-roll' ? const GlobeVector3(0, 0, 1) : null,
  );
  if (pose == 'overview') controller.showOverview(duration: Duration.zero);
  controller.updateProjections(_size, 3, 0);
  return controller;
}
