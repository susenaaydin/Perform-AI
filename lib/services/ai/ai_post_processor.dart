import 'dart:math' as math;
import 'ai_analysis_service.dart';

class AiPostProcessor {
  // EMA Alpha parameters
  static const double faceAlpha = 0.80;

  // Face Threshold & Margin parameters
  static const double faceMinConfidence = 0.08;
  static const double faceMinMargin = 0.0;
  static const double faceExceptionThreshold = 0.08;

  // Previous smoothed confidences state for temporal smoothing
  Map<String, double>? _prevFaceConfidences;

  // Rolling history buffer for pose landmarks (up to 15 frames)
  final List<List<List<double>>> _poseLandmarksBuffer = [];

  /// Resets the EMA and sliding buffer state (e.g., when starting a new session)
  void reset() {
    _prevFaceConfidences = null;
    _poseLandmarksBuffer.clear();
  }

  /// Processes the raw combined results and returns the post-processed result with visual analysis
  CombinedAnalysisResult process(
    CombinedAnalysisResult raw, {
    List<List<double>>? faceLandmarks,
    List<List<double>>? poseLandmarks,
  }) {
    // 1. Smooth and decide the face emotion
    final processedFace = _processFace(raw.faceResult);
    
    // 2. Smooth body emotion (even if unused, keep for backwards compatibility)
    final processedBody = _processBody(raw.bodyResult);

    // 3. Update the pose landmarks buffer
    if (poseLandmarks != null && poseLandmarks.isNotEmpty) {
      _poseLandmarksBuffer.add(poseLandmarks);
      if (_poseLandmarksBuffer.length > 15) {
        _poseLandmarksBuffer.removeAt(0);
      }
    }

    // 4. Perform visual analysis logic
    final visualAnalysis = _computeVisualAnalysis(
      processedFace,
      faceLandmarks,
      poseLandmarks,
    );

    return CombinedAnalysisResult(
      faceResult: processedFace,
      bodyResult: processedBody,
      visualAnalysis: visualAnalysis,
      timestamp: raw.timestamp,
    );
  }

  FaceEmotionResult _processFace(FaceEmotionResult rawFace) {
    if (rawFace.status == FaceStatus.noFace || 
        rawFace.status == FaceStatus.insufficientFaceAngle) {
      _prevFaceConfidences = null;
      return FaceEmotionResult(
        emotion: 'uncertain',
        confidences: rawFace.confidences,
        status: FaceStatus.uncertain,
      );
    }

    final smoothedConfidences = _smoothConfidences(
      rawFace.confidences,
      _prevFaceConfidences,
      faceAlpha,
    );
    _prevFaceConfidences = Map.from(smoothedConfidences);

    final decision = _makeDecision(
      confidences: smoothedConfidences,
      minConfidence: faceMinConfidence,
      minMargin: faceMinMargin,
      exceptionThreshold: faceExceptionThreshold,
    );

    return FaceEmotionResult(
      emotion: decision.emotion,
      confidences: smoothedConfidences,
      status: decision.isAccepted ? FaceStatus.active : FaceStatus.uncertain,
    );
  }

  BodyEmotionResult _processBody(BodyEmotionResult rawBody) {
    return BodyEmotionResult(
      emotion: 'uncertain',
      confidences: const {},
      status: BodyStatus.uncertain,
    );
  }

  /// Applies Exponential Moving Average (EMA) element-wise
  Map<String, double> _smoothConfidences(
    Map<String, double> current,
    Map<String, double>? previous,
    double alpha,
  ) {
    if (previous == null || previous.isEmpty) {
      return Map.from(current);
    }

    final Map<String, double> smoothed = {};
    double sum = 0.0;

    current.forEach((emotion, currentVal) {
      final prevVal = previous[emotion] ?? 0.0;
      final smoothedVal = (alpha * currentVal) + ((1.0 - alpha) * prevVal);
      smoothed[emotion] = smoothedVal;
      sum += smoothedVal;
    });

    if (sum > 0.0) {
      smoothed.updateAll((key, value) => value / sum);
    }

    return smoothed;
  }

