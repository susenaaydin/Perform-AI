import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'websocket_service.dart';

class AudioStreamController {
  final WebSocketService _webSocketService;
  final _audioRecorder = AudioRecorder();
  StreamSubscription<List<int>>? _audioStreamSubscription;
  final List<int> _buffer = [];
  Timer? _flushTimer;
  
  // Real-time volume output stream
  final _volumeController = StreamController<double>.broadcast();
  Stream<double> get volumeStream => _volumeController.stream;

  AudioStreamController(this._webSocketService);

  Future<void> startStreaming() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final stream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits, // 16-bit PCM raw
            sampleRate: 16000, // 16kHz sample rate
            numChannels: 1, // Mono channel
          ),
        );

        _buffer.clear();

        // Listen to stream of raw audio bytes
        _audioStreamSubscription = stream.listen(
          (data) {
            // Apply 2.5x gain boost to raw PCM bytes!
            final boostedData = _applyGain(data, 2.5);
            _buffer.addAll(boostedData);
            
            // Calculate real-time amplitude / volume on boosted data
            final vol = _calculateVolume(boostedData);
            _volumeController.add(vol);
          },
          onError: (err) {
            // Handle streaming error
          },
        );

        // Every 500 milliseconds (0.5s), flush buffer and send to WebSocket
        _flushTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
          if (_buffer.isNotEmpty) {
            final bytesToSend = Uint8List.fromList(_buffer);
            _webSocketService.sendAudioBytes(bytesToSend);
            _buffer.clear();
          }
        });
      } else {
        throw Exception("Microphone permission denied.");
      }
    } catch (e) {
      rethrow;
    }
  }

  List<int> _applyGain(List<int> bytes, double gain) {
    if (gain == 1.0 || bytes.isEmpty) return bytes;
    
    final Uint8List result = Uint8List(bytes.length);
    for (int i = 0; i < bytes.length - 1; i += 2) {
      int low = bytes[i];
      int high = bytes[i + 1];
      
      int sample = (high << 8) | low;
      if (sample >= 32768) sample -= 65536;
      
      double boosted = sample * gain;
      if (boosted > 32767) boosted = 32767;
      if (boosted < -32768) boosted = -32768;
      
      int outSample = boosted.round();
      if (outSample < 0) outSample += 65536;
      
      result[i] = outSample & 0xFF;
      result[i + 1] = (outSample >> 8) & 0xFF;
    }
    return result;
  }

  double _calculateVolume(List<int> bytes) {
    if (bytes.isEmpty) return 0.0;
    
    int sampleCount = bytes.length ~/ 2;
    if (sampleCount == 0) return 0.0;
    
    double absSum = 0;
    for (int i = 0; i < bytes.length - 1; i += 2) {
      int low = bytes[i];
      int high = bytes[i + 1];
      int sample = (high << 8) | low;
      if (sample >= 32768) sample -= 65536;
      absSum += sample.abs();
    }
    
    double avg = absSum / sampleCount;
    // Map speech level (typically peaks around 8000) to 0.0 - 1.0 range
    double vol = avg / 8000.0;
    if (vol > 1.0) vol = 1.0;
    return vol;
  }

  Future<void> stopStreaming() async {
    _flushTimer?.cancel();
    _audioStreamSubscription?.cancel();
    await _audioRecorder.stop();
  }

  void dispose() {
    _flushTimer?.cancel();
    _audioStreamSubscription?.cancel();
    _audioRecorder.dispose();
    _volumeController.close();
  }
}
