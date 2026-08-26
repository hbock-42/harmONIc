/// Which build of the app this is.
///
/// "Which version are you on?" is otherwise the first question on every bug
/// report, and the honest answer from a web app nobody installs is "whatever
/// was on the site that day". CI passes the commit in at build time; a build
/// from a laptop says so instead of pretending.
library;

const String _commit = String.fromEnvironment('BUILD_COMMIT');

/// Seven characters of the commit, or `dev` when nobody said.
String get buildStamp =>
    _commit.isEmpty ? 'dev' : _commit.substring(0, _commit.length.clamp(0, 7));
