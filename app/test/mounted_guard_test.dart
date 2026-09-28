@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against a class of bug that appeared in 22 places across the app.
///
/// The shape is always the same: an async handler awaits a network call, and
/// then calls `setState` in its `catch`. If the widget is disposed while the
/// request is in flight — the cashier closes the sheet, the manager navigates
/// away — the `setState` throws, turning a recoverable failure into a crash.
///
/// The success path usually has `if (!mounted) return;` and the catch path
/// usually does not, which is why this went unnoticed: the happy path was
/// tested by hand and the failure path was not.
///
/// A widget test cannot easily reach into every screen, so this file does two
/// things instead:
///
///   1. Proves the failure is real, on a minimal reproduction of the pattern.
///   2. Scans the source for the pattern, so a new occurrence fails the suite.
///
/// The second is the one that keeps working. It is a lint with a test's
/// authority, and it catches the 23rd case before it ships rather than after.

void main() {
  group('the failure is real', () {
    testWidgets('setState after dispose throws', (tester) async {
      // A widget that awaits, then writes state in a catch with no guard.
      late StateSetter setStateRef;

      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(builder: (context, setState) {
          setStateRef = setState;
          return const SizedBox();
        }),
      ));

      // Tear the tree down, as closing a sheet does.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(
        () => setStateRef(() {}),
        throwsA(isA<FlutterError>()),
        reason: 'setState on a disposed State must throw; the guards exist '
            'because of exactly this',
      );
    });
  });

  group('no unguarded setState in a catch', () {
    test('every catch that writes state checks mounted first', () {
      // Walk the source rather than the widget tree: the point is to catch a
      // pattern anywhere in the app, including screens with no test.
      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue,
          reason: 'run this suite from app/, not from the repository root');

      final offenders = <String>[];

      // `catch (...) {` then whitespace then `setState(`, with no `mounted`
      // check between them.
      final pattern = RegExp(
        r'catch\s*\([^)]*\)\s*\{\s*\n(\s*)setState\(',
        multiLine: true,
      );

      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final src = entity.readAsStringSync();
        // Only State classes have `mounted`. A plain class calling setState
        // would not compile, so it cannot be the bug this looks for.
        if (!src.contains('State<') && !src.contains('ConsumerState<')) {
          continue;
        }

        for (final match in pattern.allMatches(src)) {
          final line = src.substring(0, match.start).split('\n').length;
          offenders.add('${entity.path}:$line');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'These catches call setState with no `if (!mounted) return;`. '
            'The widget can be disposed while the request is in flight, and '
            'the setState then throws.\n  ${offenders.join('\n  ')}',
      );
    });
  });
}
