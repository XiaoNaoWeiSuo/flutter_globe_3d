import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MyEarthPage());
  }
}

class MyEarthPage extends StatefulWidget {
  const MyEarthPage({super.key});

  @override
  _MyEarthPageState createState() => _MyEarthPageState();
}

class _MyEarthPageState extends State<MyEarthPage> {
  final EarthController _controller = EarthController();

  @override
  void initState() {
    super.initState();

    // 配置控制器
    _controller.rotateSpeed = .5; // 自转速度
    _controller.enableAutoRotate = false;
    _controller.lockNorthSouth = true;
    final cities = [
      {'id': 'bj', 'lat': 39.90, 'lon': 116.40, 'name': 'Beijing'},
      {'id': 'ld', 'lat': 51.50, 'lon': -0.12, 'name': 'London'},
      {'id': 'ny', 'lat': 40.71, 'lon': -74.00, 'name': 'New York'},
      {'id': 'tk', 'lat': 35.68, 'lon': 139.69, 'name': 'Tokyo'},
      {'id': 'sy', 'lat': -33.86, 'lon': 151.20, 'name': 'Sydney'},
      {'id': 'pa', 'lat': 48.85, 'lon': 2.35, 'name': 'Paris'},
      {'id': 'ca', 'lat': 30.04, 'lon': 31.23, 'name': 'Cairo'},
      {'id': 'rio', 'lat': -22.90, 'lon': -43.17, 'name': 'Rio'},
    ];

    for (var c in cities) {
      _controller.addNode(
        EarthNode(
          id: c['id'] as String,
          latitude: c['lat'] as double,
          longitude: c['lon'] as double,
          child: _buildLabel(c['name'] as String),
        ),
      );
    }

    // 2. 添加连线 (模拟航线网络)
    // 北京 -> 东京 (短途实线)
    _controller.connect(
      EarthConnection(
        fromId: 'bj',
        toId: 'tk',
        color: Colors.redAccent,
        width: 2.0,
      ),
    );
    _controller.connect(
      EarthConnection(
        fromId: 'sy',
        toId: 'ca',
        color: Colors.redAccent,
        width: 2.0,
      ),
    );
    // 北京 -> 伦敦 (长途虚线)
    _controller.connect(
      EarthConnection(
        fromId: 'bj',
        toId: 'ld',
        color: Colors.lightBlueAccent,
        isDashed: true,
      ),
    );

    // 纽约 -> 伦敦 (跨大西洋箭头)
    _controller.connect(
      EarthConnection(
        fromId: 'ny',
        toId: 'ld',
        color: Colors.greenAccent,
        showArrow: true,
        width: 1.5,
      ),
    );

    // 伦敦 -> 巴黎 (非常近的粗线)
    _controller.connect(
      EarthConnection(
        fromId: 'ld',
        toId: 'pa',
        color: Colors.white,
        width: 3.0,
      ),
    );

    // 悉尼 -> 东京 (跨洋虚线)
    _controller.connect(
      EarthConnection(
        fromId: 'sy',
        toId: 'tk',
        color: Colors.purpleAccent,
        isDashed: true,
      ),
    );

    // 里约 -> 纽约 (南北美连线)
    _controller.connect(
      EarthConnection(fromId: 'rio', toId: 'ny', color: Colors.orangeAccent),
    );

    // 开罗 -> 北京 (一带一路节点，黄色虚线)
    _controller.connect(
      EarthConnection(
        fromId: 'ca',
        toId: 'bj',
        color: Colors.yellow,
        isDashed: true,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white30),
      ),
      child: Text(text, style: TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text("Earth Test")),
      body: Column(
        children: [
          Earth3D(
            texture: AssetImage('assets/images/earth_cloud.jpg'),
            controller: _controller,
            initialScale: 3, // 地球占宽度的 80%
            size: Size(400, 400),
          ),
          Earth3D(
            texture: AssetImage('assets/images/earth_cloud.jpg'),
            controller: _controller,
            initialScale: 3, // 地球占宽度的 80%
            size: Size(400, 400),
          ),
        ],
      ),
    );
  }
}
