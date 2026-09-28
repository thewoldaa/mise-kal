import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../repositories/menu_repository.dart' show pbProvider;

enum Reachability { online, offline }

/// Whether the server is actually answering.
///
/// Polled rather than inferred from a connectivity plugin: a tablet can be
/// firmly on the wi-fi while the machine running the restaurant is asleep,
/// rebooting, or on the other side of a switch that just died. The only
/// question that matters is whether *this server* replies.
class ConnectionMonitor extends Notifier<Reachability> {
  Timer? _timer;
  bool _checking = false;

  @override
  Reachability build() {
    // Optimistic to start: the app has usually just talked to the server to
    // get here, and opening on a red banner would be wrong.
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      // The timer is cancelled on dispose, but a tick can already be queued
      // when that happens. Without this guard the tick runs against a dead
      // provider and throws on the first `ref` use inside check().
      if (ref.mounted) check();
    });
    scheduleMicrotask(() {
      if (ref.mounted) check();
    });
    return Reachability.online;
  }

  /// Called by the repository the moment a write fails, so the UI turns red
  /// immediately rather than at the next poll.
  void reportFailure() {
    if (!ref.mounted) return;
    if (state != Reachability.offline) state = Reachability.offline;
    scheduleMicrotask(() {
      if (ref.mounted) check();
    });
  }

  void reportSuccess() {
    if (!ref.mounted) return;
    if (state != Reachability.online) state = Reachability.online;
  }

  Future<void> check() async {
    if (_checking) return;
    _checking = true;

    PocketBase pb;
    try {
      pb = ref.read(pbProvider);
    } catch (_) {
      _checking = false;
      return;
    }

    try {
      await pb
          .send<Map<String, dynamic>>('/api/health')
          .timeout(const Duration(seconds: 4));

      // The health request takes up to four seconds, and the provider can be
      // disposed while it is in flight — the app closing, or a tablet signing
      // out and tearing the shell down. Writing `state` after that throws
      // "Cannot use the Ref of NotifierProvider after it has been disposed",
      // which surfaces as a crash on the way out rather than as anything the
      // user did wrong.
      //
      // This is a real path, not a theoretical one: the poll runs every ten
      // seconds, so a sign-out lands mid-request often enough to matter.
      if (!ref.mounted) return;
      state = Reachability.online;
    } catch (_) {
      if (!ref.mounted) return;
      state = Reachability.offline;
    } finally {
      // Safe unconditionally: it only touches this object's own field, not the
      // provider, so it does not need the mount check above.
      _checking = false;
    }
  }
}

final connectionProvider =
    NotifierProvider<ConnectionMonitor, Reachability>(ConnectionMonitor.new);

final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectionProvider) == Reachability.online,
);

/// True when a failure looks like the network rather than the server refusing.
///
/// A 400 means the server heard us and said no — queueing that would replay a
/// rejection forever. Only a connection that never landed is worth keeping.
bool isNetworkFailure(Object error) {
  if (error is TimeoutException) return true;
  if (error is ClientException) {
    // statusCode 0 is the SDK's "never reached the server".
    return error.statusCode == 0;
  }
  return false;
}
