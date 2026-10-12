import 'dart:math' as math;

/// An immutable vector in the globe's right-handed XYZ world coordinate
/// system.
///
/// The globe is centered at `(0, 0, 0)` in a right-handed coordinate system.
/// +X points to the equator at east longitude 90°, +Y to the north pole, and
/// +Z to the equator at longitude 0° (Greenwich). In the default camera view,
/// +Z faces the screen and the camera looks toward -Z. The type is independent
/// of `vector_math` so it can be used directly by the public controller API.
class GlobeVector3 {
  /// X component.
  final double x;

  /// Y component.
  final double y;

  /// Z component.
  final double z;

  /// Creates a vector from its XYZ components.
  const GlobeVector3(this.x, this.y, this.z);

  /// The zero vector.
  static const zero = GlobeVector3(0, 0, 0);

  /// Euclidean vector magnitude.
  double get length => math.sqrt(x * x + y * y + z * z);

  /// Returns a unit-length vector, or this vector unchanged when it is zero.
  GlobeVector3 normalized() {
    final magnitude = length;
    return magnitude == 0 ? this : this / magnitude;
  }

  /// Dot product with [other].
  double dot(GlobeVector3 other) => x * other.x + y * other.y + z * other.z;

  /// Right-handed cross product with [other].
  GlobeVector3 cross(GlobeVector3 other) => GlobeVector3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  /// Removes the component along [normal], leaving a tangent-plane vector.
  /// A zero [normal] leaves this vector unchanged.
  GlobeVector3 projectOnPlane(GlobeVector3 normal) {
    final n = normal.normalized();
    return this - n * dot(n);
  }

  /// Component-wise vector addition.
  GlobeVector3 operator +(GlobeVector3 other) =>
      GlobeVector3(x + other.x, y + other.y, z + other.z);

  /// Component-wise vector subtraction.
  GlobeVector3 operator -(GlobeVector3 other) =>
      GlobeVector3(x - other.x, y - other.y, z - other.z);

  /// Negates all components.
  GlobeVector3 operator -() => GlobeVector3(-x, -y, -z);

  /// Multiplies all components by [scalar].
  GlobeVector3 operator *(double scalar) =>
      GlobeVector3(x * scalar, y * scalar, z * scalar);

  /// Divides all components by [scalar].
  GlobeVector3 operator /(double scalar) =>
      GlobeVector3(x / scalar, y / scalar, z / scalar);

  /// Returns a component-form representation.
  @override
  String toString() => 'GlobeVector3($x, $y, $z)';
}
