import 'package:flutter/material.dart';
import '../../app/app_strings.dart';
import '../rating/rate_experience_dialog.dart';

class OrderDetailsScreen extends StatelessWidget {
  final String orderId;
  final bool isCompleted; // true => شاشة completed / فيها Rate

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            s.orderDetailsTitle, // "Order Details"
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.orderDetailsThankYouTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.orderDetailsThankYouBody,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                s.orderDetailsSectionTitle, // "Order details"
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: s.orderDetailsStatusLabel,
                value: isCompleted
                    ? s.orderStatusCompleted
                    : s.orderStatusPending,
                valueColor: isCompleted ? Colors.green : Colors.orange,
              ),
              _DetailRow(
                label: s.orderDetailsNumberLabel,
                value: orderId,
              ),
              _DetailRow(
                label: s.orderDetailsDateLabel,
                value: '5 / 5 / 2025',
              ),
              _DetailRow(
                label: s.orderDetailsPaymentMethodLabel,
                value: s.paymentCashOnDelivery,
              ),
              _DetailRow(
                label: s.orderDetailsPhoneLabel,
                value: '010336658997',
              ),
              _DetailRow(
                label: s.orderDetailsAddressLabel,
                value: 'Cairo - Almaadi - Street 9',
                isMultiline: true,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                s.orderDetailsStatusSectionTitle, // "Order Status"
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _TimelineItem(
                dateText: 'November 16\n11 : 00 pm',
                title: s.timelineConfirmedTitle,
                subtitle: s.timelineConfirmedBody,
                isActive: true,
              ),
              _TimelineItem(
                dateText: 'November 18\n2 : 00 pm',
                title: s.timelineShippedTitle,
                subtitle: s.timelineShippedBody,
                isActive: isCompleted,
              ),
              _TimelineItem(
                dateText: 'November 19\n4 : 00 pm',
                title: s.timelineDeliveredTitle,
                subtitle: s.timelineDeliveredBody,
                isActive: isCompleted,
                isLast: true,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              if (isCompleted)
                _RateOrderSection(s: s)
              else
                _CancelOrderSection(s: s),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMultiline;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isMultiline = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment:
            isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              '$label :',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String dateText;
  final String title;
  final String subtitle;
  final bool isActive;
  final bool isLast;

  const _TimelineItem({
    required this.dateText,
    required this.title,
    required this.subtitle,
    required this.isActive,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isActive ? Colors.green : Colors.grey;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            dateText,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ),
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RateOrderSection extends StatelessWidget {
  final AppStrings s;
  const _RateOrderSection({required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.orderRateSectionTitle, // "Rate Your Order"
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.orderRateSectionBody,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () async {
              final result = await showRateExperienceDialog(context, s);
              if (result != null) {
                // TODO: إرسال التقييم للسيرفر
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Text(
              s.orderRateButton, // "Rate Your Order"
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CancelOrderSection extends StatelessWidget {
  final AppStrings s;
  const _CancelOrderSection({required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.orderCancelSectionTitle, // "Want to Cancel Your Order?"
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.orderCancelSectionBody,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () {
              // TODO: cancel order
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Text(
              s.orderCancelButton, // "Cancel Order"
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
