# Flutter Globe 3D

A high-performance, interactive 3D globe widget for Flutter applications. Render beautiful Earth globes with custom textures, markers, and connections using GPU-accelerated rendering via Fragment Shaders.

## Features

✨ **3D Rendering**
- GPU-accelerated sphere rendering using Fragment Shaders
- Smooth anti-aliased surface with high-quality texture mapping
- Real-time rotation and interactive controls

🎯 **Markers & Connections**
- Place custom markers at any latitude/longitude
- Add clickable markers with labels
- Draw connections between markers with customizable colors and widths
- Intelligent visibility culling (markers only show when facing the camera)

🎮 **Interactive Controls**
- Smooth drag-to-rotate interaction
- Pinch-to-zoom functionality (0.8x to 2.5x)
- Momentum-based inertia when releasing drags
- Automatic rotation when idle (configurable delay)
- Auto-rotation pauses when user interacts with the globe

⚙️ **Customization**
- Custom texture support (any ImageProvider)
- Configurable globe size and background color
- Adjustable rotation speed, zoom limits, and drag sensitivity
- Optional auto-rotation feature
- Scene-aware rendering with proper depth handling

## Getting Started

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_globe_3d: ^0.0.1
```

Then run:

```bash
flutter pub get
```

### Requirements

- Flutter SDK >= 1.17.0
- Dart SDK >= 3.9.2
- Device support for Fragment Shaders (all modern devices)

## Usage

### Basic Example

Create a simple 3D globe:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

class MyGlobeApp extends StatefulWidget {
  @override
  State<MyGlobeApp> createState() => _MyGlobeAppState();
}

class _MyGlobeAppState extends State<MyGlobeApp> {
  late EarthController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EarthController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('3D Globe')),
      body: Center(
        child: Flutter3DGlobe(
          controller: _controller,
          texture: AssetImage('assets/earth_texture.png'),
          radius: 150,
        ),
      ),
    );
  }
}
```

### Adding Markers

Add interactive markers to specific locations:

```dart
Flutter3DGlobe(
  controller: _controller,
  texture: AssetImage('assets/earth.png'),
  radius: 150,
  markers: [
    EarthMarker(
      id: 'ny',
      latitude: 40.7128,  // degrees
      longitude: -74.0060, // degrees
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
      label: 'New York',
      onTap: () => print('Tapped New York'),
    ),
    EarthMarker(
      id: 'tokyo',
      latitude: 35.6762,
      longitude: 139.6503,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
      ),
      label: 'Tokyo',
      onTap: () => print('Tapped Tokyo'),
    ),
  ],
)
```

### Drawing Connections

Connect markers with lines:

```dart
Flutter3DGlobe(
  controller: _controller,
  texture: AssetImage('assets/earth.png'),
  radius: 150,
  markers: [...],
  connections: [
    EarthConnection(
      startId: 'ny',
      endId: 'tokyo',
      color: Colors.lightBlue,
      width: 2.0,
    ),
    EarthConnection(
      startId: 'ny',
      endId: 'london',
      color: Colors.amber,
      width: 1.5,
    ),
  ],
)
```

### Controlling the Globe

Manipulate the globe programmatically:

```dart
// Create controller with custom configuration
final controller = EarthController(
  config: EarthConfig(
    maxZoom: 3.0,
    minZoom: 0.5,
    initialZoom: 1.0,
    initialLat: 0.0,      // Starting latitude
    initialLon: 0.0,      // Starting longitude
    autoRotateSpeed: 0.0005,
    dragSensitivity: 1.0,
  ),
  autoRotate: true,       // Start with auto-rotation
);

// Programmatically adjust zoom
controller.zoom = 1.5;

// Disable auto-rotation
controller.autoRotate = false;
```

## API Reference

### Flutter3DGlobe

Main widget for rendering the 3D globe.

**Constructor Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `controller` | `EarthController` | required | Controls rotation, zoom, and physics |
| `texture` | `ImageProvider` | required | Texture image for the globe surface |
| `shaderAssetPath` | `String` | `'assets/shaders/earth.frag'` | Path to custom fragment shader |
| `markers` | `List<EarthMarker>` | `[]` | List of markers to display |
| `connections` | `List<EarthConnection>` | `[]` | List of connections between markers |
| `radius` | `double` | `150` | Globe radius in logical pixels |
| `backgroundColor` | `Color` | `Colors.transparent` | Background color of globe container |

### EarthController

Manages globe state, rotation, and physics.

**Properties:**

- `rotationX` (double): Current horizontal rotation (radians)
- `rotationY` (double): Current vertical rotation (radians)  
- `zoom` (double): Current zoom level
- `autoRotate` (bool): Whether globe auto-rotates when idle

**Methods:**

- `startPhysics(TickerProvider vsync)`: Initialize physics simulation
- `stopPhysics()`: Stop physics simulation
- `onDragStart()`: Called when user starts dragging
- `onDragUpdate(dx, dy, sensitivity)`: Called during drag motion
- `onDragEnd(velocity, pixelRatio)`: Called when drag ends
- `getRotationMatrix()`: Get current rotation Matrix4
- `getMatrix33()`: Get 3x3 rotation matrix for shader

### EarthMarker

Represents a point of interest on the globe.

**Constructor Parameters:**

```dart
const EarthMarker({
  required String id,              // Unique identifier
  required double latitude,         // -90 to 90 degrees
  required double longitude,        // -180 to 180 degrees
  required Widget child,            // Custom marker widget
  String? label,                    // Optional label text
  VoidCallback? onTap,             // Optional tap handler
})
```

### EarthConnection

Represents a connection between two markers.

```dart
const EarthConnection({
  required String startId,          // Start marker ID
  required String endId,            // End marker ID
  Color color = Colors.lightBlueAccent, // Line color
  double width = 1.5,               // Line width
  bool isArrows = false,            // Reserved for future use
})
```

### EarthConfig

Configuration for globe behavior.

```dart
const EarthConfig({
  double maxZoom = 2.5,             // Maximum zoom level
  double minZoom = 0.8,             // Minimum zoom level
  double initialZoom = 1.0,         // Starting zoom
  double initialLat = 0.2,          // Starting latitude (radians)
  double initialLon = -2.0,         // Starting longitude (radians)
  double autoRotateSpeed = 0.0005,  // Rotation speed when idle
  double dragSensitivity = 1.0,     // Drag interaction sensitivity
})
```

## Performance Considerations

- **Markers**: The widget uses viewport culling - markers facing away from camera are not rendered
- **Connections**: Lines are drawn only when their midpoint faces the camera
- **Textures**: Use appropriately sized textures (512x256 or 1024x512 recommended)
- **Frame Rate**: Targets 60fps on modern devices with GPU acceleration

## Troubleshooting

**Globe appears blank:**
- Ensure texture asset is properly configured in `pubspec.yaml`
- Check that `shaderAssetPath` points to the correct shader file
- Verify device supports Fragment Shaders

**Markers not appearing:**
- Check latitude/longitude values are in valid ranges
- Ensure marker IDs in connections match the defined markers
- Verify markers are facing the camera (viewport culling is active)

**Performance issues:**
- Reduce number of markers and connections
- Use lower resolution textures
- Disable auto-rotation if not needed
- Check device GPU capabilities

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues on the [GitHub repository](https://github.com/XiaoNaoWeiSuo/flutter_globe_3d).

## Support

For issues, questions, or suggestions, please visit:
- [GitHub Issues](https://github.com/XiaoNaoWeiSuo/flutter_globe_3d/issues)
- [GitHub Repository](https://github.com/XiaoNaoWeiSuo/flutter_globe_3d)
