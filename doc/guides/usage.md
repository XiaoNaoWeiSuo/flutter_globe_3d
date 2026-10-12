# Usage guide

This guide describes the stable 3.0.0 public API. The main entry point is `package:flutter_globe_3d/flutter_globe_3d.dart`; renderer internals and the old 2.x `Earth*` / `Globe*` APIs are not exported there.

## 1. Create a sphere

`SphereView.earth()` uses the bundled Earth color and night-lights textures. A general sphere uses an equirectangular color map:

```dart
SphereView(
  texture: const AssetImage('assets/planet_albedo.jpg'),
  nightTexture: const AssetImage('assets/planet_lights.jpg'), // optional
)
```

Give the view finite Flutter constraints using `SizedBox`, `Expanded`, or a bounded parent. `diameterFactor` controls the visible diameter relative to the shorter viewport edge at zoom 1; its default is `0.85` and valid values are greater than zero and at most one.

The default camera is a centered overview, spin is stopped, quality is `SphereQuality.medium`, lighting follows the camera, and glow is automatic.

## 2. Coordinates and local views

All geographic coordinates use named arguments and degrees. The right-handed unit-sphere world frame is:

| Direction | Meaning |
| --- | --- |
| `+X` | Equator, 90° east longitude |
| `+Y` | North pole |
| `+Z` | Equator, 0° longitude |

```dart
const shanghai = SphereCoordinate(
  latitude: 31.2304,
  longitude: 121.4737,
);
final SphereVector3 unitPosition = shanghai.toWorldPoint();
```

Latitude must be within -90° through 90°. Longitude wraps to [-180°, 180°). `toWorldPoint()` returns a unit-sphere XYZ point, not a screen position.

`SphereViewAngle` is relative to the target point's local tangent frame. Tilt is measured from the surface normal: 0° is head-on and 60° is oblique. Bearing is clockwise from local north; 270° is left/west and 315° is upper-left/northwest. Roll is clockwise on screen.

```dart
const front = SphereViewAngle.front();
const side = SphereViewAngle.left(tiltDegrees: 45);
const upperLeft = SphereViewAngle.upperLeft(tiltDegrees: 60);
```

For the local east/north/outward direction, an upper-left 60° view is approximately `(-0.6124, 0.6124, 0.5)`. `SphereViewAngle.fromLocalVector` is available for vector-based cases and rejects zero, non-finite, or inward directions.

## 3. Focus, overview, and world poses

Create one controller per independently controlled viewport and dispose it from the owner:

```dart
late final controller = SphereController(
  limits: const SphereCameraLimits(minZoom: 0.5, maxZoom: 3),
);

// Immediate pose (does not need a mounted SphereView).
controller.camera.setPose(const SphereCameraPose.focus(
  target: shanghai,
  view: SphereViewAngle.upperLeft(tiltDegrees: 60),
  zoom: 2,
));

// Animated pose (requires the controller to be attached to a mounted view).
final result = await controller.camera.focus(
  target: shanghai,
  view: const SphereViewAngle.front(),
  zoom: 2,
  duration: const Duration(milliseconds: 900),
);
if (result == SphereCameraResult.completed) {
  // Continue only after successful arrival.
}
```

The focused surface coordinate stays at the viewport center. `camera.overview()` returns the view target to the sphere center and faces its `facing` coordinate toward the camera; its default is the Greenwich equator. `camera.setPose(SphereCameraPose.overview(...))` applies the same pose immediately.

For full XYZ control, use `SphereCameraPose.world(target:, direction:, up:, zoom:)`. `target` is a sphere-world point; `direction` points from target toward the camera; `up` defines screen-up and cannot be parallel to direction. Direction and up vector lengths do not encode camera distance.

`camera.state` is an immutable snapshot containing target, eye position, camera basis, distance, zoom and animation status. The sphere radius is normalized to one in this public state, even if the internal renderer scales it to fit the viewport.

### Animation outcomes

`animateTo`, `focus` and `overview` return a `Future<SphereCameraResult>`:

- `completed`: target pose reached.
- `cancelled`: explicitly cancelled or replaced by an immediate `setPose`.
- `interrupted`: replaced by another animated command or a user camera gesture.
- `detached`: view removed while the animation was active.
- `disposed`: controller disposed during the animation.

`cancel()` retains the current pose. Zero duration applies immediately. Negative duration and invalid pose values are rejected. If a custom curve throws or returns a non-finite result, the Future completes with that error; finite extrapolation is clamped to the pose range. There is no implicit command queue—await each result before starting the next step.

The ticker pauses when the app is backgrounded, its route is covered (when `SphereView.routeObserver` is registered), `TickerMode` is disabled, or `active` is false. Animation progress resumes from the same point when visible again.

## 4. Spin and gestures

Spin is a separate, explicit interface and is stopped by default:

```dart
controller.spin.configure(const SphereSpinOptions(degreesPerSecond: 1.5));
controller.spin.start();
controller.spin.stop();
final spinState = controller.spin.state;
```

Positive and negative degree-per-second values rotate in opposite directions; zero keeps spin stopped. Any programmatic camera command stops spin. The view becoming visible does not restart a spin that the application stopped.

`SphereGestureOptions` controls orbit, vertical orbit, pinch zoom, inertia and whether spin may resume after gesture inertia. Resumption is allowed only if spin was running at gesture start. `SphereCameraLimits` applies to both gesture and programmatic zoom; `camera.setZoom` clamps to these limits.

## 5. Declarative nodes and connections

Pass nodes and arcs into `SphereView`. Keep IDs stable between builds; connection endpoints refer to node IDs. The package compares scene values and retains coordinate/curve/path caches across unrelated Widget rebuilds.

```dart
final nodes = [
  SphereNode.annotation(
    id: 'shanghai',
    coordinate: shanghai,
    style: const SphereAnnotationStyle(maxWidth: 120, priority: 10),
    child: TextButton(
      onPressed: () => controller.camera.focus(target: shanghai),
      child: const Text('Shanghai'),
    ),
  ),
  SphereNode.surface(
    id: 'tokyo',
    coordinate: const SphereCoordinate(latitude: 35.6762, longitude: 139.6503),
    child: const Icon(Icons.location_on),
  ),
];

final connections = const [
  SphereConnection(
    id: 'flight-sh-tk',
    fromId: 'shanghai',
    toId: 'tokyo',
    isDashed: true,
    showArrow: true,
  ),
];
```

`SphereNode.surface` follows the visible projected point. `annotation` places a widget in a left/right viewport column. `denseAnnotation` packs labels into four corner groups with routed leaders. All remain ordinary interactive Flutter widgets; they are not warped onto the shader surface.

Node IDs and connection IDs must be unique. Every connection endpoint must exist in the same submitted scene. Invalid scenes throw `ArgumentError` before replacing the last valid renderer scene. Remove a node's connections when deleting the node. Update a node by rebuilding it with the same ID and submitting the updated list.

Connections support color, width, animated dashes and direction arrows. These spherical arcs are independent from annotation leader lines.

## 6. Texture, quality, lighting, and glow

Changing `texture` or `nightTexture` on a mounted `SphereView` reloads the corresponding image streams without resetting camera, zoom or node state. Old stream listeners are removed; stale loads cannot overwrite the newest selection. `nightTexture: null` removes the night layer. The main sphere API owns its built-in Shader variants; custom Shader uniforms are an internal renderer contract, not a stable `SphereView` option.

`SphereQuality.low`, `medium`, `high` and `ultra` select the built-in sampling preset. Set quality declaratively on `SphereView`; choose according to output size, device and number of simultaneously rendered spheres.

Lighting is configured as a value:

```dart
const SphereLighting.followCamera()
const SphereLighting.solarTime()
SphereLighting.fixed(coordinate: shanghai)
```

Solar-time mode approximates the subsolar point from UTC; it is not a high-precision astronomical ephemeris.

Atmosphere is `SphereGlow.automatic()`, `SphereGlow.custom(color:, width:, intensity:)`, or `SphereGlow.none()`. Custom width and intensity are in [0, 1]; width is relative to sphere radius. Zero intensity disables the glow and rim light.

## 7. Ownership and layout lifecycle

If `SphereView.controller` is omitted, that view creates and disposes its controller. A supplied controller stays owned by the caller and can attach to one view at a time. Reusing it in two simultaneous views throws `StateError`.

`SphereView.routeObserver` is optional. Add it to `MaterialApp.navigatorObservers` to pause work when another route covers the sphere. The app lifecycle and Flutter `TickerMode` are observed automatically. For scrollable/off-screen content, set `active` from your own visibility tracking; arbitrary viewport visibility is not inferred.

## 8. 2.x to 3.0 migration

The 3.0 main library intentionally has no `Earth*`, `Globe*`, or old mutable-controller aliases. The change is behavioral as well as nominal: old center-facing camera methods and current surface-focus methods did not share the same meaning. See the [migration guide](migration_3_0.md) for a complete mapping and release-boundary explanation.

## 9. Performance notes

- Cache one `SphereController` per viewport instead of creating it during every build.
- Reuse node and connection IDs; change only the values that actually changed.
- Keep static scenes static. Spin and animations stop their ticker when inactive; custom time-varying content should be enabled only when needed.
- Start at `medium` quality, then profile on representative physical devices. Shader sample presets trade texture aliasing against work per fragment.
- Generic textures should be equirectangular. Normal, roughness and metallic material channels are not currently supported.
- For package checks run `flutter analyze`, `flutter test`, and in `example/`, `flutter test`.
