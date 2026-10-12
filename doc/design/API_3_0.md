# 3.0.0 API architecture and contract

**Status: implemented for the 3.0.0 source version.** This document records the design decisions behind the public API. Copyable recipes and operational details live in the [usage guide](../guides/usage.md); breaking changes are listed in the [migration guide](../guides/migration_3_0.md).

## Release boundary

The redesign uses the major version rather than carrying ambiguous behavior forward under type aliases. The historical source entry point at commit `a7e64ecdfdebf2b45aa0f2e7eca81d3de963d790` exported `Earth*` names, while later releases added `Globe*` and `Sphere*` names and materially changed focus behavior. The old meaning kept the sphere center at the view center and turned a coordinate toward the camera; the later surface-focus behavior makes the selected point itself the view center. A typedef could not preserve those semantics.

The 3.0 main library exports one `Sphere*` vocabulary. Users who need to retain the earlier API can pin their application to 2.x; the 3.0 package does not add runtime compatibility branches or deprecated aliases.

## Separation of responsibilities

| API | Responsibility | State model |
| --- | --- | --- |
| `SphereView` | Textures, quality, lighting, glow, gestures, layout, nodes and connections | Declarative Widget configuration |
| `SphereController.camera` | Immediate and animated poses, zoom, camera snapshots | Scoped `Listenable`; read-only snapshots |
| `SphereController.spin` | Spin settings and start/stop lifecycle | Scoped `Listenable`; stopped initially |
| Immutable value objects | Geographic coordinates, angles, poses, nodes, connections and styles | Caller-created values validated at runtime entry points |

The root controller is not a bag for visual properties or an event stream of every pixel frame. Camera and spin notifications are kept on their respective interfaces. A supplied controller is caller-owned and attaches to one `SphereView`; an omitted controller is owned by the view.

## One coordinate contract

The sphere is a unit sphere centered at world origin. Coordinates use a right-handed XYZ frame:

- `+X`: equatorial longitude 90° east.
- `+Y`: north pole.
- `+Z`: equatorial longitude 0°.

Latitude and longitude are named fields and use degrees. Latitude is bounded to [-90°, 90°]; finite longitude wraps to [-180°, 180°). Public camera snapshots are normalized to the same unit-sphere coordinate frame even though the renderer may resize the sphere to fit its viewport.

`SphereViewAngle` expresses an oblique view in the target's local east/north/outward frame. Bearing is clockwise from north, tilt is measured away from the surface normal, and roll is clockwise in the screen plane. For a direction vector `(x, y, z)`, tilt is `acos(z / length)` and bearing is `atan2(x, y)`. The named front/left/upper-left constructors make common views self-describing.

## Distinct camera destinations

`SphereCameraPose.overview` targets the sphere center and faces a geographic coordinate toward the camera. `SphereCameraPose.focus` targets a surface coordinate and places it at the viewport center. `SphereCameraPose.world` accepts XYZ target, camera direction and screen-up vectors. The first two avoid exposing projection details for common app operations; the third handles advanced coordinate-space use without overloads of `tangent` or `viewDirection`.

Overview has a defined default facing and does not silently inherit a prior orientation. An immediate `setPose` works before the view is mounted. Animated commands require an attached view and return a Future, which makes sequencing depend on actual animation completion rather than an estimated timer.

`SphereCameraResult` makes terminal outcomes explicit: `completed`, `cancelled`, `interrupted`, `detached`, and `disposed`. Invalid commands and custom-curve failures complete with errors. Animation time advances only while the view's ticker is active. There is no hidden queue or implicit auto-spin restart.

## One source of scene truth

Nodes and connections are immutable-looking values passed through `SphereView`. IDs are stable identity and connection endpoints refer to node IDs. Validation occurs when the scene changes, not per frame. Invalid submissions are rejected before replacing the last valid scene.

The renderer snapshots each submitted list, compares nodes and connections by stable IDs and visual fields, and keeps geometry independent from presentation. Node coordinate changes update unit positions and invalidate curves; endpoint changes rebuild affected curves; text, color, and equivalent scene rebuilds preserve geometry and projected path allocations where possible. This keeps Flutter's normal Widget lifecycle as the state source without giving up incremental CPU projection work.

Surface nodes and viewport annotations are still Flutter overlays, not shader-warped Widgets. Annotation leaders and spherical node-to-node arcs are separate rendering concepts.

## Resource lifecycle and visual configuration

Texture, optional night texture and built-in sampling quality are Widget configuration. Replacing image providers while mounted removes old listeners and uses request generations so stale loads cannot replace newer selections. The view retains its camera and scene state. Shared `ImageProvider` images remain owned by Flutter's image cache.

Lighting, glow and gestures are immutable configurations on `SphereView`. The package keeps the four existing built-in shader quality variants, caching programs while each view owns its mutable shader/uniform instance. Custom shader uniform protocols remain an internal implementation detail rather than an option on the stable sphere API.

The legacy generic `UnifiedShaderCanvas` and `GirdShader` demo remain available from the separate `flutter_globe_3d_shader.dart` entry point. They do not share the sphere API or its resource lifecycle contract.

## Performance constraints

- Reuse compiled `FragmentProgram`s; never share a mutable `FragmentShader` across views.
- Keep camera, time, visual configuration, scene geometry and Widget content invalidation separate.
- Stop vsync when the view has no active time-based work; honor app lifecycle, route visibility, `TickerMode`, and the `active` flag.
- Cache unit-sphere positions and ID-keyed connection curves; project them with the current camera basis.
- Avoid converting a camera tick into a rebuild of the entire application Widget tree.
- Preserve edge filtering, projected-bounds clipping, transparent-silhouette coverage, longitude-seam correction and night-texture behavior.
- Measure quality and scene-size changes on representative physical devices; no universal FPS claim is part of the API contract.

These constraints guide implementation and regression checks; they are not a promise of a specific frame rate or allocation count on all devices. Benchmark methodology is in [benchmark/render_quality.md](../../benchmark/render_quality.md).

## Deliberate non-goals

Directly embedding stateful Flutter Widgets onto the curved surface, arbitrary meshes, PBR material channels, and generalized 3D annotation primitives are not part of the 3.0 stable API. In particular, an interactive Widget texture pipeline needs independent texture synchronization, pointer mapping, lifecycle, and composition experiments first. Track those capabilities in the [roadmap](../ROADMAP.md) rather than exposing a premature contract.
