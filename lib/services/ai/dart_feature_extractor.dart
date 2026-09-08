import 'dart:math';

class DartFeatureExtractor {
  // Selected landmarks indices for face (116 landmarks)
  static const List<int> selectedFaceLandmarks = [
    1, 2, 4, 5, 6, 7, 13, 14, 17, 19, 33, 46, 52, 53, 55, 58, 61, 63, 65, 66,
    70, 78, 80, 81, 82, 84, 87, 88, 91, 93, 94, 95, 98, 105, 107, 132, 133, 136,
    144, 145, 146, 148, 149, 150, 152, 153, 154, 155, 157, 158, 159, 160, 161,
    163, 168, 172, 173, 176, 178, 181, 191, 195, 197, 234, 246, 249, 263, 276,
    282, 283, 285, 288, 291, 293, 295, 296, 300, 308, 310, 311, 312, 314, 317,
    318, 321, 323, 324, 327, 334, 336, 361, 362, 365, 373, 374, 375, 377, 378,
    379, 380, 381, 382, 384, 385, 386, 387, 388, 390, 397, 398, 400, 402, 405,
    415, 454, 466
  ];

  static const List<int> leftEyeIndices = [
    33, 7, 163, 144, 145, 153, 154, 155, 133, 246, 161, 160, 159, 158, 157, 173
  ];

  static const List<int> rightEyeIndices = [
    263, 249, 390, 373, 374, 380, 381, 382, 362, 466, 388, 387, 386, 385, 384, 398
  ];

  static const List<int> outerLipIndices = [
    61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 308, 324, 318, 402, 317,
    14, 87, 178, 88, 95, 78
  ];

  static const List<int> innerLipIndices = [
    78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308, 324, 318, 402, 317, 14,
    87, 178, 88, 95
  ];

  static const List<List<int>> angleTriplesFace = [
    [61, 13, 291], [61, 14, 291], [78, 13, 308], [78, 14, 308], [61, 0, 291],
    [13, 61, 14], [13, 291, 14], [78, 61, 95], [308, 291, 324], [33, 159, 133],
    [33, 145, 133], [263, 386, 362], [263, 374, 362], [70, 105, 107],
    [336, 334, 300], [55, 65, 52], [285, 295, 282], [234, 1, 454],
    [93, 1, 323], [152, 17, 0]
  ];

  // Helper calculation functions
  static double _dist2d(List<double> p1, List<double> p2) {
    final dx = p1[0] - p2[0];
    final dy = p1[1] - p2[1];
    return sqrt(dx * dx + dy * dy);
  }

  static double _norm3d(List<double> v) {
    return sqrt(v[0] * v[0] + v[1] * v[1] + (v.length > 2 ? v[2] * v[2] : 0.0));
  }

  static double _angle2dOverPi(List<double> pa, List<double> pb, List<double> pc) {
    final ux = pa[0] - pb[0];
    final uy = pa[1] - pb[1];
    final vx = pc[0] - pb[0];
    final vy = pc[1] - pb[1];

    final cross = (ux * vy - uy * vx).abs();
    final dot = ux * vx + uy * vy;

    final angle = atan2(cross, dot);
    return angle / pi;
  }

  static double _polygonArea(List<List<double>> pts, List<int> indices) {
    double area = 0.0;
    final int numPoints = indices.length;
    for (int i = 0; i < numPoints; i++) {
      final int j = (i + 1) % numPoints;
      final p1 = pts[indices[i]];
      final p2 = pts[indices[j]];
      area += p1[0] * p2[1] - p2[0] * p1[1];
    }
    return (area / 2.0).abs();
  }

  static List<double> _meanPoint(List<List<double>> pts, List<int> indices) {
    double sx = 0.0, sy = 0.0, sz = 0.0;
    for (final idx in indices) {
      sx += pts[idx][0];
      sy += pts[idx][1];
      sz += pts[idx][2];
    }
    final len = indices.length.toDouble();
    return [sx / len, sy / len, sz / len];
  }

