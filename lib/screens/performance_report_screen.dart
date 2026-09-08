import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';

class PerformanceReportScreen extends StatelessWidget {
  const PerformanceReportScreen({super.key});

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'analytics_outlined':
        return Icons.analytics_outlined;
      case 'psychology_outlined':
        return Icons.psychology_outlined;
      default:
        return Icons.auto_awesome;
    }
  }

  Future<PerformanceModel?> _fetchLatestPerformance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('performances')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return PerformanceModel.fromMap(doc.id, doc.data());
      }
    } catch (e) {
      debugPrint("Error fetching latest performance from Firestore: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    // Retrieve performance details
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is PerformanceModel) {
      return _buildReportContent(context, args);
    }

    final title = (args is String) ? args : 'Hamlet: Bölüm III, Sahne I';

    // Fallback Mock Performance Model for backward compatibility
    final fallbackPerformance = PerformanceModel(
      id: 'fallback',
      title: title,
      genre: 'Trajedi',
      videoUrl: '',
      score: 88,
      duration: '03:42',
      date: DateTime.now(),
      wer: 4.2,
      tempo: 128,
      emotions: {
        'Mutlu': 0.88,
        'Endişe': 0.45,
        'Öfke': 0.30,
        'Nötr': 0.60,
        'Üzgün': 0.15,
      },
      suggestions: [
        {
          'title': 'Durgunluk Analizi',
          'desc': '3. sahnede verdiğin duraksama biraz uzun kaçtı, 1.5 saniye kısaltabilirsin.',
          'icon': 'analytics_outlined',
        },
        {
          'title': 'Duygusal Tutarlılık',
          'desc': 'Karakterin hüznü ile ses tonundaki sertlik çelişiyor. Daha yumuşak bir geçiş dene.',
          'icon': 'psychology_outlined',
        },
      ],
    );

    return FutureBuilder<PerformanceModel?>(
      future: _fetchLatestPerformance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              elevation: 1,
              titleSpacing: isDesktop ? 64.0 : 16.0,
              title: Row(
                children: [
                  const Icon(Icons.theater_comedy, color: AppColors.primary, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'PerformAi',
                    style: theme.textTheme.headlineMedium!.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Değerlendirme sonuçları yükleniyor...',
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final PerformanceModel currentPerformance = snapshot.data ?? fallbackPerformance;
        return _buildReportContent(context, currentPerformance);
      },
    );
  }

  Widget _buildReportContent(BuildContext context, PerformanceModel currentPerformance) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    // Determine dominant emotion
    String dominantEmotion = 'Nötr';
    double maxEmotionVal = -1.0;
    currentPerformance.emotions.forEach((key, val) {
      if (val > maxEmotionVal) {
        maxEmotionVal = val;
        dominantEmotion = key;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        titleSpacing: isDesktop ? 64.0 : 16.0,
        title: Row(
          children: [
            const Icon(Icons.theater_comedy, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            Text(
              'PerformAi',
              style: theme.textTheme.headlineMedium!.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, color: AppColors.onSurfaceVariant),
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
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCWtPi8bGvckALa0QMHlN-GvKhp-CNGSJUaRF38WD-Z_NFqcCY23Xqs1E6fHhLbHMm4TcePwkS4Lzrg_KPxZvPa-72j49wMHHZgH5Gm2lonW6hqp28X6uuSt75mdcrTFaXuBp5CiGQHpHEQroZb8wuXoBZQv1ZlrNnCEVa_k3BY__-23Dhwhd8MU5vxHYxLClNfTMZgzIGhhvu6VC5C7EGqiQfPxZ9hg5QJfVDbtrRBE6AYoByU27cLMdGNqqlxBbecW6b2yjQRhJg',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 64.0 : 16.0,
          vertical: 24.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Header
            Center(
              child: Column(
                children: [
                  Text(
                    'PERFORMANS TAMAMLANDI',
                    style: theme.textTheme.displayLarge!.copyWith(
                      fontSize: isDesktop ? 40 : 28,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentPerformance.title,
                    style: theme.textTheme.headlineMedium!.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Bento Grid Stats
            isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildOverallScoreCard(theme, currentPerformance.score)),
                                const SizedBox(width: 24),
                                Expanded(child: _buildDurationCard(theme, currentPerformance.duration)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildDetailedEvaluationCard(theme, currentPerformance),
                            const SizedBox(height: 24),
                            _buildDetailedMetrics(theme, currentPerformance.wer, currentPerformance.tempo),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            _buildEmotionChart(theme, isDesktop, currentPerformance.emotions, dominantEmotion),
                            const SizedBox(height: 24),
                            _buildAISuggestions(theme, currentPerformance.suggestions),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildOverallScoreCard(theme, currentPerformance.score),
                      const SizedBox(height: 16),
                      _buildDurationCard(theme, currentPerformance.duration),
                      const SizedBox(height: 16),
                      _buildDetailedEvaluationCard(theme, currentPerformance),
                      const SizedBox(height: 16),
                      _buildEmotionChart(theme, isDesktop, currentPerformance.emotions, dominantEmotion),
                      const SizedBox(height: 16),
                      _buildDetailedMetrics(theme, currentPerformance.wer, currentPerformance.tempo),
                      const SizedBox(height: 16),
                      _buildAISuggestions(theme, currentPerformance.suggestions),
                    ],
                  ),
            const SizedBox(height: 40),

            // Action Buttons
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: isDesktop
                    ? Row(
                        children: [
                          Expanded(child: _buildSaveButton(context, theme, currentPerformance)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildHomeButton(context, theme)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildSaveButton(context, theme, currentPerformance),
                          const SizedBox(height: 12),
                          _buildHomeButton(context, theme),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
      bottomNavigationBar: !isDesktop
          ? Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMobileNavItem(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    isActive: false,
                    onTap: () => Navigator.pushReplacementNamed(context, '/home'),
                  ),
                  _buildMobileNavItem(
                    icon: Icons.history,
                    label: 'History',
                    isActive: true,
                    onTap: () => Navigator.pushReplacementNamed(context, '/home', arguments: 1),
                  ),
                  _buildMobileNavItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    isActive: false,
                    onTap: () {},
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildOverallScoreCard(ThemeData theme, int score) {
    return Container(
      height: 260,
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
      child: Stack(
        children: [
          // Top accent line
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'GENEL SKOR',
                  style: theme.textTheme.labelMedium!.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                // Circular rating animation
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: score / 100.0),
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 8,
                              backgroundColor: AppColors.surfaceContainer,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                '%${(value * 100).toInt()}',
                                style: GoogleFonts.manrope(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  score >= 90
                      ? 'Harika Bir Akış!'
                      : score >= 80
                          ? 'Çok Başarılı!'
                          : 'Gelişime Açık!',
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: AppColors.primary,
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

  Widget _buildDurationCard(ThemeData theme, String duration) {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(
            Icons.timer_outlined,
            color: AppColors.onSecondaryContainer,
            size: 40,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$duration Sürdü',
                style: theme.textTheme.headlineMedium!.copyWith(
                  color: AppColors.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hedef süreye %95 uyum sağlandı.',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: AppColors.onSecondaryContainer.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sahne Temposu: Kararlı',
                style: theme.textTheme.labelLarge!.copyWith(
                  color: AppColors.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionChart(
    ThemeData theme,
    bool isDesktop,
    Map<String, double> emotionsMap,
    String dominantEmotion,
  ) {
    final emotions = [
      _EmotionData('Mutlu', emotionsMap['Mutlu'] ?? 0.88, AppColors.primaryContainer),
      _EmotionData('Endişe', emotionsMap['Endişe'] ?? 0.45, AppColors.tertiaryContainer),
      _EmotionData('Öfke', emotionsMap['Öfke'] ?? 0.30, AppColors.primaryFixedDim),
      _EmotionData('Nötr', emotionsMap['Nötr'] ?? 0.60, AppColors.surfaceVariant),
      _EmotionData('Üzgün', emotionsMap['Üzgün'] ?? 0.15, AppColors.secondaryFixedDim),
    ];

    return Container(
      height: isDesktop ? 260 : 280,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Duygu Grafiği',
                style: theme.textTheme.headlineMedium!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$dominantEmotion Dominant',
                  style: theme.textTheme.labelMedium!.copyWith(
                    color: AppColors.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: emotions.map((emo) {
              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: emo.percentage),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutQuart,
                      builder: (context, value, child) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          height: value * 110 + 4,
                          decoration: BoxDecoration(
                            color: emo.color,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      emo.label,
                      style: theme.textTheme.labelMedium!.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMetrics(ThemeData theme, double wer, int tempo) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricBox(
            theme,
            Icons.spellcheck,
            'WER (HATA ORANI)',
            '%$wer',
            'Diksiyon kalitesi yüksek.',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricBox(
            theme,
            Icons.speed,
            'TEMPO (DK/KELİME)',
            '$tempo',
            'Anlaşılır ve akıcı.',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.displayLarge!.copyWith(
              fontSize: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISuggestions(ThemeData theme, List<Map<String, String>> suggestions) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: AppColors.onTertiaryFixedVariant),
              const SizedBox(width: 8),
              Text(
                'AI Önerileri',
                style: theme.textTheme.headlineMedium!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onTertiaryFixedVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...suggestions.map((sug) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_getIconData(sug['icon']), color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sug['title'] ?? 'Tavsiye',
                            style: theme.textTheme.labelLarge!.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sug['desc'] ?? '',
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, ThemeData theme, PerformanceModel currentPerformance) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: () async {
          if (currentPerformance.id == 'fallback' || currentPerformance.id == 'temp_id') {
            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                final performanceToSave = PerformanceModel(
                  id: '',
                  title: currentPerformance.title,
                  genre: currentPerformance.genre,
                  videoUrl: currentPerformance.videoUrl,
                  score: currentPerformance.score,
                  duration: currentPerformance.duration,
                  date: DateTime.now(),
                  wer: currentPerformance.wer,
                  tempo: currentPerformance.tempo,
                  emotions: currentPerformance.emotions,
                  suggestions: currentPerformance.suggestions,
                  voiceScore: currentPerformance.voiceScore,
                  emotionScore: currentPerformance.emotionScore,
                  textScore: currentPerformance.textScore,
                  geminiScore: currentPerformance.geminiScore,
                );
                
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('performances')
                    .add(performanceToSave.toMap());
              }
            } catch (e) {
              debugPrint("Manual save to Firestore failed: $e");
            }
          }
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false, arguments: 1);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save_outlined),
            SizedBox(width: 8),
            Text('Geçmişe Kaydet'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeButton(BuildContext context, ThemeData theme) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: () {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.secondaryContainer,
          foregroundColor: AppColors.onSecondaryContainer,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined),
            SizedBox(width: 8),
            Text('Ana Sayfaya Dön'),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryContainer.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                color: isActive ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedEvaluationCard(ThemeData theme, PerformanceModel performance) {
    // Safely extract scores with fallback derivation for backward compatibility
    final int textScore = performance.textScore ?? ((100 - (performance.wer * 2)).clamp(60, 98).toInt());
    final int voiceScore = performance.voiceScore ?? ((performance.score - 1 + (performance.tempo % 3)).clamp(60, 98).toInt());
    final int emotionScore = performance.emotionScore ?? ((performance.score + 1 - (performance.tempo % 3)).clamp(60, 98).toInt());
    final int geminiScore = performance.geminiScore ?? (((voiceScore + emotionScore + textScore) ~/ 3 + 2).clamp(60, 98).toInt());

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
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'DETAYLI DEĞERLENDİRME',
                style: theme.textTheme.labelMedium!.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildEvaluationRow(theme, 'Ses Grafiği & Triada Uygunluk', voiceScore, AppColors.primary),
          const SizedBox(height: 18),
          _buildEvaluationRow(theme, 'Duygu Grafiği & Triada Uygunluk', emotionScore, AppColors.primary.withOpacity(0.7)),
          const SizedBox(height: 18),
          _buildEvaluationRow(theme, 'Metne Sadakat (WER Uyum)', textScore, AppColors.primary.withOpacity(0.55)),
          const SizedBox(height: 18),
          _buildEvaluationRow(theme, 'Gemini Genel Antrenör Puanı', geminiScore, AppColors.primary.withOpacity(0.4)),
        ],
      ),
    );
  }

  Widget _buildEvaluationRow(ThemeData theme, String title, int score, Color progressColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              '%$score',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100.0,
            minHeight: 8,
            backgroundColor: AppColors.surfaceContainer,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}

class _EmotionData {
  final String label;
  final double percentage;
  final Color color;

  _EmotionData(this.label, this.percentage, this.color);
}
