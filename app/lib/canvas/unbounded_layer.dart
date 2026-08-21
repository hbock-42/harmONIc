import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays its child out with no size limit, and hit-tests it beyond its own bounds.
///
/// An infinite canvas needs both halves of that. Flutter will happily *paint*
/// outside a box when told to, but it never hit-tests outside one: the default
/// `hitTest` refuses any position its own size does not contain, before the
/// child is ever asked. A node dragged past the edge of the window is therefore
/// visible and completely dead to the mouse — along with everything inside it.
///
/// `OverflowBox` solves the layout half and not the hit-testing half, which is
/// why this exists rather than that.
class UnboundedLayer extends SingleChildRenderObjectWidget {
  const UnboundedLayer({required Widget super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderUnboundedLayer();
}

class RenderUnboundedLayer extends RenderProxyBox {
  RenderUnboundedLayer({RenderBox? child}) : super(child);

  @override
  void performLayout() {
    // The child decides its own size; this box just fills what it was given.
    child?.layout(const BoxConstraints(), parentUsesSize: true);
    size = constraints.biggest;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