  /// Analyzes the top predictions to make an acceptance decision
  _DecisionResult _makeDecision({
    required Map<String, double> confidences,
    required double minConfidence,
    required double minMargin,
    required double exceptionThreshold,
  }) {
    if (confidences.isEmpty) {
      return const _DecisionResult(emotion: 'uncertain', isAccepted: false);
    }

    final sortedEntries = confidences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top1 = sortedEntries[0];
    final top2 = sortedEntries.length > 1 ? sortedEntries[1] : const MapEntry('', 0.0);

    final top1Val = top1.value;
    final top2Val = top2.value;
    final margin = top1Val - top2Val;

    if (top1Val >= exceptionThreshold) {
      return _DecisionResult(emotion: top1.key, isAccepted: true);
    }

    final hasHighConfidence = top1Val >= minConfidence;
    final hasValidMargin = margin >= minMargin;

    if (hasHighConfidence && hasValidMargin) {
      return _DecisionResult(emotion: top1.key, isAccepted: true);
    }

    return const _DecisionResult(emotion: 'uncertain', isAccepted: false);
  }

  // --- Rule-Based Pose Analyzer Logic ---

  bool _isVis(List<List<double>>? pose, int idx) {
    if (pose == null || pose.length <= idx) return false;
    final lm = pose[idx];
    if (lm.length < 4) return true; // Default to visible if no score is provided
    return lm[3] > 0.40; // 0.40 threshold for visibility
  }

  double _dist2d(List<double> p1, List<double> p2) {
    final dx = p1[0] - p2[0];
    final dy = p1[1] - p2[1];
    return math.sqrt(dx * dx + dy * dy);
  }

  String _calculateFrameQuality(List<List<double>>? face, List<List<double>>? pose) {
    final faceVisible = face != null && face.isNotEmpty;
    if (!faceVisible) return 'poor';
    
    final shoulderVisible = _isVis(pose, 11) && _isVis(pose, 12);
    if (!shoulderVisible) return 'face_only';
    
    final hipsVisible = _isVis(pose, 23) && _isVis(pose, 24);
    if (!hipsVisible) return 'chest_up';
    
    final lowerVisible = _isVis(pose, 25) && _isVis(pose, 26) && _isVis(pose, 27) && _isVis(pose, 28);
    if (!lowerVisible) return 'upper_body';
    
    return 'full_body';
  }

  String _calculateMovementEnergy() {
    if (_poseLandmarksBuffer.length < 2) return 'low';
    
    double totalDisplacement = 0.0;
    int count = 0;
    final keyIndices = [0, 11, 12, 13, 14, 15, 16]; // Nose, shoulders, elbows, wrists
    
    for (int t = 1; t < _poseLandmarksBuffer.length; t++) {
      final prevFrame = _poseLandmarksBuffer[t - 1];
      final currFrame = _poseLandmarksBuffer[t];
      
      double frameDisplacementSum = 0.0;
      int frameDisplacementCount = 0;
      
      for (final idx in keyIndices) {
        if (_isVis(prevFrame, idx) && _isVis(currFrame, idx)) {
          final dist = _dist2d(prevFrame[idx], currFrame[idx]);
          frameDisplacementSum += dist;
          frameDisplacementCount++;
        }
      }
      
      if (frameDisplacementCount > 0) {
        totalDisplacement += (frameDisplacementSum / frameDisplacementCount);
        count++;
      }
    }
    
    if (count == 0) return 'low';
    final avgDisplacement = totalDisplacement / count;
    
    if (avgDisplacement < 0.006) return 'low';
    if (avgDisplacement < 0.02) return 'medium';
    if (avgDisplacement < 0.05) return 'high';
    return 'chaotic';
  }

