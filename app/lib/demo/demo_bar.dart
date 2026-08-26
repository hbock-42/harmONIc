import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';
import 'demo_player.dart';

/// What a demo says while it plays, and how to take it at your own pace.
///
/// Along the top of the canvas rather than over it: the whole point is to
/// watch the build being made, and a panel in the middle of the screen would
/// cover the thing being demonstrated.
class DemoBar extends StatelessWidget {
  const DemoBar({required this.player, super.key});

  final DemoPlayer player;

  @override
  Widget build(BuildContext context) {
    final run = player.run;
    if (run == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: OniSpacing.lg, vertical: OniSpacing.md),
      decoration: BoxDecoration(
        color: OniColors.surfaceRaised,
        border: Border(bottom: BorderSide(color: OniColors.accent)),
      ),
      child: Row(
        children: [
          Text(
            '${run.played.clamp(1, run.demo.steps.length)}'
            '/${run.demo.steps.length}',
            style: OniType.numberSmall
                .copyWith(fontSize: 11, color: OniColors.textFaint),
          ),
          const SizedBox(width: OniSpacing.md),
          Expanded(
            child: Text(
              run.says,
              style: OniType.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: OniSpacing.md),
          if (!run.isDone) ...[
            OniButton(
              label: player.isPlaying ? 'Pause' : 'Play',
              compact: true,
              onPressed: player.isPlaying ? player.pause : player.play,
            ),
            const SizedBox(width: OniSpacing.xs),
            OniButton(
              // Named for what it does rather than drawn as an arrow, and
              // available while it plays: somebody who reads faster than the
              // clock should not have to wait for it.
              label: 'Next',
              compact: true,
              onPressed: player.step,
            ),
            const SizedBox(width: OniSpacing.xs),
          ],
          OniButton(
            // Says what it costs, because it throws the demo's build away and
            // that should not be a surprise.
            label: run.isDone ? 'Done' : 'Leave',
            compact: true,
            tone: run.isDone ? OniButtonTone.accent : OniButtonTone.neutral,
            onPressed: player.leave,
          ),
        ],
      ),
    );
  }
}
