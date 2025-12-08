Flutter Globe 3D — English / 中文

2.0.1 正式稳定版。

🚀 专为 Flutter 设计的高性能 3D 地球组件。基于 GPU Fragment Shader 渲染，提供流畅的交互、标记和连线功能。

Demo GIFs & Screenshots / 演示动图与截图
Live recording (Spin) / 旋转演示:

<table>
<tr>
<td align="center">
<img src="https://github.com/XiaoNaoWeiSuo/flutter_globe_3d/blob/main/assets/images/moon.png" width="300px;" alt="Moon"/><br />
<sub>Moon texture / 月球纹理</sub>
</td>
<td align="center">
<img src="https://github.com/XiaoNaoWeiSuo/flutter_globe_3d/blob/main/assets/images/spark.png" width="300px;" alt="Spark"/><br />
<sub>Spark texture / 火星纹理</sub>
</td>
</tr>
<tr>
<td align="center">
<img src="https://github.com/XiaoNaoWeiSuo/flutter_globe_3d/blob/main/assets/images/jupiter.png" width="300px;" alt="Jupiter"/><br />
<sub>Jupiter texture / 木星纹理</sub>
</td>
<td align="center">
<img src="https://github.com/XiaoNaoWeiSuo/flutter_globe_3d/blob/main/assets/images/earth.png" width="300px;" alt="Earth"/><br />
<sub>Earth texture / 地球纹理</sub>
</td>
</tr>
</table>
Language / 语言

This README contains both English and Chinese sections. Read the section you prefer.

本说明同时提供英文与中文内容，向下查找对应语言段落即可。

中文（简体）

🌟 简要说明 (v2.0.1)

flutter_globe_3d 是一款高性能的 3D 地球组件，通过 Flutter Fragment Shader 在 GPU 上直接渲染球体。此设计极大地减少了 CPU 开销，保证了在复杂场景下依然能保持高帧率（60–120FPS）和流畅的交互体验。

v2.0.1 核心特点：

稳定架构： 修复了所有已知布局和渲染问题，完美适应各类动态布局（如 ListView, Stack）。

控制器驱动： 所有状态（旋转、缩放、标记、连线）均由 EarthController 统一管理。

易于扩展： 可轻松更换纹理，用于展示不同的星球（如木星、月球等）。

🛠️ 快速上手指南

1. 安装与资源配置

在 pubspec.yaml 中添加依赖，并声明自定义纹理图片。

dependencies:
  flutter_globe_3d: ^2.0.1

flutter:
  assets:
    # 确保你的自定义纹理图片已声明
    - assets/your_earth_texture.png 
    # 注意：Shader 文件由包内部管理，通常无需再次声明。



2. 基础使用：渲染地球

主组件为 Earth3D。您需要创建一个 EarthController 来控制和管理地球的状态。

import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

class GlobeDemo extends StatefulWidget {
  @override
  State<GlobeDemo> createState() => _GlobeDemoState();
}

class _GlobeDemoState extends State<GlobeDemo> {
  // 1. 初始化控制器
  final EarthController controller = EarthController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Earth3D(
        controller: controller,
        // 2. 使用你的纹理图片
        texture: const AssetImage('assets/your_earth_texture.png'), 
        initialScale: 0.8, // 地球在容器中的初始缩放比例
      ),
    );
  }
}



3. 添加标记点 (Nodes / Markers)

通过 EarthNode 定义标记点，并使用 controller.addNode() 方法添加到地球上。

// 在 initState() 或其他初始化方法中调用
controller.addNode(
  EarthNode(
    id: 'shanghai',
    latitude: 31.2304, // 纬度
    longitude: 121.4737, // 经度
    // 标记点的自定义 Widget
    child: const Icon(Icons.pin_drop, color: Colors.yellow, size: 24),
  ),
);



4. 添加连线 (Connections)

使用 EarthConnection 连接两个已存在的 EarthNode 的 ID，并使用 controller.connect() 添加。连线默认呈 3D 拱形，并进行遮挡剔除。

