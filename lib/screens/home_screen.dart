import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'main_navigation_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  void _showVideoUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VideoUploadSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;
    
    final String userGreetingName = _currentUser?.displayName ?? 'Sanatçı';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 16.0,
        vertical: 24.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hero Section
          Text(
            'Sahne Senin, $userGreetingName.',
            style: isDesktop ? theme.textTheme.displayLarge : theme.textTheme.headlineLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'AI destekli analizlerle performansını zirveye taşı. Hazırsan başlayalım.',
            style: theme.textTheme.bodyLarge!.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

          // 2. Bento Layout Grid
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Large Featured Card
                    Expanded(
                      flex: 8,
                      child: _buildFeaturedCard(context, theme, 360),
                    ),
                    const SizedBox(width: 24),
                    // Side Cards Stacked
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _buildSideCard(
                            theme,
                            Icons.video_camera_front_outlined,
                            AppColors.secondaryContainer,
                            AppColors.primary,
                            'Video Yükle ve Analiz Et',
                            'Kaydedilmiş performanslarını derinlemesine incele.',
                            'Hemen Başla',
                            () => _showVideoUploadSheet(context),
                          ),
                          const SizedBox(height: 24),
                          _buildSideCard(
                            theme,
                            Icons.psychology_outlined,
                            AppColors.tertiaryFixedDim.withOpacity(0.3),
                            AppColors.tertiary,
                            'Serbest Oyunculuk Modu',
                            'Metin sınırlaması olmadan doğaçlama yeteneğini geliştir.',
                            'Keşfet',
                            () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    // Mobile Bento Flow
                    _buildFeaturedCard(context, theme, 280),
                    const SizedBox(height: 24),
                    _buildSideCard(
                      theme,
                      Icons.video_camera_front_outlined,
                      AppColors.secondaryContainer,
                      AppColors.primary,
                      'Video Yükle ve Analiz Et',
                      'Kaydedilmiş performanslarını derinlemesine incele.',
                      'Hemen Başla',
                      () => _showVideoUploadSheet(context),
                    ),
                    const SizedBox(height: 24),
                    _buildSideCard(
                      theme,
                      Icons.psychology_outlined,
                      AppColors.tertiaryFixedDim.withOpacity(0.3),
                      AppColors.tertiary,
                      'Serbest Oyunculuk Modu',
                      'Metin sınırlaması olmadan doğaçlama yeteneğini geliştir.',
                      'Keşfet',
                      () {},
                    ),
                  ],
                ),
          const SizedBox(height: 48),

          // 3. Recent Work Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Son Çalışmalar',
                style: theme.textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  final navState = MainNavigationScreen.of(context);
                  if (navState != null) {
                    navState.setIndex(1);
                  } else {
                    Navigator.pushReplacementNamed(context, '/home', arguments: 1);
                  }
                },
                child: Text(
                  'Tümünü Gör',
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dynamic recent items from Firestore
          if (_currentUser != null)
            StreamBuilder<List<PerformanceModel>>(
              stream: _firestoreService.streamPerformances(_currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  // Fallback to beautiful placeholder or mock helper
                  return _buildEmptyState(theme);
                }

                final performances = snapshot.data!.take(3).toList();

                return isDesktop
                    ? GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 24,
                        crossAxisSpacing: 24,
                        childAspectRatio: 3.2,
                        children: _buildRecentItemsFromFirestore(context, theme, performances),
                      )
                    : ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: _buildRecentItemsFromFirestore(context, theme, performances)
                            .map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: item,
                                ))
                            .toList(),
                      );
              },
            )
          else
            _buildEmptyState(theme),
          const SizedBox(height: 80), // extra padding for Mobile bottom nav bar
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.video_library_outlined, size: 48, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(
            'Henüz Analiz Yapılmadı',
            style: theme.textTheme.headlineMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Yüklediğiniz videoların AI analiz sonuçları burada listelenecektir.',
            style: theme.textTheme.bodyMedium!.copyWith(color: AppColors.onSurfaceVariant, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(BuildContext context, ThemeData theme, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuDhMcHHaPZ9dxyfhDKvdmWEERUqK78AAH0y2L-h1zft8K3Y5hk4SE_1xAZhzCoh_AUlZDCzcUxovMnNbtuPuYdtBB7vdc4masdJvv1W5WvvEA3KLcId7JhwOR6gPyq40dxSGbdF9j8q152DsK24tHdKys6oMtv5FY_Vn_8Lf4_8EmjXqE0CGzrHA0NKESraFdwrn5u9C9E12mjfgp7BYJHxAogzc7TfYeBpyu02ZdMHFt8Rsh_bEA_LKQsvgBJ89V6IGNZiywfi4gk',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.black87),
              ),
            ),
          ),
          // Dark Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),
          // Contents
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ÖNERİLEN',
                    style: theme.textTheme.labelMedium!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Bottom content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canlı Prova Modu',
                      style: theme.textTheme.headlineLarge!.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Metninizi okurken AI anlık olarak vurgu, tonlama ve mimik analizi yapar.',
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/selection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(180, 48),
                        maximumSize: const Size(220, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('PROVAYA BAŞLA'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideCard(
    ThemeData theme,
    IconData icon,
    Color iconBgColor,
    Color iconColor,
    String title,
    String description,
    String actionText,
    VoidCallback onTap,
  ) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.headlineMedium!.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionText,
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecentItemsFromFirestore(BuildContext context, ThemeData theme, List<PerformanceModel> items) {
    // Generate a list of thumbnail URLs to match performance look
    final imageUrls = [
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBgdt1DuIDIaj2J8UyGR7BveYmgnbp400BtrthdkfXyo5Ol9I_kyeURG9QA2eTPPlHBGROtdP_8H_r7Zi4HjDdeamQLNPzABF4MDoyGUvMkzhKnvFT1ryt2423f8kxoiYgrmMkSfEBqgXoQjY0SGAlsu7xjaT6XIEnwLUx5RXlzi8vGSNiDDBWEUqsybsQk4D2AZ1WcVuncQKV49RGha2qbbP7z_e7OJrurCQscxd6jFPnE4P1hBtfNgzqrVg0nVEM0q4Wn_FCIYaw',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDf7P8zy7fWz00OCkUU9uzslgwWaOWw0RLH5mSU0aJQ64TcMxO28XN1vLb4llKQ1nD0l32Ep-jIY53j784Il-abSScxEATcQTnqaMKVpY5NeERlBJEYaDIzm1_BhBRcJ8Nd9t9_lYgl7EMFZtgtRQSrNwo4a0jMRc9j3sWsvSvNw0gd3bqIv92wdlKgNr92z1_OHjZWqWcnzZDCxTcH2OnVOry7Q7MbIyq23JYQr6DyzC8NERcDYDURNj9QaMr7TGIvdFkmAc-YdxQ',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCsU3kTx6E5b7X5ss5fDnx_hLQxzCmB_2IKyC1u87OiuiTm4B02pOSa_y5XGOsiwdCCOk6D7Jg8PgiBFOi8tmTA2Ter_TjrY8FyK0qNl_yqZWAFz5x3HGdnusCw3afel5S19nO5_w2CpzINVPAPfrx-pZoFcib5IUpwM9VmLse_qlfmIKDx9rR5IL0fiCiDKA5OQPcLRjPkWR9SPbJ9Up2gyIDP1uuVCKP-KYuKOxlXCm_U_b2KMkrFZXvGzE0_l_grctDuf7BmCs8',
    ];

    return items.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final thumbnail = imageUrls[index % imageUrls.length];

      return GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, '/report', arguments: data);
        },
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(thumbnail),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Titles and Progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data.title,
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.genre} • %${data.score} Skor',
                      style: theme.textTheme.labelMedium!.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Linear progress indicator
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: data.score / 100.0,
                        backgroundColor: AppColors.surfaceContainer,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class VideoUploadSheet extends StatefulWidget {
  const VideoUploadSheet({super.key});

  @override
  State<VideoUploadSheet> createState() => _VideoUploadSheetState();
}

