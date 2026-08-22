import '../model/build_material.dart';
import '../model/game_database.dart';
import '../model/item.dart';
import '../model/process_spec.dart';
import '../model/units.dart';
import 'solution.dart';

/// A plain-text summary of a solved pipeline.
///
/// The engine ships this so the whole thing is usable — and reviewable — before
/// a single widget exists. The app's summary panel shows the same numbers.
String formatSolution(
  PipelineSolution solution,
  GameDatabase database, {
  bool perCycle = false,
}) {
  final out = StringBuffer();
  final display = perCycle ? RateDisplay.perCycle : RateDisplay.perSecond;

  // The same formatter the app uses, so a pasted summary reads exactly like
  // the screen it was copied from. Its own version printed "Egg: 0.00",
  // because an egg every four cycles is a very small number per second.
  String rate(String itemId, double value) {
    final item = database.item(itemId);
    if (item == null) return value.toStringAsFixed(2);
    return item.formatRate(value, display);
  }

  out.writeln('Status: ${solution.status.name}');
  if (solution.issues.isNotEmpty) {
    out.writeln('Issues:');
    for (final issue in solution.issues) {
      out.writeln('  ${issue.severity.name}: ${issue.message}');
    }
  }
  if (!solution.isUsable) return out.toString();

  out.writeln('\nBuildings');
  final sorted = solution.nodes.values.toList()
    ..sort((a, b) => a.nodeId.compareTo(b.nodeId));
  for (final node in sorted) {
    final spec = database.process(node.specId);
    if (spec != null &&
        (spec.kind == ProcessKind.source || spec.kind == ProcessKind.sink)) {
      continue;
    }
    final name = spec?.name ?? node.specId;
    final whole = node.wholeCount;
    final util = (node.utilisation * 100).toStringAsFixed(0);
    out.writeln('  ${node.count.toStringAsFixed(2).padLeft(8)} × $name '
        '  → build $whole ($util % busy)');
  }

  out.writeln('\nInputs needed');
  final inputs = _flowsByItem(solution, database, ProcessKind.source).entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (inputs.isEmpty) out.writeln('  (none)');
  for (final e in inputs) {
    if (e.key == WellKnownItems.power) continue;
    out.writeln('  ${database.item(e.key)?.name ?? e.key}: '
        '${rate(e.key, e.value)}');
  }

  out.writeln('\nOutputs');
  final outputs = _flowsByItem(solution, database, ProcessKind.sink).entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (outputs.isEmpty) out.writeln('  (none)');
  for (final e in outputs) {
    if (e.key == WellKnownItems.heat || e.key == WellKnownItems.power) continue;
    out.writeln('  ${database.item(e.key)?.name ?? e.key}: '
        '${rate(e.key, e.value)}');
  }

  out.writeln('\nPower');
  out.writeln('  consumed:  ${Unit.watts.format(solution.powerConsumedWatts + 0.0)}');
  out.writeln('  generated: ${Unit.watts.format(solution.powerGeneratedWatts + 0.0)}');
  out.writeln('  net:       ${Unit.watts.format(solution.netPowerWatts)}');
  out.writeln('Heat: ${Unit.kdtuPerSecond.format(solution.totalHeatKdtu)}');
  final labour = solution.dupeLabourSecondsPerCycle;
  if (labour > 0) {
    out.writeln('Dupe labour: ${labour.toStringAsFixed(0)} s/cycle');
  }

  final materials = solution.constructionMaterials(database);
  if (materials.isNotEmpty || solution.totalFootprintTiles > 0) {
    out.writeln('\nTo build');
    final sorted = materials.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sorted) {
      final material = database.item(entry.key);
      out.writeln('  ${material?.name ?? entry.key}: '
          '${formatMaterial(material, entry.value)}');
    }
    if (solution.totalFootprintTiles > 0) {
      out.writeln('  Floor: ${solution.totalFootprintTiles} tiles');
    }
  }

  if (solution.shortages.isNotEmpty) {
    out.writeln('\nShortages');
    for (final s in solution.shortages) {
      out.writeln('  ${s.ref}: short ${rate(s.itemId, s.shortage)}');
    }
  }
  return out.toString();
}

/// Raw inputs are two things at once: ports nobody feeds, *and* the explicit
/// supply nodes the user drew. Same for outputs and sink nodes. Merging them
/// is what makes the summary read like a shopping list.
Map<String, double> _flowsByItem(
  PipelineSolution solution,
  GameDatabase database,
  ProcessKind kind,
) {
  final totals = <String, double>{
    ...(kind == ProcessKind.source
        ? solution.externalInputs
        : solution.externalOutputs),
  };
  for (final node in solution.nodes.values) {
    final spec = database.process(node.specId);
    if (spec == null || spec.kind != kind) continue;
    for (final port in spec.ports) {
      final wanted = kind == ProcessKind.source ? port.isOutput : port.isInput;
      if (!wanted) continue;
      totals[port.itemId] =
          (totals[port.itemId] ?? 0) + port.ratePerSecond * node.count;
    }
  }
  totals.removeWhere((_, v) => v.abs() <= 1e-9);
  return totals;
}
