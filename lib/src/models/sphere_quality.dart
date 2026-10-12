/// Shader sampling and texture-filtering preset, independent of texture
/// resolution. All presets smooth the sphere silhouette.
enum SphereQuality {
  /// Bilinear textures, one ray per physical pixel. For many small spheres.
  low,

  /// Mipmapped textures, 2 × 2 subpixel rays. Balanced default.
  medium,

  /// Mipmapped textures, 3 × 3 subpixel rays. For large interactive previews.
  high,

  /// Mipmapped textures, 4 × 4 subpixel rays. For closeups and captures.
  /// Up to sixteen shading evaluations per physical pixel; benchmark on device.
  ultra;

  /// Number of shader samples along each grid axis (1, 2, 3, or 4).
  ///
  /// The corresponding square grid uses `samplesPerAxis` squared evaluations
  /// per physical pixel.
  int get samplesPerAxis => index + 1;
}
