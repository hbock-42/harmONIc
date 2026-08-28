@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/storage/file_store.dart';

/// Saving must never be the thing that takes the app down.
///
/// The browser store says as much in a comment and swallows what goes wrong.
/// The file store swallowed it on the way in and not on the way out, and one
/// of its callers does not even wait for it — an unawaited future that throws
/// is an unhandled error, from a save nobody asked for.
void main() {
  test('a save that cannot reach the disk is lost, not fatal', () {
    // No path_provider plugin under a plain test, so looking the directory up
    // throws. That is the same shape as a read-only volume, a full disk, or a
    // sandboxed app refused its own support directory.
    const store = FileJsonStore('probe.json');
    expect(store.write({'a': 1}), completes);
  });

  test('and reading one back finds nothing rather than throwing', () {
    const store = FileJsonStore('probe.json');
    expect(store.read(), completion(isNull));
  });
}
