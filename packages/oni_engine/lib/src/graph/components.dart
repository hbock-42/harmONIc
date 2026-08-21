import 'pipeline.dart';

/// The nodes reachable from [nodeId] by following wires in either direction.
///
/// Two builds drawn on one canvas are two of these. The distinction matters
/// because a scale set on one says nothing about the other: they share a page,
/// not a supply.
Set<String> componentOf(Pipeline pipeline, String nodeId) {
  final neighbours = _adjacency(pipeline);
  final seen = <String>{};
  final queue = <String>[nodeId];
  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    if (!seen.add(current)) continue;
    queue.addAll(neighbours[current] ?? const <String>{});
  }
  return seen;
}

/// Every separate build on the canvas, largest first.
List<Set<String>> connectedComponents(Pipeline pipeline) {
  final neighbours = _adjacency(pipeline);
  final seen = <String>{};
  final components = <Set<String>>[];

  for (final node in pipeline.nodes) {
    if (seen.contains(node.id)) continue;
    final component = <String>{};
    final queue = <String>[node.id];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (!component.add(current)) continue;
      seen.add(current);
      queue.addAll(neighbours[current] ?? const <String>{});
    }
    components.add(component);
  }

  components.sort((a, b) => b.length.compareTo(a.length));
  return components;
}

Map<String, Set<String>> _adjacency(Pipeline pipeline) {
  final neighbours = <String, Set<String>>{
    for (final node in pipeline.nodes) node.id: <String>{},
  };
  for (final edge in pipeline.edges) {
    neighbours[edge.fromNodeId]?.add(edge.toNodeId);
    neighbours[edge.toNodeId]?.add(edge.fromNodeId);
  }
  return neighbours;
}
