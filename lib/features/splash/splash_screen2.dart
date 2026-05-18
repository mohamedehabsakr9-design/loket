// onboarding_screen.dart
import 'package:flutter/material.dart';
import '../auth/sign_in_screen.dart';
import '../../app/app_strings.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToSignIn() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';

    // نحدد بيانات الصفحات حسب اللغة
    final List<_OnboardPageData> pages = [
      _OnboardPageData(
        image: 'lib/assets/splash1.jpg',
        title: s.onboardingTitle1,
        showSmallLokit: false,
      ),
      _OnboardPageData(
        image: 'lib/assets/splash2.jpg',
        title: s.onboardingTitle2,
        showSmallLokit: true,
      ),
    ];

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: PageView.builder(
          controller: _controller,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemCount: pages.length,
          itemBuilder: (context, index) {
            final page = pages[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                // خلفية الصورة
                Image.asset(page.image, fit: BoxFit.cover),

                // طبقة تغميق خفيفة
                Container(
                  color: Colors.black.withValues(alpha: 0.25),
                ),

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // نقاط + Skip
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: List.generate(
                                pages.length,
                                (i) {
                                  final isActive = i == _currentPage;
                                  return GestureDetector(
                                    onTap: () {
                                      _controller.animateToPage(
                                        i,
                                        duration:
                                            const Duration(milliseconds: 400),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            TextButton(
                              onPressed: _goToSignIn, // Skip → SignIn
                              child: Text(
                                s.onboardingSkip,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        if (page.showSmallLokit)
                          Text(
                            s.appName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),

                        const SizedBox(height: 8),

                        Text(
                          page.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const Spacer(),

                        Center(
                          child: SizedBox(
                            width: 230,
                            height: 48,
                            child: ElevatedButton(
                              // Sign Up & Login → SignIn برضه (أو شاشة اختيار)
                              onPressed: _goToSignIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                shape: StadiumBorder(
                                  side: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    s.onboardingCta,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
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
}

class _OnboardPageData {
  final String image;
  final String title;
  final bool showSmallLokit;

  const _OnboardPageData({
    required this.image,
    required this.title,
    this.showSmallLokit = false,
  });
}
