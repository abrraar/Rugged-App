import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/features/auth/widgets/auth_components.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  SignUpMode _signUpMode = SignUpMode.email;
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if ((_signUpMode == SignUpMode.email || _signUpMode == SignUpMode.both) && email.isEmpty) {
      EliteSnackbar.show(context, 'PLEASE ENTER YOUR EMAIL', isError: true);
      return;
    }

    if ((_signUpMode == SignUpMode.username || _signUpMode == SignUpMode.both) && username.isEmpty) {
      EliteSnackbar.show(context, 'PLEASE CHOOSE A USERNAME', isError: true);
      return;
    }

    if (password.isEmpty || confirm.isEmpty) {
      EliteSnackbar.show(context, 'PLEASE ENTER AND CONFIRM PASSWORD', isError: true);
      return;
    }

    if (_signUpMode == SignUpMode.email || _signUpMode == SignUpMode.both) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        EliteSnackbar.show(context, 'PLEASE ENTER A VALID EMAIL ADDRESS', isError: true);
        return;
      }
    }

    if (password != confirm) {
      EliteSnackbar.show(context, 'PASSWORDS DO NOT MATCH', isError: true);
      return;
    }

    try {
      final authProv = context.read<AuthProvider>();
      
      if (_signUpMode == SignUpMode.username) {
        // 1. Check Username Availability
        final bool isAvailable = await authProv.checkUsernameAvailability(username);
        if (!isAvailable) {
          if (!mounted) return;
          EliteSnackbar.show(context, 'USERNAME IS ALREADY TAKEN', isError: true);
          return;
        }
        
        // 2. Proceed with Shadow Email Sign Up
        await authProv.signUpWithUsername(username, password);
        if (!mounted) return;
        // Shadow emails are auto-confirmed (no OTP required), so we go straight to setup
        context.go(AppRoutes.createProfilePersonal);
        return;
      }

      // 2. Proceed with Sign Up (Email or Both)
      // If mode is 'both', we pass both email and username
      await authProv.signUp(email, password, username: _signUpMode == SignUpMode.both ? username : null);
      if (!mounted) return;
      context.push(AppRoutes.otp);
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = "SIGN UP FAILED";
      if (e is AuthException) {
        final message = e.message.toLowerCase();
        if (message.contains("already registered")) {
          errorMessage = "THIS EMAIL IS ALREADY REGISTERED";
        } else if (message.contains("password")) {
          errorMessage = "PASSWORD IS TOO WEAK";
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
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < kMobileBreakpoint;
          final isLargeScreen = constraints.maxWidth > kTabletBreakpoint;
          final double formMaxWidth = isLargeScreen ? 480 : 420;

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
                  title: 'JOIN THE\nELITE',
                  subtitle: 'START YOUR HIGH INTENSITY JOURNEY',
                ),
                SizedBox(height: 40.h),
                _buildSignUpForm(isLoading),
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
                title: 'JOIN THE\nELITE',
                subtitle: 'START YOUR HIGH INTENSITY JOURNEY',
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
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: _buildSignUpForm(isLoading, isWideLayout: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm(bool isLoading, {bool isWideLayout = false}) {
    final authProv = context.watch<AuthProvider>();
    final int cooldown = authProv.isCooldownActive(_signUpMode) ? authProv.emailCooldownSeconds : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isWideLayout) ...[
          Text(
            'CREATE ACCOUNT',
            style: AppTextStyles.h2.adaptive(context).copyWith(
              color: AppColors.white,
            ),
          ),
          SizedBox(height: 24.h.clamp(16, 40)),
        ],
        
        // --- SIGN UP MODE SELECTOR ---
        Row(
          children: [
            Expanded(
              child: _ModeSelectorButton(
                label: 'EMAIL',
                isActive: _signUpMode == SignUpMode.email,
                onTap: () => setState(() => _signUpMode = SignUpMode.email),
                isWideLayout: isWideLayout,
              ),
            ),
            SizedBox(width: isWideLayout ? 12 : 8.w),
            Expanded(
              child: _ModeSelectorButton(
                label: 'USERNAME',
                isActive: _signUpMode == SignUpMode.username,
                onTap: () => setState(() => _signUpMode = SignUpMode.username),
                isWideLayout: isWideLayout,
              ),
            ),
            SizedBox(width: isWideLayout ? 12 : 8.w),
            Expanded(
              child: _ModeSelectorButton(
                label: 'BOTH',
                isActive: _signUpMode == SignUpMode.both,
                onTap: () => setState(() => _signUpMode = SignUpMode.both),
                isWideLayout: isWideLayout,
              ),
            ),
          ],
        ),
        SizedBox(height: 32.h.clamp(24, 40)),

        if (_signUpMode == SignUpMode.username || _signUpMode == SignUpMode.both) ...[
          AuthInputField(
            controller: _usernameController,
            hint: 'CHOOSE A USERNAME',
            icon: Icons.person_outline,
            enabled: !isLoading,
            isWideLayout: isWideLayout,
          ),
          if (_signUpMode == SignUpMode.both) SizedBox(height: 16.h.clamp(12, 24)),
        ],

        if (_signUpMode == SignUpMode.email || _signUpMode == SignUpMode.both)
          AuthInputField(
            controller: _emailController,
            hint: 'EMAIL ADDRESS',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            enabled: !isLoading,
            isWideLayout: isWideLayout,
          ),
        
        SizedBox(height: 16.h.clamp(12, 24)),
        AuthInputField(
          controller: _passwordController,
          hint: 'PASSWORD',
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          enabled: !isLoading,
          isWideLayout: isWideLayout,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.inputHint,
              size: isWideLayout ? 20 : 20.r,
            ),
          ),
        ),
        SizedBox(height: 16.h.clamp(12, 24)),
        AuthInputField(
          controller: _confirmPasswordController,
          hint: 'CONFIRM PASSWORD',
          icon: Icons.lock_reset_outlined,
          obscure: _obscureConfirm,
          enabled: !isLoading,
          isWideLayout: isWideLayout,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
            child: Icon(
              _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.inputHint,
              size: isWideLayout ? 20 : 20.r,
            ),
          ),
        ),
        SizedBox(height: 32.h.clamp(24, 48)),
        AuthPrimaryButton(
          label: cooldown > 0 ? 'WAIT ${cooldown}S' : 'CREATE ACCOUNT',
          isLoading: isLoading,
          onTap: cooldown > 0 ? () {} : _handleSignUp,
          isWideLayout: isWideLayout,
        ),
        SizedBox(height: 24.h.clamp(16, 32)),
        const AuthDividerWithText(text: 'OR JOIN WITH'),
        SizedBox(height: 24.h.clamp(16, 32)),
        AuthSocialButton(
          label: 'SIGN UP WITH GOOGLE',
          icon: Icon(
            Icons.g_mobiledata_rounded, 
            color: Colors.white, 
            size: isWideLayout ? 32 : 28.r
          ),
          onTap: () => context.read<AuthProvider>().signInWithGoogle(),
          isWideLayout: isWideLayout,
          isLoading: isLoading,
        ),
        SizedBox(height: 48.h.clamp(32, 80)),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Already have an account? ",
                style: AppTextStyles.caption.adaptive(context),
              ),
              GestureDetector(
                onTap: isLoading ? null : () => context.go(AppRoutes.login),
                child: Text(
                  'LOG IN',
                  style: AppTextStyles.link.adaptive(context).copyWith(
                    color: AppColors.crimson,
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
}

class _ModeSelectorButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isWideLayout;

  const _ModeSelectorButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isWideLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        height: isWideLayout ? 54 : 48.h,
        decoration: BoxDecoration(
          color: isActive ? AppColors.crimson.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isActive ? AppColors.crimson : AppColors.white.withValues(alpha: 0.1),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: isActive ? AppColors.white : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
