import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum FaceStatus {
  active,
  noFace,
  insufficientFaceAngle,
  uncertain,
}

enum BodyStatus {
  active,
  insufficientBodyVisibility,
  uncertain,
}

class FaceEmotionResult {
  final String emotion;
  final Map<String, double> confidences;
  final FaceStatus status;

  FaceEmotionResult({
    required this.emotion,
    required this.confidences,
    required this.status,
  });

  factory FaceEmotionResult.fromMap(Map<dynamic, dynamic> map) {
    final statusIndex = map['status'] as int? ?? 1; // Default to noFace
    final status = FaceStatus.values[statusIndex];
    
    final confMap = Map<String, double>.from(
      (map['confidences'] as Map<dynamic, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      ),
    );
    
    return FaceEmotionResult(
      emotion: map['emotion']?.toString() ?? 'neutral',
      confidences: confMap,
      status: status,
    );
  }

  @override
  String toString() => 'FaceEmotionResult(emotion: $emotion, status: $status)';
}

class BodyEmotionResult {
  final String emotion;
  final Map<String, double> confidences;
  final BodyStatus status;

  BodyEmotionResult({
    required this.emotion,
    required this.confidences,
    required this.status,
  });

  factory BodyEmotionResult.fromMap(Map<dynamic, dynamic> map) {
    final statusIndex = map['status'] as int? ?? 1; // Default to insufficientBodyVisibility
    final status = BodyStatus.values[statusIndex];
    
    final confMap = Map<String, double>.from(
      (map['confidences'] as Map<dynamic, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      ),
    );

    return BodyEmotionResult(
      emotion: map['emotion']?.toString() ?? 'neutral',
      confidences: confMap,
      status: status,
    );
  }

  @override
  String toString() => 'BodyEmotionResult(emotion: $emotion, status: $status)';
}

class CombinedAnalysisResult {
  final FaceEmotionResult faceResult;
  final BodyEmotionResult bodyResult;
  final VisualAnalysisResult? visualAnalysis;
  final int timestamp;

  CombinedAnalysisResult({
    required this.faceResult,
    required this.bodyResult,
    this.visualAnalysis,
    required this.timestamp,
  });

