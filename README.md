## **Flutter Globe 3D** — English / 中文

> GPU-accelerated 3D globe widget for Flutter. 使用 Fragment Shader 在 GPU 上直接渲染球体纹理，性能强大，适合需要高帧率渲染的场景。

---

**Demo GIFs & Screenshots**

- Live recording (spin):

  ![record_earth](https://raw.githubusercontent.com/XiaoNaoWeiSuo/flutter_globe_3d/main/example/images/record_earth.gif)

- Connection spark demo:

  ![record_spark](https://raw.githubusercontent.com/XiaoNaoWeiSuo/flutter_globe_3d/main/example/images/record_spark.gif)

- Screenshot — Earth:

  ![screenshot_earth](https://raw.githubusercontent.com/XiaoNaoWeiSuo/flutter_globe_3d/main/example/images/screenshot_earth.png)

- Screenshot — Spark overlay:

  ![screenshot_spark](https://raw.githubusercontent.com/XiaoNaoWeiSuo/flutter_globe_3d/main/example/images/screenshot_spark.png)

---

**Language / 语言**

This README contains both English and Chinese sections. Read the section you prefer.

本说明同时提供英文与中文内容，向下查找对应语言段落即可。

---

## **English**

### Quick summary

Flutter Globe 3D is a performant 3D globe widget implemented with Flutter Fragment Shaders. Rendering runs on the GPU (fragment shader), the Dart UI thread is not used for sphere shading; raster thread workload is small — the result is smooth animation and the ability to reach very high frame rates (e.g. 60–120 FPS on capable devices).

Key advantages:
- GPU shader-based mapping -> high performance
- Low Dart-side cost (no heavy UI work per-frame)
- Smooth anti-aliased rendering and accurate texture mapping

Known limitation:
- Currently the widget reliably displays inside `ListView` and when used in layouts without tight constraints (the widget may have issues under some layout constraints). Contributions to improve layout compatibility are welcome.

### Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_globe_3d: ^0.1.4
```

Add assets (example):

```yaml
flutter:
  assets:
    - assets/shaders/globe.frag
    - assets/earth_texture.png
    - example/images/record_earth.gif
    - example/images/record_spark.gif
```

### Usage (updated example)

This example matches the `example/main.dart` shipped with the package and demonstrates texture loading, markers and connections:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

class ExampleApp extends StatefulWidget {
  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final EarthController controller = EarthController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Globe')),
      body: Center(
        child: Flutter3DGlobe(
          controller: controller,
          texture: AssetImage('assets/example.png'),
          radius: 200,
          markers: [
            EarthMarker(
              id: 'ny',
              latitude: 40.7128,
              longitude: -74.0060,
              child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
              label: 'New York',
            ),
          ],
          connections: [],
        ),
      ),
    );
  }
}
```

### Technical notes

- Implementation: the globe surface is shaded using a fragment shader (`assets/shaders/globe.frag`). The shader computes spherical mapping and lighting on the GPU.
- Performance: because the heavy work happens in the shader, the Dart UI thread remains mostly idle; only a small amount of state (rotation/zoom) is sent per frame. This design minimizes CPU overhead and lets modern devices reach very high frame rates.
- Raster thread: shaders run in the GPU/raster pipeline — the plugin keeps raster thread usage small.

### When things go wrong

- If you see the error `does not contain any shader data`, make sure the shader asset is declared in your app's `pubspec.yaml` under `flutter.assets` and `shaders` (if using Flutter's shader tooling).
- Example `shaderAssetPath` default is `assets/shaders/globe.frag`. Do not prefix with `packages/` when the asset is included in the same package.

---

## **中文（简体）**

### 简要说明

本插件使用 Flutter 的 Fragment Shader 在 GPU 上直接绘制球体纹理映射。渲染在 GPU 侧完成，不占用 Dart UI 线程，只有很少的 raster 线程开销，因此在支持的设备上可以非常流畅（可达 60–120FPS）。推荐用于需要高帧率的球体演示场景。

优点：
- 基于着色器的映射，性能强大
- 几乎不占用 Dart UI 线程
- 抗锯齿、贴图映射准确

已知缺陷：
- 当前在某些布局约束下显示可能不稳定；插件在 `ListView` 和无复杂约束（“无布局组件”）下表现最稳定。欢迎贡献以改善对更多布局的兼容性。

### 安装与资源

在 `pubspec.yaml` 中添加依赖与资源：

```yaml
dependencies:
  flutter_globe_3d: ^0.1.4

flutter:
  assets:
    - assets/shaders/globe.frag
    - assets/example.png
    - example/images/record_earth.gif
    - example/images/record_spark.gif
```

注意：Shader 文件须在 `assets` 下声明并与 `shaderAssetPath` 对应。

### 使用示例

请参考 `example/main.dart`：示例演示了如何创建 `EarthController`，加载纹理，添加标记，并将 `Flutter3DGlobe` 嵌入页面。

（示例代码见上方 English 部分，已更新以匹配示例工程。）

### 技术实现说明

- 映射实现：使用 fragment shader 在 GPU 上对球体进行纹理采样与着色。
- 性能说明：渲染逻辑由 GPU 完成，Dart 侧仅负责传递旋转、缩放等少量状态；因此 CPU 负担小，UI 线程空闲，渲染可保持高帧率。
- 限制：目前在复杂约束布局下可能存在显示问题；在 `ListView` 与未受限容器中表现稳定。

---

## **Contributing / 贡献**

欢迎提出 issue 或 PR。如果你能帮助改善布局兼容性（例如在更多容器与约束下也能稳定渲染），非常感谢！

## **License**

MIT — 详见 `LICENSE`

---

**Contact / 支持**

- Issues: https://github.com/XiaoNaoWeiSuo/flutter_globe_3d/issues
