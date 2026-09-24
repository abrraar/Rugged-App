import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/features/auth/widgets/auth_components.dart';

class ResetPassScreen extends StatefulWidget {
  const ResetPassScreen({super.key});

  @override
  State<ResetPassScreen> createState() => _ResetPassScreenState();
}

class _ResetPassScreenState extends State<ResetPassScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    final pass = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (pass.isEmpty || confirm.isEmpty) {
      EliteSnackbar.show(context, 'PLEASE FILL IN BOTH FIELDS', isError: true);
      return;
    }
    if (pass != confirm) {
      EliteSnackbar.show(context, 'PASSWORDS DO NOT MATCH', isError: true);
      return;
    }
    if (pass.length < 6) {
      EliteSnackbar.show(context, 'PASSWORD MUST BE AT LEAST 6 CHARACTERS', isError: true);
      return;
    }

    try {
      final authProv = context.read<AuthProvider>();
      await authProv.updateUserPassword(pass);
      
      if (!mounted) return;
      EliteSnackbar.show(context, 'PASSWORD UPDATED SUCCESSFULLY!');
      
      // Cleanup recovery mode and sign out to force fresh login with new credentials
      authProv.cancelPasswordRecovery();
      await authProv.signOut();
      
      if (mounted) {
        context.go(AppRoutes.login);
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMsg = "UPDATE FAILED";
      if (e is AuthException) {
        errorMsg = e.message.toUpperCase();
      } else {
        errorMsg = e.toString().toUpperCase();
      }
      
      EliteSnackbar.show(context, errorMsg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return PopScope(
      canPop: false, // Lockdown: We handle the back navigation manually
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        
        debugPrint("ResetPass: Manual back detected. Cleaning up and returning to Forgot Password.");
        final authProv = context.read<AuthProvider>();
        authProv.cancelPasswordRecovery();
        await authProv.signOut(); // Security: Exit the temporary recovery session
        
        if (!context.mounted) return;
        context.go(AppRoutes.forgotPass);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () {
              // Trigger the PopScope logic
              Navigator.of(context).maybePop();
            },
          ),
        ),
        extendBodyBehindAppBar: true,
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
    ));
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
                  title: 'NEW\nSTRENGTH',
                  subtitle: 'SET YOUR NEW SECURE PASSWORD',
                ),
                SizedBox(height: 40.h),
                _buildResetPassForm(isLoading),
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
                title: 'NEW\nSTRENGTH',
                subtitle: 'SET YOUR NEW SECURE PASSWORD',
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
                child: _buildResetPassForm(isLoading, isWideLayout: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetPassForm(bool isLoading, {bool isWideLayout = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthInputField(
          controller: _passwordController,
          hint: 'ENTER NEW PASSWORD',
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
          hint: 'RE-TYPE NEW PASSWORD',
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
        SizedBox(height: 40.h.clamp(24, 64)),
        AuthPrimaryButton(
          label: 'CONFIRM NEW PASSWORD',
          isLoading: isLoading,
          onTap: _handleReset,
          isWideLayout: isWideLayout,
        ),
      ],
    );
  }
}
