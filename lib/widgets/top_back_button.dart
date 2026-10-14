import 'package:flutter/material.dart';

import '../theme.dart';

/// Fixed top-left back button used across all screens that need one.
/// Place it as the last child of a `Stack` so it floats above the content.
class TopBackButton extends StatelessWidget {
  const TopBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap ?? () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back,
                        size: 20, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text(
                      'Back',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}