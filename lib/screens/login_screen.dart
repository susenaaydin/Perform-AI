import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isSignUp = false;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignUp) {
        await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt başarılı! Sahneye yönlendiriliyorsunuz...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Kimlik doğrulama hatası oluştu.';
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('user-not-found') || errStr.contains('invalid-credential')) {
          errorMsg = 'E-posta veya şifre hatalı. Lütfen kontrol edin.';
        } else if (errStr.contains('wrong-password')) {
          errorMsg = 'Hatalı şifre. Lütfen tekrar deneyin.';
        } else if (errStr.contains('email-already-in-use')) {
          errorMsg = 'Bu e-posta adresi zaten kullanımda.';
        } else if (errStr.contains('weak-password')) {
          errorMsg = 'Şifre çok zayıf. En az 6 karakter olmalıdır.';
        } else if (errStr.contains('invalid-email')) {
          errorMsg = 'Geçersiz e-posta adresi.';
        } else if (errStr.contains('network-request-failed')) {
          errorMsg = 'İnternet bağlantınızı kontrol edin.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Google ile giriş başarısız oldu.';
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('network-request-failed')) {
          errorMsg = 'İnternet bağlantınızı kontrol edin.';
        } else if (errStr.contains('sign_in_failed') || errStr.contains('account-selection-required')) {
          errorMsg = 'Google hesabı seçilirken veya doğrulanırken hata oluştu.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Subtle Background Image with 5% opacity
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuD5DajFIefi1d-MOhg7n0nAMX0mJtGls5as4HghPiUtaY6F-zOEWJaFcD4MGCq7cCrk91jnWusjy5nvNoKDyOWJrhZcTTAJlQnCjQGxS0jTgUe8m3ZZA7oNTDUxtRR_kRqrjfKO-qKP7dvMCYMeEhvs3vWAKRlMAK5VRe_qR71khJCEu7MvucMVjLNM7McnpMrL-SCIOdBuOJRd4Z1TPZRtqczXYBim0aMHSYzwsCjBjzkpvPh8BFHReIRTTvsEjzAE9jHM1I_2_-Y',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: AppColors.background),
              ),
            ),
          ),

          // 2. Subtle Ambient Glow Circles
          // Top-right soft glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryFixedDim.withOpacity(0.15),
              ),
            ),
          ),
          // Bottom-left soft glow
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tertiaryFixedDim.withOpacity(0.15),
              ),
            ),
          ),

          // 3. Main Login Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    // Logo and Title
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                      child: const Icon(
                        Icons.theater_comedy,
                        size: 56,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PerformAi',
                      style: theme.textTheme.displayLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SAHNE SENİN İÇİN HAZIRLANIYOR',
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: AppColors.onSurfaceVariant.withOpacity(0.8),
                        letterSpacing: 2.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Auth Card
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(28.0),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.2),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name Field (only for Registration)
                            if (_isSignUp) ...[
                              Text(
                                'AD SOYAD',
                                style: theme.textTheme.labelLarge!.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nameController,
                                keyboardType: TextInputType.name,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.person_outline),
                                  hintText: 'John Doe',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Lütfen adınızı ve soyadınızı girin';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Email Field
                            Text(
                              'E-POSTA',
                              style: theme.textTheme.labelLarge!.copyWith(
                                  color: AppColors.secondary,
                                ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.mail_outline),
                                hintText: 'example@performa.ai',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Lütfen e-posta adresinizi girin';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Geçersiz e-posta formatı';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password Field
                            Text(
                              'ŞİFRE',
                              style: theme.textTheme.labelLarge!.copyWith(
                                  color: AppColors.secondary,
                                ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.lock_outline),
                                hintText: '••••••••',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Lütfen şifrenizi girin';
                                }
                                if (value.length < 6) {
                                  return 'Şifre en az 6 karakter olmalıdır';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            // Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleAuth,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _isSignUp ? 'Kayıt Ol' : 'Giriş Yap',
                                            style: theme.textTheme.labelLarge!.copyWith(
                                              color: AppColors.onPrimary,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward, size: 20),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppColors.outlineVariant.withOpacity(0.3),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text(
                                    'VEYA',
                                    style: theme.textTheme.labelMedium!.copyWith(
                                      color: AppColors.outlineVariant,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppColors.outlineVariant.withOpacity(0.3),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Google Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _handleGoogleSignIn,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: AppColors.surfaceContainer,
                                  side: BorderSide(
                                    color: AppColors.outlineVariant.withOpacity(0.5),
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://lh3.googleusercontent.com/aida-public/AB6AXuD5_QAENyfJHtZzfP9HTuzWaLtvtW7ES2NNx9SQ4TrhZQ5jfmbjTitI2T_-kXY0BwqxR-9VDijB5hL6n-dsKurzqMe0cIYPrj2nIr6W8URvpBDkm16ILnxRCroCHby0YiirAYzqGf8wCEiDwnvcADv4398ld2gilcm0noEtOfDkrR1diJlJW9lG01xgnLFpNeZg44YS7OA_pbULEp0RnsreE0qpuryoVY1JvUuUiQYB3Vr7g4R-voO7HdV5TaUT5kaOWvvmtXSqm3c',
                                      width: 20,
                                      height: 20,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.g_mobiledata, color: AppColors.secondary),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Google ile Giriş Yap',
                                      style: theme.textTheme.labelLarge!.copyWith(
                                        color: AppColors.onSurface,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Registration footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUp ? 'Zaten hesabın var mı? ' : 'Hesabın yok mu? ',
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                              _formKey.currentState?.reset();
                            });
                          },
                          child: Text(
                            _isSignUp ? 'Giriş Yap' : 'Kayıt Ol',
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Tech Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBadge(Icons.psychology_outlined, 'AI ANALİZİ'),
                        const SizedBox(width: 24),
                        _buildBadge(Icons.videocam_outlined, '4K KAYIT'),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label) {
    return Opacity(
      opacity: 0.6,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.tertiary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: AppColors.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}
