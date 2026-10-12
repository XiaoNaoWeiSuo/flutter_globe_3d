# Render-quality benchmark

Run from the repository root:

~~~sh
flutter test test/render_quality_test.dart --dart-define=SPHERE_BENCHMARK=true
~~~

The benchmark uses the same 512×512 off-screen sphere, high-frequency black-and-white texture, camera, lighting and DPR 1 for each preset. Glow and night lighting are disabled. Each preset is compiled independently, warmed up three times, then measured in an interleaved sequence of seven runs; the median is reported.

Timing includes `Picture.toImage` rasterization and RGBA readback. It excludes asset loading, display-list recording and camera setup.

Measured on 2026-10-12 using Flutter 3.44.1 on macOS through the `flutter test` rendering path:

| Preset | Fixed sample count | Median rasterization + readback | Relative to low |
| --- | --- | --- | --- |
| low | 1 | 25.474 ms | 1.00× |
| medium | 4 | 87.439 ms | 3.43× |
| high | 9 | 177.743 ms | 6.98× |
| ultra | 16 | 307.008 ms | 12.05× |

This measures an off-screen test engine, **not GPU frame time on a target device and cannot be converted to app FPS**. Readback adds fixed overhead. GPU, rendering backend, textures, output size, glow, night lighting and device load all affect the ratios. The benchmark is not a pass/fail test by default. Profile on target devices with DevTools.

## Optimizations shared by all four presets

- Shader source is shared; quality differences come from compile-time fixed sample counts and texture-filter presets.
- Draw only within a conservative projected bound around the sphere and glow; reject off-screen pixels before supersampling.
- Compute analytic coverage only near the silhouette; fully covered sphere pixels skip outer-glow work.
- When glow is off, skip rim lighting. Skip night-texture sampling when no night texture is present or the point is on the lit side.
- Load and reuse Shader variants on demand; reuse sampler bindings when textures and filtering are unchanged.
- Stop vsync when there are no time-based effects; static real-time lighting refreshes once per second.
- Retain texture filtering and silhouette antialiasing at every quality level.

The low preset outputs its single sample directly. It does not accumulate multiple samples or perform unpremultiplication and gamma-conversion round trips. Medium, high and ultra combine multiple samples in linear color space; this contributes to their quality cost.

## Regression coverage

Tests verify transparent edges at all four presets, physical-pixel stroke width at DPR 1 and 3, high-frequency texture error against a reference, and equivalence between bounded drawing and full-canvas output.

Example tests verify that the correct variants load, camera state is retained, the ticker stops while the sphere is static, and auto-rotation wakes and stops it as expected.
