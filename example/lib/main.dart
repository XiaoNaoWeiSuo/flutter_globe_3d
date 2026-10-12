import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';
import 'demo_studio.dart';
import 'texture_gallery.dart';

void main() => runApp(const SphereExampleApp());

const _ink = Color(0xFF07111D);
const _panelColor = Color(0xFF10202F);
const _cyan = Color(0xFF55D6D2);
const _cities = <_City>[
  _City('Shanghai', 31.2304, 121.4737),
  _City('Tokyo', 35.6762, 139.6503),
  _City('Singapore', 1.3521, 103.8198),
  _City('London', 51.5072, -0.1276),
  _City('New York', 40.7128, -74.0060),
  _City('Sydney', -33.8688, 151.2093),
  _City('Cape Town', -33.9249, 18.4241),
];
const _textures = <_TextureOption>[
  _TextureOption('Earth', null),
  _TextureOption('Smile Ball', 'assets/textures/smile.png'),
  _TextureOption('Basketball', 'assets/textures/basketball.png'),
  _TextureOption('Soccer Ball', 'assets/textures/soccer.png'),
  _TextureOption('8-Ball', 'assets/textures/billiard.png'),
  _TextureOption('Marble', 'assets/textures/marble.jpg'),
  _TextureOption('UV Checker', 'assets/textures/uv_checker.png'),
];

class _City {
  final String name;
  final double latitude;
  final double longitude;
  const _City(this.name, this.latitude, this.longitude);

  SphereCoordinate get coordinate =>
      SphereCoordinate(latitude: latitude, longitude: longitude);
}

class _TextureOption {
  final String name;
  final String? asset;
  const _TextureOption(this.name, this.asset);
}

class SphereExampleApp extends StatelessWidget {
  const SphereExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: _ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _cyan,
        brightness: Brightness.dark,
      ),
    ),
    navigatorObservers: [SphereView.routeObserver],
    home: const SphereShowcasePage(),
  );
}

class SphereShowcasePage extends StatefulWidget {
  const SphereShowcasePage({super.key});

  @override
  State<SphereShowcasePage> createState() => _SphereShowcasePageState();
}

class _SphereShowcasePageState extends State<SphereShowcasePage> {
  late final SphereController _controller = SphereController(
    limits: const SphereCameraLimits(minZoom: 0.65, maxZoom: 3),
    spinOptions: const SphereSpinOptions(degreesPerSecond: 1.2),
  );
  _City _selected = _cities.first;
  SphereNodePlacement _placement = SphereNodePlacement.annotation;
  SphereQuality _quality = SphereQuality.medium;
  SphereLightingMode _lightingMode = SphereLightingMode.followCamera;
  String _texture = 'Earth';
  double _zoom = 1;
  double _tilt = 50;
  bool _upperLeft = true;
  bool _rolled = false;
  bool _spin = true;
  bool _autoResume = false;
  bool _customGlow = false;

  @override
  void initState() {
    super.initState();
    _controller.spin.start();
    _controller.spin.addListener(_handleSpinChanged);
  }

  void _handleSpinChanged() {
    final running = _controller.spin.state.running;
    if (_spin != running && mounted) setState(() => _spin = running);
  }

  @override
  void dispose() {
    _controller.spin.removeListener(_handleSpinChanged);
    _controller.dispose();
    super.dispose();
  }

  SphereViewAngle get _viewAngle => _upperLeft
      ? SphereViewAngle.upperLeft(
          tiltDegrees: _tilt,
          rollDegrees: _rolled ? 18 : 0,
        )
      : SphereViewAngle.front(rollDegrees: _rolled ? 18 : 0);

  Future<void> _focus(_City city) async {
    final resume = _autoResume && _controller.spin.state.running;
    final targetZoom = _zoom < 1.3 ? 2.0 : _zoom;
    setState(() {
      _selected = city;
      _zoom = targetZoom;
      _spin = false;
    });
    final result = await _controller.camera.focus(
      target: city.coordinate,
      view: _viewAngle,
      zoom: targetZoom,
      duration: const Duration(milliseconds: 950),
    );
    if (!mounted) return;
    if (result == SphereCameraResult.completed && resume && _autoResume) {
      _controller.spin.start();
      setState(() => _spin = true);
    }
  }

  Future<void> _overview() async {
    setState(() => _spin = false);
    await _controller.camera.overview(
      duration: const Duration(milliseconds: 800),
    );
    if (mounted) setState(() => _zoom = 1);
  }

