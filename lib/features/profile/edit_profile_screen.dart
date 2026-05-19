import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../services/api_service.dart';

const String kBaseUrl = 'https://lokit-production.up.railway.app';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  String? _avatarUrl;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    emailController.dispose();
    usernameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final data = await ApiService.get('/account', withAuth: true);

      if (!mounted) return;

      if (data is Map) {
        final firstName = _readString(data, 'firstName');
        final lastName = _readString(data, 'lastName');
        final username = _firstText([
          _readString(data, 'username'),
          _readString(data, 'userName'),
          '$firstName $lastName'.trim(),
        ]);

        emailController.text = _readString(data, 'email');
        usernameController.text = username;
        firstNameController.text = firstName;
        lastNameController.text = lastName;
        phoneController.text = _firstText([
          _readString(data, 'phone'),
          _readString(data, 'phoneNumber'),
          _readString(data, 'mobile'),
        ]);

        final avatar = _firstText([
          _readString(data, 'avatarUrl'),
          _readString(data, 'profileImage'),
          _readString(data, 'imageUrl'),
        ]);

        _avatarUrl = _fullImageUrl(avatar);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _saveProfile() async {
    final s = AppStrings.of(context);
    final email = emailController.text.trim();
    final username = usernameController.text.trim();
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final phone = phoneController.text.trim();

    if (email.isEmpty || firstName.isEmpty || lastName.isEmpty) {
      _showMessage(s.pleaseFillAllFields, isError: true);
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showMessage(
        s.isArabic ? 'البريد الإلكتروني غير صحيح' : 'Invalid email address',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ApiService.put(
        '/account',
        body: {
          'email': email,
          'username': username,
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
        },
        withAuth: true,
      );

      if (!mounted) return;

      _showMessage(
        s.isArabic ? 'تم تحديث البيانات بنجاح' : 'Profile updated successfully',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _readString(Map data, String key) {
    final value = data[key];
    if (value == null) return '';
    final text = value.toString().trim();
    return text == 'null' ? '' : text;
  }

  String _firstText(List<String> values) {
    for (final value in values) {
      final text = value.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  String? _fullImageUrl(String url) {
    final clean = url.trim();
    if (clean.isEmpty || clean == 'null') return null;
    if (clean.startsWith('http')) return clean;
    if (clean.startsWith('/')) return '$kBaseUrl$clean';
    return '$kBaseUrl/$clean';
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
              title: s.editProfileTitle,
              onBack: _isSaving ? null : () => Navigator.pop(context),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 57,
                                  backgroundColor: const Color(0xFFE9E9E9),
                                  backgroundImage: _avatarUrl != null &&
                                          _avatarUrl!.isNotEmpty
                                      ? NetworkImage(_avatarUrl!)
                                      : null,
                                  child: _avatarUrl == null || _avatarUrl!.isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.black38,
                                          size: 56,
                                        )
                                      : null,
                                ),
                                PositionedDirectional(
                                  end: 4,
                                  bottom: 2,
                                  child: Material(
                                    color: Colors.white,
                                    shape: const CircleBorder(),
                                    elevation: 1.5,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        _showMessage(
                                          s.isArabic
                                              ? 'تغيير الصورة غير متاح حالياً'
                                              : 'Changing photo is not available yet',
                                        );
                                      },
                                      child: const SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: Icon(
                                          Icons.edit_square,
                                          size: 18,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 34),
                          _ProfileInput(
                            label: s.editProfileEmail,
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isSaving,
                          ),
                          const SizedBox(height: 18),
                          _ProfileInput(
                            label: s.editProfileUserName,
                            controller: usernameController,
                            enabled: !_isSaving,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _ProfileInput(
                                  label: s.editProfileFirstName,
                                  controller: firstNameController,
                                  enabled: !_isSaving,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _ProfileInput(
                                  label: s.editProfileLastName,
                                  controller: lastNameController,
                                  enabled: !_isSaving,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _ProfileInput(
                            label: s.editProfilePhone,
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            enabled: !_isSaving,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: const Color(0xFF1D282E),
                                disabledBackgroundColor:
                                    const Color(0xFF1D282E).withOpacity(0.55),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
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
                                      s.editProfileSaveChanges,
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

class _ProfileInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool enabled;

  const _ProfileInput({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.enabled = true,
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
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 47,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
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
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF444444),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