  /// Extracts 404 dimensional face feature vector from [468, 3] raw landmarks
  static List<double> extractFaceFeatures(List<List<double>> rawLandmarks) {
    if (rawLandmarks.length < 468) {
      throw ArgumentError('Expected face landmarks with length >= 468');
    }

    // 1. Compute Eye centers
    final leftEyeCenter = _meanPoint(rawLandmarks, leftEyeIndices);
    final rightEyeCenter = _meanPoint(rawLandmarks, rightEyeIndices);

    final eyeCenter = [
      (leftEyeCenter[0] + rightEyeCenter[0]) / 2.0,
      (leftEyeCenter[1] + rightEyeCenter[1]) / 2.0,
      (leftEyeCenter[2] + rightEyeCenter[2]) / 2.0,
    ];

    final eyeVec = [
      rightEyeCenter[0] - leftEyeCenter[0],
      rightEyeCenter[1] - leftEyeCenter[1],
    ];

    final eyeDist = _norm3d(eyeVec) + 1e-6;
    final roll = atan2(eyeVec[1], eyeVec[0]);

    // 2. Normalization & Roll Rotation
    final pts = List<List<double>>.generate(rawLandmarks.length, (i) {
      final p = rawLandmarks[i];
      final dx = p[0] - eyeCenter[0];
      final dy = p[1] - eyeCenter[1];
      final dz = p[2] - eyeCenter[2];

      final c = cos(-roll);
      final s = sin(-roll);

      final rx = (c * dx - s * dy) / eyeDist;
      final ry = (s * dx + c * dy) / eyeDist;
      final rz = dz / eyeDist;

      return [rx, ry, rz];
    });

    final List<double> features = [];

    // 3. Selected coordinate features (116 * 3 = 348 features)
    for (final idx in selectedFaceLandmarks) {
      features.add(pts[idx][0]);
      features.add(pts[idx][1]);
      features.add(pts[idx][2]);
    }

    // 4. Engineered Mouth features (13 features)
    final mouthWidth = _dist2d(pts[61], pts[291]);
    final mouthOpen1 = _dist2d(pts[13], pts[14]);
    final mouthOpen2 = _dist2d(pts[82], pts[312]);
    final mouthOpen3 = _dist2d(pts[87], pts[317]);
    final mouthOpen = (mouthOpen1 + mouthOpen2 + mouthOpen3) / 3.0;
    final mar = mouthOpen / (mouthWidth + 1e-6);

    final outerMouthArea = _polygonArea(pts, outerLipIndices);
    final innerMouthArea = _polygonArea(pts, innerLipIndices);

    final mouthCenter = [
      (pts[61][0] + pts[291][0]) / 2.0,
      (pts[61][1] + pts[291][1]) / 2.0,
    ];
    final leftCornerLift = pts[61][1] - mouthCenter[1];
    final rightCornerLift = pts[291][1] - mouthCenter[1];
    final cornerLiftMean = (leftCornerLift + rightCornerLift) / 2.0;
    final cornerLiftDiff = (leftCornerLift - rightCornerLift).abs();

    final mouthSlope = atan2(pts[291][1] - pts[61][1], pts[291][0] - pts[61][0] + 1e-6) / pi;

    features.addAll([
      mouthWidth, mouthOpen1, mouthOpen2, mouthOpen3, mouthOpen, mar,
      outerMouthArea, innerMouthArea, leftCornerLift, rightCornerLift,
      cornerLiftMean, cornerLiftDiff, mouthSlope
    ]);

    // 5. Eye features (6 features)
    final leftEyeWidth = _dist2d(pts[33], pts[133]);
    final rightEyeWidth = _dist2d(pts[263], pts[362]);

    final leftEar = (
      _dist2d(pts[159], pts[145]) +
      _dist2d(pts[158], pts[153]) +
      _dist2d(pts[160], pts[144])
    ) / (3.0 * leftEyeWidth + 1e-6);

    final rightEar = (
      _dist2d(pts[386], pts[374]) +
      _dist2d(pts[385], pts[380]) +
      _dist2d(pts[387], pts[373])
    ) / (3.0 * rightEyeWidth + 1e-6);

    final earMean = (leftEar + rightEar) / 2.0;
    final earDiff = (leftEar - rightEar).abs();

    features.addAll([leftEyeWidth, rightEyeWidth, leftEar, rightEar, earMean, earDiff]);

    // 6. Eyebrow features (5 features)
    final leftEyeCenterNorm = _meanPoint(pts, leftEyeIndices);
    final rightEyeCenterNorm = _meanPoint(pts, rightEyeIndices);

    final leftBrowCenter = _meanPoint(pts, const [70, 63, 105, 66, 107]);
    final rightBrowCenter = _meanPoint(pts, const [336, 296, 334, 293, 300]);

    final leftBrowRaise = _dist2d(leftBrowCenter, leftEyeCenterNorm);
    final rightBrowRaise = _dist2d(rightBrowCenter, rightEyeCenterNorm);

    final browRaiseMean = (leftBrowRaise + rightBrowRaise) / 2.0;
    final browRaiseDiff = (leftBrowRaise - rightBrowRaise).abs();

    final innerBrowDistance = _dist2d(pts[107], pts[336]);

    features.addAll([
      leftBrowRaise, rightBrowRaise, browRaiseMean, browRaiseDiff, innerBrowDistance
    ]);

    // 7. Cheek/jaw/nose proxy features (9 features)
    final leftCheekNose = _dist2d(pts[234], pts[1]);
    final rightCheekNose = _dist2d(pts[454], pts[1]);
    final cheekDiff = (leftCheekNose - rightCheekNose).abs();

    final chinMouth = _dist2d(pts[152], pts[17]);
    final noseMouth = _dist2d(pts[1], pts[13]);
    final noseChin = _dist2d(pts[1], pts[152]);

    final yawProxy = (leftCheekNose - rightCheekNose) / (leftCheekNose + rightCheekNose + 1e-6);
    final pitchProxy = pts[1][1] - ((pts[33][1] + pts[263][1]) / 2.0);

    features.addAll([
      leftCheekNose, rightCheekNose, cheekDiff, chinMouth, noseMouth, noseChin,
      yawProxy, pitchProxy, roll / pi
    ]);

    // 8. Symmetry features (3 features)
    features.addAll([cornerLiftDiff, earDiff, browRaiseDiff]);

    // 9. Angle features (20 features)
    for (final triple in angleTriplesFace) {
      features.add(_angle2dOverPi(pts[triple[0]], pts[triple[1]], pts[triple[2]]));
    }

    // Sanitize any nan or inf
    for (int i = 0; i < features.length; i++) {
      if (features[i].isNaN || features[i].isInfinite) {
        features[i] = 0.0;
      }
    }

    return features;
  }

