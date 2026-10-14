import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/section_title.dart';

class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const SectionTitle('About Alight Creators', accent: true),
        const SizedBox(height: 10),
        const Text(
          'Learn • Create • Improve',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Text(
            'Alight Creators is a community-built library of step-by-step '
            'Alight Motion tutorials. We break down the techniques behind '
            'clean transitions, smooth keyframes and export settings that '
            'survive platform compression — so you can spend less time '
            'guessing and more time editing.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 22),
        const SectionTitle('Why Alight Creators?'),
        const SizedBox(height: 14),
        for (final item in const [
          ['Beginner friendly', 'Start from your very first composition.'],
          ['Practical guides', 'Every tutorial ends with a finished result.'],
          ['Free to learn', 'No paywalls, no accounts required to browse.'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item[0],
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item[1],
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '© $year Alight Creators',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: AppColors.background,
      ),
      body: const SafeArea(top: false, child: AboutTab()),
    );
  }
}