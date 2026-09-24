import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/provider/auth_provider.dart';
import '../navigation/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class EliteSettingsAppBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final bool isCompact;
  final bool showBackButton;

  const EliteSettingsAppBar({
    super.key,
    required this.title,
    this.onBackPressed,
    this.isCompact = true,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool actuallyShowBack = showBackButton || onBackPressed != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.white.withValues(alpha: 0.05), width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8.w : 16.0, 
          vertical: isCompact ? 8.h : 8.0
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (actuallyShowBack)
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.white,
                    size: isCompact ? null : 20.0,
                  ),
                  onPressed: onBackPressed ?? () {
                    final authProv = context.read<AuthProvider>();

                    if (authProv.isPasswordRecoveryMode) {
                      authProv.cancelPasswordRecovery();
                    }

                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.home);
                    }
                  },
                )
              else
                const SizedBox(width: 48.0), // Spacer to maintain centering
              
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2.adaptive(context).copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              const Opacity(
                opacity: 0,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
