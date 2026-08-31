import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';

class BrowserBridge {
  BrowserBridge() {
    html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is! Map || data['type'] != 'workbench-extension-response') return;
      final requestId = data['requestId']?.toString();
      final completer = requestId == null ? null : _pending.remove(requestId);
      if (completer == null) return;
      final response = data['response'];
      completer.complete(response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{'ok': false, 'error': 'invalid_extension_response'});
    });
  }

  final Map<String, Completer<Map<String, dynamic>?>> _pending = {};
  final Random _random = Random();
  bool get isAvailable => true;

  Future<Map<String, dynamic>?> request(String action,
      [Map<String, dynamic> payload = const {}]) {
    final requestId = 'browser_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 20)}';
    final completer = Completer<Map<String, dynamic>?>();
    _pending[requestId] = completer;
    html.window.postMessage(jsonEncode({
      'type': 'workbench-extension-request',
      'requestId': requestId,
      'action': action,
      'payload': payload,
    }), '*');
    Timer(const Duration(seconds: 8), () {
      final pending = _pending.remove(requestId);
      if (pending != null && !pending.isCompleted) pending.complete(null);
    });
    return completer.future;
  }
}
