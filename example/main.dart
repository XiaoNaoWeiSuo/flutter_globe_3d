import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';

class MyGlobeApp extends StatefulWidget {
  const MyGlobeApp({super.key});

  @override
  State<MyGlobeApp> createState() => _MyGlobeAppState();
}

class _MyGlobeAppState extends State<MyGlobeApp> {
  late EarthController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EarthController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Flutter3DGlobe(
        controller: _controller,
        texture: AssetImage('assets/example.jpg'),
        radius: 150,
      ),
    );
  }
}
