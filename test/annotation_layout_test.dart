import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_globe_3d/src/core/sphere_annotation_layout.dart';
import 'package:flutter_globe_3d/src/controller/earth_controller.dart';
import 'package:flutter_globe_3d/src/models/earth_node.dart';
import 'package:flutter_globe_3d/src/models/sphere_annotation.dart';

SphereAnnotationEntry entry(
  String id,
  Offset anchor, {
  SphereNodeType type = SphereNodeType.annotation,
  SphereAnnotationSide side = SphereAnnotationSide.automatic,
  Size size = const Size(80, 24),
  int priority = 0,
}) =>
    SphereAnnotationEntry(
        SphereNode(
          id: id,
          latitude: 0,
          longitude: 0,
          child: const SizedBox(),
          type: type,
          annotationStyle:
              SphereAnnotationStyle(side: side, priority: priority),
        ),
        anchor,
        size);

void expectPacked(
    Map<String, SphereAnnotationPlacement> placements, Size size) {
  final rects = placements.values.map((p) => p.labelRect).toList();
  for (var i = 0; i < rects.length; i++) {
    expect(rects[i].left, greaterThanOrEqualTo(0));
    expect(rects[i].top, greaterThanOrEqualTo(0));
    expect(rects[i].right, lessThanOrEqualTo(size.width));
    expect(rects[i].bottom, lessThanOrEqualTo(size.height));
    for (var j = i + 1; j < rects.length; j++) {
      expect(rects[i].overlaps(rects[j]), isFalse);
    }
  }
}

void main() {
  const settings = SphereAnnotationLayout();
  const viewport = Size(400, 300);
  test('ordinary annotations use horizontal leaders and the nearest column',
      () {
    final placements = SphereAnnotationLayoutEngine().layout(
        viewport,
        [
          entry('left', const Offset(150, 100)),
          entry('right', const Offset(250, 150)),
        ],
        settings);
    expect(placements['left']!.side, SphereAnnotationSide.left);
    expect(placements['right']!.side, SphereAnnotationSide.right);
    for (final p in placements.values) {
      expect(p.leaderPoints.length, 2);
      expect(p.labelRect.center.dy, p.anchor.dy);
    }
    expectPacked(placements, viewport);
  });

  test('side switches have hysteresis and explicit sides override it', () {
    final engine = SphereAnnotationLayoutEngine();
    for (final x in [180.0, 201.0, 210.0]) {
      expect(
          engine
              .layout(viewport, [entry('a', Offset(x, 100))], settings)['a']!
              .side,
          SphereAnnotationSide.left);
    }
    expect(
        engine
            .layout(
                viewport, [entry('a', const Offset(220, 100))], settings)['a']!
            .side,
        SphereAnnotationSide.right);
    expect(
        engine
            .layout(
                viewport,
                [
                  entry('a', const Offset(250, 100),
                      side: SphereAnnotationSide.left)
                ],
                settings)['a']!
            .side,
        SphereAnnotationSide.left);
  });

  test('dense annotations occupy four corner rows with orthogonal leaders', () {
    final placements = SphereAnnotationLayoutEngine().layout(
        viewport,
        [
          for (final x in [140.0, 260.0])
            for (final y in [90.0, 110.0, 190.0, 210.0])
              entry('$x-$y', Offset(x, y),
                  type: SphereNodeType.denseAnnotation),
        ],
        settings);
    expect(placements.length, 8);
    expect(placements.values.map((p) => p.labelRect.top), contains(12));
    expect(placements.values.map((p) => p.labelRect.bottom), contains(288));
    for (final p in placements.values) {
      expect(p.leaderPoints.length, 4);
      expect(p.leaderPoints.first, p.anchor);
      for (var i = 1; i < p.leaderPoints.length; i++) {
        final delta = p.leaderPoints[i] - p.leaderPoints[i - 1];
        expect(delta.dx == 0 || delta.dy == 0, isTrue);
      }
    }
    expectPacked(placements, viewport);
  });

  test('mixed modes and variable heights pack without overlap', () {
    final placements = SphereAnnotationLayoutEngine().layout(
        viewport,
        [
          entry('top', const Offset(160, 60),
              type: SphereNodeType.denseAnnotation),
          entry('bottom', const Offset(160, 240),
              type: SphereNodeType.denseAnnotation),
          for (var i = 0; i < 8; i++)
            entry('normal-$i', Offset(160, 130.0 + i),
                size: Size(70, 14.0 + i)),
        ],
        settings);
    expect(placements.length, 10);
    expectPacked(placements, viewport);
  });

  test('crowded columns hide lower priority labels instead of overlapping', () {
    final placements = SphereAnnotationLayoutEngine().layout(
        const Size(200, 100),
        [
          for (var i = 0; i < 30; i++)
            entry('node-$i', const Offset(70, 40),
                priority: i, type: SphereNodeType.denseAnnotation),
        ],
        settings);
    expect(placements.keys, ['node-29']);
    expectPacked(placements, const Size(200, 100));
  });

  test('offscreen, empty and too small viewports have no annotations', () {
    final engine = SphereAnnotationLayoutEngine();
    expect(
        engine.layout(viewport, [entry('a', const Offset(-1, 100))], settings),
        isEmpty);
    expect(engine.layout(Size.zero, [], settings), isEmpty);
    expect(
        engine.layout(
            const Size(20, 20), [entry('a', const Offset(10, 10))], settings),
        isEmpty);
  });

  test('default nodes remain surface nodes and updateNode preserves identity',
      () {
    final controller = SphereController();
    final node =
        SphereNode(id: 'a', latitude: 0, longitude: 0, child: const SizedBox());
    expect(node.type, SphereNodeType.surface);
    controller.addNode(node);
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.updateNode(node.copyWith(type: SphereNodeType.annotation));
    expect(controller.nodes.single.id, node.id);
    expect(controller.nodes.single.child, same(node.child));
    expect(notifications, 1);
    expect(() => controller.addNode(node), throwsArgumentError);
    expect(
        () => controller
            .updateNode(node.copyWith().copyWith(type: SphereNodeType.surface)),
        returnsNormally);
    expect(
        () => controller.updateNode(SphereNode(
            id: 'missing', latitude: 0, longitude: 0, child: const SizedBox())),
        throwsArgumentError);
    controller.dispose();
  });
}