// 连线示例：连接上海和纽约
controller.connect(
  EarthConnection(
    fromId: 'shanghai',
    toId: 'new_york', // 假设已有一个 ID 为 'new_york' 的节点
    color: Colors.cyanAccent,
    width: 2.0,
    isDashed: true, // 启用虚线动画
    showArrow: true, // 显示箭头方向
  ),
);



5. 控制器 API 参考

EarthController 是控制地球行为的核心，您可以通过修改其属性实现自定义交互和动画。

属性/方法

类型

描述

enableAutoRotate

bool

是否开启自动水平旋转。

rotateSpeed

double

自动旋转速度（正值向右，负值向左）。

lockNorthSouth

bool

锁定南北方向旋转（禁止上下倾斜）。

lockZoom

bool

锁定缩放功能。

setZoom(z)

void

编程式设置缩放级别。

setOffset(o)

void

编程式设置旋转偏移量（相当于手动拖动）。

addNode(node)

void

添加新的标记点。

connect(conn)

void

添加新的连线。

English

🌟 Quick Summary (v2.0.1)

flutter_globe_3d is a high-performance 3D globe widget for Flutter. It leverages GPU Fragment Shaders for rendering, minimizing Dart UI thread load. This results in stable, high frame-rate performance (60–120FPS) with smooth, interactive gestures.

v2.0.1 Key Features:

Stable Architecture: All known layout and rendering bugs resolved. Fully adaptive to dynamic layouts.

Controller Driven: State (rotation, zoom, markers, connections) is managed via the EarthController.

Customizable: Easily swap textures to represent different planets (Earth, Moon, Jupiter, etc.).

🛠️ Developer Usage Guide

1. Installation

Add to pubspec.yaml:

dependencies:
  flutter_globe_3d: ^2.0.1

flutter:
  assets:
    # Make sure to declare your custom texture images
    - assets/your_earth_texture.png 



2. Basic Usage: Rendering the Globe

The main widget is Earth3D. You must create and manage an EarthController instance.

import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

class GlobeDemo extends StatefulWidget {
  @override
  State<GlobeDemo> createState() => _GlobeDemoState();
}

class _GlobeDemoState extends State<GlobeDemo> {
  // 1. Initialize the controller
  final EarthController controller = EarthController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Earth3D(
        controller: controller,
        // 2. Load your texture image
        texture: const AssetImage('assets/your_earth_texture.png'), 
        initialScale: 0.8, // Initial scale of the globe within the container
      ),
    );
  }
}



3. Adding Markers (Nodes)

Define a marker using EarthNode (requires an id, latitude, longitude, and a child widget) and add it via the controller.

// Call this in initState() or setup methods
controller.addNode(
  EarthNode(
    id: 'tokyo',
    latitude: 35.6895, 
    longitude: 139.6917, 
    // Custom widget for the marker
    child: const Icon(Icons.pin_drop, color: Colors.yellow, size: 24),
  ),
);



4. Adding Connections

Use EarthConnection to link two existing node IDs. Connections are rendered as 3D arcs with occlusion culling.

// Example: connecting Tokyo and London
controller.connect(
  EarthConnection(
    fromId: 'tokyo',
    toId: 'london', // Assumes a node with ID 'london' exists
    color: Colors.cyanAccent,
    width: 2.0,
    isDashed: true, // Enable dashed line animation
    showArrow: true, // Show arrow indicator
  ),
);



5. Controller API Reference

The EarthController properties can be modified dynamically to control the globe's behavior.

Property/Method

Type

Description

enableAutoRotate

bool

Enables continuous horizontal rotation.

rotateSpeed

double

Speed of auto-rotation (positive for right).

lockNorthSouth

bool

Locks vertical rotation (pitch), preventing polar tilt.

lockZoom

bool

Disables user and programmatic zoom.

setZoom(z)

void

Programmatically sets the zoom level.

setOffset(o)

void

Programmatically sets the rotation offset.

addNode(node)

void

Adds a new marker node.

connect(conn)

void

Adds a new connection line.

Contributing / 贡献

Feel free to submit Issues or PRs to help improve the project.

License

MIT — See LICENSE

Contact / 支持

Issues: https://github.com/XiaoNaoWeiSuo/flutter_globe_3d/issues