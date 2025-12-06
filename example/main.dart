import 'package:flutter/material.dart';
import 'package:flutter_globe_3d/src/earth_controller.dart';
import 'package:flutter_globe_3d/src/earthglobe.dart';

class Example extends StatefulWidget {
  const Example({super.key});

  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  EarthController earthController = EarthController();

  @override
  Widget build(BuildContext context) {
    return Flutter3DGlobe(
      controller: earthController,
      radius: 200,
      texture: AssetImage("assets/example.png"),
    );
  }
}
