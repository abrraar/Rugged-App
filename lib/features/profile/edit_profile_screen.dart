import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/elite_snackbar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _heightController;
  DateTime? _selectedBirthday;
  String? _selectedGender;
  
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    final authProv = context.read<AuthProvider>();
    _nameController = TextEditingController(text: authProv.displayName);
    _heightController = TextEditingController(text: authProv.height?.toStringAsFixed(0) ?? "");
    _selectedBirthday = authProv.birthday;
    _selectedGender = authProv.gender;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _nameController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _triggerAutoSave() {
    if (_autoSaveTimer?.isActive ?? false) _autoSaveTimer!.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _handleSave();
    });
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => child!,
    );
    if (picked != null) {
      setState(() => _selectedBirthday = picked);
      _handleSave(); // Save immediately on selection
    }
  }

  Future<void> _handleSave() async {
    final authProv = context.read<AuthProvider>();
    
    try {
      final Map<String, dynamic> extraMetadata = {
        'gender': _selectedGender,
        'birthday': _selectedBirthday?.toIso8601String(),
      };

      await authProv.updateUserProfile(
        name: _nameController.text.trim(),
        height: double.tryParse(_heightController.text.trim()),
        extraMetadata: extraMetadata,
      );
      // Auto-save logic: silence is golden. No success snackbar needed.
    } catch (e) {
      // In an offline-first app, we suppress network-related auto-save errors.
      // The provider will handle background synchronization silently.
      final errorStr = e.toString().toLowerCase();
      final isNetworkError = errorStr.contains('socketexception') || 
                             errorStr.contains('clientexception') ||
                             errorStr.contains('failed host lookup') ||
                             errorStr.contains('errno = 7');
      
      if (!isNetworkError) {
        debugPrint("EditProfile: Non-network auto-save error: $e");
        if (!mounted) return;
        EliteSnackbar.show(context, "AUTO-SAVE FAILED: ${e.toString().toUpperCase()}", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 600;
            return Column(
              children: [
                EliteSettingsAppBar(title: "EDIT PROFILE", isCompact: isCompact),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 24.0, vertical: isCompact ? 24.r : 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                            _buildLabel("NAME", isCompact),
                            _buildTextField(
                              _nameController, 
                              "YOUR NAME", 
                              Icons.person_outline, 
                              onChanged: (_) => _triggerAutoSave(),
                              isCompact: isCompact,
                            ),
                            SizedBox(height: isCompact ? 20.h : 20.0),
                            
                            _buildLabel("GENDER", isCompact),
                            _GenderSelector(
                              selectedGender: _selectedGender,
                              onChanged: (val) {
                                setState(() {
                                  if (_selectedGender == val) {
                                    _selectedGender = null; // Deselect
                                  } else {
                                    _selectedGender = val; // Select
                                  }
                                });
                                _handleSave(); // Save immediately
                              },
                              isCompact: isCompact,
                            ),
                            SizedBox(height: isCompact ? 20.h : 20.0),
                            
                            _buildLabel("BIRTHDAY", isCompact),
                            _SelectorField(
                              hint: _selectedBirthday == null 
                                  ? 'PICK BIRTHDAY' 
                                  : DateFormat('dd MMM, yyyy').format(_selectedBirthday!).toUpperCase(),
                              icon: Icons.cake_outlined,
                              onTap: () => _selectBirthday(context),
                              onClear: _selectedBirthday == null ? null : () {
                                setState(() => _selectedBirthday = null);
                                _handleSave();
                              },
                              isCompact: isCompact,
                            ),
                            SizedBox(height: isCompact ? 20.h : 20.0),
                            
                            _buildLabel("HEIGHT (CM)", isCompact),
                            _buildTextField(
                              _heightController, 
                              "180", 
                              Icons.height_outlined, 
                              isNumber: true, 
                              onChanged: (_) => _triggerAutoSave(),
                              isCompact: isCompact,
                            ),
                            SizedBox(height: isCompact ? 40.h : 40.0),
                          ],
                        ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isCompact ? 8.h : 8.0, 
        left: isCompact ? 4.w : 4.0
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String hint, 
    IconData icon, 
    {bool isNumber = false, bool obscure = false, Function(String)? onChanged, required bool isCompact}
  ) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: AppTextStyles.inputText.adaptive(context).copyWith(
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.inputText.adaptive(context).copyWith(
          color: Colors.white24,
        ),
        filled: true,
        fillColor: AppColors.surfaceLight.withValues(alpha: 0.3),
        prefixIcon: Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 20.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), 
          borderSide: BorderSide.none
        ),
      ),
    );
  }
}

// Reuse components from CreateAccPersoScreen logic style
class _GenderSelector extends StatelessWidget {
  final String? selectedGender;
  final Function(String) onChanged;
  final bool isCompact;
  const _GenderSelector({required this.selectedGender, required this.onChanged, this.isCompact = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildGenderButton(context, 'MALE', Icons.male_rounded)),
        SizedBox(width: isCompact ? 12.w : 12.0),
        Expanded(child: _buildGenderButton(context, 'FEMALE', Icons.female_rounded)),
      ],
    );
  }

  Widget _buildGenderButton(BuildContext context, String gender, IconData icon) {
    final bool isSelected = selectedGender == gender;
    return GestureDetector(
      onTap: () => onChanged(gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isCompact ? 56.h : 54.0,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.surfaceLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          border: Border.all(color: isSelected ? AppColors.crimson : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.crimson : AppColors.textSecondary, size: isCompact ? 20.r : 20.0),
            SizedBox(width: isCompact ? 8.w : 8.0),
            Text(
              gender, 
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary, 
                fontWeight: FontWeight.w500,
              )
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool isCompact;
  const _SelectorField({
    required this.hint, 
    required this.icon, 
    required this.onTap, 
    this.onClear,
    this.isCompact = true
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 16.w : 16.0, 
                  vertical: isCompact ? 16.h : 16.0
                ),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 20.0),
                    SizedBox(width: isCompact ? 12.w : 12.0),
                    Text(
                      hint, 
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: Colors.white70,
                      )
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              icon: Icon(Icons.close_rounded, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 18.r),
              onPressed: onClear,
              padding: EdgeInsets.only(right: 8.w),
            ),
        ],
      ),
    );
  }
}
