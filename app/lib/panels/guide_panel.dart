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
  const GuidePanel({
    required this.onClose,
    this.load,
    this.footer,
    this.title = 'How this works',
    this.backLabel = '← All topics',
    this.source = 'docs/USING.md',
    this.newerThan,
    super.key,
  });

  final VoidCallback onClose;

  /// What the panel is called, and what the button back to the list says.
  ///
  /// The changelog is the same panel over a different Markdown file: a list of
  /// sections, each of which opens. Making it a second widget would have been
  /// two renderers for one job, and they disagree within a fortnight — which
  /// is the reason this panel renders `docs/USING.md` rather than a second
  /// copy of it in the first place.
  final String title;
  final String backLabel;

  /// Where the file lives in the repository, for when it will not load.
  final String source;

  /// Show only the sections above this heading, with a way to see the rest.
  ///
  /// What somebody wants after a release is the release, not the file. If one
  /// thing changed they should see one thing, and counting how much is new is
  /// most of what a changelog is for — a list of everything that ever happened
  /// answers a different question, and answers it every time.
  ///
  /// Null shows the lot, which is what the guide always wants.
  final String? newerThan;

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

  /// The topic being read, or null for the list of them.
  ///
  /// It arrived as one scroll of three hundred lines, which is a document
  /// rather than something you look an answer up in.
  GuideTopic? _open;

  /// Cleared by "Show everything", so the cut is a starting point rather than
  /// a wall.
  late String? _newerThan = widget.newerThan;

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
              title: _open?.title ?? widget.title,
              width: 640,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_open != null) ...[
                    OniButton(
                      label: widget.backLabel,
                      compact: true,
                      onPressed: () => setState(() => _open = null),
                    ),
                    const SizedBox(width: OniSpacing.xs),
                  ],
                  OniButton(
                    label: 'Close',
                    compact: true,
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: _failed != null
                        ? Padding(
                            padding: const EdgeInsets.all(OniSpacing.lg),
                            child: Text(
                              'The guide did not load: $_failed\n\n'
                              'It also lives at ${widget.source} in the '
                              'repository.',
                              style: OniType.body
                                  .copyWith(color: OniColors.warning),
                            ),
                          )
                        : _markdown == null
                            ? const SizedBox.shrink()
                            : _body(splitGuide(_markdown!)),
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

  /// Either the list of topics, or the one being read.
  Widget _body(({String intro, List<GuideTopic> topics}) guide) {
    if (_open case final GuideTopic topic) {
      return ListView(
        key: const PageStorageKey('guide-topic'),
        padding: const EdgeInsets.all(OniSpacing.lg),
        children: _render(topic.body),
      );
    }
    final cut = _newerThan;
    final at = cut == null
        ? -1
        : guide.topics.indexWhere((topic) => topic.title == cut);
    // Not found means the entry somebody last read has since been renamed or
    // removed, and a wrong cut is worse than none: show everything.
    final showing = at > 0 ? guide.topics.sublist(0, at) : guide.topics;
    final trimmed = showing.length != guide.topics.length;

    return ListView(
      padding: const EdgeInsets.all(OniSpacing.lg),
      children: [
        if (trimmed)
          Padding(
            padding: const EdgeInsets.only(bottom: OniSpacing.md),
            child: Text(
              showing.length == 1
                  ? 'One change since you were last here.'
                  : '${showing.length} changes since you were last here.',
              style: OniType.body.copyWith(color: OniColors.textFaint),
            ),
          )
        else
          ..._render(guide.intro),
        const SizedBox(height: OniSpacing.sm),
        for (final topic in showing)
          _TopicRow(topic: topic, onOpen: () => setState(() => _open = topic)),
        if (trimmed) ...[
          const SizedBox(height: OniSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OniButton(
              label: 'Show everything',
              compact: true,
              onPressed: () => setState(() => _newerThan = null),
            ),
          ),
        ],
      ],
    );
  }
}

/// One line of the list: what the topic is called, and what it is about.
class _TopicRow extends StatefulWidget {
  const _TopicRow({required this.topic, required this.onOpen});

  final GuideTopic topic;
  final VoidCallback onOpen;

  @override
  State<_TopicRow> createState() => _TopicRowState();
}

class _TopicRowState extends State<_TopicRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onOpen,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: OniSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: OniSpacing.md, vertical: OniSpacing.sm),
            decoration: BoxDecoration(
              color: _hover ? OniColors.surfaceHover : null,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _hover ? OniColors.borderStrong : OniColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.topic.title, style: OniType.heading),
                if (widget.topic.hint.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.topic.hint,
                    style: OniType.body
                        .copyWith(fontSize: 12, color: OniColors.textFaint),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

Future<String> _fromBundle() => rootBundle.loadString('assets/using.md');

/// The newest entry's heading, which is what "the version somebody has seen"
/// means.
///
/// Not the build. A deploy that fixed a typo has nothing to tell anybody, and
/// interrupting them to say so is how a notice becomes something people learn
/// to dismiss without reading. No entry, no news.
String? latestRelease(String changelog) {
  final entries = releaseTitles(changelog);
  return entries.isEmpty ? null : entries.first;
}

/// Every entry's heading, newest first.
List<String> releaseTitles(String changelog) =>
    [for (final entry in splitGuide(changelog).topics) entry.title];

/// One section of the guide: a heading, and everything under it.
class GuideTopic {
  const GuideTopic({required this.title, required this.body, required this.hint});

  final String title;
  final String body;

  /// The first sentence, for the list. What a topic is about, in the words it
  /// already uses, so nothing is written twice and nothing can drift.
  final String hint;
}

/// The guide, cut into topics at its own headings.
///
/// Derived rather than written down. `docs/USING.md` is the one copy — CI
/// checks the shipped asset is byte-for-byte the same file — so a topic list
/// maintained by hand would be a second copy waiting to disagree with it.
({String intro, List<GuideTopic> topics}) splitGuide(String markdown) {
  final intro = StringBuffer();
  final topics = <GuideTopic>[];
  String? title;
  final body = StringBuffer();

  void close() {
    final heading = title;
    if (heading == null) return;
    final text = body.toString().trim();
    final firstLine = text
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty && !line.startsWith('- '),
            orElse: () => '');
    final stop = firstLine.indexOf('. ');
    topics.add(GuideTopic(
      title: heading,
      body: text,
      hint: (stop == -1 ? firstLine : firstLine.substring(0, stop + 1))
          .replaceAll('**', '')
          .replaceAll('*', '')
          .replaceAll('`', ''),
    ));
    body.clear();
  }

  for (final line in markdown.split('\n')) {
    if (line.startsWith('## ')) {
      close();
      title = line.substring(3).trim();
    } else if (title == null) {
      if (!line.startsWith('# ')) intro.writeln(line);
    } else {
      body.writeln(line);
    }
  }
  close();
  return (intro: intro.toString().trim(), topics: topics);
}

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
