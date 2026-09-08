import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/ai/ai_analysis_service.dart';
import '../services/ai/ai_post_processor.dart';
import '../services/ai/websocket_service.dart';
import '../services/ai/audio_stream_controller.dart';

class LiveRehearsalScreen extends StatefulWidget {
  const LiveRehearsalScreen({super.key});

  @override
  State<LiveRehearsalScreen> createState() => _LiveRehearsalScreenState();
}

class _LiveRehearsalScreenState extends State<LiveRehearsalScreen> {
  late String _characterName;
  TriadModel? _selectedTriad;
  final List<double> _waveformHeights = List.generate(40, (index) => 0.2 + (index % 5) * 0.15);
  bool _isConnecting = false;
  String? _connectionError;
  DateTime? _lastMsgTime;
  bool _showDataTimeoutWarning = false;
  Timer? _dataTimeoutMonitorTimer;
  late Timer _waveformTimer;
  double _volumeLevel = 0.45;
  final Random _random = Random();
  bool _isEyeTrackingPing = false;
  late Timer _pingTimer;

  // Rehearsal State
  bool _isRecording = false;
  int _timerSeconds = 0;
  Timer? _recordingTimer;

  // Real-time server streaming
  final WebSocketService _webSocketService = WebSocketService();
  late final AudioStreamController _audioStreamController;
  
  // Sentence/script progression
  List<String> _sentences = [];
  int _currentSentenceIndex = 0;
  String _liveTranscriptText = "";

  // Camera & AI members
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isModelInitialized = false;
  final AiAnalysisService _aiAnalysisService = AiAnalysisService();
  final AiPostProcessor _aiPostProcessor = AiPostProcessor();
  bool _isProcessingFrame = false;
  DateTime? _lastProcessedTime;
  List<List<double>>? _faceLandmarks;
  List<List<double>>? _poseLandmarks;
  bool _showLandmarks = false;
  String? _activeCoachingMessage;
  Timer? _coachingTipTimer;

