import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';
import 'package:flutter_globe_3d/src/models/sphere_glow.dart';
import 'package:flutter_globe_3d/src/models/sphere_quality.dart';
import 'package:flutter_globe_3d/src/core/sphere_shader.dart';
import 'package:flutter_globe_3d/src/painter/earth_painter.dart';

void main() {
  testWidgets('Earth border repair removes meridian and south-pole dark lines',
      (tester) async {
    await tester.runAsync(() async {
      final clean = await _texture(false);
      final damaged = await _texture(true);
      try {
        for (final quality in SphereQuality.values) {
          for (final latitude in [0.0, -85.0, -90.0, 90.0]) {
            final reference = await _render(clean, quality, latitude: latitude);
            final repaired =
                await _render(damaged, quality, latitude: latitude, trim: true);
            var maxDifference = 0;
            for (var i = 0; i < reference.length; i++) {
              final difference = (reference[i] - repaired[i]).abs();
              if (difference > maxDifference) maxDifference = difference;
            }
            expect(maxDifference, lessThanOrEqualTo(2),
                reason:
                    '$quality latitude $latitude must exclude dark borders');
          }
        }
        // Cropping is opt-in: a custom texture's intentional border remains.
        final intact = await _render(damaged, SphereQuality.low);
        final repaired = await _render(damaged, SphereQuality.low, trim: true);
        expect(intact, isNot(orderedEquals(repaired)));
      } finally {
        clean.dispose();
        damaged.dispose();
      }
    });
  });

  // Optional visual inspection of the actual bundled texture, including its
  // original border. Not part of the normal suite and writes only to /tmp.
  if (const bool.fromEnvironment('SPHERE_SEAM_CAPTURE')) {
    testWidgets('capture bundled Earth boundary', (tester) async {
      await tester.runAsync(() async {
        final data = await rootBundle.load('assets/images/earth.jpg');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final texture = (await codec.getNextFrame()).image;
        codec.dispose();
        try {
          for (final quality in SphereQuality.values) {
            for (final trim in [false, true]) {
              final image = await _renderImage(texture, quality,
                  latitude: -85, trim: trim, side: 513);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File(
                      '/tmp/earth-seam-${quality.name}-${trim ? 'after' : 'before'}.png')
                  .writeAsBytes(bytes.buffer
                      .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
              image.dispose();
            }
          }
        } finally {
          texture.dispose();
        }
      });
    });
  }
}

Future<ui.Image> _texture(bool damaged) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  if (damaged) {
    final paint = ui.Paint()..color = const ui.Color(0xFF000000);
    canvas.drawRect(const ui.Rect.fromLTWH(255, 0, 1, 128), paint);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 127, 256, 1), paint);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(256, 128);
  picture.dispose();
  return image;
}

Future<Uint8List> _render(ui.Image texture, SphereQuality quality,
    {double latitude = 0, bool trim = false}) async {
  final image =
      await _renderImage(texture, quality, latitude: latitude, trim: trim);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final result = Uint8List.fromList(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
  image.dispose();
  return result;
}

Future<ui.Image> _renderImage(ui.Image texture, SphereQuality quality,
    {double latitude = 0, bool trim = false, int side = 129}) async {
  final program = await ui.FragmentProgram.fromAsset(sphereShaderAsset(quality)
      .replaceFirst('packages/flutter_globe_3d/', ''));
  final shader = program.fragmentShader();
  final controller = SphereController()
    ..setQuality(quality)
    ..setLightMode(SphereLightMode.followCamera)
    ..setGlowMode(SphereGlowMode.custom)
    ..setGlowStyle(const SphereGlowStyle(intensity: 0))
    ..setCameraFocus(latitude, 180);
  final time = ValueNotifier<double>(0);
  final recorder = ui.PictureRecorder();
  final size = ui.Size.square(side.toDouble());
  EarthScenePainter(
    shader: shader,
    shaderQuality: quality,
    texture: texture,
    trimEarthTextureEdges: trim,
    resolution: size,
    scale: 3,
    controller: controller,
    timeListenable: time,
    repaint: time,
  ).paint(ui.Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  picture.dispose();
  shader.dispose();
  time.dispose();
  controller.dispose();
  return image;
}
