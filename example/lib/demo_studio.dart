import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

/// A minimal animation sequence demonstrating the 3.0 camera Future contract.
class DemoStudioPage extends StatefulWidget {
  const DemoStudioPage({super.key, this.autoplay = false});

  final bool autoplay;

  @override
  State<DemoStudioPage> createState() => _DemoStudioPageState();
}

class _DemoStudioPageState extends State<DemoStudioPage> {
  late final SphereController _controller = SphereController();
  String _status = 'Ready';
  bool _running = false;

  static const _shanghai = SphereCoordinate(
    latitude: 31.2304,
    longitude: 121.4737,
  );

  @override
  void initState() {
    super.initState();
    if (widget.autoplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => play());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> play() async {
    if (_running) return;
    setState(() {
      _running = true;
      _status = 'Turn upper-left 60° → return to front';
    });
    final first = await _controller.camera.focus(
      target: _shanghai,
      view: const SphereViewAngle.upperLeft(tiltDegrees: 60),
      zoom: 2,
      duration: const Duration(milliseconds: 1100),
    );
    if (!mounted || first != SphereCameraResult.completed) {
      if (mounted) setState(() => _running = false);
      return;
    }
    final second = await _controller.camera.focus(
      target: _shanghai,
      view: const SphereViewAngle.front(),
      zoom: 2,
      duration: const Duration(milliseconds: 850),
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _status = 'Sequence: ${second.name}';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Camera Animation Studio')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: SphereView.earth(
              controller: _controller,
              nodes: const [
                SphereNode.annotation(
                  id: 'shanghai',
                  coordinate: _shanghai,
                  child: Text('Shanghai'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(_status),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _running ? null : play,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play sequence'),
              ),
              OutlinedButton.icon(
                onPressed: _running ? _controller.camera.cancel : null,
                icon: const Icon(Icons.stop),
                label: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => _controller.camera.setPose(
                  const SphereCameraPose.overview(),
                ),
                child: const Text('Reset pose'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
