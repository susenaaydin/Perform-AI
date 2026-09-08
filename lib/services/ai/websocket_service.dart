import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _liveTranscriptController = StreamController<String>.broadcast();
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  Stream<String> get liveTranscript => _liveTranscriptController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(String userId, String triadId, {String host = 'localhost:8000'}) async {
    String cleanHost = host.replaceAll('ws://', '').replaceAll('wss://', '').replaceAll('http://', '').replaceAll('https://', '');
    final isLocal = cleanHost.startsWith('localhost') || cleanHost.startsWith('127.0.0.1') || cleanHost.startsWith('192.168.') || cleanHost.startsWith('10.');
    final scheme = (host.startsWith('wss://') || host.startsWith('https://') || !isLocal) ? 'wss' : 'ws';
    final wsUrl = Uri.parse('$scheme://$cleanHost/ws/$userId/$triadId');
    try {
      _channel = WebSocketChannel.connect(wsUrl);
      
      // Wait for the connection to be established
      await _channel!.ready;
      
      _isConnected = true;
      _connectionController.add(true);

      _channel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> data = jsonDecode(message);
            _messageController.add(data);
            if (data['type'] == 'live_transcript') {
              _liveTranscriptController.add(data['text'] ?? '');
            }
          } catch (e) {
            // Might be binary payload echo or debug logs, ignore
          }
        },
        onError: (err) {
          _isConnected = false;
          _connectionController.add(false);
        },
        onDone: () {
          _isConnected = false;
          _connectionController.add(false);
        },
      );
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      rethrow;
    }
  }

  void sendVisualEmotion(
    String emotion, {
    int landmarksCount = 0,
    String posture = 'neutral',
    String gesture = 'none',
    String energy = 'low',
  }) {
    if (_channel == null || !_isConnected) return;
    try {
      final payload = jsonEncode({
        'emotion': emotion,
        'landmarks_count': landmarksCount,
        'posture': posture,
        'gesture': gesture,
        'energy': energy,
      });
      _channel!.sink.add(payload);
    } catch (e) {
      // Handle send error
    }
  }

  void sendAudioBytes(Uint8List bytes) {
    if (_channel == null || !_isConnected) return;
    try {
      _channel!.sink.add(bytes);
    } catch (e) {
      // Handle send error
    }
  }

  void disconnect() {
    try {
      _channel?.sink.close(status.goingAway);
    } catch (_) {}
    _isConnected = false;
    _connectionController.add(false);
  }
}
