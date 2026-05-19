import 'package:flutter/material.dart';

import '../../app/app_strings.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
              title: s.aboutTitle,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 38),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEDEDED),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Image.asset(
                            'lib/assets/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text(
                                'Lokit',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF1D282E),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      isArabic ? _aboutArabic : _aboutEnglish,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.42,
                        color: Color(0xFF3F4548),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
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

const String _aboutEnglish = '''Welcome to Lokit — your modern destination for trendy and elegant fashion.
We believe that style is a reflection of individuality, and our mission is to help you express it with confidence.
At Lokit, we carefully curate collections that combine quality, comfort, and the latest trends to suit every occasion — whether it’s casual, classic, or chic.
From clothing to accessories, every item is designed to bring out the best version of you.
Our goal is to make shopping simple, enjoyable, and inspiring.
With just a few taps, you can discover new arrivals, exclusive offers, and fashion ideas that match your unique style.
Lokit — Where your style begins.''';

const String _aboutArabic = '''مرحباً بك في Lokit — وجهتك العصرية للأزياء الأنيقة والمميزة.
نؤمن أن الأناقة تعبر عن شخصية كل فرد، ومهمتنا أن نساعدك على التعبير عن نفسك بثقة.
في Lokit نختار بعناية مجموعات تجمع بين الجودة والراحة وأحدث الصيحات لتناسب كل مناسبة، سواء كانت إطلالة يومية أو كلاسيكية أو عصرية.
من الملابس إلى الإكسسوارات، كل قطعة مصممة لتبرز أفضل نسخة منك.
هدفنا أن نجعل تجربة التسوق بسيطة وممتعة وملهمة.
بخطوات قليلة يمكنك اكتشاف أحدث المنتجات والعروض والأفكار التي تناسب أسلوبك.
Lokit — حيث تبدأ أناقتك.''';

class _ProfilePageHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

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
