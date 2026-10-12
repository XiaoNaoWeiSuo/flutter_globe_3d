# Migrate from 2.x to 3.0

Version 3.0 is a major-version redesign. The package name stays `flutter_globe_3d`, but the main entry point removes old `Earth*` and `Globe*` names and changes camera, scene, lighting, spin and sizing semantics. There is no compatibility-alias mode in 3.0. Keep a 2.x dependency until the application is ready to migrate.

```yaml
dependencies:
  flutter_globe_3d: ^3.0.0
```

Flutter 3.44 or later is required.

## Main API mapping

| 2.x | 3.0 |
| --- | --- |
| `Earth3D`, `Globe3D`, `Sphere3D` | `SphereView` or `SphereView.earth()` |
| `EarthController` / `GlobeController` | `SphereController` |
| `controller.setCameraFocus(lat, lon, ...)` | `controller.camera.focus(target: SphereCoordinate(...), ...)` |
| `controller.focusOnCoordinates(...)` | `controller.camera.focus(...)`, which returns an animation result |
| `controller.showOverview(...)` | `controller.camera.overview(...)` or `camera.setPose(SphereCameraPose.overview(...))` |
| `viewDirection`, `tangent` vectors | `SphereViewAngle` for geographic views; `SphereCameraPose.world` for world XYZ |
| `enableAutoRotate`, `rotateSpeed` | `controller.spin.start/stop/configure` with degrees per second |
| `initialScale` | `diameterFactor` |
| `setQuality(...)` | `SphereView.quality` |
| `setLightMode(...)`, fixed light setter | `SphereView.lighting` |
| `setGlowMode(...)`, `setGlowStyle(...)` | `SphereView.glow` |
| `addNode`, `updateNode`, `connect` | `SphereView.nodes` and `SphereView.connections` |
| positional `latitude, longitude` | named `SphereCoordinate(latitude:, longitude:)` |
| path/key recreation to reload textures | update `texture` / `nightTexture` on the mounted `SphereView` |
| `Sphere3D.routeObserver` | `SphereView.routeObserver` |

## Camera behavior needs an explicit choice

Historical releases used the word “focus” for different camera behaviors. In the early API, the sphere center remained the view center while a geographic coordinate was rotated toward the camera. Later versions used a surface pivot and centered the selected point in the viewport. A typedef cannot preserve both behaviors under one method name.

Choose the matching 3.0 pose intentionally:

```dart
const shanghai = SphereCoordinate(
  latitude: 31.2304,
  longitude: 121.4737,
);

// Keep the sphere center at the viewport center, with Shanghai facing forward.
controller.camera.setPose(
  const SphereCameraPose.overview(facing: shanghai),
);

// Keep Shanghai itself at the viewport center.
await controller.camera.focus(
  target: shanghai,
  view: const SphereViewAngle.front(),
  zoom: 2,
);
```

To reproduce the old “face this coordinate, then keep the sphere centered” sequence, use the overview pose directly. Do not call a surface focus followed by a zero-duration overview; the 3.0 overview already represents that complete destination pose.

## Camera direction conversion

All geographic view angles are degrees. Replace hand-authored local vectors with explicit angles where possible:

```dart
// 45° from the front, toward the left/west.
const left = SphereViewAngle.left(tiltDegrees: 45);

// 60° oblique from the upper-left/northwest.
const upperLeft = SphereViewAngle.upperLeft(tiltDegrees: 60);
```

For compatibility analysis only, a local vector `(x, y, z)` with `z > 0` maps to:

```text
tilt = acos(z / length)
bearing = atan2(x, y)
```

Angles replace that vector convention in normal application code. Use `SphereCameraPose.world` only when the target, direction and screen-up vector are already expressed in the common XYZ world frame.

The public world axes are `+Y` north, `+Z` longitude 0°, and `+X` longitude 90° east. Geographic arguments are now named to avoid swapped coordinate order.

## Move mutable scenes to declarative lists

Old controller mutation:

```dart
controller.addNode(...);
controller.connect(...);
controller.updateNode(...);
```

New widget configuration:

```dart
SphereView.earth(
  controller: controller,
  nodes: [
    SphereNode.annotation(
      id: 'shanghai',
      coordinate: shanghai,
      child: const Text('Shanghai'),
    ),
    SphereNode.surface(
      id: 'tokyo',
      coordinate: const SphereCoordinate(latitude: 35.6762, longitude: 139.6503),
      child: const Icon(Icons.place),
    ),
  ],
  connections: const [
    SphereConnection(id: 'flight', fromId: 'shanghai', toId: 'tokyo'),
  ],
)
```

Submit changed lists from the owning state. Preserve IDs when moving or changing node content so the renderer can retain its scene geometry and Flutter child identity. Every connection must reference two IDs in the same scene.

## Spin and animation migration

Spin is stopped by default in 3.0. Configure its physical unit explicitly:

```dart
controller.spin.configure(
  const SphereSpinOptions(degreesPerSecond: 1.5),
);
controller.spin.start();
```

Camera commands stop spin. To resume after a camera animation, await the Future and call `spin.start()` only when the result is `SphereCameraResult.completed`. Gestures resume spin only when `SphereGestureOptions.resumeAfterGesture` is enabled and spin was running before the gesture.

Do not migrate by copying legacy speed values directly. Earlier speeds were expressed through per-frame orbit deltas and changed with refresh rate; 3.0 uses degrees per second. Measure the visual speed and set a new degree-per-second value.

## Sizing, visual configuration, and lifecycle

Replace `initialScale` and custom width/height compensation with normal Flutter constraints and `diameterFactor`. Move quality, lighting, glow and gesture configuration from controller setters into `SphereView` parameters. Texture changes no longer require a new key.

The caller still owns a supplied `SphereController`; dispose it with the owning State. If the `controller` parameter is omitted, `SphereView` owns its internal controller. One controller may be attached to only one live view.

For the complete current API, see the [usage guide](usage.md) and the package's generated API reference.
