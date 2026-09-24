import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';

class FadeSplashScreen extends StatefulWidget {
  const FadeSplashScreen({super.key});

  @override
  State<FadeSplashScreen> createState() => _FadeSplashScreenState();
}

class _FadeSplashScreenState extends State<FadeSplashScreen> {
  bool _showAffuLabs = true;

  @override
  void initState() {
    super.initState();

    // Show AffuLabs logo for 1.2 seconds, then transition to Rugged branding
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _showAffuLabs = false;
        });

        // Show Rugged branding for another 800ms, then navigate
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            // ELITE NAVIGATION GUARD:
            // Check the GLOBAL router state. If the app has already moved away 
            // from /splash (e.g. pushed an Import Screen on top), ABORT.
            final String currentRoute = appRouter.state.uri.path;
            if (currentRoute != AppRoutes.splash) {
              debugPrint("Splash: Global route changed to $currentRoute. Aborting home redirect.");
              return;
            }

            final authProv = context.read<AuthProvider>();
            if (authProv.isAuthenticated && authProv.isProfileComplete) {
              context.go(AppRoutes.home);
            } else {
              context.go(AppRoutes.login);
            }
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final bool isTablet = screenSize.width >= 600 || screenSize.height >= 600;

    final double maxLogoWidth = isLandscape
        ? (screenSize.height * 0.45).clamp(180.0, 320.0)
        : (isTablet ? 300.0 : 240.w.clamp(180.0, 260.0));
    final double maxLogoHeight = screenSize.height * (isLandscape ? 0.45 : 0.35);

    return Scaffold(
      backgroundColor: AppColors.background, // Pure black background #0D0D0D
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _showAffuLabs
              ? Padding(
                  key: const ValueKey('affulabs'),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxLogoWidth,
                      maxHeight: maxLogoHeight,
                    ),
                    child: Image.asset(
                      'lib/assets/images/affulabs_presents_logo_nobackground.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              : Hero(
                  key: const ValueKey('rugged'),
                  tag: 'branding_title',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      'RUGGED',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displayLarge.adaptive(context).copyWith(
                        color: AppColors.white,
                        fontSize: 80.0, // Force a much larger size
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
