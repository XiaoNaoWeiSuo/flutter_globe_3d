import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/src/core/shader_canvas.dart';

/// `GirdShader` 是一个简单的 StatefulWidget，用于显示一个基于着色器的网格。
/// 它使用了 `UnifiedShaderCanvas` 来加载和渲染 `uniform.frag` 着色器。
class GirdShader extends StatefulWidget {
  /// 构造函数，用于创建 `GirdShader` 实例。
  const GirdShader({super.key});

  @override
  State<GirdShader> createState() => _GirdShaderState();
}

class _GirdShaderState extends State<GirdShader> {
  @override
  Widget build(BuildContext context) {
    return UnifiedShaderCanvas(
      shaderAssetPath: "packages/flutter_globe_3d/assets/shaders/uniform.frag",
    );
  }
}
