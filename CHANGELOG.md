## 3.0.0

### Breaking changes

- Replaced the `Earth*` / `Globe*` public API with a focused `Sphere*` API. The main library no longer exports legacy aliases; use the [migration guide](doc/guides/migration_3_0.md).
- Replaced the mutable camera-and-scene controller with `SphereController.camera` and `SphereController.spin`. Camera operations use explicit poses and zoom limits; spin uses degrees per second.
- Replaced imperative node mutation with declarative `SphereView.nodes` and `SphereView.connections`, each identified by stable IDs.
- Replaced ambiguous latitude/longitude positional arguments and local direction vectors with named `SphereCoordinate`, `SphereViewAngle`, and explicit world-space pose values.
- Replaced `initialScale` with `diameterFactor` and standard Flutter layout constraints.
- Moved lighting, glow, quality, gestures, texture, nodes and connections to immutable `SphereView` configuration.
- Raised the minimum Flutter version to 3.44.0. The package version is now 3.0.0.

### Added and improved

- Added `SphereCameraPose.overview`, `.focus`, and `.world`, with a consistent right-handed XYZ world frame and degree-based view angles.
- Added awaitable camera animation results for completion, cancellation, interruption, view detachment and controller disposal.
- Added explicit spin lifecycle controls and opt-in spin resumption after gesture inertia.
- Added generic `SphereView(texture: ...)` and the `SphereView.earth()` convenience constructor.
- Added in-place texture and night-texture replacement without requiring a new Widget key.
- Added `SphereNode.surface`, `.annotation`, and `.denseAnnotation`, plus stable-ID `SphereConnection` values.
- Preserved shader variants, CPU projection, Flutter-widget interaction, annotation layout, glow modes, seam repair and connection rendering.
- Reused unit-node coordinates, keyed connection curves and projected `Path` objects across declarative scene rebuilds.
- Reworked the example around the 3.0 camera, scene, lighting, spin and material APIs.

### Performance and validation

- `flutter analyze`, package tests and example tests cover the public API, scene validation, camera lifecycle and retained rendering behavior.
- Shader programs remain cached and each view owns its mutable shader instance. Image streams and stale asynchronous resource loads are guarded during in-place updates.
- Camera animation curve failures now complete the animation Future with an error rather than leaving it pending.

## 2.2.5

### Added

- Register `Earth3D.routeObserver` in `MaterialApp.navigatorObservers` to automatically handle app startup, route visibility and pause/resume behavior.

## 2.2.4

### Added

- Added support for a night-side texture.

## 2.2.3

### Added

- Added camera focus API `setCameraFocus`, allowing developers to aim the camera at a geographic coordinate.

### Fixed and improved

- Corrected longitude phase offset in `setCameraFocus` for accurate positioning at coordinates such as Shanghai.
- In `EarthLightMode.followCamera`, moved the light from directly in front of the camera to its upper-left in camera space, producing more visible lower-right shadows and a stronger day/night boundary.

### Internal

- Unified camera-focus coordinate handling with the +90° longitude offset used by node projection and lighting.

## 2.1.3

- Fixed latitude and longitude misalignment.

## 2.1.2

- Fixed the README display image.

## 2.1.1

- Increased drag inertia.

## 2.0.1

### Stable release with breaking changes

This was the stable release of `flutter_globe_3d` and was not compatible with 1.x. Migration was required when upgrading.

### Highlights

- Fixed known rendering, interaction and performance problems.
- Improved internal structure and maintainability.
- Added source documentation.

## 1.2.2

- Fixed the globe being displaced by one radius in a ListView.

## 1.2.1

- Adjusted the sphere-to-frame size ratio to 1:1.5 for improved visual balance.
- Corrected marker and connection alignment with the sphere surface.

## 1.2.0

### Highlights

- Unified auto-rotation state under `EarthController.autoRotate`. User drag and scale interactions temporarily disable rotation and restore it when idle.
- Removed image-stream listeners on both texture-load success and failure.
- Correctly stop the old controller's physics ticker and start the new one when replacing an `EarthController` on a Widget.
- Added `EarthConfig.polarLock` to disable vertical rotation and `zoomLock` to ignore gesture and programmatic zoom changes.

### Migration notes

Auto-rotation now uses the controller as its single source of truth:

~~~dart
final controller = EarthController(autoRotate: true);

// Pause during a custom interaction.
controller.autoRotate = false;

// Resume.
controller.autoRotate = true;
~~~

Configure axis and zoom locks through `EarthConfig`:

~~~dart
final controller = EarthController(
  config: const EarthConfig(polarLock: true, zoomLock: false),
);
~~~

Texture listeners are removed after success or failure, preventing listener leaks when decoding fails. Replacing an `EarthController` at runtime stops the old physics ticker and starts the new one to prevent duplicate tickers.

This release was marked unreleased in the historical source. The public package version and publishing steps were to be completed later; the local codebase targeted 1.2.0 while behavior continued to be refined.

### Summary

- Keep auto-rotation consistent after user interaction using `controller.autoRotate`.
- Remove image stream listeners on decode errors.
- Correctly manage the physics ticker when swapping controllers.

## 1.1.5

- Fixed stuttering caused by scaling.

## 1.1.4

- Fixed layout and display issues; the component adapts to dynamic layouts including ListView, Column, Row and Stack.
- Updated the example and README with demo GIFs and screenshots.

## 0.1.4

- Updated the example and added a display GIF.

## 0.0.4

- Fixed the missing fragment Shader file and removed the assets label.

## 0.0.3

- Fixed another missing fragment Shader file issue.

## 0.0.2

- Fixed a missing fragment Shader file.

## 0.0.1

- Initial release of the 3D Globe Widget.
