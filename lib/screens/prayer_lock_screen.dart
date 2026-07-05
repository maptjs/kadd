import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prayer.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'rug_scan_screen.dart';

/// Shown (via a full-screen native Activity, see android_additions/) when a
/// locked app is foregrounded during an active post-Athan lock window.
class PrayerLockScreen extends StatelessWidget {
  final PrayerName prayer;
  const PrayerLockScreen({super.key, required this.prayer});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lockedApps = state.apps.where((a) => a.isEnabled).take(2).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(prayer.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 6),
                Text('أذان ${prayer.labelAr}', style: AppTextStyles.kufi(size: 26)),
                Text('أُذّن قبل ${state.delayMinutesAfterAthan} دقائق — ${state.cityLabel}',
                    style: AppTextStyles.body(size: 12, color: AppColors.textFaint)),
                const SizedBox(height: 18),
                Container(
                  width: 120,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.signal, width: 2),
                  ),
                  child: const Text('🔒', style: TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 14),
                Text(
                  'تطبيقاتك مقفلة الآن. صوّر سجادة صلاتك لتفتحها.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(size: 12.5, color: AppColors.textDim),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.signal,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RugScanScreen(prayer: prayer)),
                  ),
                  child: Text('صوّر السجادة الآن', style: AppTextStyles.kufi(size: 14, color: const Color(0xFF1A0D08))),
                ),
                const SizedBox(height: 20),
                ...lockedApps.map((app) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Text(app.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(app.nameAr, style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600)),
                                  Text('مقفل حتى التحقق', style: AppTextStyles.body(size: 11, color: AppColors.textFaint)),
                                ],
                              ),
                            ),
                            const Text('🔒'),
                          ],
                        ),
                      ),
                    )),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'سيُفتح كل شيء تلقائيًا بمجرد التعرف على السجادة، بلا عقلات هذه المرة',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(size: 11, color: AppColors.textFaint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
