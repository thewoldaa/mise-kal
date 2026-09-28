import 'dart:convert';
import 'dart:io';

/// A stand-in for PocketBase, on a real socket.
///
/// The offline queue talks to the server through the PocketBase SDK, and the
/// interesting behaviour is what happens when that call fails in different
/// ways. A mock object would let a test assert that `create()` was called, but
/// not that a real `ClientException` with `statusCode == 0` comes back out of
/// the SDK — and that distinction is exactly what `isNetworkFailure` keys on to
/// decide "keep it and retry" versus "the server refused, drop it".
///
/// So this speaks HTTP on a loopback port, the same approach the printer tests
/// take with a fake thermal printer.
class FakePocketBaseServer {
  FakePocketBaseServer._(this._server);

  final HttpServer _server;

  /// Bodies of every successfully created `order_items` record, in arrival
  /// order. Tests assert on this to prove ordering survived a reconnect.
  final List<Map<String, dynamic>> created = [];

  /// When set, every request fails this way instead of succeeding. A
  /// [SocketException] is what a dropped connection looks like.
  Object? failWith;

  /// When set, the first N requests succeed and every later one is dropped at
  /// the socket, so the SDK reports statusCode 0 and `isNetworkFailure` is
  /// true. Used to test stopping mid-queue.
  ///
  /// Deliberately a dropped connection rather than a 5xx: a 5xx is a server
  /// that heard the request and refused it, which the queue drops on purpose.
  /// Only a connection that never landed is worth retrying, so a test for
  /// "stop and keep the rest" has to look like the network, not like a refusal.
  int? failAfter;

  /// When set, requests are answered with this HTTP status, which the SDK
  /// surfaces as a `ClientException` with a non-zero status — i.e. the server
  /// heard the request and refused it.
  int? rejectWith;

  /// When true, the first request is rejected and the rest succeed.
  bool rejectFirstOnly = false;

  /// Counts only order_items writes. Health probes are excluded, because the
  /// connection monitor polls them on its own schedule and would otherwise
  /// make these counters depend on timing the test does not control.
  int _writes = 0;

  int get port => _server.port;

  static Future<FakePocketBaseServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakePocketBaseServer._(server);
    server.listen(fake._handle);
    return fake;
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    // The health probe the connection monitor polls. Answered before anything
    // else so a monitor started by an unrelated provider does not turn the
    // whole suite red, and so it does not disturb the write counters.
    if (request.uri.path.endsWith('/api/health')) {
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"code":200,"message":"ok"}');
      await request.response.close();
      return;
    }

    _writes++;

    // A dropped connection: close the socket without answering.
    if (failWith is SocketException) {
      request.response.close();
      try {
        await request.response.done;
      } catch (_) {}
      return;
    }

    if (failAfter != null && _writes > failAfter!) {
      // Drop the socket without answering, which is what a lost connection
      // looks like to the SDK.
      request.response.close();
      try {
        await request.response.done;
      } catch (_) {}
      return;
    }

    if (rejectWith != null) {
      final reject = !rejectFirstOnly || _writes == 1;
      if (reject) {
        request.response.statusCode = rejectWith!;
        request.response.write(jsonEncode({
          'status': rejectWith,
          'message': 'the server refused this',
        }));
        await request.response.close();
        return;
      }
    }

    final raw = await utf8.decoder.bind(request).join();
    if (raw.isNotEmpty && request.method == 'POST') {
      try {
        created.add(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A body the test did not intend to assert on.
      }
    }

    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'id': 'srv-${created.length}',
      'collectionId': 'order_items',
      'collectionName': 'order_items',
    }));
    await request.response.close();
  }
}
