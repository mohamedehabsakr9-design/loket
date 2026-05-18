// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// شاشات التطبيق
import 'features/splash/splash_screen1.dart';
import 'features/splash/splash_screen2.dart';
import 'features/auth/sign_in_screen.dart' as auth;
import 'features/auth/sign_up_screen.dart' as register;
import 'features/auth/forget_password_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/home/home_screen.dart';
import 'core/api/api_client.dart'; // ← جديد

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient().init(); // ← جديد
  runApp(const LokitApp());
}

class LokitApp extends StatefulWidget {
  const LokitApp({super.key});

  static void setLocale(BuildContext context, Locale locale) {
    final _LokitAppState? state =
        context.findAncestorStateOfType<_LokitAppState>();
    state?.changeLocale(locale);
  }

  @override
  State<LokitApp> createState() => _LokitAppState();
}

class _LokitAppState extends State<LokitApp> {
  Locale _locale = const Locale('en');

  void changeLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lokit',
      theme: ThemeData(
        useMaterial3: false,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return supportedLocales.first;
        for (final l in supportedLocales) {
          if (l.languageCode == locale.languageCode) return l;
        }
        return supportedLocales.first;
      },
      home: const SplashLogoScreen(),
      routes: {
        '/splash': (_) => const SplashLogoScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/signin': (_) => const auth.SignInScreen(),
        '/signup': (_) => const register.SignUpScreen(),
        '/forget-password': (_) => const ForgetPasswordScreen(),
        '/reset-password': (context) => ResetPasswordScreen(
              email: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}