@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mise/data/offline/connection.dart';
import 'package:mise/data/offline/pending_writes.dart';
import 'package:mise/data/prefs.dart';
import 'package:mise/data/repositories/menu_repository.dart' show pbProvider;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_server.dart';

/// The offline queue is the feature the whole product leans on: the POS keeps
/// taking orders when the internet drops. Until this file existed, `flush()`
/// had no test at all — every test here covers `PendingWrite` serialisation,
/// and none covered what actually happens when the queue drains.
///
/// That gap hid a real bug. See the `ordering` group.

PendingWrite line(String id, {String orderId = 'o1', int qty = 1}) =>
    PendingWrite(
      id: id,
      kind: PendingKind.addLine,
      orderId: orderId,
      at: DateTime(2026, 9, 1, 20, 30),
      describe: '$qty x Sea bass',
      body: {
        'menu_item': 'm1',
        'name_snapshot': 'Sea bass',
        'qty': qty,
        'unit_price': 850,
        'modifiers': const [],
        'note': '',
        'course': 0,
        'status': 'queued',
      },
    );

void main() {
  // No TestWidgetsFlutterBinding here on purpose. It installs a mock
  // HttpClient that answers every request with 400 and never opens a socket,
  // which is exactly the traffic this suite needs to exercise. These tests use
  // the plain Dart VM binding so real HTTP reaches the fake server.

  late FakePocketBaseServer server;
  late SharedPreferences prefs;

  setUp(() async {
    server = await FakePocketBaseServer.start();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await server.stop();
  });

  ProviderContainer container() => ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(Prefs(prefs)),
          pbProvider.overrideWithValue(
            PocketBase('http://127.0.0.1:${server.port}'),
          ),
        ],
      );

  /// Seeds prefs, then builds a container, so `PendingWrites.build()` sees the
  /// queue. The order matters: build() reads prefs exactly once, when the
  /// provider is first read.
  Future<(ProviderContainer, PendingWrites)> queueWith(
    List<PendingWrite> writes,
  ) async {
    await prefs.setString(
      'pending_writes',
      jsonEncode(writes.map((w) => w.toJson()).toList()),
    );
    final c = container();
    final q = c.read(pendingWritesProvider.notifier);
    // Touch the connection monitor so its timer is created inside the test and
    // disposed with the container, rather than starting during teardown and
    // firing a health request after the suite has finished.
    c.read(connectionProvider);
    return (c, q);
  }

  group('draining', () {
    test('sends everything and empties the queue', () async {
      final (c, q) = await queueWith([line('pending-1'), line('pending-2')]);
      addTearDown(c.dispose);

      final sent = await q.flush();

      expect(sent, 2);
      expect(c.read(pendingWritesProvider), isEmpty);
      expect(server.created, hasLength(2));
    });

    test('preserves order', () async {
      final (c, q) = await queueWith([
        line('pending-a', qty: 1),
        line('pending-b', qty: 2),
        line('pending-c', qty: 3),
      ]);
      addTearDown(c.dispose);

      await q.flush();

      expect(server.created.map((b) => b['qty']), [1, 2, 3]);
    });

    test('attaches the order id to every line it sends', () async {
      final (c, q) = await queueWith([line('pending-1', orderId: 'order-99')]);
      addTearDown(c.dispose);

      await q.flush();

      expect(server.created.single['order'], 'order-99');
    });
  });

  group('when the network drops', () {
    test('keeps what it could not send', () async {
      final (c, q) = await queueWith([line('pending-1')]);
      addTearDown(c.dispose);
      server.failWith = const SocketException('connection refused');

      final sent = await q.flush();

      expect(sent, 0);
      expect(c.read(pendingWritesProvider), hasLength(1),
          reason: 'a line that never reached the server must not be lost');
    });

    test('stops at the first failure so ordering survives', () async {
      // Replaying out of order could put a quantity change before the line it
      // changes, which the server would then reject for a reason that looks
      // like a data bug.
      final (c, q) = await queueWith([
        line('pending-1', qty: 1),
        line('pending-2', qty: 2),
        line('pending-3', qty: 3),
      ]);
      addTearDown(c.dispose);
      server.failAfter = 1;

      final sent = await q.flush();

      expect(sent, 1);
      expect(server.created, hasLength(1));
      final left = c.read(pendingWritesProvider);
      expect(left, hasLength(2), reason: 'the unsent tail must be kept');
    });
  });

  group('when the server refuses', () {
    test('drops a rejected write rather than retrying forever', () async {
      // A 400 means the server heard it and said no. Retrying that on every
      // reconnect would wedge the queue permanently behind one bad line.
      final (c, q) = await queueWith([line('pending-1')]);
      addTearDown(c.dispose);
      server.rejectWith = 400;

      final sent = await q.flush();

      expect(sent, 0);
      expect(c.read(pendingWritesProvider), isEmpty);
    });

    test('a rejection does not block the writes behind it', () async {
      final (c, q) = await queueWith([
        line('pending-1', qty: 1),
        line('pending-2', qty: 2),
      ]);
      addTearDown(c.dispose);
      server.rejectWith = 400;
      server.rejectFirstOnly = true;

      await q.flush();

      expect(server.created, hasLength(1));
      expect(c.read(pendingWritesProvider), isEmpty);
    });
  });

  group('ordering', () {
    test('a network failure does not reorder the queue', () async {
      // The bug this test exists for: flush() used to rebuild the queue as
      // [everything that failed] followed by [everything that was skipped],
      // because a skipped write was appended in the loop and a failed one was
      // appended in the catch. After one reconnect the queue came back in a
      // different order than it went in, and the next flush replayed it in that
      // wrong order.
      final (c, q) = await queueWith([
        line('pending-1', qty: 1),
        line('pending-2', qty: 2),
        line('pending-3', qty: 3),
      ]);
      addTearDown(c.dispose);

      server.failAfter = 1;
      await q.flush();

      final left = c.read(pendingWritesProvider);
      expect(
        left.map((w) => w.id),
        ['pending-2', 'pending-3'],
        reason: 'the surviving queue must keep its original order',
      );
    });

    test('the order survives a second attempt', () async {
      final (c, q) = await queueWith([
        line('pending-1', qty: 1),
        line('pending-2', qty: 2),
        line('pending-3', qty: 3),
      ]);
      addTearDown(c.dispose);

      server.failAfter = 1;
      await q.flush();
      server.failAfter = null;
      server.failWith = null;
      await q.flush();

      expect(server.created.map((b) => b['qty']), [1, 2, 3],
          reason: 'a reconnect must replay in the order the waiter entered');
    });
  });

  group('persistence', () {
    test('the queue survives a restart', () async {
      final (c, q) = await queueWith([line('pending-1', qty: 4)]);
      addTearDown(c.dispose);
      server.failWith = const SocketException('offline');
      await q.flush();

      // A fresh container, as after the app is closed and reopened.
      final c2 = container();
      addTearDown(c2.dispose);
      final restored = c2.read(pendingWritesProvider);
      expect(restored, hasLength(1));
      expect(restored.single.body['qty'], 4);
    });

    test('flushing twice at once does not double-send', () async {
      // The queue is flushed from a connection listener, and a flaky network
      // can flip online twice in quick succession.
      final (c, q) = await queueWith([line('pending-1')]);
      addTearDown(c.dispose);

      await Future.wait([q.flush(), q.flush()]);

      expect(server.created, hasLength(1));
    });
  });
}
