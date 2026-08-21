import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  test('there are templates, and they are the builds people make', () {
    expect(pipelineTemplates.map((t) => t.id),
        containsAll(['spom', 'petroleum_boiler', 'coal_farm', 'cooling_loop']));
  });

  for (final template in pipelineTemplates) {
    group(template.name, () {
      test('solves, with everything wired and nothing contradictory', () {
        final pipeline = template.build(db);
        final solution = solver.solve(pipeline);

        // A template that opens underdetermined is a template that opens with
        // a warning on it, which is a poor first impression.
        expect(solution.status, SolveStatus.solved,
            reason: solution.issues.map((i) => i.message).join('; '));
        expect(
            solution.issues.where((i) => i.severity == IssueSeverity.error),
            isEmpty);
      });

      test('is one build rather than several loose pieces', () {
        final pipeline = template.build(db);
        expect(connectedComponents(pipeline), hasLength(1),
            reason: 'a template that arrives in two halves looks broken');
      });

      test('says what it is for', () {
        expect(template.summary, isNotEmpty);
        expect(template.name, isNotEmpty);
        // The summary is read while choosing between them, so it has to fit.
        expect(template.summary.length, lessThan(180));
      });
    });
  }
}