  List<SphereNode> get _nodes => [
    for (final city in _cities)
      switch (_placement) {
        SphereNodePlacement.surface => SphereNode.surface(
          id: city.name,
          coordinate: city.coordinate,
          child: _cityDot(city),
        ),
        SphereNodePlacement.annotation => SphereNode.annotation(
          id: city.name,
          coordinate: city.coordinate,
          style: const SphereAnnotationStyle(maxWidth: 106, priority: 2),
          child: _cityLabel(city),
        ),
        SphereNodePlacement.denseAnnotation => SphereNode.denseAnnotation(
          id: city.name,
          coordinate: city.coordinate,
          style: const SphereAnnotationStyle(maxWidth: 106, priority: 2),
          child: _cityLabel(city),
        ),
      },
  ];

  Widget _cityDot(_City city) => Tooltip(
    message: city.name,
    child: InkWell(
      onTap: () => _focus(city),
      child: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: _cyan,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: _cyan, blurRadius: 8)],
        ),
      ),
    ),
  );

  Widget _cityLabel(_City city) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: ValueKey('city-${city.name}'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => _focus(city),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _panelColor.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cyan.withValues(alpha: 0.45)),
        ),
        child: Text(city.name, style: const TextStyle(fontSize: 11)),
      ),
    ),
  );

  List<SphereConnection> get _connections => [
    for (var i = 0; i < _cities.length - 1; i++)
      SphereConnection(
        id: 'route-$i',
        fromId: _cities[i].name,
        toId: _cities[i + 1].name,
        color: _cyan.withValues(alpha: 0.8),
        width: 1.3,
        isDashed: i.isOdd,
        showArrow: i == 0,
      ),
  ];

  ImageProvider get _textureProvider {
    final option = _textures.firstWhere((value) => value.name == _texture);
    if (option.asset case final asset?) return AssetImage(asset);
    return const AssetImage(
      'packages/flutter_globe_3d/assets/images/earth.jpg',
    );
  }

  Widget _buildSphere() => Stack(
    fit: StackFit.expand,
    children: [
      SphereView(
        texture: _textureProvider,
        nightTexture: _texture == 'Earth'
            ? const AssetImage(
                'packages/flutter_globe_3d/assets/images/earth_night.jpg',
              )
            : null,
        controller: _controller,
        diameterFactor: 0.94,
        quality: _quality,
        lighting: _lightingMode == SphereLightingMode.fixed
            ? const SphereLighting.fixed(
                coordinate: SphereCoordinate(latitude: 18, longitude: -35),
              )
            : switch (_lightingMode) {
                SphereLightingMode.followCamera =>
                  const SphereLighting.followCamera(),
                SphereLightingMode.solarTime =>
                  const SphereLighting.solarTime(),
                SphereLightingMode.fixed => const SphereLighting.followCamera(),
              },
        glow: _customGlow
            ? const SphereGlow.custom(
                color: Color(0xFF55D6D2),
                width: 0.42,
                intensity: 0.72,
              )
            : const SphereGlow.automatic(),
        gestures: const SphereGestureOptions(
          resumeAfterGesture: false,
          inertiaEnabled: true,
        ),
        annotationLayout: const SphereAnnotationLayout(
          padding: EdgeInsets.fromLTRB(8, 38, 8, 26),
        ),
        nodes: _nodes,
        connections: _connections,
      ),
      const IgnorePointer(
        child: Center(child: Icon(Icons.add, color: Colors.white38)),
      ),
      Positioned(
        left: 8,
        right: 8,
        bottom: 4,
        child: AnimatedBuilder(
          animation: _controller.camera,
          builder: (context, _) => IgnorePointer(
            child: Text(
              '${_selected.name} · ${_controller.camera.zoom.toStringAsFixed(2)}× · ${_controller.camera.isAnimating ? 'animating' : 'ready'}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                shadows: [Shadow(blurRadius: 6, color: Colors.black)],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: 8,
        right: 8,
        child: IconButton.filledTonal(
          tooltip: 'Overview',
          onPressed: _overview,
          icon: const Icon(Icons.center_focus_strong),
        ),
      ),
    ],
  );

  Widget _panel({required String title, required Widget child}) => Material(
    color: _panelColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    ),
  );

  Widget _buildControls() => ListView(
    padding: const EdgeInsets.only(bottom: 12),
    children: [
      _panel(
        title: 'Camera · geographic pose',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final city in _cities)
                  ActionChip(
                    label: Text(city.name),
                    onPressed: () => _focus(city),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Front')),
                ButtonSegment(value: true, label: Text('Upper-left')),
              ],
              selected: {_upperLeft},
              onSelectionChanged: (values) =>
                  setState(() => _upperLeft = values.first),
            ),
            if (_upperLeft)
              Row(
                children: [
                  const Text('Tilt'),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: 80,
                      divisions: 16,
                      value: _tilt,
                      label: '${_tilt.round()}°',
                      onChanged: (value) => setState(() => _tilt = value),
                    ),
                  ),
                  Text('${_tilt.round()}°'),
                ],
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Screen roll'),
              value: _rolled,
              onChanged: (value) => setState(() => _rolled = value),
            ),
            Row(
              children: [
                const Text('Zoom'),
                Expanded(
                  child: Slider(
                    min: 0.65,
                    max: 3,
                    value: _zoom,
                    label: '${_zoom.toStringAsFixed(1)}×',
                    onChanged: (value) {
                      setState(() => _zoom = value);
                      _controller.camera.setZoom(value);
                    },
                  ),
                ),
                Text('${_zoom.toStringAsFixed(1)}×'),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _overview,
                  icon: const Icon(Icons.public),
                  label: const Text('Overview'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _controller.camera.cancel(),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _panel(
        title: 'Scene · nodes and connections',
        child: Column(
          children: [
            SegmentedButton<SphereNodePlacement>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: SphereNodePlacement.surface,
                  label: Text('Surface'),
                ),
                ButtonSegment(
                  value: SphereNodePlacement.annotation,
                  label: Text('Side labels'),
                ),
                ButtonSegment(
                  value: SphereNodePlacement.denseAnnotation,
                  label: Text('Dense'),
                ),
              ],
              selected: {_placement},
              onSelectionChanged: (values) =>
                  setState(() => _placement = values.first),
            ),
            const SizedBox(height: 6),
            const Text(
              'Stable node IDs · interactive Flutter children · keyed arc cache',
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _panel(
        title: 'Spin · explicit lifecycle',
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatic spin · 1.2°/s'),
              value: _spin,
              onChanged: (value) {
                setState(() => _spin = value);
                value ? _controller.spin.start() : _controller.spin.stop();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-resume after completed focus'),
              value: _autoResume,
              onChanged: (value) => setState(() => _autoResume = value),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _panel(
        title: 'Materials · live widget updates',
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _texture,
              decoration: const InputDecoration(labelText: 'Texture'),
              items: [
                for (final value in _textures)
                  DropdownMenuItem(value: value.name, child: Text(value.name)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _texture = value);
              },
            ),
            DropdownButtonFormField<SphereQuality>(
              initialValue: _quality,
              decoration: const InputDecoration(labelText: 'Shader quality'),
              items: [
                for (final value in SphereQuality.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(value.name.toUpperCase()),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _quality = value);
              },
            ),
            DropdownButtonFormField<SphereLightingMode>(
              initialValue: _lightingMode,
              decoration: const InputDecoration(labelText: 'Lighting'),
              items: const [
                DropdownMenuItem(
                  value: SphereLightingMode.followCamera,
                  child: Text('Follow camera'),
                ),
                DropdownMenuItem(
                  value: SphereLightingMode.solarTime,
                  child: Text('Solar time · UTC'),
                ),
                DropdownMenuItem(
                  value: SphereLightingMode.fixed,
                  child: Text('Fixed coordinate'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _lightingMode = value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Custom atmosphere'),
              value: _customGlow,
              onChanged: (value) => setState(() => _customGlow = value),
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 820;
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.public, color: _cyan, size: 30),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Flutter Sphere 3D',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            '3.0 API · camera, scene, materials, spin',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownButton<String>(
                      value: _texture,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final value in _textures)
                          DropdownMenuItem(
                            value: value.name,
                            child: Text(value.name),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _texture = value);
                      },
                    ),
                    IconButton(
                      tooltip: 'Camera Animation Studio',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DemoStudioPage(),
                        ),
                      ),
                      icon: const Icon(Icons.movie_outlined, color: _cyan),
                    ),
                    IconButton(
                      tooltip: 'Texture Gallery',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TextureGalleryPage(),
                        ),
                      ),
                      icon: const Icon(Icons.texture, color: _cyan),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: wide
                      ? Row(
                          children: [
                            Expanded(flex: 7, child: _buildSphere()),
                            const SizedBox(width: 12),
                            SizedBox(width: 360, child: _buildControls()),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(flex: 6, child: _buildSphere()),
                            const SizedBox(height: 8),
                            Expanded(flex: 5, child: _buildControls()),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
