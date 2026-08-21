import '../graph/pipeline.dart';

/// Resolves every edge's effective share of its source port.
///
/// Explicit shares are honoured; the remaining fraction of the port is split
/// equally between the edges that did not specify one. Whatever is left over
/// becomes surplus at that port.
Map<String, double> resolveShares(Pipeline pipeline) {
  final byPort = <PortRef, List<PipelineEdge>>{};
  for (final edge in pipeline.edges) {
    byPort
        .putIfAbsent(PortRef(edge.fromNodeId, edge.fromPortId), () => [])
        .add(edge);
  }

  final result = <String, double>{};
  byPort.forEach((_, edges) {
    var explicitTotal = 0.0;
    var autoCount = 0;
    for (final edge in edges) {
      if (edge.share != null) {
        explicitTotal += edge.share!;
      } else {
        autoCount++;
      }
    }
    final remaining = (1 - explicitTotal).clamp(0.0, 1.0);
    final autoShare = autoCount == 0 ? 0.0 : remaining / autoCount;
    for (final edge in edges) {
      result[edge.id] = edge.share ?? autoShare;
    }
  });
  return result;
}
