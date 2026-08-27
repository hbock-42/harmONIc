import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/build_stamp.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../state/pipeline_controller.dart';

/// Where a report goes.
const String kRepository = 'https://github.com/hbock-42/harmONIc';

/// How much of a share code a URL will carry.
///
/// Measured against GitHub rather than guessed, because the first guess —
/// 1500 — was under the size of every build the app ships with, so the link
/// never carried one and the feature's whole point never happened. Asking
/// github.com directly: a query of 6500 characters is served, 7000 comes back
/// 500, and 12000 comes back 414. So 6000 for the whole URL, which is about
/// twenty nodes.
///
/// Past it the code goes to the clipboard and the form asks for a paste, which
/// is worse by one step and never wrong — a link that silently truncates would
/// send a share code decoding to nothing.
const int kUrlBudget = 6000;

/// The link that opens a pre-filled report.
///
/// The fields are the issue form's own ids, which is how GitHub fills a form
/// in from a URL. [shareCode] is left out when it would not fit; the caller
/// finds that out by asking [shareCodeFits] first, because it also has to put
/// the code somewhere.
Uri reportUri({
  required String template,
  required String version,
  required String platform,
  String? shareCode,
}) =>
    Uri.parse('$kRepository/issues/new').replace(queryParameters: {
      'template': template,
      'version': version,
      'platform': platform,
      'build': ?shareCode,
    });

/// Whether this code can travel in the link rather than on the clipboard.
bool shareCodeFits(String shareCode) =>
    reportUri(
      template: 'bug.yml',
      version: buildStamp,
      platform: describePlatform(),
      shareCode: shareCode,
    ).toString().length <=
    kUrlBudget;

/// "Chrome on Windows" is what the form asks for; this is the honest version
/// of it that the app can actually know.
String describePlatform() {
  final os = switch (defaultTargetPlatform) {
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
  return kIsWeb ? '$os, in a browser' : os;
}

/// The foot of the guide: how to say that something is wrong.
///
/// Here rather than in the toolbar because this is where somebody already is
/// when the app has confused them, and because the toolbar has been out of
/// room since before any of this.
class ReportFooter extends StatefulWidget {
  const ReportFooter({
    required this.controller,
    this.open,
    this.onWatch,
    this.onWhatsNew,
    super.key,
  });

  final PipelineController controller;

  /// Play a demo, and close the guide on the way. Null when the app was built
  /// without a player.
  final VoidCallback? onWatch;

  /// Read what changed. Beside the build stamp, because "which build is this"
  /// and "what changed in it" are the same question asked twice — and because
  /// the notice that announces a release is dismissible and never comes back,
  /// so without this there would be no way in at all.
  final VoidCallback? onWhatsNew;

  /// How a link is opened. The browser, unless a test says otherwise — a
  /// widget test has no browser and no desktop to hand one to.
  final Future<bool> Function(Uri)? open;

  @override
  State<ReportFooter> createState() => _ReportFooterState();
}

class _ReportFooterState extends State<ReportFooter> {
  String? _said;

  Future<void> _report(String template) async {
    final code = PipelineShareCode.encode(widget.controller.pipeline);
    final fits = shareCodeFits(code);
    if (!fits) {
      // Too long to carry, so it goes where a paste can reach it. Said out
      // loud, because a clipboard that changed silently is a clipboard that
      // ate whatever was in it.
      await Clipboard.setData(ClipboardData(text: code));
    }
    final uri = reportUri(
      template: template,
      version: buildStamp,
      platform: describePlatform(),
      shareCode: fits ? code : null,
    );
    final opened = await (widget.open ?? _launch)(uri);
    if (!mounted) return;
    setState(() {
      _said = !opened
          ? 'The browser would not open. The form is at $kRepository/issues.'
          : fits
              ? 'Opened, with this build already in it.'
              : 'Opened. This build was too big for a link, so its share code '
                  'is on your clipboard — paste it into the form.';
    });
  }

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(OniSpacing.lg),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: OniColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onWatch case final VoidCallback watch) ...[
              // Above the reporting, because somebody in the guide is more
              // often lost than cross, and being shown beats being read to.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Would you rather be shown? It builds one in front of '
                      'you, in a tab of its own.',
                      style: OniType.body.copyWith(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: OniSpacing.md),
                  OniButton(
                    label: 'Watch a demo',
                    compact: true,
                    tone: OniButtonTone.accent,
                    onPressed: watch,
                  ),
                ],
              ),
              const SizedBox(height: OniSpacing.lg),
            ],
            Text(
              'Something wrong, or something missing? Say so — the report '
              'takes the build with it, which is most of the work of a fix.',
              style: OniType.body.copyWith(fontSize: 12),
            ),
            const SizedBox(height: OniSpacing.md),
            Row(
              children: [
                OniButton(
                  label: 'Report a bug',
                  compact: true,
                  onPressed: () => _report('bug.yml'),
                ),
                const SizedBox(width: OniSpacing.sm),
                OniButton(
                  label: 'Suggest something',
                  compact: true,
                  onPressed: () => _report('idea.yml'),
                ),
                const Spacer(),
                if (widget.onWhatsNew case final VoidCallback read) ...[
                  OniButton(
                    label: "What's new",
                    compact: true,
                    onPressed: read,
                  ),
                  const SizedBox(width: OniSpacing.sm),
                ],
                // The version, where a report can quote it and where somebody
                // can check they are looking at what everybody else is.
                Text(
                  'build $buildStamp',
                  style: OniType.numberSmall
                      .copyWith(fontSize: 11, color: OniColors.textFaint),
                ),
              ],
            ),
            if (_said case final String said) ...[
              const SizedBox(height: OniSpacing.sm),
              Text(
                said,
                style: OniType.body
                    .copyWith(fontSize: 11.5, color: OniColors.textFaint),
              ),
            ],
          ],
        ),
      );
}
