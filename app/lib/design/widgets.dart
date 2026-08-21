import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Thin wrappers over the chrome. Everything the rest of the app draws goes
/// through here, so swapping the underlying library is a one-folder change.

class OniPanel extends StatelessWidget {
  const OniPanel({
    required this.child,
    this.title,
    this.trailing,
    this.width,
    super.key,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        decoration: const BoxDecoration(
          color: OniColors.surface,
          border: Border(
            left: BorderSide(color: OniColors.border),
            right: BorderSide(color: OniColors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: OniSpacing.md),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: OniColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title!.toUpperCase(), style: OniType.label),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            Expanded(child: child),
          ],
        ),
      );
}

class OniButton extends StatefulWidget {
  const OniButton({
    required this.label,
    required this.onPressed,
    this.tone = OniButtonTone.neutral,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final OniButtonTone tone;
  final bool compact;

  @override
  State<OniButton> createState() => _OniButtonState();
}

enum OniButtonTone { neutral, accent, danger }

class _OniButtonState extends State<OniButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final base = switch (widget.tone) {
      OniButtonTone.neutral => OniColors.textMuted,
      OniButtonTone.accent => OniColors.accent,
      OniButtonTone.danger => OniColors.danger,
    };
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : 12,
            vertical: widget.compact ? 4 : 7,
          ),
          decoration: BoxDecoration(
            color: _hover && enabled
                ? base.withValues(alpha: 0.16)
                : OniColors.surfaceRaised,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: enabled ? base.withValues(alpha: 0.5) : OniColors.border,
            ),
          ),
          child: Text(
            widget.label,
            style: OniType.body.copyWith(
              fontSize: widget.compact ? 11 : 12,
              color: enabled ? base : OniColors.textFaint,
            ),
          ),
        ),
      ),
    );
  }
}

/// A bare numeric/text input. Built on [EditableText] so it carries no design
/// system's opinions but still has a cursor, selection and focus.
class OniField extends StatefulWidget {
  const OniField({
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hint,
    this.autofocus = false,
    this.focusNode,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final TextEditingController controller;

  /// Supply one to put the cursor here from elsewhere. Without it the field
  /// owns its own, which is all most callers need.
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hint;
  final bool autofocus;
  final TextAlign textAlign;

  @override
  State<OniField> createState() => _OniFieldState();
}

class _OniFieldState extends State<OniField> {
  FocusNode? _owned;
  late FocusNode _focus = _resolveFocus();

  FocusNode _resolveFocus() {
    final node = widget.focusNode ?? (_owned = FocusNode());
    return node..addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void didUpdateWidget(OniField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focus.removeListener(_onFocus);
      _owned?.dispose();
      _owned = null;
      _focus = _resolveFocus();
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _focus.requestFocus,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: OniColors.background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _focus.hasFocus ? OniColors.accent : OniColors.border,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (widget.controller.text.isEmpty && widget.hint != null)
                Text(widget.hint!,
                    style: OniType.number
                        .copyWith(color: OniColors.textFaint)),
              EditableText(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                style: OniType.number,
                cursorColor: OniColors.accent,
                backgroundCursorColor: OniColors.border,
                selectionColor: OniColors.accent.withValues(alpha: 0.3),
                textAlign: widget.textAlign,
                maxLines: 1,
                onChanged: (v) {
                  setState(() {});
                  widget.onChanged?.call(v);
                },
                onSubmitted: widget.onSubmitted,
              ),
            ],
          ),
        ),
      );
}

/// A rate, which switches every rate in the app between per second and per
/// cycle when clicked. Both readings are right; which is useful depends on
/// whether you are sizing a pipe or reading the wiki.
class OniRate extends StatefulWidget {
  const OniRate({
    required this.text,
    required this.onToggle,
    this.style,
    super.key,
  });

  final String text;
  final VoidCallback onToggle;
  final TextStyle? style;

  @override
  State<OniRate> createState() => _OniRateState();
}

class _OniRateState extends State<OniRate> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onToggle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _hover ? OniColors.accent : const Color(0x00000000),
                ),
              ),
            ),
            child: Text(
              widget.text,
              style: (widget.style ?? OniType.number).copyWith(
                color: _hover ? OniColors.accent : null,
              ),
            ),
          ),
        ),
      );
}

/// Label above a value — the workhorse of the inspector.
class OniStat extends StatelessWidget {
  const OniStat({
    required this.label,
    required this.value,
    this.valueColour,
    this.onToggle,
    super.key,
  });

  final String label;
  final String value;
  final Color? valueColour;

  /// When given, the value is a rate and clicking it switches the units.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: OniType.label),
          const SizedBox(height: 2),
          if (onToggle == null)
            Text(value, style: OniType.number.copyWith(color: valueColour))
          else
            OniRate(
              text: value,
              onToggle: onToggle!,
              style: OniType.number.copyWith(color: valueColour),
            ),
        ],
      );
}
