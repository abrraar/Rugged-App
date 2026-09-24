import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';

class DeleteAccountScreen extends StatefulWidget {
  final bool isEmbedded;
  const DeleteAccountScreen({super.key, this.isEmbedded = false});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _isConfirming = false;
  bool _isLoading = false;

  Future<void> _handleDelete() async {
    if (!_isConfirming) {
      EliteSnackbar.show(context, "PLEASE CONFIRM THE DELETION POLICY", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().deleteAccount();
      if (mounted) {
        EliteSnackbar.show(context, "ACCOUNT DELETED SUCCESSFULLY");
        // Navigation is handled by AuthProvider's notifyListeners and GoRouter redirect
      }
    } catch (e) {
      if (mounted) {
        EliteSnackbar.show(context, "DELETION FAILED: ${e.toString().toUpperCase()}", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            EliteSettingsAppBar(
              title: "DELETE ACCOUNT",
              showBackButton: !widget.isEmbedded,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWarningCard(),
                    SizedBox(height: 32.h),
                    _buildPolicySection(),
                    SizedBox(height: 40.h),
                    _buildConfirmationToggle(),
                    SizedBox(height: 24.h),
                    _buildDeleteButton(),
                    SizedBox(height: 100.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.crimson.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.crimson.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.crimson, size: 48.r),
          SizedBox(height: 16.h),
          Text(
            "CRITICAL ACTION REQUIRED",
            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
              color: AppColors.crimson,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "Account deletion is permanent and cannot be reversed.",
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.adaptive(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "WHAT HAPPENS TO YOUR DATA?",
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.crimson,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 16.h),
        _buildPolicyItem(
          icon: Icons.cloud_off_rounded,
          title: "Cloud Data Purge",
          description: "All training cycles, nutrition logs, and supplement data will be wiped from our secure servers.",
        ),
        _buildPolicyItem(
          icon: Icons.storage_rounded,
          title: "Local Database Wipe",
          description: "The RUGGED database on this device will be encrypted and permanently erased.",
        ),
        _buildPolicyItem(
          icon: Icons.no_accounts_rounded,
          title: "Identity Deletion",
          description: "Your username, email, and authentication credentials will be removed from the system.",
        ),
      ],
    );
  }

  Widget _buildPolicyItem({required IconData icon, required String title, required String description}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20.r),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isConfirming = !_isConfirming),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: _isConfirming ? AppColors.crimson : AppColors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: _isConfirming,
              onChanged: (v) => setState(() => _isConfirming = v ?? false),
              activeColor: AppColors.crimson,
              checkColor: Colors.white,
              side: BorderSide(color: AppColors.white.withValues(alpha: 0.2)),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                "I understand that my data is unrecoverable and I wish to proceed with deletion.",
                style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                  color: _isConfirming ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleDelete,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 18.h),
        decoration: BoxDecoration(
          color: _isConfirming ? AppColors.crimson : AppColors.crimson.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
          boxShadow: _isConfirming ? [
            BoxShadow(
              color: AppColors.crimson.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ] : [],
        ),
        child: Center(
          child: _isLoading
            ? SizedBox(
                height: 20.r,
                width: 20.r,
                child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                "PERMANENTLY DELETE ACCOUNT",
                style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                  color: _isConfirming ? Colors.white : AppColors.crimson,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
        ),
      ),
    );
  }
}