  String _calculateGestureLevel(List<List<double>>? pose) {
    final handsVisible = _isVis(pose, 15) || _isVis(pose, 16);
    if (!handsVisible) return 'hands_not_visible';
    
    double wristSpeed = 0.0;
    int wristSpeedCount = 0;
    
    if (_poseLandmarksBuffer.length >= 2) {
      for (int t = 1; t < _poseLandmarksBuffer.length; t++) {
        final prevFrame = _poseLandmarksBuffer[t - 1];
        final currFrame = _poseLandmarksBuffer[t];
        
        if (_isVis(prevFrame, 15) && _isVis(currFrame, 15)) {
          wristSpeed += _dist2d(prevFrame[15], currFrame[15]);
          wristSpeedCount++;
        }
        if (_isVis(prevFrame, 16) && _isVis(currFrame, 16)) {
          wristSpeed += _dist2d(prevFrame[16], currFrame[16]);
          wristSpeedCount++;
        }
      }
    }
    
    final ws = wristSpeedCount > 0 ? (wristSpeed / wristSpeedCount) : 0.0;
    
    double wy = 1.0;
    if (_isVis(pose, 15)) wy = math.min(wy, pose![15][1]);
    if (_isVis(pose, 16)) wy = math.min(wy, pose![16][1]);
    
    double hy = 0.8;
    if (_isVis(pose, 23) && _isVis(pose, 24)) {
      hy = (pose![23][1] + pose[24][1]) / 2;
    }
    double sy = 0.4;
    if (_isVis(pose, 11) && _isVis(pose, 12)) {
      sy = (pose![11][1] + pose[12][1]) / 2;
    }
    
    if (ws > 0.05) return 'excessive';
    if (ws > 0.02) {
      if (wy < sy) return 'strong';
      return 'natural';
    }
    if (ws > 0.005) {
      if (wy < sy) return 'natural';
      if (wy < hy) return 'low';
      return 'none';
    }
    if (wy < hy) return 'low';
    return 'none';
  }

  String _calculatePosture(List<List<double>>? pose) {
    if (pose == null || pose.length < 25) return 'neutral';
    
    final noseVisible = _isVis(pose, 0);
    final shouldersVisible = _isVis(pose, 11) && _isVis(pose, 12);
    final earsVisible = _isVis(pose, 7) && _isVis(pose, 8);
    final wristsVisible = _isVis(pose, 15) && _isVis(pose, 16);
    
    if (shouldersVisible && noseVisible) {
      final dLeft = _dist2d(pose[0], pose[11]);
      final dRight = _dist2d(pose[0], pose[12]);
      final ratio = dLeft / (dRight + 1e-6);
      if (ratio < 0.6 || ratio > 1.6) {
        return 'turned';
      }
    }
    
    if (earsVisible && shouldersVisible) {
      final dLeftEarSh = pose[11][1] - pose[7][1];
      final dRightEarSh = pose[12][1] - pose[8][1];
      final avgEarShDist = (dLeftEarSh + dRightEarSh) / 2;
      if (avgEarShDist < 0.08) {
        return 'tense';
      }
    }
    
    if (shouldersVisible && noseVisible) {
      final avgShoulderY = (pose[11][1] + pose[12][1]) / 2;
      final noseY = pose[0][1];
      final dy = avgShoulderY - noseY;
      if (dy < 0.07) {
        return 'slouched';
      }
    }
    
    if (wristsVisible && shouldersVisible) {
      final wristDist = _dist2d(pose[15], pose[16]);
      final shWidth = _dist2d(pose[11], pose[12]);
      if (wristDist < shWidth * 0.5) {
        return 'closed';
      }
      if (wristDist > shWidth * 1.5) {
        return 'open';
      }
    }
    
    if (shouldersVisible) {
      final shWidth = _dist2d(pose[11], pose[12]);
      if (shWidth > 0.45) return 'forward';
      if (shWidth < 0.18) return 'backward';
    }
    
    return 'neutral';
  }

