import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/design/build_stamp.dart';

/// Which build of the app this is.
void main() {
  test('an unstamped build says so rather than inventing a version', () {
    // Written as the relationship rather than as "dev", because the suite
    // itself can be run with the define set — and a test that fails when you
    // pass the flag it is testing would be a poor sort of test.
    expect(buildStamp == 'dev', !isPublishedBuild);
  });

  test('and a stamped one is short enough to read out', () {
    // Seven characters is what git shows and what somebody can read off the
    // screen into a bug report.
    expect(buildStamp.length, lessThanOrEqualTo(7));
    expect(buildStamp, isNotEmpty);
  });
}
