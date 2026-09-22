import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:resq/services/api_service.dart';

/// Live push channel for the donor mobile app — backed by the same /ws
/// WebSocket endpoint the admin dashboard already uses (see
/// server/src/realtime/socketServer.js, now extended to accept donor
/// tokens too), instead of only ever finding out about a new hospital
/// broadcast, an appointment change, or an admin eligibility override on
/// the next poll tick, app foreground, or manual pull-to-refresh.
///
/// Deliberately dumb: this class only connects, decodes JSON frames, and
/// hands each decoded event to [onEvent] — it does not know what a
/// "blood_request_created" event should DO to the UI. That stays in
/// HomeView, same as everywhere else in this app that already reacts to
/// backend events by re-fetching the real data rather than trusting
/// whatever partial payload the push itself carries.
///
/// If the socket can't connect or drops (no network, backend restart, an
/// app running on a WebSocket-hostile network), this fails silently and
/// stays disconnected — HomeView's own poll timer is the fallback safety
/// net for exactly that case, so a donor never ends up with NO way to see
/// a broadcast, just a slower one.
class RealtimeService {
  WebSocket? _socket;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  String _token = '';
  void Function(Map<String, dynamic> event)? onEvent;

  /// Derives the WebSocket URL from kApiBaseUrl — same host/scheme, just
  /// swapping https->wss / http->ws and dropping the "/api" suffix, since
  /// the server mounts the WebSocket upgrade handler at the bare root (see
  /// index.js's attachRealtime call, alongside app.js's express app, not
  /// under the "/api" router).
  Uri _wsUri(String token) {
    final apiUri = Uri.parse(kApiBaseUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
      path: '/ws',
      queryParameters: {'token': token},
    );
  }

  void connect(String token) {
    if (token.isEmpty) return;
    _token = token;
    _disposed = false;
    _connectNow();
  }

  Future<void> _connectNow() async {
    if (_disposed || _token.isEmpty) return;
    try {
      final socket = await WebSocket.connect(_wsUri(_token).toString());
      if (_disposed) {
        socket.close();
        return;
      }
      _socket = socket;
      _subscription = socket.listen(
        (raw) {
          try {
            final decoded = jsonDecode(raw as String);
            if (decoded is Map<String, dynamic>) onEvent?.call(decoded);
          } catch (e) {
            debugPrint('RealtimeService: could not decode event: $e');
          }
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('RealtimeService: connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _socket = null;
    if (_disposed) return;
    _reconnectTimer?.cancel();
    // Fixed 10s backoff — simple and good enough for a mobile app that's
    // usually foregrounded/backgrounded far more often than it sits open
    // and disconnected for long; HomeView's own poll timer covers the gap
    // in between attempts regardless.
    _reconnectTimer = Timer(const Duration(seconds: 10), _connectNow);
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
    _socket = null;
  }
}
