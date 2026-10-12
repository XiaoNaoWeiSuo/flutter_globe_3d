import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('3.0 showcase builds the public sphere and interactive scene', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SphereExampleApp());
    expect(find.byType(SphereView), findsOneWidget);
    expect(find.text('Flutter Sphere 3D'), findsOneWidget);
    expect(find.text('Shanghai'), findsWidgets);
    final initial = tester.widget<SphereView>(find.byType(SphereView));
    expect(initial.nodes, hasLength(7));
    expect(initial.connections, hasLength(6));

    await tester.tap(find.text('Dense').first);
    await tester.pump();
    final dense = tester.widget<SphereView>(find.byType(SphereView));
    expect(
      dense.nodes.every(
        (node) => node.placement == SphereNodePlacement.denseAnnotation,
      ),
      isTrue,
    );
    expect(identical(initial.controller, dense.controller), isTrue);

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pump();
    await tester.tap(find.text('Smile Ball').last);
    await tester.pump();
    final changedTexture = tester.widget<SphereView>(find.byType(SphereView));
    expect(
      (changedTexture.texture as AssetImage).assetName,
      'assets/textures/smile.png',
    );
    expect(identical(dense.controller, changedTexture.controller), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
