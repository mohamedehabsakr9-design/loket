import 'package:flutter/material.dart';

import '../../main.dart';
import '../../app/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/lokit_bottom_nav_bar.dart';

import 'edit_profile_screen.dart';
import '../shipping/shipping_address_screen.dart';
import '../auth/change_password_screen.dart';
import '../auth/sign_in_screen.dart';
import '../legal/about_screen.dart';
import '../legal/privacy_policy_screen.dart';
import '../support/support_chat_screen.dart';
import '../orders/my_orders_screen.dart';

class ProfileMenuScreen extends StatefulWidget {
  final String? userName;
  final String? userEmail;
  final String? avatarUrl;

  const ProfileMenuScreen({
    super.key,
    this.userName,
    this.userEmail,
    this.avatarUrl,
  });

  @override
  State<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends State<ProfileMenuScreen> {
  String _selectedLanguage = 'English';
  bool _replicate = false;
  bool _isLoggingOut = false;
  bool _isLoadingProfile = true;

  String _name = '';
  String _email = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();

    _name = widget.userName ?? '';
    _email = widget.userEmail ?? '';
    _avatarUrl = widget.avatarUrl;

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.get('/account', withAuth: true);

      if (!mounted) return;

      if (data is Map) {
        final firstName = _readString(data, 'firstName');
        final lastName = _readString(data, 'lastName');
        final fullName = _readString(data, 'name');

        setState(() {
          _name = fullName.isNotEmpty
              ? fullName
              : '$firstName $lastName'.trim();

          _email = _readString(data, 'email');
          _avatarUrl = _readString(data, 'avatarUrl').isNotEmpty
              ? _readString(data, 'avatarUrl')
              : _readString(data, 'profileImage');

          _isLoadingProfile = false;
        });
      } else {
        setState(() => _isLoadingProfile = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    await AuthService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  String _readString(Map data, String key) {
    final value = data[key];
    if (value == null) return '';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';

    _selectedLanguage = isArabic ? 'Arabic' : 'English';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Container(
              color: const Color(0xFF11181F),
              padding: const EdgeInsets.only(
                top: 48,
                left: 16,
                right: 16,
                bottom: 24,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null || _avatarUrl!.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: Colors.black54,
                            size: 28,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isLoadingProfile
                        ? const Text(
                            'Loading...',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name.isEmpty ? 'User' : _name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _email.isEmpty ? 'user@email.com' : _email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                  InkWell(
                    onTap: _loadProfile,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF11181F),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.sync,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      s.profilePersonalInfo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  _ProfileTile(
                    icon: Icons.edit_outlined,
                    title: s.profileEditProfile,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );

                      _loadProfile();
                    },
                  ),

                  _ProfileTile(
                    icon: Icons.shopping_bag_outlined,
                    title: s.profileMyOrders,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyOrdersScreen(),
                        ),
                      );
                    },
                  ),

                  _ProfileTile(
                    icon: Icons.local_shipping_outlined,
                    title: s.profileShippingAddress,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShippingAddressScreen(),
                        ),
                      );
                    },
                  ),

                  const Divider(height: 24, thickness: 0.6),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      s.profileSupportInfo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  _ProfileTile(
                    icon: Icons.shield_outlined,
                    title: s.profilePrivacyPolicy,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),

                  _ProfileTile(
                    icon: Icons.headphones_outlined,
                    title: s.profileSupportChat,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SupportChatScreen(),
                        ),
                      );
                    },
                  ),

                  _ProfileTile(
                    icon: Icons.info_outline,
                    title: s.profileAbout,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),

                  const Divider(height: 24, thickness: 0.6),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      s.profileSettings,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          const Icon(Icons.language, color: Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.profileLanguage,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              setState(() {
                                _selectedLanguage = value;
                              });

                              if (value == 'English') {
                                LokitApp.setLocale(context, const Locale('en'));
                              } else {
                                LokitApp.setLocale(context, const Locale('ar'));
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'English',
                                child: Text('English'),
                              ),
                              PopupMenuItem(
                                value: 'Arabic',
                                child: Text('عربي'),
                              ),
                            ],
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedLanguage,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  _ProfileTile(
                    icon: Icons.lock_outline,
                    title: s.profileChangePassword,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.profileReplicate,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Switch(
                            value: _replicate,
                            activeThumbColor: Colors.white,
                            activeTrackColor: Colors.black,
                            onChanged: (val) {
                              setState(() => _replicate = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoggingOut ? null : _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          disabledBackgroundColor: Colors.black54,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isLoggingOut
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.logout, color: Colors.white),
                        label: Text(
                          _isLoggingOut ? 'Logging out...' : s.profileLogout,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      s.profileVersion,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ),

                  const SizedBox(height: 110),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: const LokitBottomNavBar(
          currentTab: LokitBottomTab.profile,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _ProfileTile({required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}
