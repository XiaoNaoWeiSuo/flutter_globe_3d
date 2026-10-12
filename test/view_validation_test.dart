import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

void main() {
  const coordinate = SphereCoordinate(latitude: 0, longitude: 0);

  Future<void> expectViewError(
    WidgetTester tester,
    SphereView view,
  ) async {
    await tester.pumpWidget(MaterialApp(home: view));
    expect(tester.takeException(), isA<ArgumentError>());
  }

  testWidgets('view validates layout and scene identity before rendering',
      (tester) async {
    await expectViewError(
      tester,
      const SphereView.earth(diameterFactor: 0),
    );
    await expectViewError(
      tester,
      const SphereView.earth(
        nodes: [
          SphereNode.surface(
              id: 'same', coordinate: coordinate, child: Text('A')),
          SphereNode.surface(
              id: 'same', coordinate: coordinate, child: Text('B')),
        ],
      ),
    );
    await expectViewError(
      tester,
      const SphereView.earth(
        nodes: [
          SphereNode.surface(id: 'a', coordinate: coordinate, child: Text('A')),
        ],
        connections: [
          SphereConnection(id: 'route', fromId: 'a', toId: 'missing'),
        ],
      ),
    );
  });
}
