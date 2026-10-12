import '../models/sphere_quality.dart';

const defaultSphereShaderAsset =
    'packages/flutter_globe_3d/assets/shaders/earth.frag';

String sphereShaderAsset(SphereQuality quality) =>
    'packages/flutter_globe_3d/assets/shaders/${switch (quality) {
      SphereQuality.low => 'earth_low.frag',
      SphereQuality.medium => 'earth.frag',
      SphereQuality.high => 'earth_high.frag',
      SphereQuality.ultra => 'earth_ultra.frag',
    }}';
