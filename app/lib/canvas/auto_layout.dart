import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import 'geometry.dart';

/// Arranges a pipeline left to right, so a build reads the way it flows.
///
/// A layered layout: every node sits one column to the right of whatever feeds
/// it, and the nodes within a column are ordered to keep the wires between them
/// from crossing more than they must.
class AutoLayout {
  const AutoLayout({
    required this.pipeline,
    required this.database,
    this.columnGap = 112,
    this.rowGap = 36,
  });

  final Pipeline pipeline;
  final GameDatabase database;
  final double columnGap;
  final double rowGap;

  /// New positions for every node, ready to be applied as one edit.
  Map<String, Offset> positions() {
    if (pipeline.nodes.isEmpty) return const {};

    final forward = _forwardEdges();
    final layers = _assignLayers(forward);
    final columns = _orderWithinColumns(layers, forward);
    return _placeColumns(columns);
  }

  /// Edges that go "forwards", with the ones closing a cycle left out.
  ///
  /// A recycling loop has no left-to-right reading — something has to point
  /// backwards — so the layout ignores the edge that closes it and lets the
  /// wire double back instead of stretching the whole graph to accommodate it.
  List<PipelineEdge> _forwardEdges() {
    final outgoing = <String, List<PipelineEdge>>{};
    for (final edge in pipeline.edges) {
      if (edge.fromNodeId == edge.toNodeId) continue;
      outgoing.putIfAbsent(edge.fromNodeId, () => []).add(edge);
    }

    final backEdges = <String>{};
    final visited = <String>{};
    final onStack = <String>{};

    void visit(String nodeId) {
      visited.add(nodeId);
      onStack.add(nodeId);
      for (final edge in outgoing[nodeId] ?? const <PipelineEdge>[]) {
        if (onStack.contains(edge.toNodeId)) {
          backEdges.add(edge.id);
        } else if (!visited.contains(edge.toNodeId)) {
          visit(edge.toNodeId);
        }
      }
      onStack.remove(nodeId);
    }

    for (final node in pipeline.nodes) {
      if (!visited.contains(node.id)) visit(node.id);
    }

    return [
      for (final edge in pipeline.edges)
        if (edge.fromNodeId != edge.toNodeId && !backEdges.contains(edge.id))
          edge,
    ];
  }

  /// Longest path from the sources: a node sits one column right of its
  /// furthest-left feeder, so nothing is ever drawn upstream of its own input.
  Map<String, int> _assignLayers(List<PipelineEdge> forward) {
    final layer = {for (final n in pipeline.nodes) n.id: 0};
    for (var pass = 0; pass < pipeline.nodes.length; pass++) {
      var changed = false;
      for (final edge in forward) {
        final from = layer[edge.fromNodeId];
        final to = layer[edge.toNodeId];
        if (from == null || to == null) continue;
        if (to < from + 1) {
          layer[edge.toNodeId] = from + 1;
          changed = true;
        }
      }
      if (!changed) break;
    }
    return layer;
  }

  /// Barycentre ordering: put each node opposite the average position of what
  /// it connects to, sweeping until it settles. Cheap, and good enough that the
  /// remaining crossings are ones a human would also draw.
  List<List<String>> _orderWithinColumns(
    Map<String, int> layer,
    List<PipelineEdge> forward,
  ) {
    final depth = layer.values.fold<int>(0, math.max);
    final columns = <List<String>>[for (var i = 0; i <= depth; i++) []];
    for (final node in pipeline.nodes) {
      columns[layer[node.id]!].add(node.id);
    }

    final incoming = <String, List<String>>{};
    final outgoing = <String, List<String>>{};
    for (final edge in forward) {
      incoming.putIfAbsent(edge.toNodeId, () => []).add(edge.fromNodeId);
      outgoing.putIfAbsent(edge.fromNodeId, () => []).add(edge.toNodeId);
    }

    double? barycentre(String nodeId, List<String> neighbours, List<String> row) {
      final positions = [
        for (final other in neighbours)
          if (row.contains(other)) row.indexOf(other).toDouble(),
      ];
      if (positions.isEmpty) return null;
      return positions.reduce((a, b) => a + b) / positions.length;
    }

    void sortBy(List<String> column, Map<String, double?> keys) {
      final original = [...column];
      column.sort((a, b) {
        final ka = keys[a];
        final kb = keys[b];
        // A node with nothing to line up against keeps where it was.
        if (ka == null && kb == null) {
          return original.indexOf(a).compareTo(original.indexOf(b));
        }
        if (ka == null) return 1;
        if (kb == null) return -1;
        return ka.compareTo(kb);
      });
    }

    for (var sweep = 0; sweep < 4; sweep++) {
      for (var i = 1; i < columns.length; i++) {
        sortBy(columns[i], {
          for (final id in columns[i])
            id: barycentre(id, incoming[id] ?? const [], columns[i - 1]),
        });
      }
      for (var i = columns.length - 2; i >= 0; i--) {
        sortBy(columns[i], {
          for (final id in columns[i])
            id: barycentre(id, outgoing[id] ?? const [], columns[i + 1]),
        });
      }
    }
    return columns;
  }

  Map<String, Offset> _placeColumns(List<List<String>> columns) {
    final positions = <String, Offset>{};
    var x = 0.0;

    for (final column in columns) {
      var height = 0.0;
      for (final id in column) {
        height += _sizeOf(id).height + rowGap;
      }
      height -= column.isEmpty ? 0 : rowGap;

      var y = -height / 2;
      var widest = 0.0;
      for (final id in column) {
        final size = _sizeOf(id);
        positions[id] = Offset(NodeLayout.snap(x), NodeLayout.snap(y));
        y += size.height + rowGap;
        widest = math.max(widest, size.width);
      }
      x += widest + columnGap;
    }
    return positions;
  }

  Size _sizeOf(String nodeId) {
    final node = pipeline.nodeOrThrow(nodeId);
    return NodeLayout.sizeOf(database.processOrThrow(node.specId));
  }
}