class _VideoUploadSheetState extends State<VideoUploadSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _genreController = TextEditingController();

  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();

  XFile? _pickedVideo;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  UploadTask? _uploadTask;

  List<TriadModel> _triads = [];
  TriadModel? _selectedTriad;
  bool _isLoadingTriads = true;

  @override
  void initState() {
    super.initState();
    _loadTriads();
  }

  Future<void> _loadTriads() async {
    try {
      final triads = await _firestoreService.getTriads();
      setState(() {
        _triads = triads;
        if (triads.isNotEmpty) {
          _selectedTriad = triads.first;
          _genreController.text = triads.first.difficulty;
        }
        _isLoadingTriads = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTriads = false;
      });
      debugPrint("Error loading triads for upload: $e");
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (video != null) {
        setState(() {
          _pickedVideo = video;
          // Set a default title based on file name if empty
          if (_titleController.text.isEmpty) {
            final fileNameWithoutExtension = video.name.split('.').first;
            _titleController.text = fileNameWithoutExtension.replaceAll('_', ' ');
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video seçilirken hata oluştu: $e')),
      );
    }
  }

  Future<void> _startUploadAndAnalysis() async {
    if (!_formKey.currentState!.validate() || _pickedVideo == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      _uploadTask = _storageService.uploadVideoTask(
        uid: user.uid,
        file: _pickedVideo!,
      );

      _uploadTask!.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      // Wait for upload completion
      final TaskSnapshot completedSnapshot = await _uploadTask!;
      final downloadUrl = await completedSnapshot.ref.getDownloadURL();

      // Trigger Real Video Analysis on Backend synchronously
      final host = await _firestoreService.getServerHost();
      final protocol = host.startsWith('localhost') || host.startsWith('127.0.0.1') || host.startsWith('10.0.2.2') ? 'http' : 'https';
      final url = Uri.parse('$protocol://$host/api/upload-process');

      final httpClient = HttpClient();
      try {
        final request = await httpClient.postUrl(url);
        request.headers.set('content-type', 'application/json');

        final body = {
          'downloadURL': downloadUrl,
          'user_id': user.uid,
          'triad_id': _selectedTriad?.id ?? 'hamlet',
          'session_mode': 'triad',
          'title': _titleController.text.trim(),
          'genre': _genreController.text.trim(),
        };

        request.write(json.encode(body));
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final responseData = json.decode(responseBody);
          if (responseData['status'] == 'success' && responseData['performance'] != null) {
            final performanceMap = responseData['performance'] as Map<String, dynamic>;
            final newPerformance = PerformanceModel.fromMap(
              performanceMap['id'] ?? 'temp_id',
              performanceMap,
            );

            if (mounted) {
              Navigator.pop(context); // Close bottom sheet
              Navigator.pushNamed(context, '/report', arguments: newPerformance);
            }
            return;
          } else if (responseData['status'] == 'processing' && responseData['performance'] != null) {
            if (mounted) {
              Navigator.pop(context); // Close bottom sheet
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Videonuz yüklendi. Arka planda analiz ediliyor, sonuçlar tamamlandığında Geçmiş tabında belirecektir.'),
                  backgroundColor: AppColors.primary,
                  duration: Duration(seconds: 5),
                ),
              );

              // Switch to History Tab
              final navState = MainNavigationScreen.of(context);
              if (navState != null) {
                navState.setIndex(1);
              }
            }
            return;
          }
        }
        
        throw Exception("Analiz hatası: Sunucu ${response.statusCode} durum kodu döndürdü.");
      } finally {
        httpClient.close();
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: 24 + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'YENİ VİDEO ANALİZİ',
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  if (!_isUploading)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Kaydedilmiş performans videonuzu seçerek yükleyin. AI ses tonlaması ve mimiklerinizi analiz ederek gelişim raporunuzu oluşturacaktır.',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),

              if (_isUploading) ...[
                // Uploading progress view
                Column(
                  children: [
                    const SizedBox(height: 20),
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Videonuz Yükleniyor & Analiz Ediliyor...',
                      style: theme.textTheme.headlineMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '%${(_uploadProgress * 100).toInt()}',
                      style: theme.textTheme.displayLarge!.copyWith(fontSize: 32, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: AppColors.surfaceContainer,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        _uploadTask?.cancel();
                        Navigator.pop(context);
                      },
                      child: const Text('İptal Et', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ] else ...[
                // Input Fields
                Text(
                  'KARAKTER / TİRAD SEÇİMİ',
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                _isLoadingTriads
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    : DropdownButtonFormField<TriadModel>(
                        value: _selectedTriad,
                        isExpanded: true,
                        items: _triads.map((triad) {
                          return DropdownMenuItem<TriadModel>(
                            value: triad,
                            child: Text(
                              triad.title,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTriad = value;
                            if (value != null) {
                              _genreController.text = value.difficulty;
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                const SizedBox(height: 20),

                Text(
                  'PERFORMANS BAŞLIĞI',
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.title),
                    hintText: 'örn. Hamlet - 3. Perde Tiradı',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen bir başlık girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Text(
                  'KATEGORİ VEYA TÜR',
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _genreController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                    hintText: 'Monolog, Klasik, Trajedi, Dram...',
                  ),
                ),
                const SizedBox(height: 24),

                // Video Selector Box
                GestureDetector(
                  onTap: _pickVideo,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        style: BorderStyle.solid,
                        width: 1,
                      ),
                    ),
                    child: _pickedVideo == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.primary),
                              const SizedBox(height: 12),
                              Text(
                                'Bir Video Dosyası Seçin',
                                style: theme.textTheme.labelLarge!.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tıklayarak galeriden bir video seçin (Max 100MB)',
                                style: theme.textTheme.labelMedium!.copyWith(color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 40, color: Colors.green),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  _pickedVideo!.name,
                                  style: theme.textTheme.labelLarge!.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Değiştirmek için tıklayın',
                                style: theme.textTheme.labelMedium!.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),

                // Action buttons
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _pickedVideo == null ? null : _startUploadAndAnalysis,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor: AppColors.surfaceContainerHigh,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Yükle ve Analizi Başlat'),
                        SizedBox(width: 8),
                        Icon(Icons.auto_awesome),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