  String _faceEmotion = "neutral";
  FaceStatus _faceStatus = FaceStatus.noFace;
  Map<String, double> _faceConfidences = {};
  VisualAnalysisResult? _visualAnalysisResult;
  String _soundEmotion = 'neutral';
  bool _hasVoiceEmotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Retrieve character name or triad from route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is TriadModel) {
      _selectedTriad = args;
      _characterName = _selectedTriad!.name;
      _sentences = _selectedTriad!.script
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      final name = (args is String) ? args : 'Hamlet';
      _characterName = name;
      _loadTriadFromDb(name);
    }
  }

  Future<void> _loadTriadFromDb(String name) async {
    try {
      final FirestoreService firestoreService = FirestoreService();
      final triads = await firestoreService.getTriads();
      final match = triads.firstWhere(
        (t) => t.name.toLowerCase() == name.toLowerCase() || t.id.toLowerCase() == name.toLowerCase(),
        orElse: () => triads.first,
      );
      if (mounted) {
        setState(() {
          _selectedTriad = match;
          _characterName = match.name;
          _sentences = match.script
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading triad from DB: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _audioStreamController = AudioStreamController(_webSocketService);
    
    // Bind real-time microphone volume to waveform heights and level bar
    _audioStreamController.volumeStream.listen((vol) {
      if (mounted && _isRecording) {
        setState(() {
          _volumeLevel = vol;
          // Shift heights and add a new dynamic height proportional to actual microphone input
          _waveformHeights.removeAt(0);
          _waveformHeights.add((vol * 0.7) + (_random.nextDouble() * 0.2) + 0.1);
        });
      }
    });

    // Initialize AI models and Camera
    _initializeAiAndCamera();

    // Eye tracking ping animation simulation
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _isEyeTrackingPing = !_isEyeTrackingPing;
        });
      }
    });
  }

  Future<void> _initializeAiAndCamera() async {
    // 1. Initialize AI service
    final initialized = await _aiAnalysisService.initialize();
    debugPrint("-------------------------------------------------------------");
    debugPrint("AI Models Initialization: $initialized");
    debugPrint("-------------------------------------------------------------");
    if (mounted) {
      setState(() {
        _isModelInitialized = initialized;
      });
    }
    // 2. Initialize Camera
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint("No cameras found");
        return;
      }
      
      // Select front camera if available, otherwise first camera
      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        
        // Start streaming camera frames directly
        await _cameraController!.startImageStream((CameraImage image) {
          _processCameraImage(image);
        });
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final controller = _cameraController;
    if (controller == null || !_isCameraInitialized || !_isModelInitialized || !mounted) return;
    if (_isProcessingFrame) return;

    final now = DateTime.now();
    if (_lastProcessedTime != null && now.difference(_lastProcessedTime!).inMilliseconds < 150) {
      return; // Limit to ~6.6 FPS
    }

    _isProcessingFrame = true;
    _lastProcessedTime = now;

    try {
      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes[1].bytes;
      final vPlane = image.planes[2].bytes;

      final yRowStride = image.planes[0].bytesPerRow;
      final uRowStride = image.planes[1].bytesPerRow;
      final vRowStride = image.planes[2].bytesPerRow;
      final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      final width = image.width;
      final height = image.height;

      // Use the camera sensor orientation from the local non-null reference safely
      final rotation = controller.description.sensorOrientation;

      final results = await _aiAnalysisService.processImageFrame(
        yPlane: yPlane,
        uPlane: uPlane,
        vPlane: vPlane,
        yRowStride: yRowStride,
        uRowStride: uRowStride,
        vRowStride: vRowStride,
        uvPixelStride: uvPixelStride,
        width: width,
        height: height,
        rotation: rotation,
        view: 'front',
      );

      if (results != null && mounted) {
        // 1. Map raw results to CombinedAnalysisResult
        final faceResMap = results['faceResult'] as Map?;
        final bodyResMap = results['bodyResult'] as Map?;

        final faceLmsRaw = results['faceLandmarks'] as List<dynamic>?;
        final poseLmsRaw = results['poseLandmarks'] as List<dynamic>?;

        // Parse landmarks safely
        List<List<double>>? parsedFaceLms;
        if (faceLmsRaw != null && faceLmsRaw.isNotEmpty) {
          parsedFaceLms = faceLmsRaw.map((lm) => (lm as List<dynamic>).map((v) => (v as num).toDouble()).toList()).toList();
        }

        List<List<double>>? parsedPoseLms;
        if (poseLmsRaw != null && poseLmsRaw.isNotEmpty) {
          parsedPoseLms = poseLmsRaw.map((lm) => (lm as List<dynamic>).map((v) => (v as num).toDouble()).toList()).toList();
        }

        // Construct raw result for post processor
        final rawResult = CombinedAnalysisResult(
          faceResult: FaceEmotionResult.fromMap(faceResMap ?? {}),
          bodyResult: BodyEmotionResult.fromMap(bodyResMap ?? {}),
          timestamp: results['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        );

        // 2. Post-process to filter predictions based on quality gates
        final processedResult = _aiPostProcessor.process(
          rawResult,
          faceLandmarks: parsedFaceLms,
          poseLandmarks: parsedPoseLms,
        );

        final faceRes = processedResult.faceResult;

        setState(() {
          _faceEmotion = faceRes.emotion;
          _faceStatus = faceRes.status;
          _faceConfidences = faceRes.confidences;
          _faceLandmarks = parsedFaceLms;
          _poseLandmarks = parsedPoseLms;
          _visualAnalysisResult = processedResult.visualAnalysis;
        });

        if (_isRecording && _webSocketService.isConnected) {
          final poseSup = processedResult.visualAnalysis?.poseSupport;
          _webSocketService.sendVisualEmotion(
            _faceEmotion,
            landmarksCount: parsedFaceLms?.length ?? 0,
            posture: poseSup?.posture ?? 'neutral',
            gesture: poseSup?.gestureLevel ?? 'none',
            energy: poseSup?.movementEnergy ?? 'low',
          );
        }

        // Print results to terminal
        debugPrint("================== CAMERA FRAME AI ANALYSIS ==================");
        debugPrint("Face Status: $_faceStatus | Emotion: $_faceEmotion");
        debugPrint("Face Confidences: $_faceConfidences");
        debugPrint("Visual Analysis: $_visualAnalysisResult");
        debugPrint("==============================================================");
        if (parsedFaceLms != null) {
          debugPrint("Face Landmarks Count: ${parsedFaceLms.length}");
        }
        if (parsedPoseLms != null) {
          debugPrint("Pose Landmarks Count: ${parsedPoseLms.length}");
        }
        debugPrint("-----------------------------------------------------------------");
      }
    } catch (e) {
      debugPrint("Error in _processCameraImage: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy': return '😊';
      case 'sad': return '😢';
      case 'surprise': return '😲';
      case 'fear': return '😨';
      case 'disgust': return '🤢';
      case 'angry': return '😡';
      case 'contempt': return '😏';
      case 'uncertain': return '🤔';
      case 'neutral':
      default:
        return '😐';
    }
  }

  String _getEmotionTr(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy': return 'MUTLU';
      case 'sad': return 'ÜZGÜN';
      case 'surprise': return 'ŞAŞIRMIŞ';
      case 'fear': return 'KORKU';
      case 'disgust': return 'TIKSİNTİ';
      case 'angry': return 'ÖFKELİ';
      case 'contempt': return 'AŞAĞILAYICI';
      case 'uncertain': return 'BELİRSİZ';
      case 'neutral':
      default:
        return 'NÖTR';
    }
  }

  Color _getStatusColor(FaceStatus status) {
    if (status == FaceStatus.active) {
      return Colors.greenAccent;
    } else if (status == FaceStatus.noFace) {
      return Colors.redAccent;
    } else {
      return Colors.orangeAccent;
    }
  }

  Future<void> _startRehearsal() async {
    if (_cameraController == null || !_isCameraInitialized) return;

    setState(() {
      _isConnecting = true;
      _connectionError = null;
      _showDataTimeoutWarning = false;
      _lastMsgTime = null;
      _hasVoiceEmotion = false;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final triadId = _selectedTriad != null
        ? _selectedTriad!.id
        : _characterName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

    try {
      // Connect to server (using dynamically retrieved host from Firestore)
      final firestoreService = FirestoreService();
      final host = await firestoreService.getServerHost();
      await _webSocketService.connect(uid, triadId, host: host);
      
      // Start audio streaming
      await _audioStreamController.startStreaming();

      // Listen to connection status to detect network drops
      _webSocketService.connectionStatus.listen((isConnected) {
        if (mounted && _isRecording && !isConnected) {
          setState(() {
            _connectionError = "Sunucu ile bağlantı kesildi! Lütfen internet bağlantınızı kontrol edin.";
          });
          _finishRehearsal();
        }
      });

      // Listen to live transcripts
      _webSocketService.liveTranscript.listen((text) {
        if (mounted) {
          setState(() {
            _lastMsgTime = DateTime.now();
            _showDataTimeoutWarning = false;
            _liveTranscriptText = text;
            _checkSpeechProgress(text);
          });
        }
      });
      
      // Listen to incoming gemma coach messages and audio analysis updates
      _webSocketService.messages.listen((msg) {
        if (mounted) {
          setState(() {
            _lastMsgTime = DateTime.now();
            _showDataTimeoutWarning = false;
          });
          if (msg['type'] == 'coaching') {
            setState(() {
              _activeCoachingMessage = msg['message'];
            });
          } else if (msg['type'] == 'audio_analysis') {
            setState(() {
              _soundEmotion = msg['emotion'] ?? 'neutral';
              _hasVoiceEmotion = true;
            });
          }
        }
      });

      if (mounted) {
        setState(() {
          _isRecording = true;
          _isConnecting = false;
          _timerSeconds = 0;
          _currentSentenceIndex = 0;
          _liveTranscriptText = "";
          _lastMsgTime = DateTime.now();
        });
      }

      // Start timer
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _timerSeconds++;
          });
        }
      });

      // Start timeout checker for expected data
      _dataTimeoutMonitorTimer?.cancel();
      _dataTimeoutMonitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _isRecording) {
          final now = DateTime.now();
          if (_lastMsgTime != null && now.difference(_lastMsgTime!).inSeconds >= 8) {
            setState(() {
              _showDataTimeoutWarning = true;
            });
          }
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isRecording = false;
          _connectionError = "Sunucuya veya internete bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.";
        });
      }
      debugPrint("WebSocket/Audio stream connection error: $e");
    }
  }

  void _checkSpeechProgress(String text) {
    if (_sentences.isEmpty || _currentSentenceIndex >= _sentences.length) return;
    
    final currentSentence = _sentences[_currentSentenceIndex];
    final cleanSentence = currentSentence.toLowerCase().replaceAll(RegExp(r'[^\w\sçğıöşüÇĞİÖŞÜ]'), '');
    final cleanTranscript = text.toLowerCase().replaceAll(RegExp(r'[^\w\sçğıöşüÇĞİÖŞÜ]'), '');
    
    final words = cleanSentence.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();

    if (words.isEmpty) {
      if (cleanTranscript.contains(cleanSentence)) {
        _advanceSentence();
      }
      return;
    }
    
    int matchCount = 0;
    for (final word in words) {
      if (cleanTranscript.contains(word)) {
        matchCount++;
      }
    }
    
    final matchRatio = matchCount / words.length;
    if (matchRatio >= 0.40) {
      _advanceSentence();
    }
  }

  void _advanceSentence() {
    if (_currentSentenceIndex < _sentences.length - 1) {
      setState(() {
        _currentSentenceIndex++;
      });
    }
  }

  Future<void> _finishRehearsal() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _dataTimeoutMonitorTimer?.cancel();

    try {
      await _audioStreamController.stopStreaming();
      _webSocketService.disconnect();
    } catch (e) {
      debugPrint("Error stopping WebSocket streams: $e");
    }

    try {
      setState(() {
        _isRecording = false;
      });

      final title = _selectedTriad != null ? _selectedTriad!.title : 'Tirad Provası';

      // Brief delay to allow backend to finish writing database records
      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        // Navigate replacement to the report screen
        Navigator.pushReplacementNamed(
          context,
          '/report',
          arguments: title,
        );
      }
    } catch (e) {
      debugPrint("Error finishing rehearsal: $e");
    }
  }



  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Prova Ayarları',
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'AI Landmark İzlerini Göster',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Kamera görüntüsü üzerinde yüz ve vücut çizgilerini çizer.',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    value: _showLandmarks,
                    onChanged: (bool value) {
                      setSheetState(() {
                        _showLandmarks = value;
                      });
                      setState(() {
                        _showLandmarks = value;
                      });
                    },
                  ),
                  const Divider(color: AppColors.outlineVariant, height: 24),
                  // Informational Volume slider
                  Text(
                    'Mikrofon Hassasiyeti',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.surfaceContainerHighest,
                    value: 0.8,
                    onChanged: (val) {},
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }



  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _pingTimer.cancel();
    _recordingTimer?.cancel();
    _dataTimeoutMonitorTimer?.cancel();
    _audioStreamController.dispose();
    _webSocketService.disconnect();
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }
    _cameraController?.dispose();
    _aiAnalysisService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        automaticallyImplyLeading: false,
        titleSpacing: isDesktop ? 64.0 : 16.0,
        title: Row(
          children: [
            const Icon(Icons.theater_comedy, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_characterName - SAHNE 3',
                  style: theme.textTheme.headlineMedium!.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isModelInitialized ? Colors.greenAccent : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isModelInitialized ? 'AI MODEL HAZIR' : 'AI MODEL BAŞLATILIYOR',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showLandmarks = !_showLandmarks;
              });
            },
            icon: Icon(
              _showLandmarks ? Icons.analytics : Icons.analytics_outlined,
              color: _showLandmarks ? AppColors.primary : AppColors.onSurface,
            ),
            tooltip: 'Landmarkları Göster/Gizle',
          ),
          const SizedBox(width: 8),
          Container(
            margin: EdgeInsets.only(right: isDesktop ? 64.0 : 16.0),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.outlineVariant, width: 2),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuD0i09ZK4CajStHXzGYhhu-bMWimhhNl4csU7etG8ua6JDcpNcAOybM7S_GTf7R_BhAdwDJTw0olNX3xtRzpF2za9h535lLMyZluhgGuI3qBLYu6dhfW11HQLC9FBZD_lBlJU4zmDX3nTg1pM2sGppe44soO63QQWEtyfG1mnAy_yODrX4ll-28_1A44IVG8FpFmLyjII4u2FJTf8qHNA2aW6By8Lli_SK93_L5FSbCk3J8blY9JmJ5V8cNxVAe7_t6SCMdZGw3688',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Live Camera Preview Background or network image fallback
          Positioned.fill(
            child: (_isCameraInitialized && _cameraController != null)
                ? ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: width,
                        height: width * _cameraController!.value.aspectRatio,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CameraPreview(_cameraController!),
                            ),
                            if (_showLandmarks)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: LandmarkPainter(
                                    faceLandmarks: _faceLandmarks,
                                    poseLandmarks: _poseLandmarks,
                                    isFrontCamera: _cameraController!.description.lensDirection == CameraLensDirection.front,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDoee3MXbQqOlxKyoATLm1_4_YxNjZQQhE7VyjVL2ChRkjtLotGRogXrd9jcxohl9xt47U2qtPLytMpX6q6-hgm9XPp6PtIEHF5jpzZwKaO1CBnr7vOn7YyOv2poL0rud3_ijMfJeK8kACToNrjtWha98yDkPNkl7S1qDxKlFtB89_g4G_Xcn7M7o-uiNxJAE5pELTlvHMKN4WLOz3qPTuGB_-roUiMVSOrkDLUmYWvRZ-MjBZzQfAOQPDasHSGeevR0vwUjSVEsjM',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.black38),
                  ),
          ),

          // 2. Camera Haze Overlay (Soft tint - set to 0 opacity)
          Positioned.fill(
            child: Container(
              color: AppColors.surface.withOpacity(0.0),
            ),
          ),

          // 3. UI Content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64.0 : 16.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Unified Visual & Sound Analysis Cards side-by-side
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildVisualAnalysisCard(theme)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSoundAnalysisCard(theme)),
                      ],
                    ),
                  ),

                  const Spacer(),

                  if (_activeCoachingMessage != null) ...[
                    _buildCoachingBanner(theme, _activeCoachingMessage!),
                    const SizedBox(height: 16),
                  ],

                  // 2. Transcript Tracking (Transkript Takibi)


                  // 3. Shortened Sentence Card at the bottom
                  Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24, width: 1.0),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _currentSentenceIndex > 0
                                  ? () => setState(() => _currentSentenceIndex--)
                                  : null,
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                              color: Colors.white,
                              disabledColor: Colors.white24,
                            ),
                            Expanded(
                              child: Container(
                                height: 50,
                                alignment: Alignment.center,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: Text(
                                    _sentences.isNotEmpty
                                        ? _sentences[_currentSentenceIndex]
                                        : 'Replik yükleniyor...',
                                    key: ValueKey<int>(_currentSentenceIndex),
                                    style: GoogleFonts.hankenGrotesk(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      height: 1.2,
                                      shadows: const [
                                        Shadow(color: Colors.black, blurRadius: 6, offset: Offset(1, 1))
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _currentSentenceIndex < _sentences.length - 1
                                  ? () => setState(() => _currentSentenceIndex++)
                                  : null,
                              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                              color: Colors.white,
                              disabledColor: Colors.white24,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CÜMLE ${_currentSentenceIndex + 1} / ${_sentences.length}',
                              style: GoogleFonts.hankenGrotesk(
                                color: AppColors.primaryContainer,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            if (_isRecording)
                              ElevatedButton(
                                onPressed: _finishRehearsal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  minimumSize: const Size(100, 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Seansı Bitir',
                                      style: theme.textTheme.headlineMedium!.copyWith(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.stop_circle_outlined, size: 14),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // 4. Data Timeout Warning Banner
          if (_showDataTimeoutWarning)
            Positioned(
              top: 140,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                opacity: _showDataTimeoutWarning ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade700),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync_problem, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sunucudan veya mikrofondan veri akışı bekleniyor... Lütfen konuşmaya devam edin.',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4b. Mid-Rehearsal Connection Error Banner
          if (_connectionError != null && _isRecording)
            Positioned(
              top: 140,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'İnternet bağlantınızı kontrol edin. Sunucu ile bağlantı kesildi!',
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Rehearsal Start Overlay / Connection Error UI
          if (!_isRecording)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      padding: const EdgeInsets.all(28.0),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_circle_outline,
                            color: AppColors.primary,
                            size: 64,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _selectedTriad?.title ?? 'Tirad Provası',
                            style: theme.textTheme.headlineMedium!.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedTriad?.author ?? '',
                            style: theme.textTheme.labelMedium!.copyWith(
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'AI Acting Coach ile prova yapmaya başlamak için aşağıdaki butona basın. Prova boyunca ses tonunuz ve yüz ifadeleriniz gerçek zamanlı analiz edilecektir.',
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: AppColors.onSurfaceVariant,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          
                          if (_connectionError != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.error.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.error),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _connectionError!,
                                      style: theme.textTheme.labelMedium!.copyWith(
                                        color: AppColors.onErrorContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isConnecting ? null : _startRehearsal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: _isConnecting
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('BAĞLANILIYOR...'),
                                      ],
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('PROVAYI BAŞLAT'),
                                        SizedBox(width: 8),
                                        Icon(Icons.play_arrow),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSoundAnalysisCard(ThemeData theme) {
    if (!_hasVoiceEmotion && _isRecording) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SES ANALİZİ',
              style: theme.textTheme.labelMedium!.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    }

    final String emoji = _getEmotionEmoji(_soundEmotion);
    final String label = _getEmotionTr(_soundEmotion);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SES ANALİZİ',
                style: theme.textTheme.labelMedium!.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        style: theme.textTheme.headlineMedium!.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _volumeLevel,
                        backgroundColor: AppColors.surfaceContainer,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoachingBanner(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI KOÇLUK TAVSİYESİ',
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.headlineMedium!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualAnalysisCard(ThemeData theme) {
    final result = _visualAnalysisResult;
    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'GÖRSEL ANALİZ',
              style: theme.textTheme.labelMedium!.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
          ],
        ),
      );
    }

    final String emotion = result.mainEmotion;
    final String emoji = _getEmotionEmoji(emotion);
    final String label = result.ui.label;
    final String status = result.visualStatus;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GÖRSEL ANALİZ',
                style: theme.textTheme.labelMedium!.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(emotion == 'uncertain' ? FaceStatus.uncertain : FaceStatus.active),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _getEmotionTr(label),
                        style: theme.textTheme.headlineMedium!.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Durum: $status',
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LandmarkPainter extends CustomPainter {
  final List<List<double>>? faceLandmarks;
  final List<List<double>>? poseLandmarks;
  final bool isFrontCamera;

  LandmarkPainter({
    required this.faceLandmarks,
    required this.poseLandmarks,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Face Landmarks (Green translucent dots)
    if (faceLandmarks != null) {
      final Paint facePaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.65)
        ..style = PaintingStyle.fill;

      for (final lm in faceLandmarks!) {
        if (lm.length >= 2) {
          final double rawX = lm[0];
          final double rawY = lm[1];
          final double x = isFrontCamera ? (1.0 - rawX) * size.width : rawX * size.width;
          final double y = rawY * size.height;
          canvas.drawCircle(Offset(x, y), 1.5, facePaint);
        }
      }
    }

    // 2. Draw Pose Landmarks (Cyan lines and joints)
    if (poseLandmarks != null && poseLandmarks!.length >= 33) {
      final Paint linePaint = Paint()
        ..color = Colors.cyanAccent.withOpacity(0.8)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final Paint jointPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.fill;

      // Define body skeleton connections for upper body
      const connections = [
        [11, 12], // Left shoulder to right shoulder
        [11, 13], // Left shoulder to left elbow
        [13, 15], // Left elbow to left wrist
        [12, 14], // Right shoulder to right elbow
        [14, 16], // Right elbow to right wrist
        [11, 23], // Left shoulder to left hip
        [12, 24], // Right shoulder to right hip
        [23, 24], // Left hip to right hip
      ];

      // Draw connection lines
      for (final connection in connections) {
        final int startIdx = connection[0];
        final int endIdx = connection[1];

        final startLm = poseLandmarks![startIdx];
        final endLm = poseLandmarks![endIdx];

        // Only draw if visibility is high enough (e.g. > 0.3)
        final double startVis = startLm.length >= 4 ? startLm[3] : 0.9;
        final double endVis = endLm.length >= 4 ? endLm[3] : 0.9;

        if (startVis > 0.3 && endVis > 0.3) {
          final double sx = isFrontCamera ? (1.0 - startLm[0]) * size.width : startLm[0] * size.width;
          final double sy = startLm[1] * size.height;

          final double ex = isFrontCamera ? (1.0 - endLm[0]) * size.width : endLm[0] * size.width;
          final double ey = endLm[1] * size.height;

          canvas.drawLine(Offset(sx, sy), Offset(ex, ey), linePaint);
        }
      }

      // Draw joint circles (shoulders, elbows, wrists, hips)
      const joints = [11, 12, 13, 14, 15, 16, 23, 24];
      for (final idx in joints) {
        final lm = poseLandmarks![idx];
        final double vis = lm.length >= 4 ? lm[3] : 0.9;
        if (vis > 0.3) {
          final double x = isFrontCamera ? (1.0 - lm[0]) * size.width : lm[0] * size.width;
          final double y = lm[1] * size.height;
          canvas.drawCircle(Offset(x, y), 5.0, jointPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant LandmarkPainter oldDelegate) {
    return oldDelegate.faceLandmarks != faceLandmarks ||
        oldDelegate.poseLandmarks != poseLandmarks ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}

class _PulsingRedDot extends StatefulWidget {
  const _PulsingRedDot();

  @override
  State<_PulsingRedDot> createState() => _PulsingRedDotState();
}

class _PulsingRedDotState extends State<_PulsingRedDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

