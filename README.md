Flutter Globe 3D — English / 中文

GPU-accelerated 3D globe widget for Flutter.

2.0.1 Official Stable Release.

使用 Fragment Shader 在 GPU 上直接渲染球体纹理，性能强大，适合需要高帧率渲染的场景。正式稳定版。

Demo GIFs & Screenshots

Live recording (spin):

Connection spark demo:

Screenshot — Earth:

Screenshot — Spark overlay:

Language / 语言

This README contains both English and Chinese sections. Read the section you prefer.

本说明同时提供英文与中文内容，向下查找对应语言段落即可。

English

⚠️ Important Note for 2.0.1

Version 2.0.1 is a stable release featuring a completely refactored architecture.
It is not compatible with 1.x.x versions. The API has been simplified, and performance has been significantly optimized. Please check the Usage section for migration.

Quick summary

Flutter Globe 3D is a performant 3D globe widget implemented with Flutter Fragment Shaders. Rendering runs on the GPU (fragment shader), minimizing Dart UI thread usage. This design ensures smooth animations and high frame rates (60–120 FPS).

Key updates in 2.0.1:

Stable & Robust: Solved all known rendering anomalies and interaction bugs.

Layout Adaptive: Perfectly adapts to ListView, Column, Row, Stack, and other dynamic layouts.

Controller-Driven: Markers and connections are now managed entirely via EarthController.

Installation

Add to pubspec.yaml:

dependencies:
  flutter_globe_3d: ^2.0.1

flutter:
  assets:
    - packages/flutter_globe_3d/assets/shaders/earth.frag # Optional: usage explanation below
    - assets/your_texture.png


Usage

The main widget is now Earth3D (previously Flutter3DGlobe). All interactions and data (Nodes/Connections) are managed through EarthController.

import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

class ExampleApp extends StatefulWidget {
  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  // 1. Initialize the controller
  final EarthController controller = EarthController();

  @override
  void initState() {
    super.initState();
    // 2. Load data (Nodes/Markers)
    controller.addNode(
      EarthNode(
        id: 'new_york',
        latitude: 40.7128,
        longitude: -74.0060,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Globe 2.0')),
      body: Center(
        // 3. Use the Earth3D widget
        child: Earth3D(
          controller: controller,
          texture: AssetImage('assets/earth_texture.png'), // Use your own texture image
          initialScale: 0.8,
        ),
      ),
    );
  }
}


Configuration & Controller

In 2.0.1, configuration is done directly via EarthController properties, allowing dynamic updates.

// Auto-rotation
controller.enableAutoRotate = true;
controller.rotateSpeed = 1.0; // Positive for right, negative for left

// Interaction Locks
controller.lockNorthSouth = true; // Lock vertical rotation (Latitude lock)
controller.lockZoom = false;      // Enable/Disable zoom

// Camera/View
controller.setZoom(1.5); // Set zoom level programmatically
controller.setOffset(Offset(100, 0)); // Manually rotate


Technical Notes

Architecture: The Earth3D widget is a lightweight wrapper. The heavy lifting (projection, occlusion culling, rendering) is handled by the EarthController and the GPU Shader.

Assets: The package includes default shaders. You generally do not need to manually import the shader file in your pubspec.yaml unless you are overriding it, as the package handles it internally. However, ensure your texture images are declared.

中文（简体）

⚠️ 2.0.1 版本重要说明

2.0.1 是正式稳定版本。
此版本对架构进行了重构，不兼容 1.x.x 版本。API 更加简洁，性能大幅提升，并且彻底解决了旧版本在 ListView 或复杂布局中显示异常的问题。

简要说明

Flutter Globe 3D 是一个基于 Flutter Fragment Shader 的高性能 3D 地球组件。所有渲染计算均在 GPU 片段着色器中完成，极大地降低了 Dart UI 线程的开销，即使在移动设备上也能保持 60–120 FPS 的流畅度。

2.0.1 亮点：

稳定可靠： 修复了所有已知的渲染、闪烁和交互 Bug。

布局适应性： 完美适配 ListView、Row、Column 等动态布局，不再出现位置偏移。

控制器驱动： 标记（Nodes）和连线（Connections）现在完全通过 EarthController 管理，逻辑更清晰。

安装

在 pubspec.yaml 中添加依赖：

dependencies:
  flutter_globe_3d: ^2.0.1

flutter:
  assets:
    # 请确保添加你自己的地球纹理图片
    - assets/earth_texture.png


使用示例

核心组件变更为 Earth3D，通过 EarthController 来管理状态。

import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

class ExampleApp extends StatefulWidget {
  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  // 1. 创建控制器
  final EarthController controller = EarthController();

  @override
  void initState() {
    super.initState();
    // 2. 添加标记点 (Nodes)
    controller.addNode(
      EarthNode(
        id: 'beijing',
        latitude: 39.9042,
        longitude: 116.4074,
        child: const Icon(Icons.location_on, color: Colors.red, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Globe 2.0')),
      body: Center(
        // 3. 渲染地球
        child: Earth3D(
          controller: controller,
          texture: AssetImage('assets/earth_texture.png'), // 加载你的纹理
          initialScale: 0.8, // 初始缩放比例
        ),
      ),
    );
  }
}


配置与控制器

2.0.1 移除了 EarthConfig 类，您可以直接修改 EarthController 的属性来实时控制地球行为。

// 自动旋转控制
controller.enableAutoRotate = true; // 开启/关闭自动旋转
controller.rotateSpeed = 1.2;       // 调整转速

// 交互锁定
controller.lockNorthSouth = true;   // 锁定南北方向（禁止上下倾斜）
controller.lockZoom = true;         // 锁定缩放

// 编程式控制
controller.setZoom(2.0);            // 代码设置缩放
