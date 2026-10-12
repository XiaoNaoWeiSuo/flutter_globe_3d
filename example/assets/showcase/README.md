# README showcase renders

These PNGs were exported from the actual `SphereView` widget in the example app:

- `SphereQuality.ultra`, with 16 subpixel samples per physical pixel.
- A 360×360 logical-pixel viewport at DPR 3, exported as a lossless 1080×1080 PNG.
- Camera-following lighting, auto-rotation disabled, and no nodes or connections.
- Earth uses the package's 8192×4096 day/night textures, focused at 15° N, 85° E, with a subtle blue glow.
- Smile, basketball, soccer, marble and wood use the example's 2048×1024 textures with night lighting and glow disabled.

From the repository root (Flutter 3.44+ required):

~~~sh
cd example
flutter test test/readme_renders_test.dart \
  --dart-define=README_RENDER_DIR="$(pwd)/assets/showcase"
~~~

Without `README_RENDER_DIR`, the export test is skipped and does not overwrite images during routine test runs.
See [texture sources and licenses](../textures/SOURCES.md).
Marble and wood show color textures under sphere lighting; they do not use PBR material channels.

## Seven-sphere collage

`seven-spheres-1-2-4-ultra.png` is the compact 1 / 2 / 4 layout used in the README. Each source image is center-cropped to 960×960. Earth remains 960 pixels wide; the basketball and soccer ball on the right are reduced to 480 pixels, and the smile, marble, wood and billiard balls along the bottom are reduced to 360 pixels.

Lanczos filtering is used for downscaling. Sphere-radius proportions are 1 / 0.5 / 0.375, and the final collage is 1476×1344. The billiard source image uses the same ultra quality, DPR 3 and lighting settings as the other individual renders.