  factory CombinedAnalysisResult.fromMap(Map<dynamic, dynamic> map) {
    return CombinedAnalysisResult(
      faceResult: FaceEmotionResult.fromMap(map['faceResult'] as Map? ?? {}),
      bodyResult: BodyEmotionResult.fromMap(map['bodyResult'] as Map? ?? {}),
      visualAnalysis: map['visual_analysis'] != null
          ? VisualAnalysisResult.fromMap(map['visual_analysis'] as Map)
          : null,
      timestamp: map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  String toString() => 'CombinedAnalysisResult(face: ${faceResult.emotion}, body: ${bodyResult.emotion}, visualAnalysis: $visualAnalysis)';
}

class VisualAnalysisResult {
  final String mainSource;
  final String mainEmotion;
  final double faceConfidence;
  final String visualStatus;
  final int supportScore;
  final PoseSupportResult poseSupport;
  final VisualUiResult ui;

  VisualAnalysisResult({
    required this.mainSource,
    required this.mainEmotion,
    required this.faceConfidence,
    required this.visualStatus,
    required this.supportScore,
    required this.poseSupport,
    required this.ui,
  });

  factory VisualAnalysisResult.fromMap(Map<dynamic, dynamic> map) {
    return VisualAnalysisResult(
      mainSource: map['main_source']?.toString() ?? 'face',
      mainEmotion: map['main_emotion']?.toString() ?? 'uncertain',
      faceConfidence: (map['face_confidence'] as num?)?.toDouble() ?? 0.0,
      visualStatus: map['visual_status']?.toString() ?? '',
      supportScore: map['support_score'] as int? ?? 0,
      poseSupport: PoseSupportResult.fromMap(map['pose_support'] as Map? ?? {}),
      ui: VisualUiResult.fromMap(map['ui'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'main_source': mainSource,
      'main_emotion': mainEmotion,
      'face_confidence': faceConfidence,
      'visual_status': visualStatus,
      'support_score': supportScore,
      'pose_support': poseSupport.toMap(),
      'ui': ui.toMap(),
    };
  }

  @override
  String toString() => 'VisualAnalysisResult(emotion: $mainEmotion, status: $visualStatus, score: $supportScore)';
}

class PoseSupportResult {
  final String frameQuality;
  final String movementEnergy;
  final String gestureLevel;
  final String posture;
  final String stability;
  final String orientation;

  PoseSupportResult({
    required this.frameQuality,
    required this.movementEnergy,
    required this.gestureLevel,
    required this.posture,
    required this.stability,
    required this.orientation,
  });

  factory PoseSupportResult.fromMap(Map<dynamic, dynamic> map) {
    return PoseSupportResult(
      frameQuality: map['frame_quality']?.toString() ?? 'poor',
      movementEnergy: map['movement_energy']?.toString() ?? 'low',
      gestureLevel: map['gesture_level']?.toString() ?? 'none',
      posture: map['posture']?.toString() ?? 'neutral',
      stability: map['stability']?.toString() ?? 'stable',
      orientation: map['orientation']?.toString() ?? 'camera',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'frame_quality': frameQuality,
      'movement_energy': movementEnergy,
      'gesture_level': gestureLevel,
      'posture': posture,
      'stability': stability,
      'orientation': orientation,
    };
  }
}

class VisualUiResult {
  final String title;
  final String label;
  final String status;

  VisualUiResult({
    required this.title,
    required this.label,
    required this.status,
  });

  factory VisualUiResult.fromMap(Map<dynamic, dynamic> map) {
    return VisualUiResult(
      title: map['title']?.toString() ?? 'Visual Analysis',
      label: map['label']?.toString() ?? 'Uncertain',
      status: map['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'label': label,
      'status': status,
    };
  }
}

class AiAnalysisService {
  static const MethodChannel _methodChannel = MethodChannel('com.example.perform_ai/ai_analysis');
  static const EventChannel _eventChannel = EventChannel('com.example.perform_ai/ai_analysis_stream');

  StreamSubscription? _subscription;
  final StreamController<CombinedAnalysisResult> _controller = StreamController<CombinedAnalysisResult>.broadcast();

  Stream<CombinedAnalysisResult> get analysisStream => _controller.stream;

  /// Initializes models with GPU configurations
  Future<bool> initialize() async {
    try {
      final bool success = await _methodChannel.invokeMethod('initialize') ?? false;
      return success;
    } on PlatformException catch (e) {
      debugPrint('AiAnalysisService: Failed to initialize native models: ${e.message}');
      return false;
    }
  }

  /// Starts frame capture and analysis pipeline
  Future<void> startProcessing() async {
    try {
      await _methodChannel.invokeMethod('startProcessing');
      _subscription?.cancel();
      _subscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) {
        if (event is Map) {
          final result = CombinedAnalysisResult.fromMap(event);
          _controller.add(result);
        }
      }, onError: (dynamic err) {
        debugPrint('AiAnalysisService: Error in analysis stream: $err');
      });
    } on PlatformException catch (e) {
      debugPrint('AiAnalysisService: Failed to start processing: ${e.message}');
    }
  }

  /// Stops frame capture and analysis pipeline
  Future<void> stopProcessing() async {
    try {
      await _methodChannel.invokeMethod('stopProcessing');
      await _subscription?.cancel();
      _subscription = null;
    } on PlatformException catch (e) {
      debugPrint('AiAnalysisService: Failed to stop processing: ${e.message}');
    }
  }

  /// Runs model inference with given face and body landmarks
  Future<Map<String, dynamic>?> analyzeFrame({
    required List<List<double>> faceLandmarks,
    required List<List<double>> poseLandmarks,
    String view = 'front',
  }) async {
    try {
      final Map<dynamic, dynamic>? rawResult = await _methodChannel.invokeMethod(
        'analyzeFrame',
        {
          'faceLandmarks': faceLandmarks,
          'poseLandmarks': poseLandmarks,
          'view': view,
        },
      );
      if (rawResult != null) {
        return Map<String, dynamic>.from(rawResult);
      }
    } on PlatformException catch (e) {
      debugPrint('AiAnalysisService: Failed to analyze frame: ${e.message}');
    }
    return null;
  }

  /// Processes a raw camera frame on a native background thread
  Future<Map<String, dynamic>?> processImageFrame({
    required Uint8List yPlane,
    required Uint8List uPlane,
    required Uint8List vPlane,
    required int yRowStride,
    required int uRowStride,
    required int vRowStride,
    required int uvPixelStride,
    required int width,
    required int height,
    required int rotation,
    String view = 'front',
  }) async {
    try {
      final Map<dynamic, dynamic>? rawResult = await _methodChannel.invokeMethod(
        'processImageFrame',
        {
          'yPlane': yPlane,
          'uPlane': uPlane,
          'vPlane': vPlane,
          'yRowStride': yRowStride,
          'uRowStride': uRowStride,
          'vRowStride': vRowStride,
          'uvPixelStride': uvPixelStride,
          'width': width,
          'height': height,
          'rotation': rotation,
          'view': view,
        },
      );
      if (rawResult != null) {
        return Map<String, dynamic>.from(rawResult);
      }
    } on PlatformException catch (e) {
      debugPrint('AiAnalysisService: Failed to process image frame: ${e.message}');
    }
    return null;
  }

  /// Closes the streams
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
