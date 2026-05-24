import 'package:flutter/material.dart';
import '../../app/app_strings.dart';
import '../../services/auth_service.dart';
import 'reset_password_screen.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() =>
      _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState
    extends State<ForgetPasswordScreen> {

  final TextEditingController _emailController =
      TextEditingController();

  bool _isLoading = false;

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(email);
  }

  Future<void> _sendResetEmail() async {
    final s = AppStrings.of(context);

    final email = _emailController.text.trim();

    // Empty validation
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.pleaseFillAllFields),
        ),
      );
      return;
    }

    // Strong email validation
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid email address'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await AuthService.forgotPassword(
        email: email,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.resetCodeSent)),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ResetPasswordScreen(email: email),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Email not found or server error'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    final isArabic =
        Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection:
          isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFEEEEEE),
        body: SafeArea(
          child: Column(
            children: [

              // Top Image
              Expanded(
                flex: 4,
                child: Center(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Image.asset(
                      'lib/assets/bro.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // Bottom White Container
              Expanded(
                flex: 6,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    28,
                    36,
                    28,
                    24,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        // Title
                        const Text(
                          'Forget Password',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Email Label
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Email Field
                        TextField(
                          controller: _emailController,
                          keyboardType:
                              TextInputType.emailAddress,
                          textAlign: isArabic
                              ? TextAlign.right
                              : TextAlign.left,
                          decoration: InputDecoration(
                            hintTextDirection: isArabic
                                ? TextDirection.rtl
                                : TextDirection.ltr,

                            hintText:
                                'example@gmail.com',

                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: Colors.black54,
                            ),

                            filled: true,
                            fillColor: Colors.white,

                            enabledBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color:
                                    Colors.grey.shade300,
                              ),
                            ),

                            focusedBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),

                            contentPadding:
                                const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Send Button
                        SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : _sendResetEmail,

                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.black,

                              disabledBackgroundColor:
                                  Colors.black54,

                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                              ),

                              elevation: 0,
                            ),

                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Send',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Remember Password
                        Center(
                          child: GestureDetector(
                            onTap: () =>
                                Navigator.pop(context),

                            child: Text.rich(
                              TextSpan(
                                text: s
                                    .forgetPasswordRemember,

                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),

                                children: [
                                  TextSpan(
                                    text: s
                                        .forgetPasswordSignIn,

                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      decoration:
                                          TextDecoration
                                              .underline,

                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),

                              textAlign:
                                  TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
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