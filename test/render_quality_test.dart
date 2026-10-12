import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';
import 'package:flutter_globe_3d/src/models/globe_vector3.dart';
import 'package:flutter_globe_3d/src/models/sphere_glow.dart';
import 'package:flutter_globe_3d/src/models/sphere_quality.dart';
import 'package:flutter_globe_3d/src/painter/earth_painter.dart';
import 'package:flutter_globe_3d/src/core/sphere_shader.dart';

void main() {
  test('quality changes notify without resetting the camera', () {
    final controller = SphereController();
    addTearDown(controller.dispose);
    controller.setCameraFocus(25, 80, zoom: 1.4);
    final position = controller.cameraPosition;
    var notifications = 0;
    controller.addListener(() => notifications++);
    expect(controller.quality, SphereQuality.medium);
    for (final quality in SphereQuality.values) {
      controller.setQuality(quality);
      expect(controller.cameraPosition.x, position.x);
      expect(controller.cameraPosition.y, position.y);
      expect(controller.cameraPosition.z, position.z);
      expect(controller.zoom, 1.4);
    }
    expect(notifications, 4);
    controller.setQuality(SphereQuality.ultra);
    expect(notifications, 4);
  });

  testWidgets(
      'all presets smooth transparent silhouettes at physical pixel density',
      (tester) async {
    await tester.runAsync(() async {
      final texture = await _texture(false);
      try {
        for (final quality in SphereQuality.values) {
          final partialCounts = <int>[];
          for (final dpr in [1.0, 3.0]) {
            final bytes = await _render(texture, quality, dpr);
            var partial = 0;
            for (var i = 3; i < bytes.length; i += 4) {
              if (bytes[i] > 0 && bytes[i] < 255) partial++;
              expect(bytes[i - 3], lessThanOrEqualTo(bytes[i]));
            }
            expect(partial, greaterThan(50),
                reason: '$quality DPR $dpr must have partial pixel coverage');
            partialCounts.add(partial);
          }
          // An edge must stay about one physical pixel wide, rather than
          // growing to three physical pixels on a Retina display.
          expect(
              partialCounts[1] / partialCounts[0], inInclusiveRange(2.0, 4.5));
        }
      } finally {
        texture.dispose();
      }
    });
  });

  testWidgets('ultra reduces texture aliasing against a supersampled reference',
      (tester) async {
    await tester.runAsync(() async {
      final texture = await _texture(true);
      try {
        final low = await _render(texture, SphereQuality.low, 1);
        final ultra = await _render(texture, SphereQuality.ultra, 1);
        final reference = await _render(texture, SphereQuality.ultra, 4);
        double error(Uint8List candidate) {
          var result = 0.0;
          // Central region avoids conflating texture filtering with silhouette.
          for (var y = 48; y < 80; y++) {
            for (var x = 48; x < 80; x++) {
              var sum = 0.0;
              for (var sy = 0; sy < 4; sy++) {
                for (var sx = 0; sx < 4; sx++) {
                  final index = ((y * 4 + sy) * 512 + x * 4 + sx) * 4;
                  sum += math.pow(reference[index] / 255, 2.2);
                }
              }
              final value = math.pow(candidate[(y * 128 + x) * 4] / 255, 2.2);
              result += math.pow(value - sum / 16, 2);
            }
          }
          return result;
        }

        expect(error(ultra), lessThan(error(low) * 0.8));
      } finally {
        texture.dispose();
      }
    });
  });
  testWidgets('projected bounds preserve off-center and glowing pixels',
      (tester) async {
    await tester.runAsync(() async {
      final texture = await _texture(false);
      try {
        for (final quality in [SphereQuality.low, SphereQuality.ultra]) {
          for (final setup in <void Function(SphereController)>[
            (_) {},
            (c) => c.setCameraFocus(38, 160,
                viewDirection: const GlobeVector3(-1, 0, 1)),
            (c) => c.setZoom(2.7),
            (c) {
              c.setGlowStyle(const SphereGlowStyle(width: 0.9, intensity: 0.7));
              c.setCameraFocus(-65, 120);
            },
          ]) {
            final bounded = await _render(texture, quality, 1, setup: setup);
            final full = await _render(texture, quality, 1,
                setup: setup, fullViewport: true);
            expect(bounded, full,
                reason: 'Bounds must not trim sphere or glow: $quality');
          }
        }
      } finally {
        texture.dispose();
      }
    });
  });

  if (const bool.fromEnvironment('SPHERE_BENCHMARK')) {
    testWidgets('offscreen raster benchmark (not device FPS)', (tester) async {
      await tester.runAsync(() async {
        final texture = await _texture(true);
        final timings = {for (final q in SphereQuality.values) q: <double>[]};
        try {
          // Warm each variant, interleave measurements, exclude setup/loading.
          for (var round = 0; round < 10; round++) {
            for (final quality in SphereQuality.values) {
              final watch = Stopwatch();
              await _render(texture, quality, 1,
                  logicalSize: 512, rasterWatch: watch);
              if (round >= 3) {
                timings[quality]!.add(watch.elapsedMicroseconds / 1000);
              }
            }
          }
          for (final entry in timings.entries) {
            entry.value.sort();
            debugPrint(
                'SPHERE_RASTER ${entry.key.name}: ${entry.value[entry.value.length ~/ 2].toStringAsFixed(3)} ms median (512x512, raster+readback)');
          }
        } finally {
          texture.dispose();
        }
      });
    });
  }
}

Future<ui.Image> _texture(bool stripes) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (var x = 0; x < 512; x++) {
    canvas.drawRect(
        ui.Rect.fromLTWH(x.toDouble(), 0, 1, 256),
        ui.Paint()
          ..color = (!stripes || (x ~/ 2).isEven)
              ? const ui.Color(0xFFFFFFFF)
              : const ui.Color(0xFF000000));
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(512, 256);
  picture.dispose();
  return image;
}

Future<Uint8List> _render(
  ui.Image texture,
  SphereQuality quality,
  double dpr, {
  double logicalSize = 128,
  Stopwatch? rasterWatch,
  void Function(SphereController)? setup,
  bool fullViewport = false,
}) async {
  final program = await ui.FragmentProgram.fromAsset(sphereShaderAsset(quality)
      .replaceFirst('packages/flutter_globe_3d/', ''));
  final controller = SphereController()
    ..setQuality(quality)
    ..setLightMode(SphereLightMode.followCamera)
    ..setGlowMode(SphereGlowMode.custom)
    ..setGlowStyle(const SphereGlowStyle(intensity: 0));
  setup?.call(controller);
  final size = ui.Size.square(logicalSize);
  controller.updateProjections(size, 3, 0);
  final time = ValueNotifier<double>(0);
  final shader = program.fragmentShader();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(dpr);
  final painter = EarthScenePainter(
      shader: shader,
      texture: texture,
      resolution: size,
      scale: 3,
      devicePixelRatio: dpr,
      controller: controller,
      timeListenable: time,
      repaint: time);
  if (fullViewport) {
    final scratch = ui.PictureRecorder();
    painter.paint(ui.Canvas(scratch), size);
    scratch.endRecording().dispose();
    canvas.drawRect(ui.Offset.zero & size, ui.Paint()..shader = shader);
  } else {
    painter.paint(canvas, size);
  }
  final picture = recorder.endRecording();
  rasterWatch?.start();
  final image = await picture.toImage(
      (logicalSize * dpr).round(), (logicalSize * dpr).round());
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  rasterWatch?.stop();
  final bytes = Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  image.dispose();
  picture.dispose();
  shader.dispose();
  time.dispose();
  controller.dispose();
  return bytes;
}
