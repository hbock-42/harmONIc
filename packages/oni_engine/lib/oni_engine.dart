/// Pure-Dart engine for planning Oxygen Not Included production pipelines.
///
/// Build a [Pipeline] of [ProcessSpec] nodes, pin one of them ("I have three
/// Electrolyzers", "I have 10 kg/s of water", "I want 1 kg/s of oxygen") and
/// [PipelineSolver] scales every other node to match.
library;

export 'src/data/default_database.dart';
export 'src/graph/builder.dart';
export 'src/graph/pin.dart';
export 'src/graph/pipeline.dart';
export 'src/graph/share_code.dart';
export 'src/graph/validation.dart';
export 'src/model/conduits.dart';
export 'src/model/game_database.dart';
export 'src/model/item.dart';
export 'src/model/port.dart';
export 'src/model/process_spec.dart';
export 'src/model/units.dart';
export 'src/solver/linear_algebra.dart';
export 'src/solver/report.dart';
export 'src/solver/shares.dart';
export 'src/solver/solution.dart';
export 'src/solver/solver.dart';
