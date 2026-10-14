import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/pill_button.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('404',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 72,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text("Oops! That page doesn't exist.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 16)),
                const SizedBox(height: 32),
                PillButton(
                  label: 'Return Home',
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          '/home', (r) => false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}