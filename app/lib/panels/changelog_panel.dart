import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'guide_panel.dart';

/// What has changed, newest first.
///
/// The guide's panel over `docs/CHANGELOG.md` instead of `docs/USING.md`. The
/// list *is* the history, so "what changed" and "what has ever changed" are one
/// panel rather than two.
class ChangelogPanel extends StatelessWidget {
  const ChangelogPanel({required this.onClose, this.load, super.key});

  final VoidCallback onClose;
  final Future<String> Function()? load;

  @override
  Widget build(BuildContext context) => GuidePanel(
        onClose: onClose,
        load: load ?? loadChangelog,
        title: "What's new",
        backLabel: '← All changes',
        source: 'docs/CHANGELOG.md',
      );
}

/// Reading an asset is real I/O, which a widget test does not run — so tests
/// hand the text over instead, and a separate test proves the shipped asset is
/// the file in `docs/`.
Future<String> loadChangelog() => rootBundle.loadString('assets/changelog.md');
