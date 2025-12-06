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
      body: ListView(
        children: [
          Container(height: 100),
          Container(
            decoration: BoxDecoration(color: Colors.black),
            child: Row(
              children: [
                Flutter3DGlobe(
                  controller: _controller,
                  texture: AssetImage('assets/mark.jpg'),
                  radius: 150,
                ),
                Column(
                  children: [
                    Text(
                      "Spark",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
