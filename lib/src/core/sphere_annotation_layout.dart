import 'dart:math' as math;
import 'package:flutter/painting.dart';
import '../models/earth_node.dart';
import '../models/sphere_annotation.dart';

/// Measured widget plus its currently visible screen anchor.
class SphereAnnotationEntry {
  final GlobeNode node;
  final Offset anchor;
  final Size size;
  const SphereAnnotationEntry(this.node, this.anchor, this.size);
}

/// Stateful only for side/quadrant hysteresis; geometry is recalculated on
/// layout, never from paint or by rebuilding the widget children each frame.
class SphereAnnotationLayoutEngine {
  final Map<String, SphereAnnotationSide> _sides = {};
  final Map<String, bool> _bottom = {};

  void retainIds(Set<String> ids) {
    _sides.removeWhere((id, _) => !ids.contains(id));
    _bottom.removeWhere((id, _) => !ids.contains(id));
  }

  Map<String, SphereAnnotationPlacement> layout(
    Size viewport,
    List<SphereAnnotationEntry> entries,
    SphereAnnotationLayout settings,
  ) {
    final result = <String, SphereAnnotationPlacement>{};
    if (viewport.isEmpty ||
        viewport.width <= settings.padding.horizontal + settings.columnGap ||
        viewport.height <= settings.padding.vertical) {
      return result;
    }
    final top = settings.padding.top.clamp(0.0, viewport.height);
    final bottom =
        (viewport.height - settings.padding.bottom).clamp(top, viewport.height);
    final center = viewport.center(Offset.zero);
    final sides = <SphereAnnotationSide, List<SphereAnnotationEntry>>{
      SphereAnnotationSide.left: [],
      SphereAnnotationSide.right: [],
    };
    for (final entry in entries) {
      if (!(Offset.zero & viewport).contains(entry.anchor)) continue;
      var side = entry.node.annotationStyle.side;
      if (side == SphereAnnotationSide.automatic) {
        side = _sides[entry.node.id] ??
            (entry.anchor.dx < center.dx
                ? SphereAnnotationSide.left
                : SphereAnnotationSide.right);
        if (entry.anchor.dx < center.dx - settings.sideSwitchThreshold) {
          side = SphereAnnotationSide.left;
        } else if (entry.anchor.dx > center.dx + settings.sideSwitchThreshold) {
          side = SphereAnnotationSide.right;
        }
      }
      _sides[entry.node.id] = side;
      sides[side]!.add(entry);
    }

    for (final side in sides.keys) {
      final column = sides[side]!;
      if (column.isEmpty) continue;
      final columnWidth = column.fold<double>(
          0, (width, entry) => math.max(width, entry.size.width));
      final upper = <SphereAnnotationEntry>[];
      final lower = <SphereAnnotationEntry>[];
      final normal = <SphereAnnotationEntry>[];
      for (final entry in column) {
        if (entry.node.type != SphereNodeType.denseAnnotation) {
          normal.add(entry);
          continue;
        }
        var isBottom = _bottom[entry.node.id] ?? entry.anchor.dy >= center.dy;
        if (entry.anchor.dy < center.dy - settings.sideSwitchThreshold) {
          isBottom = false;
        } else if (entry.anchor.dy > center.dy + settings.sideSwitchThreshold) {
          isBottom = true;
        }
        _bottom[entry.node.id] = isBottom;
        (isBottom ? lower : upper).add(entry);
      }
      final middle = (top + bottom) / 2;
      final halfGap = settings.rowGap / 2;
      final upperLimit = math.max(top, middle - halfGap);
      final lowerLimit = math.min(bottom, middle + halfGap);
      final topRows = _fit(upper, upperLimit - top, settings.rowGap);
      final bottomRows = _fit(lower, bottom - lowerLimit, settings.rowGap);
      var topCursor = top;
      for (final entry in topRows) {
        _place(result, entry, side, columnWidth, topCursor, viewport, settings);
        topCursor += entry.size.height + settings.rowGap;
      }
      var bottomCursor = bottom - _height(bottomRows, settings.rowGap);
      for (final entry in bottomRows) {
        _place(
            result, entry, side, columnWidth, bottomCursor, viewport, settings);
        bottomCursor += entry.size.height + settings.rowGap;
      }

      // Ordinary annotations keep their anchor Y when possible. Resolve
      // collisions within the free interval between dense corner blocks.
      final normalTop = topRows.isEmpty ? top : topCursor;
      final normalBottom = bottomRows.isEmpty
          ? bottom
          : bottom - _height(bottomRows, settings.rowGap) - settings.rowGap;
      final rows = _fit(normal, normalBottom - normalTop, settings.rowGap);
      final ys = <double>[];
      var cursor = normalTop;
      for (final entry in rows) {
        final preferred = entry.anchor.dy - entry.size.height / 2;
        final y = math.max(cursor, preferred);
        ys.add(y);
        cursor = y + entry.size.height + settings.rowGap;
      }
      cursor = normalBottom;
      for (var i = rows.length - 1; i >= 0; i--) {
        ys[i] = math.min(ys[i], cursor - rows[i].size.height);
        cursor = ys[i] - settings.rowGap;
      }
      for (var i = 0; i < rows.length; i++) {
        _place(result, rows[i], side, columnWidth, ys[i], viewport, settings);
      }
    }
    return result;
  }

