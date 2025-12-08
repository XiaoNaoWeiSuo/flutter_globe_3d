import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyEarthPage(),
    );
  }
}

class MyEarthPage extends StatefulWidget {
  const MyEarthPage({super.key});

  @override
  State<MyEarthPage> createState() => _MyEarthPageState();
}

class _MyEarthPageState extends State<MyEarthPage> {
  final EarthController _controller = EarthController();

  // 预定义颜色板
  final Color colorHub = Colors.cyanAccent;
  final Color colorRoute = Colors.orangeAccent;
  final Color colorLongHaul = Colors.purpleAccent;
  final Color colorLocal = Colors.white38;

  @override
  void initState() {
    super.initState();
    _initEarthData();
  }

  void _initEarthData() {
    // 1. 基础配置
    _controller.rotateSpeed = 0.5;
    _controller.enableAutoRotate = true;
    _controller.minZoom = 0.1; // 允许缩放得很小以查看全貌

    // 2. 全球城市数据 (覆盖各大洲、极端经纬度)
    final cities = [
      // --- 亚洲 ---
      {'id': 'bj', 'lat': 39.90, 'lon': 116.40, 'name': '北京'},
      {'id': 'sh', 'lat': 31.23, 'lon': 121.47, 'name': '上海'},
      {'id': 'tk', 'lat': 35.68, 'lon': 139.69, 'name': '东京'},
      {'id': 'sg', 'lat': 1.35, 'lon': 103.82, 'name': '新加坡'}, // 赤道附近
      {'id': 'dxb', 'lat': 25.20, 'lon': 55.27, 'name': '迪拜'},
      {'id': 'nd', 'lat': 28.61, 'lon': 77.20, 'name': '新德里'},

      // --- 欧洲 ---
      {'id': 'ld', 'lat': 51.50, 'lon': -0.12, 'name': '伦敦'}, // 本初子午线
      {'id': 'pa', 'lat': 48.85, 'lon': 2.35, 'name': '巴黎'},
      {'id': 'mos', 'lat': 55.75, 'lon': 37.61, 'name': '莫斯科'},
      {'id': 'rey', 'lat': 64.14, 'lon': -21.90, 'name': '雷克雅未克'}, // 高纬度北
      // --- 北美洲 ---
      {'id': 'ny', 'lat': 40.71, 'lon': -74.00, 'name': '纽约'},
      {'id': 'sf', 'lat': 37.77, 'lon': -122.41, 'name': '旧金山'},
      {'id': 'van', 'lat': 49.28, 'lon': -123.12, 'name': '温哥华'},
      {'id': 'anc', 'lat': 61.21, 'lon': -149.90, 'name': '安克雷奇'}, // 阿拉斯加
      // --- 南美洲 ---
      {'id': 'rio', 'lat': -22.90, 'lon': -43.17, 'name': '里约热内卢'},
      {'id': 'bsas', 'lat': -34.60, 'lon': -58.38, 'name': '布宜诺斯艾利斯'},
      {'id': 'ush', 'lat': -54.80, 'lon': -68.30, 'name': '乌斯怀亚'}, // 世界尽头
      {'id': 'lim', 'lat': -12.04, 'lon': -77.04, 'name': '利马'},

      // --- 非洲 ---
      {'id': 'ca', 'lat': 30.04, 'lon': 31.23, 'name': '开罗'},
      {'id': 'cpt', 'lat': -33.92, 'lon': 18.42, 'name': '开普敦'},
      {'id': 'lag', 'lat': 6.52, 'lon': 3.37, 'name': '拉各斯'},
      {'id': 'nbi', 'lat': -1.29, 'lon': 36.82, 'name': '内罗毕'},

      // --- 大洋洲 ---
      {'id': 'sy', 'lat': -33.86, 'lon': 151.20, 'name': '悉尼'},
      {'id': 'ak', 'lat': -36.84, 'lon': 174.76, 'name': '奥克兰'}, // 接近日界线
      {'id': 'fiji', 'lat': -17.71, 'lon': 178.06, 'name': '斐济'}, // 东经178
      // --- 极地/特殊点 ---
      {'id': 'ant', 'lat': -62.19, 'lon': -58.96, 'name': '长城站'}, // 南极
      {'id': 'hono', 'lat': 21.30, 'lon': -157.85, 'name': '火奴鲁鲁'}, // 太平洋中心
    ];

    // 添加节点
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

    // 3. 添加连线 (测试不同场景)

    // --- 场景A: 枢纽辐射 (以迪拜为中心) ---
    final hubs = ['ld', 'bj', 'cpt', 'ny', 'sy'];
    for (var target in hubs) {
      _controller.connect(
        EarthConnection(
          fromId: 'dxb',
          toId: target,
          color: colorHub,
          width: 1.5,
          isDashed: true,
        ),
      );
    }

    // --- 场景B: 环太平洋航线 (跨日界线测试) ---
    // 悉尼 -> 斐济 -> 火奴鲁鲁 -> 旧金山 -> 东京 -> 悉尼
    final pacificRoute = ['sy', 'fiji', 'hono', 'sf', 'tk', 'sy'];
    for (int i = 0; i < pacificRoute.length - 1; i++) {
      _controller.connect(
        EarthConnection(
          fromId: pacificRoute[i],
          toId: pacificRoute[i + 1],
          color: Colors.pinkAccent,
          showArrow: true,
          width: 2.0,
        ),
      );
    }

    // --- 场景C: 极地航线 (测试高纬度连线) ---
    // 纽约 -> 伦敦 (北大西洋)
    _controller.connect(
      EarthConnection(
        fromId: 'ny',
        toId: 'ld',
        color: Colors.greenAccent,
        width: 2.0,
      ),
    );
    // 北京 -> 纽约 (跨北极圈，这通常是最短路径)
    _controller.connect(
      EarthConnection(
        fromId: 'bj',
        toId: 'ny',
        color: Colors.tealAccent,
        isDashed: true,
        width: 1.5,
      ),
    );

    // --- 场景D: 纵贯线 (测试南北连接) ---
    // 开罗 -> 开普敦 (非洲纵贯)
    _controller.connect(
      EarthConnection(fromId: 'ca', toId: 'cpt', color: colorRoute),
    );
    // 纽约 -> 里约 -> 乌斯怀亚 -> 长城站 (美洲纵贯到南极)
    _controller.connect(
      EarthConnection(fromId: 'ny', toId: 'rio', color: colorRoute),
    );
    _controller.connect(
      EarthConnection(fromId: 'rio', toId: 'ush', color: colorRoute),
    );
    _controller.connect(
      EarthConnection(
        fromId: 'ush',
        toId: 'ant',
        color: Colors.blueGrey,
        isDashed: true,
      ),
    );

    // --- 场景E: 丝绸之路 (横贯亚欧) ---
    // 上海 -> 新加坡 -> 新德里 -> 迪拜 -> 开罗 -> 伦敦
    final silkRoad = ['sh', 'sg', 'nd', 'dxb', 'ca', 'ld'];
    for (int i = 0; i < silkRoad.length - 1; i++) {
      _controller.connect(
        EarthConnection(
          fromId: silkRoad[i],
          toId: silkRoad[i + 1],
          color: Colors.amber,
          width: 2.5,
        ),
      );
    }
  }

  Widget _buildLabel(String text) {
    return Transform.scale(
      scale: 0.8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            shadows: [Shadow(color: Colors.black, blurRadius: 2)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 3D 地球
          Center(
            child: Earth3D(
              texture: const AssetImage('assets/images/earth.png'),
              controller: _controller,
              initialScale: 3,
              // 让地球撑满宽度，高度自动适配
              size: const Size(400, 400),
            ),
          ),
          // 顶部标题
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: const [
                  Text(
                    "GLOBAL NETWORK VISUALIZATION",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      letterSpacing: 3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Touch to interact • Auto-reset enabled",
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
