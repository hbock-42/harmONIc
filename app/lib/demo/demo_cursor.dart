import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import 'widget_hands.dart';

/// The pointer a demo moves about the screen.
///
/// Without it a demo is a build assembling itself, which is what it looked
/// like: things appeared and wired themselves up and nothing said where the
/// click was. A ring that arrives somewhere, presses, and then something
/// happens is the whole of the difference between watching somebody use an
/// app and watching an app use itself.
class DemoCursor extends StatelessWidget {
  const DemoCursor({required this.hands, super.key});

  final WidgetHands hands;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: hands,
        builder: (context, _) {
          final at = hands.cursor;
          if (at == null) return const SizedBox.shrink();
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return const SizedBox.shrink();
          final local = box.globalToLocal(at);
          final size = hands.pressed ? 34.0 : 22.0;

          return Stack(
            children: [
              // Travel is animated rather than teleported: the eye follows a
              // thing that moves and does not follow a thing that appears.
              AnimatedPositioned(
                duration: kCursorTravel,
                curve: Curves.easeInOutCubic,
                left: local.dx - size / 2,
                top: local.dy - size / 2,
                width: size,
                height: size,
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: OniColors.accent
                          .withValues(alpha: hands.pressed ? 0.35 : 0.18),
                      border: Border.all(
                        color: OniColors.accent,
                        width: hands.pressed ? 3 : 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}