  // Upper-body pose definitions for static features
  static const int nose = 0;
  static const int leftEar = 7;
  static const int rightEar = 8;
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;
  static const int leftHip = 23;
  static const int rightHip = 24;

  static const List<int> upperBodyLms = [
    nose, leftEar, rightEar, leftShoulder, rightShoulder,
    leftElbow, rightElbow, leftWrist, rightWrist, leftHip, rightHip
  ];

  static const List<int> leftSideLms = [
    leftShoulder, leftElbow, leftWrist, leftHip
  ];

  static const List<int> rightSideLms = [
    rightShoulder, rightElbow, rightWrist, rightHip
  ];

  static const List<List<int>> bodyBones = [
    [leftShoulder, rightShoulder],
    [leftShoulder, leftElbow],
    [leftElbow, leftWrist],
    [rightShoulder, rightElbow],
    [rightElbow, rightWrist],
    [leftShoulder, leftHip],
    [rightShoulder, rightHip],
    [leftHip, rightHip],
    [nose, leftShoulder],
    [nose, rightShoulder]
  ];

  static const List<List<int>> angleTriplesBody = [
    [leftShoulder, leftElbow, leftWrist],
    [rightShoulder, rightElbow, rightWrist],
    [leftElbow, leftShoulder, leftHip],
    [rightElbow, rightShoulder, rightHip],
    [leftShoulder, nose, rightShoulder],
    [leftHip, leftShoulder, rightShoulder],
    [rightHip, rightShoulder, leftShoulder]
  ];

