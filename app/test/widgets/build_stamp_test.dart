import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/design/build_stamp.dart';

/// Which build of the app this is.
void main() {
  test('an unstamped build says so rather than inventing a version', () {
    // Under `flutter test` nobody passes --dart-define, so this is the
    // unstamped case; a version number invented to look official would be
    // worse than the truth.
    const stamped = bool.hasEnvironment('BUILD_COMMIT');
    expect(buildStamp == 'dev', !stamped);
  });

  test('and a stamped one is short enough to read out', () {
    // Seven characters is what git shows and what somebody can read off the
    // screen into a bug report.
    expect(buildStamp.length, lessThanOrEqualTo(7));
    expect(buildStamp, isNotEmpty);
  });
}
