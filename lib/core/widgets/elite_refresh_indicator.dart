import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';

class EliteRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;
  final Color? backgroundColor;

  const EliteRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPro = context.watch<AuthProvider>().isPro;

    return RefreshIndicator(
      color: color ?? AppColors.crimson,
      backgroundColor: backgroundColor ?? AppColors.surface,
      notificationPredicate: (notification) =>
          isPro && defaultScrollNotificationPredicate(notification),
      onRefresh: onRefresh,
      child: child,
    );
  }
}
