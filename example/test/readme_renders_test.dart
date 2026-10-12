import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

/// Reproduce README images using the actual widget, not sphere mockups:
/// flutter test test/readme_renders_test.dart \
///   --dart-define=README_RENDER_DIR=/absolute/path/example/assets/showcase
void main() {
  const directory = String.fromEnvironment('README_RENDER_DIR');

  for (final name in [
    'earth',
    'smile',
    'basketball',
    'soccer',
    'marble',
    'wood',
  ]) {
    testWidgets('export ultra-quality $name for README', (tester) async {
      tester.view.physicalSize = const Size(1080, 1080);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = SphereController();
      controller.camera.setPose(
        const SphereCameraPose.overview(
          facing: SphereCoordinate(latitude: 15, longitude: 85),
        ),
      );
      final preview = GlobalKey();
      final earth = name == 'earth';
      final extension = ['marble', 'wood'].contains(name) ? 'jpg' : 'png';
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [SphereView.routeObserver],
          home: RepaintBoundary(
            key: preview,
            child: ColoredBox(
              color: const Color(0xFF07111D),
              child: SphereView(
                controller: controller,
                diameterFactor: 0.94,
                quality: SphereQuality.ultra,
                lighting: const SphereLighting.followCamera(),
                glow: SphereGlow.custom(
                  width: 0.12,
                  intensity: name == 'earth' ? 0.3 : 0,
                ),
                texture: AssetImage(
                  earth
                      ? 'packages/flutter_globe_3d/assets/images/earth.jpg'
                      : 'assets/textures/$name.$extension',
                ),
                nightTexture: earth
                    ? const AssetImage(
                        'packages/flutter_globe_3d/assets/images/earth_night.jpg',
                      )
                    : null,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            preview.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        expect(image.width, 1080);
        expect(image.height, 1080);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await Directory(directory).create(recursive: true);
        await File('$directory/$name-ultra.png').writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }, skip: directory.isEmpty);
  }
}
