import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  final canvasKey = GlobalKey<GraphCanvasState>();

  Future<PipelineController> pumpCanvas(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(GraphCanvas(
      key: canvasKey,
      controller: controller,
      rateDisplay: RateDisplay.perSecond,
    )));
    return controller;
  }

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  group('the buttons', () {
    testWidgets('are on the canvas and say the current zoom', (tester) async {
      await pumpCanvas(tester);
      expect(find.text('100 %'), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
      expect(find.text('−'), findsOneWidget);
    });

    testWidgets('zoom in and out about the middle', (tester) async {
      await pumpCanvas(tester);
      await tester.tap(find.text('+'));
      await tester.pump();
      expect(canvasKey.currentState!.scale, closeTo(1.25, 1e-9));
      expect(find.text('125 %'), findsOneWidget);

      await tester.tap(find.text('−'));
      await tester.pump();
      expect(canvasKey.currentState!.scale, closeTo(1, 1e-9));
    });

    testWidgets('the percentage resets the view when clicked', (tester) async {
      await pumpCanvas(tester);
      canvasKey.currentState!.zoomAtCentre(2);
      await tester.pump();
      expect(canvasKey.currentState!.scale, closeTo(2, 1e-9));

      await tester.tap(find.text('200 %'));
      await tester.pump();
      expect(canvasKey.currentState!.scale, 1);
    });

    testWidgets('zooming out is bounded, so the canvas cannot be lost',
        (tester) async {
      await pumpCanvas(tester);
      for (var i = 0; i < 30; i++) {
        canvasKey.currentState!.zoomAtCentre(1 / 1.25);
      }
      await tester.pump();
      expect(canvasKey.currentState!.scale,
          greaterThanOrEqualTo(GraphCanvasState.minScale));
    });
  });

  group('a trackpad', () {
    testWidgets('pinching zooms', (tester) async {
      await pumpCanvas(tester);
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);

      await tester.sendEventToBinding(
          pointer.panZoomStart(const Offset(600, 400)));
      await tester.pump();
      await tester.sendEventToBinding(
          pointer.panZoomUpdate(const Offset(600, 400), scale: 1.5));
      await tester.pump();

      expect(canvasKey.currentState!.scale, closeTo(1.5, 1e-6),
          reason: 'a pinch used to do nothing at all');

      await tester.sendEventToBinding(pointer.panZoomEnd());
    });

    testWidgets('two-finger panning pans once, not twice', (tester) async {
      // The pan half of a trackpad gesture reaches the background's pan
      // recogniser as well as the pointer listener; handling it in both moved
      // the canvas twice as far as the fingers did.
      await pumpCanvas(tester);
      final before = canvasKey.currentState!.offset;
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);

      await tester.sendEventToBinding(
          pointer.panZoomStart(const Offset(600, 400)));
      await tester.sendEventToBinding(pointer.panZoomUpdate(
          const Offset(600, 400),
          pan: const Offset(-40, 20)));
      await tester.pump();

      expect(canvasKey.currentState!.offset, before + const Offset(-40, 20));
      expect(canvasKey.currentState!.scale, 1, reason: 'panning is not zooming');

      await tester.sendEventToBinding(pointer.panZoomEnd());
    });
  });

  group('the keyboard', () {
    testWidgets('⌘= zooms in and ⌘0 puts it back', (tester) async {
      await pumpEditor(tester);
      final state = tester.state<GraphCanvasState>(find.byType(GraphCanvas));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      expect(state.scale, greaterThan(1));

      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      expect(state.scale, 1);
    });
  });
}
