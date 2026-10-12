import 'package:example/demo_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('camera studio awaits the first animation before continuing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: DemoStudioPage()));

    await tester.tap(find.text('Play sequence'));
    await tester.pump();
    expect(find.text('Turn upper-left 60° → return to front'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Sequence: completed'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'removing a view completes its pending camera Future as detached',
    (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = SphereController();
      addTearDown(controller.dispose);
      var showSphere = true;
      late StateSetter update;
      Widget app() => MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SizedBox.expand(
              child: showSphere
                  ? SphereView.earth(controller: controller)
                  : const SizedBox.shrink(),
            );
          },
        ),
      );

      await tester.pumpWidget(app());
      final pending = controller.camera.focus(
        target: const SphereCoordinate(latitude: 20, longitude: 40),
        duration: const Duration(seconds: 4),
      );
      await tester.pump(const Duration(milliseconds: 100));
      update(() => showSphere = false);
      await tester.pump();
      expect(await pending, SphereCameraResult.detached);
      expect(controller.isDisposed, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failing animation curve completes with an error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = SphereController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: SphereView.earth(controller: controller)),
    );

    final transition = controller.camera.focus(
      target: const SphereCoordinate(latitude: 20, longitude: 40),
      duration: const Duration(seconds: 1),
      curve: const _NonFiniteCurve(),
    );
    final failed = expectLater(transition, throwsArgumentError);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.camera.isAnimating, isFalse);
    await failed;
    expect(tester.takeException(), isNull);
  });

  testWidgets('replaced, cancelled, and disposed camera requests terminate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = SphereController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: SphereView.earth(controller: controller)),
    );

    final first = controller.camera.focus(
      target: const SphereCoordinate(latitude: 20, longitude: 30),
      duration: const Duration(seconds: 3),
    );
    final firstResult = expectLater(
      first,
      completion(SphereCameraResult.interrupted),
    );
    await tester.pump();
    final second = controller.camera.focus(
      target: const SphereCoordinate(latitude: -30, longitude: 110),
      duration: const Duration(seconds: 3),
    );
    await firstResult;
    final secondResult = expectLater(
      second,
      completion(SphereCameraResult.cancelled),
    );
    controller.camera.cancel();
    await secondResult;

    final third = controller.camera.focus(
      target: const SphereCoordinate(latitude: 0, longitude: 0),
      duration: const Duration(seconds: 3),
    );
    final thirdResult = expectLater(
      third,
      completion(SphereCameraResult.disposed),
    );
    controller.dispose();
    await thirdResult;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

class _NonFiniteCurve extends Curve {
  const _NonFiniteCurve();

  @override
  double transformInternal(double t) => double.nan;
}
