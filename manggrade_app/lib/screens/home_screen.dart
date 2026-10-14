import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/mango_illustration.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const HomeScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cream,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Row(
              children: [
                BrandText(fontSize: 22),
                Spacer(),
                OfflineChip(),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 190,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Classify Mango',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Capture or select an image to estimate its quality class.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => onNavigate(2),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                          ),
                          child: const Text(
                            'Start Scan',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    flex: 3,
                    child: MangoIllustration(width: 108, height: 128),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Explore',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 11,
              mainAxisSpacing: 11,
              childAspectRatio: 1.35,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MangoCard(
                  title: 'Classification History',
                  subtitle: 'View saved results',
                  icon: Icons.history_rounded,
                  onTap: () => onNavigate(1),
                ),
                MangoCard(
                  title: 'PNS Grading Guide',
                  subtitle: 'Learn the standard',
                  icon: Icons.menu_book_rounded,
                  onTap: () => onNavigate(3),
                ),
                MangoCard(
                  title: 'About the Model',
                  subtitle: 'MobileNetV3 details',
                  icon: Icons.memory_rounded,
                  onTap: () => onNavigate(4),
                ),
                MangoCard(
                  title: 'How to Use',
                  subtitle: 'Capture tips',
                  icon: Icons.help_outline_rounded,
                  onTap: () => onNavigate(2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
