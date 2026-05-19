import 'package:flutter/material.dart';

import '../../app/app_strings.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final sections = isArabic ? _arabicSections : _englishSections;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _ProfilePageHeader(
              title: s.privacyPolicyTitle,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                itemCount: sections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final section = sections[index];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. ${section.title}',
                        style: const TextStyle(
                          fontSize: 19,
                          height: 1.15,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2D3336),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        section.body,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.42,
                          color: Color(0xFF3F4548),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacySection {
  final String title;
  final String body;

  const _PrivacySection(this.title, this.body);
}

const List<_PrivacySection> _englishSections = [
  _PrivacySection(
    'Introduction',
    'We value your privacy and are committed to protecting your personal data when you use our mobile application or website. This Privacy Policy explains how we collect, use, and safeguard your information.',
  ),
  _PrivacySection(
    'Information We Collect',
    'We may collect information such as your name, email address, phone number, shipping address, order details, and app activity to provide a better shopping experience.',
  ),
  _PrivacySection(
    'How We Use Your Information',
    'We use your information to manage your account, process orders, improve our services, personalize recommendations, and communicate important updates.',
  ),
  _PrivacySection(
    'Data Protection',
    'We apply reasonable security measures to protect your data from unauthorized access, loss, misuse, or disclosure. Your account information remains private and secure.',
  ),
  _PrivacySection(
    'Contact Us',
    'If you have any questions about this Privacy Policy or your personal data, please contact our support team through the application.',
  ),
];

const List<_PrivacySection> _arabicSections = [
  _PrivacySection(
    'مقدمة',
    'نحن نقدّر خصوصيتك ونلتزم بحماية بياناتك الشخصية عند استخدام التطبيق أو الموقع. توضح سياسة الخصوصية هذه كيفية جمع واستخدام وحماية معلوماتك.',
  ),
  _PrivacySection(
    'المعلومات التي نجمعها',
    'قد نقوم بجمع بيانات مثل الاسم والبريد الإلكتروني ورقم الهاتف وعنوان الشحن وتفاصيل الطلبات ونشاطك داخل التطبيق لتحسين تجربة التسوق.',
  ),
  _PrivacySection(
    'كيف نستخدم معلوماتك',
    'نستخدم معلوماتك لإدارة حسابك ومعالجة الطلبات وتحسين خدماتنا وتخصيص التوصيات وإرسال التحديثات المهمة.',
  ),
  _PrivacySection(
    'حماية البيانات',
    'نستخدم إجراءات أمان مناسبة لحماية بياناتك من الوصول غير المصرح به أو الفقدان أو سوء الاستخدام أو الإفصاح.',
  ),
  _PrivacySection(
    'تواصل معنا',
    'إذا كان لديك أي استفسار بخصوص سياسة الخصوصية أو بياناتك الشخصية، يمكنك التواصل مع فريق الدعم من خلال التطبيق.',
  ),
];

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