  /// Extracts 92 dimensional static pose features from raw [33, 4] pose landmarks (x, y, z, visibility)
  static List<double> extractStaticBodyFeatures(List<List<double>> rawPose) {
    if (rawPose.length < 33) {
      throw ArgumentError('Expected pose landmarks with length >= 33');
    }

    // 1. Normalization parameters
    final lSh = rawPose[leftShoulder];
    final rSh = rawPose[rightShoulder];
    final lHip = rawPose[leftHip];
    final rHip = rawPose[rightHip];

    final midShoulder = [
      (lSh[0] + rSh[0]) / 2.0,
      (lSh[1] + rSh[1]) / 2.0,
      (lSh[2] + rSh[2]) / 2.0,
    ];
    final midHip = [
      (lHip[0] + rHip[0]) / 2.0,
      (lHip[1] + rHip[1]) / 2.0,
      (lHip[2] + rHip[2]) / 2.0,
    ];
    final center = [
      (midShoulder[0] + midHip[0]) / 2.0,
      (midShoulder[1] + midHip[1]) / 2.0,
      (midShoulder[2] + midHip[2]) / 2.0,
    ];

    final shoulderWidth = _dist2d(lSh, rSh);
    final leftTorso = _dist2d(lSh, lHip);
    final rightTorso = _dist2d(rSh, rHip);
    final torsoLen = (leftTorso + rightTorso) / 2.0;

    final scale = ((shoulderWidth + torsoLen) / 2.0) + 1e-6;

    // Normalize coordinates (x, y, z) and keep visibility (w)
    final pts = List<List<double>>.generate(rawPose.length, (i) {
      final p = rawPose[i];
      return [
        (p[0] - center[0]) / scale,
        (p[1] - center[1]) / scale,
        (p[2] - center[2]) / scale,
        p[3] // visibility
      ];
    });

    final List<double> features = [];

    // 1) Upper body landmark coords: 11 lms * 4 = 44 features
    for (final idx in upperBodyLms) {
      features.addAll([pts[idx][0], pts[idx][1], pts[idx][2], pts[idx][3]]);
    }

    // 2) Bone lengths: 10 features
    for (final bone in bodyBones) {
      features.add(_dist2d(pts[bone[0]], pts[bone[1]]));
    }

    // 3) Joint angles: 7 features
    for (final triple in angleTriplesBody) {
      features.add(_angle2dOverPi(pts[triple[0]], pts[triple[1]], pts[triple[2]]));
    }

    // 4) Shoulder/hip/torso geometry: 7 features
    final shoulderVec = [pts[rightShoulder][0] - pts[leftShoulder][0], pts[rightShoulder][1] - pts[leftShoulder][1]];
    final hipVec = [pts[rightHip][0] - pts[leftHip][0], pts[rightHip][1] - pts[leftHip][1]];

    final shoulderAngle = atan2(shoulderVec[1], shoulderVec[0] + 1e-6) / pi;
    final hipAngle = atan2(hipVec[1], hipVec[0] + 1e-6) / pi;

    final midShoulder2d = [(pts[leftShoulder][0] + pts[rightShoulder][0]) / 2.0, (pts[leftShoulder][1] + pts[rightShoulder][1]) / 2.0];
    final midHip2d = [(pts[leftHip][0] + pts[rightHip][0]) / 2.0, (pts[leftHip][1] + pts[rightHip][1]) / 2.0];

    final torsoVec = [midShoulder2d[0] - midHip2d[0], midShoulder2d[1] - midHip2d[1]];
    final torsoLean = atan2(torsoVec[0], -torsoVec[1] + 1e-6) / pi;

    final headVec = [pts[nose][0] - midShoulder2d[0], pts[nose][1] - midShoulder2d[1]];
    final headOffsetX = headVec[0];
    final headOffsetY = headVec[1];

    features.addAll([
      shoulderAngle, hipAngle, torsoLean, headOffsetX, headOffsetY,
      shoulderWidth / scale, torsoLen / scale
    ]);

    // 5) Signed left/right asymmetry: 10 features
    final signedWristYDiff = pts[leftWrist][1] - pts[rightWrist][1];
    final signedWristXDiff = pts[leftWrist][0] - pts[rightWrist][0];
    final signedElbowYDiff = pts[leftElbow][1] - pts[rightElbow][1];
    final signedElbowXDiff = pts[leftElbow][0] - pts[rightElbow][0];
    final signedShoulderYDiff = pts[leftShoulder][1] - pts[rightShoulder][1];

    final leftElbowAngle = _angle2dOverPi(pts[leftShoulder], pts[leftElbow], pts[leftWrist]);
    final rightElbowAngle = _angle2dOverPi(pts[rightShoulder], pts[rightElbow], pts[rightWrist]);

    final leftShoulderAngle = _angle2dOverPi(pts[leftElbow], pts[leftShoulder], pts[leftHip]);
    final rightShoulderAngle = _angle2dOverPi(pts[rightElbow], pts[rightShoulder], pts[rightHip]);

    features.addAll([
      signedWristYDiff, signedWristXDiff, signedElbowYDiff, signedElbowXDiff, signedShoulderYDiff,
      signedWristYDiff.abs(), signedElbowYDiff.abs(), signedShoulderYDiff.abs(),
      leftElbowAngle - rightElbowAngle, leftShoulderAngle - rightShoulderAngle
    ]);

    // 6) Arm openness/contraction: 9 features
    final wristDistance = _dist2d(pts[leftWrist], pts[rightWrist]);
    final elbowDistance = _dist2d(pts[leftElbow], pts[rightElbow]);
    final shoulderDistance = _dist2d(pts[leftShoulder], pts[rightShoulder]);

    final leftHandToTorso = _dist2d(pts[leftWrist], midShoulder);
    final rightHandToTorso = _dist2d(pts[rightWrist], midShoulder);

    final leftElbowToTorso = _dist2d(pts[leftElbow], midShoulder);
    final rightElbowToTorso = _dist2d(pts[rightElbow], midShoulder);

    features.addAll([
      wristDistance, elbowDistance, shoulderDistance,
      leftHandToTorso, rightHandToTorso, leftElbowToTorso, rightElbowToTorso,
      (leftHandToTorso - rightHandToTorso).abs(),
      (leftElbowToTorso - rightElbowToTorso).abs()
    ]);

    // 7) Visibility features: 5 features
    double upperVisSum = 0.0;
    double upperVisMin = pts[upperBodyLms[0]][3];
    for (final idx in upperBodyLms) {
      final vis = pts[idx][3];
      upperVisSum += vis;
      if (vis < upperVisMin) upperVisMin = vis;
    }
    final upperVisMean = upperVisSum / upperBodyLms.length;

    double leftVisSum = 0.0;
    for (final idx in leftSideLms) {
      leftVisSum += pts[idx][3];
    }
    final leftVisMean = leftVisSum / leftSideLms.length;

    double rightVisSum = 0.0;
    for (final idx in rightSideLms) {
      rightVisSum += pts[idx][3];
    }
    final rightVisMean = rightVisSum / rightSideLms.length;

    features.addAll([
      upperVisMean, upperVisMin, leftVisMean, rightVisMean,
      (leftVisMean - rightVisMean).abs()
    ]);

    // Sanitize any nan or inf
    for (int i = 0; i < features.length; i++) {
      if (features[i].isNaN || features[i].isInfinite) {
        features[i] = 0.0;
      }
    }

    return features;
  }

