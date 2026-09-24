import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isEmbedded;
  const ChangePasswordScreen({super.key, this.isEmbedded = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isCurrentVerified = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _newPasswordController.text.isNotEmpty &&
          _newPasswordController.text == _confirmPasswordController.text &&
          _newPasswordController.text.length >= 6;

  Future<void> _verifyCurrent() async {
    final password = _currentPasswordController.text;
    if (password.isEmpty) return;

    final authProv = context.read<AuthProvider>();
    final success = await authProv.verifyCurrentPassword(password);

    if (success) {
      setState(() => _isCurrentVerified = true);
    } else {
      if (!mounted) return;
      EliteSnackbar.show(context, "INVALID CURRENT PASSWORD", isError: true);
    }
  }

  Future<void> _handleChangePassword() async {
    final authProv = context.read<AuthProvider>();
    try {
      await authProv.updateUserPassword(_newPasswordController.text.trim());
      
      if (!mounted) return;
      
      // Reset internal verification state now that a password exists
      setState(() {
        _isCurrentVerified = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });

      EliteSnackbar.show(context, "PASSWORD UPDATED SUCCESSFULLY");

      // Give the user a moment to see the success before navigating away
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.home);
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      EliteSnackbar.show(context, "ERROR: ${e.toString().toUpperCase()}", isError: true);
    }
  }

  Future<void> _sendResetEmail() async {
    final authProv = context.read<AuthProvider>();
    final email = authProv.currentUser?.email;
    if (email == null) return;

    try {
      await authProv.sendPasswordResetEmail(email, source: 'settings');
      if (!mounted) return;
      EliteSnackbar.show(context, "RESET EMAIL SENT SUCCESSFULLY");
    } catch (e) {
      if (!mounted) return;
      EliteSnackbar.show(context, "ERROR: ${e.toString().toUpperCase()}", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final isLoading = authProv.isLoading;
    final bool bypassVerification = authProv.isPasswordRecoveryMode;
    final bool hasExistingPassword = authProv.hasPassword;

    // ELITE DYNAMIC UI: If the user doesn't have a password (OAuth only),
    // we bypass the verification step automatically.
    final bool showVerificationStep = !bypassVerification && hasExistingPassword && !_isCurrentVerified;

    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = deviceWidth >= 600;

    return PopScope(
      canPop: !bypassVerification, // Lockdown: Disable natural pop during recovery
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && bypassVerification) {
          debugPrint("ChangePassword: Back button detected during recovery. Initiating security logout.");
          final authProv = context.read<AuthProvider>();
          authProv.cancelPasswordRecovery();
          await authProv.signOut();
          if (!context.mounted) return;
          context.go(AppRoutes.login);
        } else if (!didPop && !bypassVerification) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 600 && !isLargeScreen;

              return Column(
                children: [
                  EliteSettingsAppBar(
                    title: "SECURITY", 
                    isCompact: isCompact,
                    showBackButton: !widget.isEmbedded,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 24.0 : 24.w, 
                        vertical: isLargeScreen ? 24.0 : 24.r
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                              Text(
                                bypassVerification 
                                    ? "RECOVER PASSWORD" 
                                    : (hasExistingPassword ? "CHANGE PASSWORD" : "CREATE PASSWORD"),
                                style: AppTextStyles.h1.copyWith(
                                  fontSize: isLargeScreen ? 28.0 : 32.sp, 
                                  letterSpacing: -1
                                ),
                              ),
                              SizedBox(height: isLargeScreen ? 8.0 : 8.h),
                              Text(
                                bypassVerification 
                                    ? "RESTORING AUTHENTICATION ACCESS" 
                                    : (hasExistingPassword 
                                        ? "PROTECT YOUR HIGH INTENSITY DATA"
                                        : "SET A BACKUP PASSWORD FOR EMAIL LOGIN"),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary, 
                                  letterSpacing: 1.5,
                                  fontSize: isLargeScreen ? 11.0 : null,
                                ),
                              ),
                              SizedBox(height: isLargeScreen ? 40.0 : 40.h),

                              if (showVerificationStep) ...[
                                _buildLabel("CURRENT PASSWORD", isCompact, isLargeScreen),
                                _buildTextField(
                                  controller: _currentPasswordController,
                                  hint: "ENTER CURRENT PASSWORD",
                                  icon: Icons.lock_outline,
                                  obscure: _obscureCurrent,
                                  toggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
                                  isCompact: isCompact,
                                  isLargeScreen: isLargeScreen,
                                ),
                                SizedBox(height: isLargeScreen ? 24.0 : 24.h),
                                _buildPrimaryButton(
                                  label: "VERIFY PASSWORD",
                                  isLoading: isLoading,
                                  onTap: _verifyCurrent,
                                  isCompact: isCompact,
                                  isLargeScreen: isLargeScreen,
                                ),
                                SizedBox(height: isLargeScreen ? 32.0 : 32.h),
                                Center(
                                  child: TextButton(
                                    onPressed: (isLoading || authProv.emailCooldownSeconds > 0 || authProv.isUsernameOnly) ? null : _sendResetEmail,
                                    child: Text(
                                      authProv.emailCooldownSeconds > 0 
                                          ? "RESEND RESET LINK IN ${authProv.emailCooldownSeconds}S" 
                                          : (authProv.isUsernameOnly ? "NO EMAIL TO SEND VERIFICATION" : "FORGOT CURRENT PASSWORD?"),
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: (authProv.emailCooldownSeconds > 0 || authProv.isUsernameOnly) 
                                            ? AppColors.textSecondary.withValues(alpha: 0.5) 
                                            : AppColors.crimson,
                                        fontWeight: FontWeight.w500,
                                        decoration: (authProv.emailCooldownSeconds > 0 || authProv.isUsernameOnly) 
                                            ? TextDecoration.none 
                                            : TextDecoration.underline,
                                        fontSize: isLargeScreen ? 12.0 : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                _buildLabel("NEW PASSWORD", isCompact, isLargeScreen),
                                _buildTextField(
                                  controller: _newPasswordController,
                                  hint: "ENTER NEW PASSWORD",
                                  icon: Icons.vpn_key_outlined,
                                  obscure: _obscureNew,
                                  toggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                                  onChanged: (_) => setState(() {}),
                                  isCompact: isCompact,
                                  isLargeScreen: isLargeScreen,
                                ),
                                SizedBox(height: isLargeScreen ? 20.0 : 20.h),
                                _buildLabel("CONFIRM NEW PASSWORD", isCompact, isLargeScreen),
                                _buildTextField(
                                  controller: _confirmPasswordController,
                                  hint: "RE-TYPE NEW PASSWORD",
                                  icon: Icons.check_circle_outline_rounded,
                                  obscure: _obscureConfirm,
                                  toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  onChanged: (_) => setState(() {}),
                                  isCompact: isCompact,
                                  isLargeScreen: isLargeScreen,
                                ),
                                if (_newPasswordController.text.isNotEmpty &&
                                    _confirmPasswordController.text.isNotEmpty &&
                                    _newPasswordController.text != _confirmPasswordController.text)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: isLargeScreen ? 8.0 : 8.h, 
                                      left: isLargeScreen ? 4.0 : 4.w
                                    ),
                                    child: Text(
                                      "PASSWORDS DO NOT MATCH", 
                                      style: TextStyle(
                                        color: AppColors.error, 
                                        fontSize: isLargeScreen ? 10.0 : 10.sp, 
                                        fontWeight: FontWeight.w500
                                      )
                                    ),
                                  ),
                                SizedBox(height: isLargeScreen ? 40.0 : 40.h),
                                _buildPrimaryButton(
                                  label: hasExistingPassword ? "UPDATE PASSWORD" : "SET ACCOUNT PASSWORD",
                                  isLoading: isLoading,
                                  onTap: _canSave ? _handleChangePassword : () {},
                                  enabled: _canSave,
                                  isCompact: isCompact,
                                  isLargeScreen: isLargeScreen,
                                ),
                                if (bypassVerification) ...[
                                  SizedBox(height: isLargeScreen ? 16.0 : 16.h),
                                  Center(
                                    child: TextButton(
                                      onPressed: () {
                                        authProv.cancelPasswordRecovery();
                                        if (authProv.isAuthenticated) {
                                          context.go(AppRoutes.home);
                                        } else {
                                          context.go(AppRoutes.login);
                                        }
                                      },
                                      child: Text(
                                        "CANCEL RECOVERY",
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: Colors.white38,
                                          fontWeight: FontWeight.w500,
                                          decoration: TextDecoration.underline,
                                          fontSize: isLargeScreen ? 12.0 : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                      ),
                    ),
                  ],
                );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isCompact, bool isLargeScreen) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLargeScreen ? 8.0 : 8.h, 
        left: isLargeScreen ? 4.0 : 4.w
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary, 
          letterSpacing: 1.5, 
          fontWeight: FontWeight.w500,
          fontSize: isLargeScreen ? 11.0 : null,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? toggleObscure,
    Function(String)? onChanged,
    required bool isCompact,
    required bool isLargeScreen,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      style: AppTextStyles.inputText.copyWith(
        color: Colors.white,
        fontSize: isLargeScreen ? 14.0 : null,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white24,
          fontSize: isLargeScreen ? 14.0 : null,
        ),
        filled: true,
        fillColor: AppColors.surfaceLight.withValues(alpha: 0.3),
        prefixIcon: Icon(icon, color: AppColors.crimson, size: isLargeScreen ? 20.0 : 20.r),
        suffixIcon: toggleObscure != null
            ? IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, 
            color: Colors.white24, 
            size: isLargeScreen ? 18.0 : 18.r
          ),
          onPressed: toggleObscure,
        )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.r), 
          borderSide: BorderSide.none
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label, 
    required VoidCallback onTap, 
    bool isLoading = false, 
    bool enabled = true,
    required bool isCompact,
    required bool isLargeScreen,
  }) {
    return GestureDetector(
      onTap: (isLoading || !enabled) ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          width: double.infinity,
          height: isLargeScreen ? 54.0 : 56.h,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.r),
            boxShadow: enabled ? [
              BoxShadow(
                color: AppColors.crimson.withValues(alpha: 0.3), 
                blurRadius: 15, 
                offset: const Offset(0, 8)
              )
            ] : null,
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  label, 
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white, 
                    fontWeight: FontWeight.w500,
                    fontSize: isLargeScreen ? 14.0 : null,
                  )
                ),
        ),
      ),
    );
  }
}
