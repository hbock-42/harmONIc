import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';
import 'demo.dart';
import 'demo_player.dart';
import 'widget_hands.dart';

/// What a demo is about to do, said beside the thing it is about to do it to.
///
/// It was a bar along the top, which meant reading a line at one end of the
/// screen and then hunting for the thing it described at the other. This
/// follows the cursor: the words, and the button that advances them, sit next
/// to where you should be looking.
class DemoCallout extends StatelessWidget {
  const DemoCallout({required this.player, required this.hands, super.key});

  final DemoPlayer player;
  final WidgetHands hands;

  static const double width = 340;
  static const double _gap = 44;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([player, hands]),
        builder: (context, _) {
          final run = player.run;
          if (run == null) return const SizedBox.shrink();
          final says = run.nextSays ?? run.says;
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return const SizedBox.shrink();

          // Beside the thing when there is a thing; over the middle of the
          // canvas when the step is only talking about what is already there.
          final aim = hands.aim;
          final target =
              aim == null ? null : box.globalToLocal(aim);
          final left = target == null
              ? (box.size.width - width) / 2
              : (target.dx + _gap)
                  .clamp(8.0, box.size.width - width - 8)
                  .toDouble();
          final top = target == null
              ? box.size.height * 0.62
              : (target.dy - 40).clamp(8.0, box.size.height - 180).toDouble();

          // A Stack of its own, because this sits inside a Positioned.fill
          // and two Positioneds cannot both write to one render object.
          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: width,
                child: _Card(player: player, run: run, says: says),
              ),
            ],
          );
        },
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.player, required this.run, required this.says});

  final DemoPlayer player;
  final DemoRun run;
  final String says;

  @override
  Widget build(BuildContext context) {
    final done = run.isDone;
    return Container(
      padding: const EdgeInsets.all(OniSpacing.lg),
      decoration: BoxDecoration(
        color: OniColors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OniColors.accent),
        boxShadow: const [
          BoxShadow(color: Color(0xAA000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${run.played + (done ? 0 : 1)}/${run.demo.steps.length}',
            style: OniType.numberSmall
                .copyWith(fontSize: 11, color: OniColors.textFaint),
          ),
          const SizedBox(height: OniSpacing.sm),
          Text(says, style: OniType.body.copyWith(height: 1.45)),
          const SizedBox(height: OniSpacing.lg),
          Row(
            children: [
              if (!done)
                OniButton(
                  // Next is here rather than in a bar, because this is where
                  // you are already looking.
                  label: player.isStepping ? 'Wait…' : 'Next',
                  compact: true,
                  tone: OniButtonTone.accent,
                  onPressed: player.isStepping ? null : player.step,
                ),
              const Spacer(),
              OniButton(
                label: done ? 'Done' : 'Leave',
                compact: true,
                tone: done ? OniButtonTone.accent : OniButtonTone.neutral,
                onPressed: player.leave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
