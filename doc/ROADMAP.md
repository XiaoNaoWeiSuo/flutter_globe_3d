# Sphere interaction roadmap

This document distinguishes current capabilities from future ideas. It does not promise released APIs or performance.

## Current API source target: 3.0.0

- Custom 2D Widgets anchored to the sphere, plus 3D connections between nodes.
- External annotations: anchors stay on the sphere while Widgets are arranged in left and right viewport columns.
- Dense annotations: aligned rows in the four corners, routed leader lines, side-switch hysteresis and priority-based overflow hiding.
- Nodes can be updated in place by ID; existing surface nodes remain the default and require no migration.

See the [usage guide](guides/usage.md#5-declarative-nodes-and-connections) for details.

## Future direction: stateful Widgets embedded on the curved surface

The goal is more than today's 2D markers or a static screenshot. A live Flutter Widget subtree would be rendered onto a region of the sphere while preserving its Element/State identity, so interaction, asynchronous data and internal state changes remain visible on the surface.

The first phase should investigate public rendering APIs without assuming that the Flutter engine must be modified:

- Sample a subtree drawing, or use `ImageFilter.shader` to access live drawing input on supported backends.
- Define local coordinates, dimensions, UVs, occlusion and blending rules for a surface region.
- Let text and controls remain unlit or receive sphere lighting, as appropriate.
- Reuse drawing input while the subtree is unchanged; update only the mapping when the camera moves, and refresh dynamic subtrees when they change.
- Do not use per-frame PNG encoding/decoding as the production pipeline, and do not claim zero-copy or a fixed frame rate without measurement.

Relevant public references include [ImageFilter.shader](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html), [FragmentShader.setImageSampler](https://api.flutter.dev/flutter/dart-ui/FragmentShader/setImageSampler.html), and the [AnimatedSampler implementation](https://github.com/jonahwilliams/flutter_shaders/blob/main/lib/src/animated_sampler.dart). Supported behavior must be verified for each Flutter version and rendering backend; platform parity cannot be assumed.

### Staged acceptance criteria

1. **Rendering and state:** stateful counters, switches and asynchronous data remain intact during rotation, zoom, hide and restore.
2. **Tap and input:** ray intersection, region hit testing and UV mapping reach the original Widget subtree; tap feedback, pointer up/cancel and occlusion behave correctly.
3. **Continuous gestures:** sliders and basic scrolling work; multi-touch ownership, local movement and arbitration with sphere camera gestures have defined behavior.
4. **Performance and compatibility:** measure dynamic subtrees, multiple surface Widgets and high resolutions; document backend fallbacks and resource disposal.

### Not promised in the first phase

- Transparent compatibility with every possible Widget interaction.
- TextField cursor, selection and IME candidate positioning that automatically follows the curved surface.
- Tooltips, menus or dialogs curved onto the sphere; normal screen overlays are preferred.
- Accessibility semantic bounds that precisely deform along the sphere.
- Identical cross-platform support for WebView, PlatformView, video and camera textures.

These capabilities require individual adaptations. A successful button demo does not prove full compatibility. No curved-Widget class or enabling parameter exists yet; do not use a hypothetical API.

## Future candidates (not scheduled)

Unified sphere picking, draggable nodes, spherical regions, clustering and level of detail, and connection hit-testing need separate design based on concrete requirements. This iteration implements external and dense annotations only.