  List<SphereAnnotationEntry> _fit(
      List<SphereAnnotationEntry> entries, double space, double gap) {
    final ranked = List<SphereAnnotationEntry>.of(entries)
      ..sort((a, b) {
        final priority = b.node.annotationStyle.priority
            .compareTo(a.node.annotationStyle.priority);
        return priority != 0 ? priority : a.node.id.compareTo(b.node.id);
      });
    final selected = <SphereAnnotationEntry>[];
    var used = 0.0;
    for (final entry in ranked) {
      final required = entry.size.height + (selected.isEmpty ? 0 : gap);
      if (used + required > space) continue;
      selected.add(entry);
      used += required;
    }
    selected.sort((a, b) {
      final y = a.anchor.dy.compareTo(b.anchor.dy);
      return y != 0 ? y : a.node.id.compareTo(b.node.id);
    });
    return selected;
  }

  double _height(List<SphereAnnotationEntry> rows, double gap) =>
      rows.fold<double>(0, (height, entry) => height + entry.size.height) +
      math.max(0, rows.length - 1) * gap;

  void _place(
    Map<String, SphereAnnotationPlacement> result,
    SphereAnnotationEntry entry,
    SphereAnnotationSide side,
    double columnWidth,
    double y,
    Size viewport,
    SphereAnnotationLayout settings,
  ) {
    final isLeft = side == SphereAnnotationSide.left;
    // Align the inner edges of each column, giving leader lines a common
    // terminal rail even when widget widths differ.
    final x = isLeft
        ? settings.padding.left + columnWidth - entry.size.width
        : viewport.width - settings.padding.right - columnWidth;
    final rect = Offset(x, y) & entry.size;
    final end = Offset(isLeft ? rect.right : rect.left, rect.center.dy);
    final span = (entry.anchor.dx - end.dx).abs();
    final dense = entry.node.type == SphereNodeType.denseAnnotation;
    // Longer vertical runs use an outer lane. Together with anchor-Y sorting,
    // this avoids crossed elbows in ordered corner blocks; arbitrary anchor
    // geometry can still cross, so this is routing, not a global optimizer.
    final lane =
        math.min(span / 2, 12 + (entry.anchor.dy - end.dy).abs() * 0.2);
    final elbowX = end.dx + (entry.anchor.dx >= end.dx ? lane : -lane);
    final horizontal = (entry.anchor.dy - end.dy).abs() < 0.01;
    result[entry.node.id] = SphereAnnotationPlacement(
      anchor: entry.anchor,
      labelRect: rect,
      side: side,
      leaderPoints: !dense && horizontal
          ? [entry.anchor, end]
          : [
              entry.anchor,
              Offset(elbowX, entry.anchor.dy),
              Offset(elbowX, end.dy),
              end
            ],
    );
  }
}
