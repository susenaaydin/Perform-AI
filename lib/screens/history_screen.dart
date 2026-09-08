import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    final user = FirebaseAuth.instance.currentUser;
    final FirestoreService firestoreService = FirestoreService();

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Lütfen Giriş Yapın',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Geçmişinizi görmek için giriş yapmalısınız.',
                style: theme.textTheme.bodyMedium!.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<PerformanceModel>>(
      stream: firestoreService.streamPerformances(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        final historyItems = snapshot.data ?? [];
        
        // Calculate statistics dynamically
        final totalSessions = historyItems.length;
        final completedItems = historyItems.where((item) => item.status != 'processing').toList();
        final avgScore = completedItems.isEmpty
            ? 0
            : (completedItems.map((item) => item.score).reduce((a, b) => a + b) / completedItems.length).round();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 64.0 : 16.0,
            vertical: 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Text(
                      'Performans Geçmişi',
                      style: theme.textTheme.headlineLarge!.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Son sahnelerinizi ve gelişim skorlarınızı inceleyin.',
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Stats Bento Row (Total Sessions / Avg Score)
              Row(
                children: [
                  Expanded(
                    child: _buildBentoStatsBox(
                      theme,
                      Icons.event_repeat_outlined,
                      'TOPLAM SEANS',
                      totalSessions.toString(),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildBentoStatsBox(
                      theme,
                      Icons.trending_up,
                      'ORT. SKOR',
                      totalSessions == 0 ? '0/100' : '$avgScore/100',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // History List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Son Performanslar',
                    style: theme.textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Text('Filtrele'),
                    label: const Icon(Icons.filter_list, size: 18),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: theme.textTheme.labelLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (historyItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.video_library_outlined, size: 64, color: AppColors.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz Performans Yok',
                        style: theme.textTheme.headlineMedium!.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'İlk video analizinizi gerçekleştirdikten sonra geçmişinizi burada görebilirsiniz.',
                        style: theme.textTheme.bodyMedium!.copyWith(color: AppColors.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else ...[
                // History Items List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: historyItems.length,
                  itemBuilder: (context, index) {
                    final item = historyItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildHistoryItem(context, theme, item, isDesktop),
                    );
                  },
                ),
              ],
              const SizedBox(height: 80), // Mobile nav offset
            ],
          ),
        );
      },
    );
  }

  Widget _buildBentoStatsBox(ThemeData theme, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium!.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.displayLarge!.copyWith(
                    fontSize: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, ThemeData theme, PerformanceModel item, bool isDesktop) {
    final String formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(item.date);
    final bool isProcessing = item.status == 'processing';
    
    // Determine status badge based on score or status
    String statusLabel = 'Gelişiyor';
    Color statusBgColor = AppColors.secondaryContainer;
    Color statusTextColor = AppColors.onSecondaryContainer;
    
    if (isProcessing) {
      statusLabel = 'İşleniyor';
      statusBgColor = const Color(0xFFFFF1E6);
      statusTextColor = const Color(0xFFD97706);
    } else if (item.score >= 90) {
      statusLabel = 'Mükemmel';
      statusBgColor = AppColors.primaryContainer.withValues(alpha: 0.2);
      statusTextColor = AppColors.onPrimaryContainer;
    } else if (item.score >= 80) {
      statusLabel = 'Başarılı';
      statusBgColor = AppColors.secondaryContainer;
      statusTextColor = AppColors.onSecondaryContainer;
    }

    final imageUrls = [
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBgdt1DuIDIaj2J8UyGR7BveYmgnbp400BtrthdkfXyo5Ol9I_kyeURG9QA2eTPPlHBGROtdP_8H_r7Zi4HjDdeamQLNPzABF4MDoyGUvMkzhKnvFT1ryt2423f8kxoiYgrmMkSfEBqgXoQjY0SGAlsu7xjaT6XIEnwLUx5RXlzi8vGSNiDDBWEUqsybsQk4D2AZ1WcVuncQKV49RGha2qbbP7z_e7OJrurCQscxd6jFPnE4P1hBtfNgzqrVg0nVEM0q4Wn_FCIYaw',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDf7P8zy7fWz00OCkUU9uzslgwWaOWw0RLH5mSU0aJQ64TcMxO28XN1vLb4llKQ1nD0l32Ep-jIY53j784Il-abSScxEATcQTnqaMKVpY5NeERlBJEYaDIzm1_BhBRcJ8Nd9t9_lYgl7EMFZtgtRQSrNwo4a0jMRc9j3sWsvSvNw0gd3bqIv92wdlKgNr92z1_OHjZWqWcnzZDCxTcH2OnVOry7Q7MbIyq23JYQr6DyzC8NERcDYDURNj9QaMr7TGIvdFkmAc-YdxQ',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCsU3kTx6E5b7X5ss5fDnx_hLQxzCmB_2IKyC1u87OiuiTm4B02pOSa_y5XGOsiwdCCOk6D7Jg8PgiBFOi8tmTA2Ter_TjrY8FyK0qNl_yqZWAFz5x3HGdnusCw3afel5S19nO5_w2CpzINVPAPfrx-pZoFcib5IUpwM9VmLse_qlfmIKDx9rR5IL0fiCiDKA5OQPcLRjPkWR9SPbJ9Up2gyIDP1uuVCKP-KYuKOxlXCm_U_b2KMkrFZXvGzE0_l_grctDuf7BmCs8',
    ];
    final imageUrl = imageUrls[item.id.hashCode % imageUrls.length];

    return GestureDetector(
      onTap: isProcessing
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Performans videosu işleniyor. Lütfen analiz tamamlandığında tekrar deneyin.'),
                  backgroundColor: AppColors.secondary,
                ),
              );
            }
          : () {
              Navigator.pushNamed(context, '/report', arguments: item);
            },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isProcessing
                ? const Color(0xFFF59E0B).withOpacity(0.4)
                : AppColors.secondary.withOpacity(0.1),
            width: isProcessing ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isProcessing
                  ? const Color(0xFFF59E0B).withOpacity(0.06)
                  : AppColors.primary.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isDesktop
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: isProcessing
                            ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.headlineMedium!.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(formattedDate, style: theme.textTheme.labelMedium!.copyWith(color: AppColors.onSurfaceVariant)),
                              const SizedBox(width: 8),
                              Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.outlineVariant)),
                              const SizedBox(width: 8),
                              Text(item.genre, style: theme.textTheme.labelMedium!.copyWith(color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Right side
                  Row(
                    children: [
                      if (isProcessing)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Skor', style: theme.textTheme.labelMedium!.copyWith(color: AppColors.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Skor', style: theme.textTheme.labelMedium!.copyWith(color: AppColors.onSurfaceVariant)),
                            Text(
                              '${item.score}',
                              style: theme.textTheme.headlineMedium!.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(width: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: theme.textTheme.labelLarge!.copyWith(
                            color: statusTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        isProcessing ? Icons.hourglass_top_rounded : Icons.chevron_right,
                        color: isProcessing ? const Color(0xFFD97706) : AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: isProcessing
                            ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.headlineMedium!.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(formattedDate, style: theme.textTheme.labelMedium!.copyWith(color: AppColors.onSurfaceVariant)),
                                const SizedBox(width: 8),
                                Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.outlineVariant)),
                                const SizedBox(width: 8),
                                Text(item.genre, style: theme.textTheme.labelMedium!.copyWith(color: AppColors.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.surfaceContainer),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('Skor: ', style: theme.textTheme.labelMedium!.copyWith(color: AppColors.onSurfaceVariant)),
                          if (isProcessing)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            )
                          else
                            Text(
                              '${item.score}',
                              style: theme.textTheme.headlineMedium!.copyWith(
                                fontSize: 18,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: theme.textTheme.labelMedium!.copyWith(
                                color: statusTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isProcessing ? Icons.hourglass_top_rounded : Icons.chevron_right,
                            color: isProcessing ? const Color(0xFFD97706) : AppColors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
