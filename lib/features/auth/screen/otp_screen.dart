import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:flutter/widget_previews.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/features/auth/widgets/auth_components.dart';

@Preview()
Widget previewOtpScreen() {
  // Dummy initialization for the previewer environment to prevent Supabase crash
  try {
    Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      publishableKey: 'dummy',
    );
  } catch (_) {}

  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: const Scaffold(body: OtpScreen()),
      );
    },
  );
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  bool _isOtpComplete = false;

  @override
  void initState() {
    super.initState();
    for (var controller in _controllers) {
      controller.addListener(_validateOtpState);
    }
  }

  void _validateOtpState() {
    final complete = _controllers.every((c) => c.text.isNotEmpty);
    if (complete != _isOtpComplete) {
      setState(() => _isOtpComplete = complete);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.removeListener(_validateOtpState);
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // ELITE AUTO-VERIFICATION
    // As soon as all boxes are filled, we trigger verification immediately.
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6 && !_isVerifying) {
      // Small delay to allow the UI to show the last digit before the buffer starts
      Future.delayed(const Duration(milliseconds: 100), () => _verifyOtp());
    }
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;

    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      EliteSnackbar.show(context, 'PLEASE ENTER THE FULL 6-DIGIT CODE', isError: true);
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();

      final email = authProvider.pendingEmail;
      if (email == null) {
        // If we are already authenticated, just move forward
        if (authProvider.isAuthenticated) {
          context.go(AppRoutes.createProfilePersonal);
          return;
        }
        EliteSnackbar.show(context, 'SESSION EXPIRED. PLEASE SIGN UP AGAIN.', isError: true);
        context.go(AppRoutes.signin);
        return;
      }

      setState(() => _isVerifying = true);
      
      // We wrap the call to ensure the UI has updated to show the loading state
      await Future.delayed(const Duration(milliseconds: 50));
      await authProvider.verifyOTPCode(email, otp);
      
      // ELITE FORCED REDIRECT: We don't wait for the Router to notice the change.
      // We explicitly push the user to the personal info screen.
      if (mounted) {
        debugPrint("OtpScreen: Verification successful. Redirecting to Final Steps...");
        context.go(AppRoutes.createProfilePersonal);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      
      String errorMessage = "VERIFICATION FAILED";
      if (e is AuthException) {
        final message = e.message.toLowerCase();
        if (message.contains("invalid") || message.contains("token")) {
          errorMessage = "INVALID OR EXPIRED VERIFICATION CODE";
        } else if (message.contains("too many")) {
          errorMessage = "TOO MANY ATTEMPTS. PLEASE WAIT.";
        } else {
          errorMessage = e.message.toUpperCase();
        }
      } else {
        errorMessage = e.toString().toUpperCase();
      }

      EliteSnackbar.show(context, errorMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // In preview mode, provide dummy values if AuthProvider is not initialized
    AuthProvider? authProvider;
    try {
      authProvider = context.watch<AuthProvider>();
    } catch (_) {}

    final isLoading = (authProvider?.isLoading ?? false) || _isVerifying;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < kMobileBreakpoint;
          final isLargeScreen = constraints.maxWidth > kTabletBreakpoint;
          final double formMaxWidth = isLargeScreen ? 600 : 500;

          if (isSmallScreen) {
            return _buildMobileLayout(isLoading);
          } else {
            return _buildWideLayout(isLoading, constraints, formMaxWidth);
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout(bool isLoading) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthBrandingSection(
                  title: 'VERIFY\nIDENTITY',
                  subtitle: 'ENTER THE 6-DIGIT CODE SENT TO YOUR EMAIL',
                ),
                SizedBox(height: 60.h),
                _buildOtpForm(isLoading),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(bool isLoading, BoxConstraints constraints, double formMaxWidth) {
    return Row(
      children: [
        Expanded(
          flex: constraints.maxWidth > kTabletBreakpoint ? 4 : 3,
          child: Container(
            color: AppColors.surface.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(64),
            child: const Center(
              child: AuthBrandingSection(
                title: 'VERIFY\nIDENTITY',
                subtitle: 'ENTER THE 6-DIGIT CODE SENT TO YOUR EMAIL',
                isWideLayout: true,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: formMaxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: _buildOtpForm(isLoading, isWideLayout: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpForm(bool isLoading, {bool isWideLayout = false}) {
    AuthProvider? authProv;
    try {
      authProv = context.watch<AuthProvider>();
    } catch (_) {}

    final int cooldown = authProv?.emailCooldownSeconds ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (index) => _buildOtpBox(index, !isLoading, isWideLayout),
          ),
        ),
        SizedBox(height: 40.h.clamp(32, 64)),
        AuthPrimaryButton(
          label: 'VERIFY CODE',
          isLoading: isLoading,
          isEnabled: _isOtpComplete,
          onTap: _verifyOtp,
          isWideLayout: isWideLayout,
        ),
        SizedBox(height: 48.h.clamp(32, 80)),
        Center(
          child: Column(
            children: [
              Text(
                "Didn't receive the code?",
                style: AppTextStyles.caption.adaptive(context),
              ),
              TextButton(
                onPressed: (isLoading || cooldown > 0)
                    ? null
                    : () async {
                        final authProvider = context.read<AuthProvider>();
                        final email = authProvider.pendingEmail;
                        if (email != null) {
                          try {
                            await authProvider.resendOTP(email);
                            if (!mounted) return;
                            EliteSnackbar.show(context, 'CODE RESENT SUCCESSFULLY!');
                          } catch (e) {
                            if (!mounted) return;
                            String error = "RESEND FAILED";
                            if (e is AuthException) {
                              if (e.message.toLowerCase().contains("too many")) {
                                error = "PLEASE WAIT BEFORE REQUESTING A NEW CODE";
                              } else {
                                error = e.message.toUpperCase();
                              }
                            }
                            EliteSnackbar.show(context, error, isError: true);
                          }
                        }
                      },
                child: Text(
                  cooldown == 0 ? 'RESEND OTP' : 'RESEND OTP IN ${cooldown}S',
                  style: AppTextStyles.link.adaptive(context).copyWith(
                    color: cooldown == 0 ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpBox(int index, bool enabled, bool isWideLayout) {
    return SizedBox(
      width: isWideLayout ? 60 : 45.w,
      height: isWideLayout ? 70 : 56.h,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        onChanged: (v) => _onChanged(v, index),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        enabled: enabled,
        style: AppTextStyles.h3.adaptive(context).copyWith(
          color: Colors.white,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: const BorderSide(color: AppColors.crimson, width: 1.5),
          ),
        ),
      ),
    );
  }
}
