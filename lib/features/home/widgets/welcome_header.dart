import 'package:flutter/material.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class WelcomeHeader extends StatelessWidget {
  final bool isCompact;
  const WelcomeHeader({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final String name = authProvider.displayName.toUpperCase();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WELCOME BACK, $name',
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: AppColors.crimson,
                letterSpacing: 2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'READY FOR INTENSITY?',
              style: AppTextStyles.h1.adaptive(context).copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        );
      },
    );
  }
}
