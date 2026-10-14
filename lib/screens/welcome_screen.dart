import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/pill_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/landing_background.webp',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            cacheWidth: 1080,
            errorBuilder: (context, error, stack) {
              debugPrint('Welcome background failed: $error');
              return const SizedBox.shrink();
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xD90C121D),
                  Color(0x7A0C121D),
                  Color(0xE80C121D),
                  AppColors.background,
                ],
                stops: [0, 0.32, 0.72, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 54,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const BrandMark(fontSize: 25, iconSize: 38),
                          const Spacer(flex: 4),
                          const Text.rich(
                            TextSpan(
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 39,
                                height: 1.14,
                                fontWeight: FontWeight.w800,
                                shadows: [
                                  Shadow(
                                    color: Color(0xCC000000),
                                    offset: Offset(0, 2),
                                    blurRadius: 12,
                                  ),
                                  Shadow(
                                    color: Color(0x99000000),
                                    offset: Offset(0, 4),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                              children: [
                                TextSpan(text: 'Elevate Your\n'),
                                TextSpan(
                                  text: 'Motion Design',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    shadows: [
                                      Shadow(
                                        color: Color(0xCC000000),
                                        offset: Offset(0, 2),
                                        blurRadius: 12,
                                      ),
                                      Shadow(
                                        color: Color(0x99000000),
                                        offset: Offset(0, 4),
                                        blurRadius: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Master professional video editing and\nanimation',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              height: 1.45,
                              shadows: [
                                Shadow(
                                  color: Color(0xCC000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 8,
                                ),
                                Shadow(
                                  color: Color(0x99000000),
                                  offset: Offset(0, 2),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(flex: 7),
                          PillButton(
                            label: 'Log In',
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/login'),
                          ),
                          const SizedBox(height: 14),
                          PillButton(
                            label: 'Sign Up',
                            outlined: true,
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/signup'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}