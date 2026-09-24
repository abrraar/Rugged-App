import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_confirm_dialog.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/core/widgets/elite_refresh_indicator.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_routes.dart';

class ManageEmailScreen extends StatefulWidget {
  final bool isEmbedded;
  const ManageEmailScreen({super.key, this.isEmbedded = false});

  @override
  State<ManageEmailScreen> createState() => _ManageEmailScreenState();
}

class _ManageEmailScreenState extends State<ManageEmailScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  String? _pendingEmail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProv = context.read<AuthProvider>();
      final state = GoRouterState.of(context);
      final bool wasVerified = state.uri.queryParameters['verified'] == 'true';

      if (wasVerified) {
        await authProv.refreshEmails();
        if (mounted) {
          final rawMessage = state.uri.queryParameters['message'];
          if (rawMessage != null && rawMessage.isNotEmpty) {
            if (rawMessage.toLowerCase().contains('other email')) {
              EliteSnackbar.show(context, "PRIMARY EMAIL SWITCHED");
            } else {
              EliteSnackbar.show(context, rawMessage.toUpperCase());
            }
          } else {
            EliteSnackbar.show(context, "PRIMARY EMAIL SWITCHED");
          }
        }
      } else {
        authProv.refreshEmails();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _resetState() {
    if (mounted) {
      setState(() {
        _emailController.clear();
        _otpController.clear();
        _pendingEmail = null;
        _isSending = false;
        _isVerifying = false;
      });
    }
  }

  void _showAddEmailSheet() {
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => LayoutBuilder(
        builder: (context, constraints) {
          final double deviceWidth = MediaQuery.of(context).size.width;
          final bool isLargeScreen = deviceWidth >= 600;
          final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet && !isLargeScreen;
          final double sheetWidth = isSideSheet ? constraints.maxWidth : (isSheetCompact ? constraints.maxWidth : 500.0);

          return Center(
            child: SizedBox(
              width: sheetWidth,
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  final authProv = context.read<AuthProvider>();
                  final emailInput = _emailController.text.trim().toLowerCase();
                  final bool isDuplicate = authProv.userEmails.any((e) => e.email.toLowerCase() == emailInput);
                  final int cooldown = authProv.emailCooldownSeconds;

                  return Container(
                    height: isSideSheet ? double.infinity : null,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: isSideSheet 
                        ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                        : BorderRadius.vertical(top: Radius.circular(isLargeScreen ? 24.0 : 24.r)),
                    ),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + (isLargeScreen ? 16.0 : 20.h),
                      left: isLargeScreen ? 24.0 : 24.r,
                      right: isLargeScreen ? 24.0 : 24.r,
                      top: isSideSheet ? 0 : (isLargeScreen ? 20.0 : 24.r),
                    ),
                    child: Column(
                      mainAxisSize: isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSideSheet) const SizedBox(height: 24.0),
                        if (!isSideSheet)
                          Center(
                            child: Container(
                              width: 40.0,
                              height: 4.0,
                              margin: EdgeInsets.only(bottom: isLargeScreen ? 16.0 : 20.h),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(2.r),
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _pendingEmail == null ? "ADD EMAIL ADDRESS" : "VERIFY CODE", 
                              style: AppTextStyles.h3.copyWith(fontSize: isLargeScreen ? 18.0 : null)
                            ),
                            if (isSideSheet)
                              IconButton(
                                icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                onPressed: () => Navigator.pop(sheetContext),
                              ),
                          ],
                        ),
                        SizedBox(height: isLargeScreen ? 6.0 : 8.h),
                        Text(
                          _pendingEmail == null
                            ? "A 6-DIGIT VERIFICATION CODE WILL BE SENT"
                            : "ENTER THE CODE SENT TO ${_pendingEmail!.toUpperCase()}",
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: isLargeScreen ? 10.0 : null,
                          )
                        ),
                        SizedBox(height: isLargeScreen ? 20.0 : 24.h),

                        if (_pendingEmail == null)
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isSending && cooldown == 0,
                            onChanged: (_) => setSheetState(() {}),
                            style: TextStyle(color: Colors.white, fontSize: isLargeScreen ? 14.0 : null),
                            decoration: InputDecoration(
                              hintText: "EMAIL ADDRESS",
                              hintStyle: const TextStyle(color: Colors.white24),
                              filled: true,
                              fillColor: AppColors.surfaceLight.withValues(alpha: 0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.r), 
                                borderSide: BorderSide.none
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isLargeScreen ? 14.0 : 16.w, 
                                vertical: isLargeScreen ? 12.0 : 14.h
                              ),
                            ),
                          )
                        else
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            enabled: !_isVerifying,
                            style: AppTextStyles.h2.copyWith(
                              color: Colors.white, 
                              letterSpacing: 10,
                              fontSize: isLargeScreen ? 24.0 : null,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              counterText: "",
                              hintText: "000000",
                              hintStyle: const TextStyle(color: Colors.white12),
                              filled: true,
                              fillColor: AppColors.surfaceLight.withValues(alpha: 0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.r), 
                                borderSide: BorderSide.none
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isLargeScreen ? 14.0 : 16.w, 
                                vertical: isLargeScreen ? 12.0 : 14.h
                              ),
                            ),
                          ),

                        SizedBox(height: isLargeScreen ? 24.0 : 20.h),
                        _PrimaryButton(
                          label: _pendingEmail != null
                            ? "VERIFY & ADD EMAIL"
                            : (cooldown > 0 ? "WAIT ${cooldown}S" : (isDuplicate ? "EMAIL ALREADY EXISTS" : "SEND VERIFICATION CODE")),
                          isLoading: _isSending || _isVerifying,
                          enabled: _pendingEmail != null || (cooldown == 0 && !isDuplicate),
                          isLargeScreen: isLargeScreen,
                          onTap: () async {
                            if (_pendingEmail == null) {
                              final email = _emailController.text.trim();
                              if (email.isNotEmpty && !isDuplicate && cooldown == 0) {
                                setSheetState(() => _isSending = true);
                                try {
                                  await context.read<AuthProvider>().addEmail(email);
                                  if (!context.mounted) return;
                                  setSheetState(() {
                                    _pendingEmail = email;
                                    _isSending = false;
                                  });
                                } catch (e) {
                                  if (!context.mounted) return;
                                  EliteSnackbar.show(context, "FAILED: ${e.toString().toUpperCase()}", isError: true);
                                  setSheetState(() => _isSending = false);
                                }
                              }
                            } else {
                              final code = _otpController.text.trim();
                              if (code.length == 6) {
                                setSheetState(() => _isVerifying = true);
                                  final success = await context.read<AuthProvider>().verifySecondaryEmailOTP(_pendingEmail!, code);
                                  if (!context.mounted) return;
                                  if (success) {
                                    Navigator.pop(sheetContext);
                                    _resetState();
                                    EliteSnackbar.show(context, "EMAIL VERIFIED SUCCESSFULLY");
                                  } else {
                                    EliteSnackbar.show(context, "INVALID CODE", isError: true);
                                    setSheetState(() => _isVerifying = false);
                                  }
                              }
                            }
                          },
                        ),
                        if (_pendingEmail != null) ...[
                          Center(
                            child: TextButton(
                              onPressed: (_isSending || _isVerifying || cooldown > 0) ? null : () async {
                                setSheetState(() => _isSending = true);
                                try {
                                  await context.read<AuthProvider>().resendSecondaryOTP(_pendingEmail!);
                                  if (!context.mounted) return;
                                  EliteSnackbar.show(context, "FRESH CODE SENT");
                                } catch (e) {
                                  if (!context.mounted) return;
                                  EliteSnackbar.show(context, "RESEND FAILED", isError: true);
                                } finally {
                                  if (mounted) setSheetState(() => _isSending = false);
                                }
                              },
                              child: Text(
                                _isSending
                                  ? "SENDING..."
                                  : (cooldown > 0
                                      ? "RESEND IN ${cooldown}S"
                                      : "RESEND VERIFICATION CODE"),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: cooldown > 0 ? Colors.white12 : AppColors.crimson,
                                  decoration: cooldown > 0 ? TextDecoration.none : TextDecoration.underline,
                                  fontSize: isLargeScreen ? 10.0 : null,
                                )
                              ),
                            ),
                          ),
                          Center(
                            child: TextButton(
                              onPressed: () => setSheetState(() => _pendingEmail = null),
                              child: Text("RE-TYPE EMAIL", style: AppTextStyles.labelSmall.copyWith(color: Colors.white24, decoration: TextDecoration.underline, fontSize: isLargeScreen ? 10.0 : null)),
                            ),
                          ),
                        ],
                        SizedBox(height: isLargeScreen ? 12.0 : 10.h),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    ).then((_) => _resetState());
  }

  Future<bool> _confirmDelete(String id, String email) async {
    final confirmed = await EliteConfirmDialog.show(
      context,
      title: "REMOVE EMAIL",
      message: "ARE YOU SURE YOU WANT TO REMOVE $email?",
      confirmText: "REMOVE",
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().removeEmail(id);
      if (!mounted) return false;
      EliteSnackbar.show(context, "EMAIL REMOVED");
      return true;
    }
    return false;
  }

  Future<void> _confirmPromotion(String email) async {
    final authProv = context.read<AuthProvider>();
    if (authProv.emailCooldownSeconds > 0) return;

    final confirmed = await EliteConfirmDialog.show(
      context,
      title: "PROMOTE TO PRIMARY",
      message: "MAKE $email YOUR MAIN IDENTITY? A VERIFICATION LINK WILL BE SENT TO THE NEW ADDRESS.",
      confirmText: "PROMOTE",
    );

    if (confirmed == true && mounted) {
      EliteSnackbar.show(context, "PROMOTION INITIATED. CHECK YOUR NEW INBOX.");
      authProv.promoteToPrimaryEmail(email).catchError((e) {
        if (mounted) {
          EliteSnackbar.show(context, "PROMOTION FAILED: ${e.toString().toUpperCase()}", isError: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final isUsernameOnly = authProv.isUsernameOnly;
    final emails = authProv.userEmails;
    final bool limitReached = emails.length >= 3;
    final int cooldown = authProv.emailCooldownSeconds;

    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = deviceWidth >= 600;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
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
                    title: "MANAGE EMAILS", 
                    isCompact: isCompact,
                    showBackButton: !widget.isEmbedded,
                  ),
                  Expanded(
                    child: EliteRefreshIndicator(
                      onRefresh: () => authProv.refreshEmails(),
                      color: AppColors.crimson,
                      backgroundColor: AppColors.surface,
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 24.0 : 24.w, 
                          vertical: isLargeScreen ? 24.0 : 24.r
                        ),
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        children: [
                          if (isUsernameOnly)
                            _buildSecureAccountCard(isLargeScreen),
                          
                          ...emails.map((email) {
                            final bool isPrimary = email.email == authProv.currentUser?.email;

                            return Dismissible(
                              key: Key(email.id),
                              direction: isPrimary
                                  ? DismissDirection.none
                                  : (email.isVerified ? DismissDirection.endToStart : DismissDirection.horizontal),
                              confirmDismiss: (dir) async {
                                if (dir == DismissDirection.startToEnd) {
                                  setState(() => _pendingEmail = email.email);
                                  _showAddEmailSheet();
                                  return false;
                                } else {
                                  return await _confirmDelete(email.id, email.email);
                                }
                              },
                              background: Container(
                                margin: EdgeInsets.only(bottom: isLargeScreen ? 16.0 : 16.h),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(isLargeScreen ? 12.0 : 16.r),
                                ),
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.only(left: isLargeScreen ? 24.0 : 24.w),
                                child: Icon(Icons.verified_user_outlined, color: Colors.greenAccent, size: isLargeScreen ? 28.0 : 28.r),
                              ),
                              secondaryBackground: Container(
                                margin: EdgeInsets.only(bottom: isLargeScreen ? 16.0 : 16.h),
                                decoration: BoxDecoration(
                                  color: AppColors.crimson.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(isLargeScreen ? 12.0 : 16.r),
                                ),
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.only(right: isLargeScreen ? 24.0 : 24.w),
                                child: Icon(Icons.delete_outline_rounded, color: AppColors.crimson, size: isLargeScreen ? 28.0 : 28.r),
                              ),
                              child: GestureDetector(
                                onTap: (email.isVerified && !isPrimary && cooldown == 0) ? () => _confirmPromotion(email.email) : null,
                                child: Container(
                                  margin: EdgeInsets.only(bottom: isLargeScreen ? 16.0 : 16.h),
                                  padding: EdgeInsets.all(isLargeScreen ? 16.0 : 16.r),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(isLargeScreen ? 12.0 : 16.r),
                                    border: Border.all(
                                      color: isPrimary ? AppColors.crimson.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
                                      width: isPrimary ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    email.email,
                                                    style: AppTextStyles.labelMedium.copyWith(
                                                      color: Colors.white,
                                                      fontSize: isLargeScreen ? 14.0 : null,
                                                    ),
                                                    overflow: TextOverflow.ellipsis
                                                  )
                                                ),
                                                if (isPrimary) ...[
                                                  SizedBox(width: isLargeScreen ? 8.0 : 8.w),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: isLargeScreen ? 6.0 : 6.w,
                                                      vertical: isLargeScreen ? 2.0 : 2.h
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.crimson.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(isLargeScreen ? 4.0 : 4.r),
                                                      border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
                                                    ),
                                                    child: Text(
                                                      "PRIMARY",
                                                      style: AppTextStyles.labelSmall.copyWith(
                                                        color: AppColors.crimson,
                                                        fontSize: isLargeScreen ? 9.0 : 8.sp,
                                                        fontWeight: FontWeight.w500,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ] else ...[
                                                  SizedBox(width: isLargeScreen ? 8.0 : 8.w),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: isLargeScreen ? 6.0 : 6.w,
                                                      vertical: isLargeScreen ? 2.0 : 2.h
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.05),
                                                      borderRadius: BorderRadius.circular(isLargeScreen ? 4.0 : 4.r),
                                                    ),
                                                    child: Text(
                                                      "SECONDARY",
                                                      style: AppTextStyles.labelSmall.copyWith(
                                                        color: Colors.white38,
                                                        fontSize: isLargeScreen ? 9.0 : 8.sp,
                                                        fontWeight: FontWeight.w500,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            SizedBox(height: isLargeScreen ? 6.0 : 6.h),
                                            Row(
                                              children: [
                                                Icon(
                                                  email.isVerified ? Icons.verified_rounded : Icons.pending_actions_rounded,
                                                  size: isLargeScreen ? 14.0 : 14.r,
                                                  color: email.isVerified ? Colors.greenAccent : Colors.orangeAccent,
                                                ),
                                                SizedBox(width: isLargeScreen ? 6.0 : 6.w),
                                                Text(
                                                  email.isVerified ? "VERIFIED" : "NOT VERIFIED",
                                                  style: AppTextStyles.labelSmall.copyWith(
                                                    color: email.isVerified ? Colors.greenAccent : Colors.orangeAccent,
                                                    fontSize: isLargeScreen ? 11.0 : 10.sp,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (!email.isVerified) ...[
                                                  const Spacer(),
                                                  Text(
                                                    "SLIDE RIGHT TO VERIFY",
                                                    style: AppTextStyles.labelSmall.copyWith(
                                                      color: Colors.white24,
                                                      fontSize: isLargeScreen ? 9.0 : 8.sp,
                                                      fontWeight: FontWeight.w500
                                                    ),
                                                  ),
                                                ] else if (!isPrimary) ...[
                                                  const Spacer(),
                                                  Text(
                                                    cooldown > 0
                                                      ? "WAIT ${cooldown}S"
                                                      : "TAP TO PROMOTE",
                                                    style: AppTextStyles.labelSmall.copyWith(
                                                      color: cooldown > 0 ? Colors.white12 : AppColors.crimson.withValues(alpha: 0.5),
                                                      fontSize: isLargeScreen ? 9.0 : 8.sp,
                                                      fontWeight: FontWeight.w500
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isLargeScreen ? 24.0 : 24.r),
                    child: _PrimaryButton(
                      label: limitReached
                          ? "MAXIMUM EMAILS REACHED"
                          : (cooldown > 0
                              ? "WAIT ${cooldown}S"
                              : "ADD EMAIL ADDRESS"),
                      onTap: (limitReached || cooldown > 0) ? () {} : _showAddEmailSheet,
                      enabled: !limitReached && cooldown == 0,
                      isLargeScreen: isLargeScreen,
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 20.0 : 20.h),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSecureAccountCard(bool isLargeScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isLargeScreen ? 24.0 : 24.h),
      padding: EdgeInsets.all(isLargeScreen ? 20.0 : 20.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.crimson.withValues(alpha: 0.15), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isLargeScreen ? 16.0 : 20.r),
        border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.crimson, size: isLargeScreen ? 24.0 : 24.r),
              SizedBox(width: isLargeScreen ? 12.0 : 12.w),
              Text(
                "SECURE YOUR ACCOUNT",
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.white,
                  fontSize: isLargeScreen ? 16.0 : null,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 12.0 : 12.h),
          Text(
            "YOUR ACCOUNT IS CURRENTLY UNSECURED. ADD A PRIMARY EMAIL TO ENABLE PASSWORD RECOVERY AND ACCOUNT PROTECTION.",
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: isLargeScreen ? 11.0 : 11.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;
  final bool isLargeScreen;

  const _PrimaryButton({
    required this.label, 
    required this.onTap, 
    this.isLoading = false, 
    this.enabled = true,
    this.isLargeScreen = false,
  });

  @override
  Widget build(BuildContext context) {
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
          ),
          alignment: Alignment.center,
          child: isLoading
            ? SizedBox(
                height: isLargeScreen ? 24.0 : 24.r,
                width: isLargeScreen ? 24.0 : 24.r,
                child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              )
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