  /// Builds a [30, 279] TCN sequence feature matrix from a sequence of 30 static [92] frame features
  static List<List<double>> buildBodyMotionSequence(List<List<double>> staticSeq, {String view = 'front'}) {
    if (staticSeq.length != 30) {
      throw ArgumentError('Expected sequence of exactly 30 static features');
    }

    final int numFrames = 30;
    final int staticDim = 92;

    // 1. Calculate Velocity
    final List<List<double>> velocity = List<List<double>>.generate(numFrames, (t) {
      if (t == 0) return List<double>.filled(staticDim, 0.0);
      return List<double>.generate(staticDim, (i) => staticSeq[t][i] - staticSeq[t - 1][i]);
    });

    // 2. Calculate Acceleration
    final List<List<double>> acceleration = List<List<double>>.generate(numFrames, (t) {
      if (t == 0) return List<double>.filled(staticDim, 0.0);
      return List<double>.generate(staticDim, (i) => velocity[t][i] - velocity[t - 1][i]);
    });

    // 3. One-hot view vector
    final List<double> viewOnehot;
    switch (view.toLowerCase().trim()) {
      case 'front':
        viewOnehot = [1.0, 0.0, 0.0];
        break;
      case 'left':
        viewOnehot = [0.0, 1.0, 0.0];
        break;
      case 'right':
        viewOnehot = [0.0, 0.0, 1.0];
        break;
      default:
        viewOnehot = [0.0, 0.0, 0.0]; // unknown
    }

    // 4. Concatenate per frame (92 static + 92 vel + 92 acc + 3 view = 279)
    final List<List<double>> finalSeq = List<List<double>>.generate(numFrames, (t) {
      final List<double> frame = [];
      frame.addAll(staticSeq[t]);
      frame.addAll(velocity[t]);
      frame.addAll(acceleration[t]);
      frame.addAll(viewOnehot);
      return frame;
    });

    return finalSeq;
  }
}
