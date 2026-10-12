import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';
import 'package:flutter_globe_3d/src/models/earth_connection.dart';
import 'package:flutter_globe_3d/src/models/earth_node.dart';

void main() {
  test('declarative style updates retain path objects by connection ID', () {
    final controller = GlobeController();
    addTearDown(controller.dispose);
    final nodes = [
      GlobeNode(
        id: 'a',
        latitude: 0,
        longitude: 0,
        child: const SizedBox.shrink(),
      ),
      GlobeNode(
        id: 'b',
        latitude: 20,
        longitude: 50,
        child: const SizedBox.shrink(),
      ),
    ];
    controller.replaceScene(nodes, [
      GlobeConnection(id: 'route', fromId: 'a', toId: 'b'),
    ]);
    var sceneUpdates = 0;
    controller.addListener(() => sceneUpdates++);
    controller.updateProjections(const Size(400, 400), 3, 0);
    final previousPath = controller.connectionPaths.values.single;

    controller.replaceScene(nodes, [
      GlobeConnection(id: 'route', fromId: 'a', toId: 'b'),
    ]);
    expect(sceneUpdates, 0, reason: 'equivalent declarative values are quiet');
    controller.replaceScene(nodes, [
      GlobeConnection(
        id: 'route',
        fromId: 'a',
        toId: 'b',
        color: Colors.purple,
        showArrow: true,
      ),
    ]);
    controller.updateProjections(const Size(400, 400), 3, 0);

    expect(sceneUpdates, 1);
    expect(controller.connectionPaths.values.single, same(previousPath));
  });
}
