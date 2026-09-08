import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'history_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static MainNavigationScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainNavigationScreenState>();
  }

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _initialized = false;

  final List<Widget> _tabs = [
    const HomeTab(),
    const HistoryTab(),
    const ProfileTab(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('tab')) {
        _currentIndex = args['tab'] as int;
      } else if (args is int) {
        _currentIndex = args;
      }
      _initialized = true;
    }
  }

  void setIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
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
          if (isDesktop) ...[
            TextButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 0;
                });
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    'Home',
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: _currentIndex == 0 ? AppColors.primary : AppColors.onSurfaceVariant,
                      fontWeight: _currentIndex == 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (_currentIndex == 0)
                    Positioned(
                      bottom: -8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 1;
                });
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    'History',
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: _currentIndex == 1 ? AppColors.primary : AppColors.onSurfaceVariant,
                      fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (_currentIndex == 1)
                    Positioned(
                      bottom: -8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 2;
                });
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    'Profile',
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: _currentIndex == 2 ? AppColors.primary : AppColors.onSurfaceVariant,
                      fontWeight: _currentIndex == 2 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (_currentIndex == 2)
                    Positioned(
                      bottom: -8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 24),
          ],
          // User Profile Photo
          GestureDetector(
            onTap: () {
              setState(() {
                _currentIndex = 2;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: isDesktop ? 64.0 : 16.0),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _currentIndex == 2 ? AppColors.primary : AppColors.outlineVariant,
                  width: _currentIndex == 2 ? 2 : 1,
                ),
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuCl9WGjQWew8ZyvuC4yVKZQeW51MVc1XlKBwP9OVBlhO47pd6lKFqj5VAGan8OaULpQtUmzDjTOeyr6pQCGJ_mQZTI1CXVpHJqqQR4_yXQxETW8XqfxyhYfZjkCsiTnk3FUtekh8L0pJ2toRaSmM3n8FA_5uc4xMtlY20dC4G73mc_H1Y1AngXyfn4Ok9iD0qE274dLD2iiCALs3DvJv2RdeW0-9TLWa6G79ob61V2jAWLfzEC5UzN6SchHfzNCTJelFp52YkB_Jo0',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      floatingActionButton: (isDesktop && _currentIndex == 0)
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, '/selection'),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      bottomNavigationBar: !isDesktop
          ? Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
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
                    icon: _currentIndex == 0 ? Icons.home : Icons.home_outlined,
                    label: 'Home',
                    isActive: _currentIndex == 0,
                    onTap: () {
                      setState(() {
                        _currentIndex = 0;
                      });
                    },
                  ),
                  _buildMobileNavItem(
                    icon: Icons.history,
                    label: 'History',
                    isActive: _currentIndex == 1,
                    onTap: () {
                      setState(() {
                        _currentIndex = 1;
                      });
                    },
                  ),
                  _buildMobileNavItem(
                    icon: _currentIndex == 2 ? Icons.person : Icons.person_outline,
                    label: 'Profile',
                    isActive: _currentIndex == 2,
                    onTap: () {
                      setState(() {
                        _currentIndex = 2;
                      });
                    },
                  ),
                ],
              ),
            )
          : null,
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
          color: isActive ? AppColors.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
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
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 16.0,
        vertical: 24.0,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(28.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Large Profile Avatar
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuCl9WGjQWew8ZyvuC4yVKZQeW51MVc1XlKBwP9OVBlhO47pd6lKFqj5VAGan8OaULpQtUmzDjTOeyr6pQCGJ_mQZTI1CXVpHJqqQR4_yXQxETW8XqfxyhYfZjkCsiTnk3FUtekh8L0pJ2toRaSmM3n8FA_5uc4xMtlY20dC4G73mc_H1Y1AngXyfn4Ok9iD0qE274dLD2iiCALs3DvJv2RdeW0-9TLWa6G79ob61V2jAWLfzEC5UzN6SchHfzNCTJelFp52YkB_Jo0',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // User info
              Text(
                'Kaan Öztürk',
                style: theme.textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Profesyonel Oyuncu',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              const Divider(color: AppColors.surfaceContainer),
              const SizedBox(height: 16),
              // Profile stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildProfileStat('24', 'Seans'),
                  _buildProfileStat('%88', 'Ort. Skor'),
                  _buildProfileStat('İleri', 'Seviye'),
                ],
              ),
              const SizedBox(height: 32),
              // Actions
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/');
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'ÇIKIŞ YAP',
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
