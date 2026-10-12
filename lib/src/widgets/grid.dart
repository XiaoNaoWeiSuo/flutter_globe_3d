import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/src/core/shader_canvas.dart';

/// Displays the package's sample uniform grid shader.
///
/// The historical public spelling is `GirdShader` (rather than GridShader).
/// For an application-provided shader, use [UnifiedShaderCanvas] directly.
class GirdShader extends StatefulWidget {
  /// Creates the built-in grid shader demo.
  const GirdShader({super.key});

  @override
  State<GirdShader> createState() => _GirdShaderState();
}

class _GirdShaderState extends State<GirdShader> {
  @override
  Widget build(BuildContext context) {
    return const UnifiedShaderCanvas(
      shaderAssetPath: "packages/flutter_globe_3d/assets/shaders/uniform.frag",
    );
  }
}
