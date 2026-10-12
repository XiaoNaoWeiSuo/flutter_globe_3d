# Flutter Sphere 3D

[![pub package](https://img.shields.io/pub/v/flutter_globe_3d.svg)](https://pub.dev/packages/flutter_globe_3d)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

High-performance interactive 3D spheres for Flutter. A GPU fragment shader draws the textured sphere; Flutter widgets remain interactive as surface markers or arranged annotations. The API also includes a camera pose system, animated focus, automatic spin, lighting, atmosphere and curved connections.

Version 3.0 is a deliberate breaking redesign. The package name remains `flutter_globe_3d`, while the public API is now consistently `Sphere*`. Existing 2.x applications can stay on their current version until they migrate.

## Showcase

<p align="center">
  <a href="https://github.com/user-attachments/assets/8df80385-8cef-44c3-b6f9-4d13accf6c73">
    <img src="https://github.com/user-attachments/assets/8df80385-8cef-44c3-b6f9-4d13accf6c73" width="720" alt="Seven sphere showcase" />
  </a>
  <br />
  <sub>Seven spheres rendered by the example app with the public 3.0 API.</sub>
</p>

<p>
  <img src="https://github.com/user-attachments/assets/42879e6b-a656-4f0e-bf06-86282ec767b1" width="300" align="right" hspace="24" vspace="8" alt="Live network tour" />
</p>

### Live network tour

The network scene combines geographic nodes with stable-ID spherical connections. Animated dashes and direction arrows show flow while the camera moves between targets with awaitable focus commands. Each label remains a normal interactive Flutter widget, so its callback can update application state or start another camera operation.

- Surface nodes keep their geographic anchors during camera motion.
- Connections are keyed by ID so unchanged curves can be reused.
- Camera commands report completion, cancellation and interruption explicitly.

<br clear="all" />

<p>
  <img src="https://github.com/user-attachments/assets/a5c577a2-7b36-436b-87a9-6aad66d55d7e" width="300" align="left" hspace="24" vspace="8" alt="Layout and light" />
</p>

### Layout and light

This scene shows the three node placements together: surface markers, side annotations and dense corner annotations. The geographic anchor stays on the sphere while the label is packed outside it. Leader lines route around neighboring labels, automatic side selection has hysteresis, and low-priority labels yield when a viewport is crowded.

- `SphereLighting` supports camera-following, solar-time and fixed-coordinate modes.
- `SphereGlow` can be automatic, custom or disabled.
- Layout and material changes apply without replacing the controller.

<br clear="all" />

<p>
  <img src="https://github.com/user-attachments/assets/6248bfe7-fe78-410f-970c-f4d774c9e741" width="300" align="right" hspace="24" vspace="8" alt="Sphere toolkit" />
</p>

### Sphere toolkit

The toolkit scene exercises the reusable sphere surface itself: live equirectangular texture replacement, four quality presets, bounded zoom, explicit spin lifecycle, camera poses and the 60° upper-left view. The same mounted view keeps its camera and scene state while texture, lighting and presentation settings change.

- `SphereView.earth()` supplies the bundled day and night textures.
- `SphereView(texture: ...)` supports planets, sports balls, expressions and materials.
- `SphereController.camera` and `.spin` keep animation state explicit and observable.

<br clear="all" />

These animations and the collage are captures from the real example app. See [demo asset details](doc/guides/demo-assets.md) and [texture source credits](example/assets/textures/SOURCES.md).

## Install

```yaml
dependencies:
  flutter_globe_3d: ^3.0.0
```

Flutter 3.44 or newer is required.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

class InteractiveSphere extends StatefulWidget {
  const InteractiveSphere({super.key});

  @override
  State<InteractiveSphere> createState() => _InteractiveSphereState();
}

class _InteractiveSphereState extends State<InteractiveSphere> {
  late final controller = SphereController();

  static const shanghai = SphereCoordinate(
    latitude: 31.2304,
    longitude: 121.4737,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 360,
        height: 360,
        child: SphereView.earth(
          controller: controller,
          nodes: [
            SphereNode.annotation(
              id: 'shanghai',
              coordinate: shanghai,
              child: TextButton(
                onPressed: () => controller.camera.focus(
                  target: shanghai,
                  view: const SphereViewAngle.upperLeft(tiltDegrees: 60),
                  zoom: 2,
                ),
                child: const Text('Shanghai'),
              ),
            ),
          ],
        ),
      );
}
```

`SphereView.earth()` uses the bundled day and night textures. For your own equirectangular color map, use `SphereView(texture: ...)`; night texture is optional. Texture providers can be replaced while the widget remains mounted.

## 3.0 API at a glance

- `SphereView`: declarative texture, quality, lighting, glow, gestures, node and connection configuration.
- `SphereController.camera`: pose commands, zoom, state snapshots and awaitable animation results.
- `SphereController.spin`: explicit start/stop/configure controls; default speed is 1.5 degrees per second and spin starts stopped.
- `SphereCoordinate`, `SphereViewAngle`, `SphereCameraPose`, `SphereVector3`: named geographic values and right-handed XYZ camera values.
- `SphereNode.surface`, `.annotation`, `.denseAnnotation`: interactive Flutter widgets associated with geographic anchors.
- `SphereConnection`: stable-ID arcs with optional animated dashes and directional arrows.

The world axes are +Y north, +Z longitude 0°, and +X longitude 90° east. Coordinates and camera angles use degrees; zoom is bounded by `SphereCameraLimits`.

The optional, standalone shader-canvas demo is exported separately from `package:flutter_globe_3d/flutter_globe_3d_shader.dart` (`UnifiedShaderCanvas` and the historical `GirdShader` spelling). It is not part of the sphere camera or material API.

## Documentation

- [Usage guide](doc/guides/usage.md): camera recipes, scene construction, materials, lifecycle and performance.
- [3.0 migration guide](doc/guides/migration_3_0.md): breaking changes and old-to-new API mappings.
- [API architecture and design](doc/design/API_3_0.md): public API responsibilities, coordinate semantics, animation outcomes and performance contracts.
- [Roadmap](doc/ROADMAP.md): planned capabilities, including Flutter widgets rendered directly onto the sphere surface.
- [Changelog](CHANGELOG.md): 3.0 changes and historical release notes.

The complete public reference is generated from Dart documentation comments; pub.dev builds and hosts it when a package version is published. To generate it locally, run `dart doc` from the package root.

## Example

Run the interactive showcase:

```sh
cd example
flutter run
```

It demonstrates camera focus and overview, a 60° upper-left view, roll, three node placements, interactive labels, connections, quality, lighting, glow, live texture replacement, automatic spin and opt-in spin resumption after focus.

See [example/README.md](example/README.md) and [texture source credits](example/assets/textures/SOURCES.md) for details.

## Verify a release

From the package root:

```sh
flutter analyze
flutter test
cd example
flutter analyze
flutter test
```

`dart doc --dry-run .` checks the generated API reference. Run
`flutter pub publish --dry-run` immediately before publishing from a clean
working tree.

## License

MIT. See [LICENSE](LICENSE).
