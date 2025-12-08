library;

// Core
/// Flutter Globe 3D
///
/// A small convenience library that re-exports the public API of the
/// `flutter_globe_3d` package. Importing this library gives you access to
/// `Flutter3DGlobe`, `EarthController`, `EarthConfig`, `EarthMarker`, and
/// related types used to render an interactive GPU-driven 3D globe.

// Core re-exports
export 'src/core/shader_canvas.dart' show UnifiedShaderCanvas;

export 'src/widgets/grid.dart' show GirdShader;

export 'src/widgets/earth.dart' show Earth3D;

export 'src/controller/earth_controller.dart' show EarthController;

export 'src/models/earth_connection.dart' show EarthConnection;

export 'src/models/earth_node.dart' show EarthNode;
