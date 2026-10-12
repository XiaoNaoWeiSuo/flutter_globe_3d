# Flutter Sphere 3D example

Run the interactive 3.0 showcase:

```sh
cd example
flutter pub get
flutter run
```

The main page demonstrates:

- `SphereView.earth()` with a reusable `SphereController`.
- Front and upper-left camera poses, including a 60° tilt, roll, bounded zoom, overview, cancellation and awaited focus animation.
- Surface, side-column annotation and dense-corner annotation nodes using interactive Flutter children.
- Stable-ID spherical connections with dashes and arrows.
- Stopped-by-default spin, explicit start/stop, and an application-level option to resume after a completed focus animation.
- Live texture, quality, lighting and atmosphere updates while the same sphere widget remains mounted.

The Camera Animation Studio shows sequential camera operations: it awaits completion of an upper-left 60° pose before returning the same geographic target to a front-on pose. Cancellation and interruption are represented by `SphereCameraResult`, not a guessed delay.

The Texture Gallery (`lib/texture_gallery.dart`) contains offline non-Earth maps for expressions, sports balls, materials and UV debugging. Sources and licenses are documented in [assets/textures/SOURCES.md](assets/textures/SOURCES.md).

The root [usage guide](../doc/guides/usage.md) and [3.0 migration guide](../doc/guides/migration_3_0.md) explain the public API. Example widgets intentionally import only the package's public library.
