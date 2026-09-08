import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';

class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({super.key});

  @override
  State<CharacterSelectionScreen> createState() => _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<TriadModel> _triads = [];
  bool _isLoading = true;
  String _selectedId = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTriads();
  }

  Future<void> _loadTriads() async {
    try {
      final triads = await _firestoreService.getTriads();
      if (mounted) {
        setState(() {
          _triads = triads;
          _isLoading = false;
          if (triads.isNotEmpty) {
            final hasHamlet = triads.any((t) => t.id == 'hamlet');
            _selectedId = hasHamlet ? 'hamlet' : triads.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Tiradlar Yükleniyor...',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: AppColors.onSurfaceVariant.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'Tiradlar yüklenirken hata oluştu',
                style: theme.textTheme.headlineMedium!.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium!.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadTriads();
                },
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (_triads.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Kayıtlı tirad bulunamadı.',
            style: theme.textTheme.headlineMedium,
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;
    final selectedChar = _triads.firstWhere((t) => t.id == _selectedId, orElse: () => _triads.first);

    return Scaffold(
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
          Container(
            margin: EdgeInsets.only(right: isDesktop ? 64.0 : 16.0),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.outlineVariant, width: 2),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCcVllWSghplwg8V7LjkSgZLryn2rS5sdiejtpsakhqF52-bNEVFq5TSmukgrRLg5qMDfCz133mst1M1j91zjOF8jqdVHw5iYRO4OwjRPLj73RbkQCXMU911r4jL-f_pWdWTMfyy3rNO8rsRHyYRBTCvSxvSzvR2_dMx6sd_MB2_bn6lugUjuUs0IDVaKnD26_j2NEdOrNYWkoWT0K_hDjl3UWWLbo0lP0fWenOL6nYum_G2qadk4qeoHQnWfcVCuK8qbiuSOIFoa4',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Center(
              child: Column(
                children: [
                  Text(
                    'Karakterini Seç',
                    style: theme.textTheme.headlineLarge!.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI PROVA PARTNERİNİ VE ROLÜNÜ BELİRLE',
                    style: theme.textTheme.labelLarge!.copyWith(
                      letterSpacing: 2.0,
                      color: AppColors.onSurfaceVariant.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Bento row/column layout
            isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Character Cards + Emotion Badge
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCharacterCarousel(),
                            const SizedBox(height: 24),
                            _buildEmotionTargetChip(selectedChar),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      // Right: Details canvas
                      Expanded(
                        flex: 5,
                        child: _buildDetailsCanvas(theme, selectedChar),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildCharacterCarousel(),
                      const SizedBox(height: 24),
                      _buildEmotionTargetChip(selectedChar),
                      const SizedBox(height: 24),
                      _buildDetailsCanvas(theme, selectedChar),
                    ],
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
                    isActive: false,
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

  Widget _buildCharacterCarousel() {
    return SizedBox(
      height: 340,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: _triads.map((char) {
          final isSelected = char.id == _selectedId;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedId = char.id;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 16, bottom: 8, top: 8),
              width: 220,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: isSelected ? 3.0 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.18)
                        : AppColors.primary.withOpacity(0.04),
                    blurRadius: isSelected ? 16 : 8,
                    offset: Offset(0, isSelected ? 6 : 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    // Gray scaled Image
                    Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(isSelected ? 0.2 : 0.7),
                              Colors.black.withOpacity(0.9),
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcOver,
                        child: Image.network(
                          char.imageUrl,
                          fit: BoxFit.cover,
                          color: isSelected ? null : Colors.grey,
                          colorBlendMode: isSelected ? null : BlendMode.saturation,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.black45),
                        ),
                      ),
                    ),
                    // Titles
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            char.name,
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            char.author,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmotionTargetChip(TriadModel char) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.sentiment_dissatisfied_outlined,
                  color: AppColors.onTertiaryFixedVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'HEDEF DUYGU: ${char.targetEmotion.toUpperCase()}',
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: AppColors.onTertiaryFixedVariant,
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.4),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCanvas(ThemeData theme, TriadModel char) {
    return Container(
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondaryContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            char.title,
            style: theme.textTheme.headlineMedium!.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            char.desc,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),

          // Stats bento row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatBox('AI Analizi', char.aiScore, Icons.analytics_outlined),
              _buildStatBox('Zorluk', char.difficulty, Icons.bolt_outlined),
              _buildStatBox('Süre', char.duration, Icons.schedule_outlined),
            ],
          ),
          const SizedBox(height: 32),

          // Rehearsal start action
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/rehearsal', arguments: char);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('PROVAYI BAŞLAT'),
                  SizedBox(width: 8),
                  Icon(Icons.play_arrow),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Bu oturum sonrasında ses ve yüz ifadesi analizi gerçekleştirilecektir.',
              style: theme.textTheme.labelMedium!.copyWith(
                color: AppColors.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
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
}

// _CharacterData removed in favor of TriadModel
