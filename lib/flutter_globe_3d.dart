library;

// Core
/// Flutter Globe 3D
///
/// A small convenience library that re-exports the public API of the
/// `flutter_globe_3d` package. Importing this library gives you access to
/// `Flutter3DGlobe`, `EarthController`, `EarthConfig`, `EarthMarker`, and
/// related types used to render an interactive GPU-driven 3D globe.


// Core re-exports
export 'src/earthglobe.dart' show Flutter3DGlobe;
export 'src/earth_controller.dart' show EarthController, EarthConfig;
export 'src/models/earth_connection.dart' show EarthConnection;
export 'src/models/earth_maker.dart' show EarthMarker;
