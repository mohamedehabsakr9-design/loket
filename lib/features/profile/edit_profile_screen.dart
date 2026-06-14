import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final data = await ApiService.get('/account', withAuth: true);
      final map = data is Map ? data : <String, dynamic>{};
      final nested = map['data'];
      final source = nested is Map ? nested : map;

      final firstName = _firstText([
        source['firstName'],
        source['firstname'],
        source['givenName'],
      ]);
      final lastName = _firstText([
        source['lastName'],
        source['lastname'],
        source['familyName'],
      ]);
      final name = _firstText([source['name'], source['fullName']]);

      if (!mounted) return;
      setState(() {
        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          _firstNameController.text = firstName;
          _lastNameController.text = lastName;
        } else if (name.isNotEmpty) {
          final parts = name.split(' ');
          _firstNameController.text = parts.isNotEmpty ? parts.first : '';
          _lastNameController.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }

        _emailController.text = _firstText([source['email']]);
        _phoneController.text = _firstText([
          source['phone'],
          source['phoneNumber'],
          source['mobile'],
        ]);
        _avatarUrl = _firstText([
          source['avatarUrl'],
          source['profileImage'],
          source['imageUrl'],
        ]);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^\d{10,15}$').hasMatch(phone);
  }

  Future<void> _saveProfile() async {
    final s = AppStrings.of(context);
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || phone.isEmpty) {
      _showMessage(s.pleaseFillAllFields, error: true);
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage(s.isArabic ? 'البريد الإلكتروني غير صحيح' : 'Invalid email address', error: true);
      return;
    }

    if (!_isValidPhone(phone)) {
      _showMessage(s.isArabic ? 'رقم الهاتف غير صحيح' : 'Enter a valid phone number', error: true);
      return;
    }

    setState(() => _isSaving = true);

    final body = {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
    };

    try {
      try {
        await ApiService.put('/account', body: body, withAuth: true);
      } catch (_) {
        await ApiService.patch('/account', body: body, withAuth: true);
      }

      if (!mounted) return;
      _showMessage(s.isArabic ? 'تم تحديث الملف الشخصي' : 'Profile updated successfully');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _EditProfileHeader(
                title: s.profileEditProfile,
                onBack: _isSaving ? null : () => Navigator.pop(context),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.black))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            _AvatarBlock(avatarUrl: _avatarUrl),
                            const SizedBox(height: 34),
                            _ProfileInput(
                              controller: _firstNameController,
                              label: s.signUpFirstName,
                              icon: Icons.person_outline_rounded,
                              enabled: !_isSaving,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 18),
                            _ProfileInput(
                              controller: _lastNameController,
                              label: s.signUpLastName,
                              icon: Icons.person_outline_rounded,
                              enabled: !_isSaving,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 18),
                            _ProfileInput(
                              controller: _emailController,
                              label: s.signUpEmailLabel,
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !_isSaving,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 18),
                            _ProfileInput(
                              controller: _phoneController,
                              label: s.signUpPhone,
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              enabled: !_isSaving,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                if (!_isSaving) _saveProfile();
                              },
                            ),
                            const SizedBox(height: 34),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: const Color(0xFF1D282E),
                                  disabledBackgroundColor: const Color(0xFF1D282E).withOpacity(0.55),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isArabic ? 'حفظ' : 'Save',
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
      ),
    );
  }
}

class _EditProfileHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const _EditProfileHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    width: 44,
                    height: 44,
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  ),
                ),
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 23,
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  final String? avatarUrl;

  const _AvatarBlock({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim() ?? '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F1F1),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: url.isEmpty
              ? const Icon(Icons.person_rounded, size: 62, color: Colors.black38)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person_rounded,
                    size: 62,
                    color: Colors.black38,
                  ),
                ),
        ),
        PositionedDirectional(
          end: 0,
          bottom: 4,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1D282E),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 17),
          ),
        ),
      ],
    );
  }
}

class _ProfileInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _ProfileInput({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            color: Color(0xFF4E5356),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 54,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF777777)),
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

String _firstText(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != 'null') return text;
  }
  return '';
}
