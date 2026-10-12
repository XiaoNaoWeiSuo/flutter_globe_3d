import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

class _TextureDemo {
  const _TextureDemo(this.id, this.name, this.group, this.description);

  final String id;
  final String name;
  final String group;
  final String description;

  String get asset =>
      'assets/textures/$id.${group == 'Materials' ? 'jpg' : 'png'}';
}

const _textures = [
  _TextureDemo(
    'smile',
    'Smile Ball',
    'Expressions',
    'A bright smile facing longitude 0°. Drag to see the reverse side.',
  ),
  _TextureDemo(
    'wink',
    'Wink Ball',
    'Expressions',
    'A winking face with blush, drawn as a spherical texture.',
  ),
  _TextureDemo(
    'basketball',
    'Basketball',
    'Sports',
    'Procedurally generated orange pebbled texture and spherical seams.',
  ),
  _TextureDemo(
    'soccer',
    'Soccer Ball',
    'Sports',
    'High-resolution black pentagons and white hexagons based on a truncated icosahedron.',
  ),
  _TextureDemo(
    'billiard',
    '8-Ball',
    'Sports',
    'Unbranded black billiard ball with a number badge.',
  ),
  _TextureDemo(
    'marble',
    'Marble',
    'Materials',
    'Light stone texture · ambientCG Marble012 · CC0',
  ),
  _TextureDemo(
    'wood',
    'Wood',
    'Materials',
    'Dark brown wood grain · ambientCG Wood051 · CC0',
  ),
  _TextureDemo(
    'fabric',
    'Fabric',
    'Materials',
    'Gray woven texture · ambientCG Fabric030 · CC0',
  ),
  _TextureDemo(
    'uv_checker',
    'UV Checker',
    'Debug',
    'Numbered latitude-longitude grid for inspecting seams, orientation, and pole distortion.',
  ),
];

/// Local, offline examples of non-planet sphere textures.
class TextureGalleryPage extends StatefulWidget {
  const TextureGalleryPage({super.key});

  @override
  State<TextureGalleryPage> createState() => _TextureGalleryPageState();
}

class _TextureGalleryPageState extends State<TextureGalleryPage> {
  final _controller = SphereController(
    limits: const SphereCameraLimits(minZoom: 0.55, maxZoom: 2.0),
  );
  _TextureDemo _selected = _textures.first;
  SphereQuality _quality = SphereQuality.ultra;
  bool _autoRotate = false;
  bool _glow = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetView() {
    _controller.camera.setPose(const SphereCameraPose.overview());
    _controller.camera.setZoom(1);
    if (_autoRotate) {
      _controller.spin.start();
    } else {
      _controller.spin.stop();
    }
  }

  void _select(_TextureDemo texture) {
    if (_selected == texture) return;
    setState(() => _selected = texture);
    _resetView();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Texture Gallery')),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxHeight * 0.55).clamp(240.0, 440.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 864),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'More Than Planets',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '9 local textures · Drag to rotate, pinch or scroll to zoom',
                  ),
                  SizedBox(
                    height: height,
                    width: double.infinity,
                    child: SphereView(
                      controller: _controller,
                      texture: AssetImage(_selected.asset),
                      nightTexture: null,
                      diameterFactor: 0.9,
                      quality: _quality,
                      lighting: const SphereLighting.followCamera(),
                      glow: SphereGlow.custom(intensity: _glow ? 0.6 : 0),
                    ),
                  ),
                  Text(
                    _selected.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selected.description,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final quality in SphereQuality.values)
                        ChoiceChip(
                          key: ValueKey('quality-${quality.name}'),
                          label: Text(
                            const [
                              'Smooth',
                              'Balanced',
                              'High',
                              'Ultra',
                            ][quality.index],
                          ),
                          selected: _quality == quality,
                          onSelected: (_) {
                            setState(() => _quality = quality);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ultra is ideal for close-ups; use Smooth or Balanced for multiple spheres or lower-powered devices.',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        label: const Text('Auto-Rotate'),
                        selected: _autoRotate,
                        onSelected: (value) {
                          setState(() => _autoRotate = value);
                          value
                              ? _controller.spin.start()
                              : _controller.spin.stop();
                        },
                      ),
                      FilterChip(
                        label: const Text('Atmospheric Glow'),
                        selected: _glow,
                        onSelected: (value) {
                          setState(() => _glow = value);
                        },
                      ),
                      OutlinedButton.icon(
                        onPressed: _resetView,
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('Reset View'),
                      ),
                    ],
                  ),
                  for (final group in [
                    'Expressions',
                    'Sports',
                    'Materials',
                    'Debug',
                  ]) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 18, bottom: 8),
                      child: Text(
                        group,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final texture in _textures.where(
                          (t) => t.group == group,
                        ))
                          ChoiceChip(
                            key: ValueKey('texture-${texture.id}'),
                            avatar: ClipOval(
                              child: Image.asset(
                                texture.asset,
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                              ),
                            ),
                            label: Text(texture.name),
                            selected: _selected == texture,
                            onSelected: (_) => _select(texture),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Material spheres use color textures with the component lighting. The renderer does not read normal, roughness, or metallic maps. '
                    'Tiled materials stretch near the poles; use the UV Checker to inspect this behavior.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
