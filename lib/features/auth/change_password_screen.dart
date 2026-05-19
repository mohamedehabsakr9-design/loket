import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      ),
    );
  }

  Future<void> _savePassword() async {
    final s = AppStrings.of(context);
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showMessage(s.pleaseFillAllFields, isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage(
        s.isArabic ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match',
        isError: true,
      );
      return;
    }

    if (newPassword.length < 8) {
      _showMessage(
        s.isArabic
            ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'
            : 'Password must be at least 8 characters',
        isError: true,
      );
      return;
    }

    if (oldPassword == newPassword) {
      _showMessage(
        s.isArabic
            ? 'كلمة المرور الجديدة يجب أن تكون مختلفة عن القديمة'
            : 'New password must be different from old password',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
        confirmNewPassword: confirmPassword,
      );

      if (!mounted) return;

      _showMessage(s.passwordResetSuccessfully);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      final raw = e.toString();
      String errorMsg = s.isArabic ? 'فشل تغيير كلمة المرور' : 'Failed to change password';

      if (raw.contains('403') || raw.contains('Forbidden') || raw.toLowerCase().contains('wrong')) {
        errorMsg = s.isArabic ? 'كلمة المرور الحالية غير صحيحة' : 'Old password is incorrect';
      } else if (raw.contains('401')) {
        errorMsg = s.isArabic ? 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى' : 'Session expired, please login again';
      }

      _showMessage(errorMsg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _ProfilePageHeader(
              title: s.changePasswordTitle,
              onBack: _isLoading ? null : () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
                child: Column(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF4F4F4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: Color(0xFF1D282E),
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _PasswordInput(
                      controller: _oldPasswordController,
                      label: s.changePasswordOld,
                      obscure: _obscureOld,
                      enabled: !_isLoading,
                      onToggle: () => setState(() => _obscureOld = !_obscureOld),
                    ),
                    const SizedBox(height: 18),
                    _PasswordInput(
                      controller: _newPasswordController,
                      label: s.changePasswordNew,
                      obscure: _obscureNew,
                      enabled: !_isLoading,
                      onToggle: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                    const SizedBox(height: 18),
                    _PasswordInput(
                      controller: _confirmPasswordController,
                      label: s.changePasswordConfirm,
                      obscure: _obscureConfirm,
                      enabled: !_isLoading,
                      onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _savePassword,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF1D282E),
                          disabledBackgroundColor: const Color(0xFF1D282E).withOpacity(0.55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                s.changePasswordSave,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final bool enabled;
  final VoidCallback onToggle;

  const _PasswordInput({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF4E5356),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 52,
          child: TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscure,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF777777),
              ),
              suffixIcon: IconButton(
                onPressed: onToggle,
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF777777),
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF1D282E), width: 1.3),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const _ProfilePageHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).padding.top + 104,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.05), width: 1),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Material(
              color: const Color(0xFFF4F4F4),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack,
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
