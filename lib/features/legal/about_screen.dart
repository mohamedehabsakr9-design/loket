// about_screen.dart
import 'package:flutter/material.dart';
import '../../app/app_strings.dart'; // كلاس النصوص المترجمة

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            s.aboutTitle, // يتغير عربي/إنجليزي
            style: const TextStyle(color: Colors.black),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              // لوجو Lokit
              CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFFF5F5F5),
                child: ClipOval(
                  child: Image.asset(
                    'lib/assets/logo.png', // نفس المسار في pubspec.yaml
                    fit: BoxFit.contain,
                    width: 72,
                    height: 72,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                s.aboutBody, // نص من AppStrings بالعربي أو الإنجليزي
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
