import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/features/auth/widgets/auth_components.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      EliteSnackbar.show(context, 'PLEASE FILL IN ALL FIELDS', isError: true);
      return;
    }

    try {
      await context.read<AuthProvider>().signIn(identifier, password);
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = e.toString().toUpperCase();
      
      // Handle Supabase specific AuthException
      if (e is AuthException) {
        errorMessage = e.message.toUpperCase();
        if (errorMessage.contains('INVALID LOGIN CREDENTIALS')) {
          errorMessage = "INVALID USERNAME, EMAIL OR PASSWORD";
        }
      }

      EliteSnackbar.show(
        context,
        errorMessage,
        isError: true,
      );
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
                  title: 'RUGGED',
                  subtitle: 'INTENSE BRIEF INFREQUENT',
                ),
                SizedBox(height: 40.h),
                _buildLoginForm(isLoading),
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
                title: 'RUGGED',
                subtitle: 'INTENSE BRIEF INFREQUENT',
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
                child: _buildLoginForm(isLoading, isWideLayout: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(bool isLoading, {bool isWideLayout = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isWideLayout) ...[
          Text(
            'WELCOME BACK',
            style: AppTextStyles.h2.adaptive(context).copyWith(
              color: AppColors.white,
            ),
          ),
          SizedBox(height: 24.h.clamp(16, 40)),
        ],
        AuthInputField(
          controller: _emailController,
          hint: 'USERNAME OR EMAIL',
          icon: Icons.person_outline,
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
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: isLoading ? null : () => context.push(AppRoutes.forgotPass),
            child: Text(
              'Forgot password?',
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h.clamp(8, 20)),
        AuthPrimaryButton(
          label: 'LOG IN',
          isLoading: isLoading,
          onTap: _handleLogin,
          isWideLayout: isWideLayout,
        ),
        SizedBox(height: 24.h.clamp(16, 32)),
        const AuthDividerWithText(text: 'OR CONTINUE WITH'),
        SizedBox(height: 24.h.clamp(16, 32)),
        AuthSocialButton(
          label: 'GOOGLE SIGN IN',
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
                "Don't have an account? ",
                style: AppTextStyles.caption.adaptive(context),
              ),
              GestureDetector(
                onTap: isLoading ? null : () => context.push(AppRoutes.signin),
                child: Text(
                  'SIGN UP',
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