  String _calculateStability() {
    if (_poseLandmarksBuffer.length < 5) return 'stable';
    
    final List<double> xs = [];
    final List<double> ys = [];
    
    for (final frame in _poseLandmarksBuffer) {
      if (_isVis(frame, 11) && _isVis(frame, 12)) {
        final midX = (frame[11][0] + frame[12][0]) / 2;
        final midY = (frame[11][1] + frame[12][1]) / 2;
        xs.add(midX);
        ys.add(midY);
      }
    }
    
    if (xs.length < 5) return 'stable';
    
    final meanX = xs.reduce((a, b) => a + b) / xs.length;
    final meanY = ys.reduce((a, b) => a + b) / ys.length;
    
    double sumSqDiff = 0.0;
    for (int i = 0; i < xs.length; i++) {
      final dx = xs[i] - meanX;
      final dy = ys[i] - meanY;
      sumSqDiff += (dx * dx + dy * dy);
    }
    
    final sd = math.sqrt(sumSqDiff / xs.length);
    
    if (sd < 0.008) return 'stable';
    if (sd < 0.025) return 'slightly_unstable';
    return 'unstable';
  }

  String _calculateOrientation(List<List<double>>? face, List<List<double>>? pose) {
    final faceVisible = face != null && face.isNotEmpty;
    final shouldersVisible = _isVis(pose, 11) && _isVis(pose, 12);
    
    if (!faceVisible && shouldersVisible) return 'away';
    if (!faceVisible) return 'camera';
    
    final noseVisible = _isVis(pose, 0);
    final earsVisible = _isVis(pose, 7) && _isVis(pose, 8);
    
    if (earsVisible && noseVisible) {
      final xNose = pose![0][0];
      final xLeftEar = pose[7][0];
      final xRightEar = pose[8][0];
      
      final distLeft = (xNose - xLeftEar).abs();
      final distRight = (xNose - xRightEar).abs();
      
      if (distLeft / (distRight + 1e-6) < 0.45) return 'left';
      if (distRight / (distLeft + 1e-6) < 0.45) return 'right';
      
      final avgEarY = (pose[7][1] + pose[8][1]) / 2;
      final noseY = pose[0][1];
      if (noseY - avgEarY > 0.08) return 'down';
    }
    
    return 'camera';
  }

