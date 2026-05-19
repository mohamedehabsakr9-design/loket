import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final notifications = [
      _NotificationItem(
        icon: Icons.local_offer_outlined,
        title: isArabic ? 'خصومات جديدة' : 'New discounts',
        body: isArabic
            ? 'خصومات مميزة على منتجات مختارة لفترة محدودة.'
            : 'Special discounts on selected products for a limited time.',
        time: isArabic ? 'الآن' : 'Now',
      ),
      _NotificationItem(
        icon: Icons.shopping_bag_outlined,
        title: isArabic ? 'منتجات جديدة وصلت' : 'New arrivals are here',
        body: isArabic
            ? 'تم إضافة منتجات جديدة في المتجر، اكتشفها الآن.'
            : 'New products have been added to the store. Discover them now.',
        time: isArabic ? 'منذ 10 دقائق' : '10 min ago',
      ),
      _NotificationItem(
        icon: Icons.favorite_border_rounded,
        title: isArabic ? 'المفضلة' : 'Wishlist update',
        body: isArabic
            ? 'تابع المنتجات اللي ضفتها للمفضلة من صفحة Wishlist.'
            : 'Keep track of products you added to your wishlist.',
        time: isArabic ? 'اليوم' : 'Today',
      ),
      _NotificationItem(
        icon: Icons.local_shipping_outlined,
        title: isArabic ? 'متابعة الطلبات' : 'Track your orders',
        body: isArabic
            ? 'تقدر تتابع حالة طلباتك من صفحة My Orders.'
            : 'You can follow your order status from My Orders.',
        time: isArabic ? 'اليوم' : 'Today',
      ),
    ];

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            isArabic
                                ? Icons.arrow_forward_ios_rounded
                                : Icons.arrow_back_ios_new_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      isArabic ? 'الإشعارات' : 'Notification',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: notifications.isEmpty
                    ? _EmptyNotifications(isArabic: isArabic)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          return _NotificationCard(
                            item: notifications[index],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final _NotificationItem item;

  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 92,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F0F0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              color: Colors.black,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.time,
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  item.body,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem {
  final IconData icon;
  final String title;
  final String body;
  final String time;

  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
  });
}

class _EmptyNotifications extends StatelessWidget {
  final bool isArabic;

  const _EmptyNotifications({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F0F0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.black38,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isArabic ? 'لا توجد إشعارات' : 'No notifications yet',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'أي تحديثات جديدة هتظهر هنا.'
                  : 'Any new updates will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
