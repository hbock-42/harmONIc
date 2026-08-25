import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';

/// The guide, shown inside the app.
///
/// It renders `docs/USING.md` — the same file people read in the repository,
/// copied into the assets by `tool/copy_docs.sh` and checked for drift by CI —
/// rather than a second copy of the same words written for a screen. Two
/// explanations of one thing disagree within a fortnight.
class GuidePanel extends StatefulWidget {
  const GuidePanel({required this.onClose, this.load, this.footer, super.key});

  final VoidCallback onClose;

  /// What sits under the text — how to report a bug, and which build this is.
  ///
  /// Handed in rather than built here, because it needs the pipeline and this
  /// panel is a renderer for one Markdown file and nothing else.
  final Widget? footer;

  /// Where the text comes from. The asset, unless a test hands it over —
  /// reading an asset is real I/O and a widget test does not run any, so a
  /// test that used the bundle would sit for ever waiting on a future and
  /// report an empty guide.
  ///
  /// That the shipped asset really is `docs/USING.md` is checked separately,
  /// by a test that reads both files off the disk.
  final Future<String> Function()? load;

  @override
  State<GuidePanel> createState() => _GuidePanelState();
}

class _GuidePanelState extends State<GuidePanel> {
  String? _markdown;
  Object? _failed;

  @override
  void initState() {
    super.initState();
    // Failures are shown rather than swallowed: a guide that silently renders
    // nothing is worse than one that says it could not be found, because the
    // first looks like the guide is empty.
    (widget.load ?? _fromBundle)().then(
      (text) {
        if (mounted) setState(() => _markdown = text);
      },
      onError: (Object error) {
        if (mounted) setState(() => _failed = error);
      },
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        // Clicking away closes it, the way the pipelines menu and the recipe
        // form already do. A panel that can only be dismissed by finding its
        // one button is a panel people leave open.
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose,
        child: Container(
          color: const Color(0xCC000000),
        // Against the right edge rather than the middle: the canvas is what
        // somebody is reading this *about*, and covering the palette and the
        // build with a centred slab hides the thing being explained.
          alignment: Alignment.centerRight,
          // Swallowed, so that reading the thing does not shut it.
          child: GestureDetector(
            onTap: () {},
            child: OniPanel(
              title: 'How this works',
              width: 640,
              trailing: OniButton(
                label: 'Close',
                compact: true,
                onPressed: widget.onClose,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: _failed != null
                        ? Padding(
                            padding: const EdgeInsets.all(OniSpacing.lg),
                            child: Text(
                              'The guide did not load: $_failed\n\n'
                              'It also lives at docs/USING.md in the '
                              'repository.',
                              style: OniType.body
                                  .copyWith(color: OniColors.warning),
                            ),
                          )
                        : _markdown == null
                            ? const SizedBox.shrink()
                            : ListView(
                                padding: const EdgeInsets.all(OniSpacing.lg),
                                children: _render(_markdown!),
                              ),
                  ),
                  // Under the text even when the text failed to load: a guide
                  // that will not open is itself worth reporting.
                  ?widget.footer,
                ],
              ),
            ),
          ),
        ),
      );
}

Future<String> _fromBundle() => rootBundle.loadString('assets/using.md');

/// The small part of Markdown the guide actually uses.
///
/// Headings, paragraphs, bullets, bold and inline code. Not a Markdown
/// renderer — a renderer for this document, which is why it is thirty lines
/// instead of a dependency. If the guide ever grows a table this will show it
/// as a row of pipes, and that is the moment to reach for a package.
List<Widget> _render(String markdown) {
  final widgets = <Widget>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    widgets.add(Padding(
      padding: const EdgeInsets.only(bottom: OniSpacing.md),
      child: _rich(paragraph.join(' '), OniType.body.copyWith(height: 1.5)),
    ));
    paragraph.clear();
  }

  for (final line in markdown.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      flush();
    } else if (trimmed.startsWith('## ')) {
      flush();
      widgets
        ..add(const SizedBox(height: OniSpacing.md))
        ..add(Padding(
          padding: const EdgeInsets.only(bottom: OniSpacing.sm),
          child: Text(trimmed.substring(3), style: OniType.title),
        ));
    } else if (trimmed.startsWith('# ')) {
      flush();
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: OniSpacing.md),
        child: Text(trimmed.substring(2), style: OniType.heading),
      ));
    } else if (trimmed.startsWith('- ')) {
      flush();
      widgets.add(Padding(
        padding: const EdgeInsets.only(left: OniSpacing.sm, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('·  ', style: OniType.body.copyWith(height: 1.5)),
            Expanded(
              child: _rich(
                  trimmed.substring(2), OniType.body.copyWith(height: 1.5)),
            ),
          ],
        ),
      ));
    } else {
      paragraph.add(trimmed);
    }
  }
  flush();
  return widgets;
}

/// Bold between `**`, code between backticks, everything else as it is.
Widget _rich(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|`(.+?)`|\*(.+?)\*');
  var at = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > at) {
      spans.add(TextSpan(text: text.substring(at, match.start)));
    }
    if (match.group(1) != null) {
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ));
    } else if (match.group(2) != null) {
      spans.add(TextSpan(
        text: match.group(2),
        style: OniType.numberSmall.copyWith(color: OniColors.accent),
      ));
    } else {
      spans.add(TextSpan(
        text: match.group(3),
        style: const TextStyle(fontStyle: FontStyle.italic),
      ));
    }
    at = match.end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));

  return Text.rich(TextSpan(children: spans, style: base));
}