  VisualAnalysisResult _computeVisualAnalysis(
    FaceEmotionResult faceResult,
    List<List<double>>? faceLandmarks,
    List<List<double>>? poseLandmarks,
  ) {
    final faceConfidence = faceResult.confidences[faceResult.emotion] ?? 0.0;
    
    final frameQuality = _calculateFrameQuality(faceLandmarks, poseLandmarks);
    final movementEnergy = _calculateMovementEnergy();
    final gestureLevel = _calculateGestureLevel(poseLandmarks);
    final posture = _calculatePosture(poseLandmarks);
    final stability = _calculateStability();
    final orientation = _calculateOrientation(faceLandmarks, poseLandmarks);
    
    final poseSupport = PoseSupportResult(
      frameQuality: frameQuality,
      movementEnergy: movementEnergy,
      gestureLevel: gestureLevel,
      posture: posture,
      stability: stability,
      orientation: orientation,
    );
    
    final emotion = faceResult.emotion;
    
    // Rule: If pose visibility is poor or the frame is too limited, show "Limited frame" (Kısıtlı kadraj)
    if (frameQuality == 'face_only' || frameQuality == 'poor') {
      return VisualAnalysisResult(
        mainSource: 'face',
        mainEmotion: emotion,
        faceConfidence: faceConfidence,
        visualStatus: 'Kısıtlı kadraj',
        supportScore: 1,
        poseSupport: poseSupport,
        ui: VisualUiResult(
          title: 'Görsel Analiz',
          label: _capitalize(emotion),
          status: 'Kısıtlı kadraj',
        ),
      );
    }
    
    int supportScore = 0;
    String visualStatus = '';
    
    List<String> expectedEnergy = [];
    List<String> expectedPosture = [];
    List<String> expectedGesture = [];
    
    switch (emotion.toLowerCase()) {
      case 'neutral':
        expectedEnergy = ['low', 'medium'];
        expectedPosture = ['neutral', 'open'];
        expectedGesture = ['none', 'low', 'natural'];
        break;
      case 'sad':
        expectedEnergy = ['low'];
        expectedPosture = ['closed', 'neutral', 'slouched', 'tense'];
        expectedGesture = ['none', 'low'];
        break;
      case 'angry':
        expectedEnergy = ['medium', 'high'];
        expectedPosture = ['tense', 'forward', 'open', 'neutral'];
        expectedGesture = ['natural', 'strong'];
        break;
      case 'disgust':
        expectedEnergy = ['low', 'medium'];
        expectedPosture = ['closed', 'backward', 'turned', 'slouched'];
        expectedGesture = ['none', 'low'];
        break;
      case 'happy':
        expectedEnergy = ['medium', 'high'];
        expectedPosture = ['open', 'neutral'];
        expectedGesture = ['natural', 'strong'];
        break;
      case 'surprise':
        expectedEnergy = ['medium', 'high'];
        expectedPosture = ['open', 'backward', 'neutral'];
        expectedGesture = ['natural', 'strong'];
        break;
      case 'contempt':
        expectedEnergy = ['low', 'medium'];
        expectedPosture = ['neutral', 'closed', 'turned', 'tense'];
        expectedGesture = ['none', 'low', 'natural'];
        break;
      default:
        expectedEnergy = ['low', 'medium', 'high', 'chaotic'];
        expectedPosture = ['open', 'neutral', 'closed', 'tense', 'forward', 'backward', 'turned', 'slouched'];
        expectedGesture = ['none', 'low', 'natural', 'strong', 'excessive', 'hands_not_visible'];
    }
    
    // Scoring logic
    if (expectedEnergy.contains(movementEnergy)) supportScore++;
    if (expectedPosture.contains(posture)) supportScore++;
    if (gestureLevel == 'hands_not_visible') {
      supportScore++; // don't penalize
    } else if (expectedGesture.contains(gestureLevel)) {
      supportScore++;
    }
    
    // Determine status message based on emotion support checks (in Turkish)
    switch (emotion.toLowerCase()) {
      case 'neutral':
        if (supportScore == 3) {
          if (movementEnergy == 'low' && gestureLevel == 'none') {
            visualStatus = 'Düşük görsel enerji';
          } else {
            visualStatus = 'Doğal';
          }
        } else {
          if (movementEnergy == 'high' || movementEnergy == 'chaotic') {
            visualStatus = 'Çok aktif';
          } else if (posture == 'closed') {
            visualStatus = 'Kapalı duruş';
          } else {
            visualStatus = supportScore == 2 ? 'Kısmen uyumlu' : 'Beden pasif';
          }
        }
        break;
        
      case 'sad':
        if (supportScore == 3) {
          if (movementEnergy == 'low' && gestureLevel == 'none' && stability == 'stable') {
            visualStatus = 'Çok statik';
          } else {
            visualStatus = 'Beden duyguyu destekliyor';
          }
        } else {
          if (movementEnergy == 'high' || movementEnergy == 'chaotic' || movementEnergy == 'medium') {
            visualStatus = 'Beden çok aktif';
          } else if (posture == 'open' && (gestureLevel == 'strong' || gestureLevel == 'excessive')) {
            visualStatus = 'Beden duyguyu desteklemiyor';
          } else {
            visualStatus = supportScore == 2 ? 'Kısmen uyumlu' : 'Çok statik';
          }
        }
        break;
        
      case 'angry':
        if (supportScore == 3) {
          visualStatus = 'Beden duyguyu destekliyor';
        } else {
          if (movementEnergy == 'low') {
            visualStatus = 'Yüz belirgin, beden pasif';
          } else if (gestureLevel == 'none') {
            visualStatus = 'Jest eksik';
          } else if (movementEnergy == 'chaotic') {
            visualStatus = 'Kontrolsüz hareket';
          } else if (posture == 'closed' || posture == 'slouched') {
            visualStatus = 'Düşük fiziksel güç';
          } else {
            visualStatus = 'Kısmen uyumlu';
          }
        }
        break;
        
      case 'disgust':
        if (supportScore == 3) {
          visualStatus = 'Beden duyguyu destekliyor';
        } else {
          if (posture == 'neutral' && movementEnergy == 'low') {
            visualStatus = 'Beden nötr kalıyor';
          } else if (posture == 'neutral') {
            visualStatus = 'Tepki zayıf';
          } else if (movementEnergy == 'high' || movementEnergy == 'chaotic') {
            visualStatus = 'Abartılı tepki';
          } else {
            visualStatus = 'Tepki zayıf';
          }
        }
        break;
        
      case 'happy':
        if (supportScore == 3) {
          visualStatus = 'Görsel olarak uyumlu';
        } else {
          if (movementEnergy == 'low') {
            visualStatus = 'Enerji düşük';
          } else if (posture == 'closed') {
            visualStatus = 'Yüz olumlu, beden kapalı';
          } else if (gestureLevel == 'none') {
            visualStatus = 'Jest eksik';
          } else if (movementEnergy == 'chaotic' || gestureLevel == 'excessive') {
            visualStatus = 'Çok aktif';
          } else {
            visualStatus = 'Kısmen uyumlu';
          }
        }
        break;
        
      case 'surprise':
        if (supportScore == 3) {
          visualStatus = 'Beden reaksiyonu destekliyor';
        } else {
          if (movementEnergy == 'low' && gestureLevel == 'none') {
            visualStatus = 'Tepki bedene ulaşmıyor';
          } else if (movementEnergy == 'low') {
            visualStatus = 'Tepki zayıf';
          } else if (movementEnergy == 'high' || movementEnergy == 'chaotic') {
            visualStatus = 'Abartılı tepki';
          } else {
            visualStatus = 'Kısmen uyumlu';
          }
        }
        break;
        
      case 'contempt':
        if (supportScore == 3) {
          if (posture == 'neutral' && movementEnergy == 'low') {
            visualStatus = 'Tepki zayıf';
          } else {
            visualStatus = 'Kontrollü';
          }
        } else {
          if (movementEnergy == 'high' || movementEnergy == 'chaotic') {
            visualStatus = 'Abartılı tepki';
          } else if (gestureLevel == 'strong' || gestureLevel == 'excessive') {
            visualStatus = 'Jest çok güçlü';
          } else {
            visualStatus = 'Kısmen uyumlu';
          }
        }
        break;
        
      default:
        visualStatus = supportScore == 3
            ? 'Beden duyguyu destekliyor'
            : (supportScore == 2 ? 'Kısmen uyumlu' : 'Beden duyguyu desteklemiyor');
    }
    
    if (visualStatus.isEmpty) {
      visualStatus = supportScore == 3
          ? 'Beden duyguyu destekliyor'
          : (supportScore == 2 ? 'Kısmen uyumlu' : 'Beden duyguyu desteklemiyor');
    }
    
    return VisualAnalysisResult(
      mainSource: 'face',
      mainEmotion: emotion,
      faceConfidence: faceConfidence,
      visualStatus: visualStatus,
      supportScore: supportScore,
      poseSupport: poseSupport,
      ui: VisualUiResult(
        title: 'Görsel Analiz',
        label: _capitalize(emotion),
        status: visualStatus,
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }
}

class _DecisionResult {
  final String emotion;
  final bool isAccepted;

  const _DecisionResult({
    required this.emotion,
    required this.isAccepted,
  });
}
