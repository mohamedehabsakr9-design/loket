import 'package:flutter/material.dart';
import '../../app/app_strings.dart';
import '../../services/api_service.dart';
import '../rating/rate_experience_dialog.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final bool isCompleted;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.isCompleted,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isLoading = true;
  bool _isCancelling = false;
  String? _error;
  Map<String, dynamic> _order = {};

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  String get _cleanOrderId => widget.orderId.replaceAll('#', '');

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.get(
        '/orders/$_cleanOrderId',
        withAuth: true,
      );

      if (!mounted) return;

      setState(() {
        _order = data is Map ? Map<String, dynamic>.from(data) : {};
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelOrder(AppStrings s) async {
    setState(() => _isCancelling = true);

    try {
      await ApiService.patch(
        '/orders/$_cleanOrderId/cancel',
        body: {
          'status': 'CANCELLED',
        },
        withAuth: true,
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isArabic ? 'تم إلغاء الطلب بنجاح' : 'Order cancelled successfully',
          ),
          backgroundColor: Colors.deepOrange,
        ),
      );

      _loadOrderDetails();
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  String _readString(String key) {
    final value = _order[key];
    if (value == null) return '';
    return value.toString();
  }

  String _status(AppStrings s) {
    final status = _readString('status');
    if (status.isNotEmpty) return status;
    return widget.isCompleted ? s.orderStatusCompleted : s.orderStatusPending;
  }

  bool _isCompleted() {
    final status = _readString('status').toLowerCase();
    if (status.isEmpty) return widget.isCompleted;

    return status.contains('completed') ||
        status.contains('delivered') ||
        status.contains('done') ||
        status.contains('paid');
  }

  String _date() {
    final value = _readString('createdAt').isNotEmpty
        ? _readString('createdAt')
        : _readString('orderDate');

    if (value.isEmpty) return '-';

    return value.replaceFirst('T', ' ').split('.').first;
  }

  String _paymentMethod(AppStrings s) {
    final value = _readString('paymentMethod');
    return value.isEmpty ? s.paymentCashOnDelivery : value;
  }

  String _phone() {
    return _readString('phone').isNotEmpty
        ? _readString('phone')
        : _readString('customerPhone');
  }

  String _address() {
    final direct = _readString('address');
    if (direct.isNotEmpty) return direct;

    final shippingAddress = _order['shippingAddress'];
    if (shippingAddress is Map) {
      return [
        shippingAddress['city'],
        shippingAddress['area'],
        shippingAddress['street'],
      ].where((e) => e != null && e.toString().isNotEmpty).join(' - ');
    }

    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final completed = _isCompleted();

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
            s.orderDetailsTitle,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(
                    message: _error!,
                    onRetry: _loadOrderDetails,
                  )
                : RefreshIndicator(
                    onRefresh: _loadOrderDetails,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            s.orderDetailsSectionTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: s.orderDetailsStatusLabel,
                            value: _status(s),
                            valueColor:
                                completed ? Colors.green : Colors.deepOrange,
                            icon:
                                completed ? Icons.check_circle : Icons.schedule,
                          ),
                          _DetailRow(
                            label: s.orderDetailsNumberLabel,
                            value: widget.orderId,
                            icon: Icons.receipt_long_outlined,
                          ),
                          _DetailRow(
                            label: s.orderDetailsDateLabel,
                            value: _date(),
                            icon: Icons.calendar_today,
                          ),
                          _DetailRow(
                            label: s.orderDetailsPaymentMethodLabel,
                            value: _paymentMethod(s),
                            icon: Icons.payment,
                          ),
                          _DetailRow(
                            label: s.orderDetailsPhoneLabel,
                            value: _phone().isEmpty ? '-' : _phone(),
                            icon: Icons.phone,
                          ),
                          _DetailRow(
                            label: s.orderDetailsAddressLabel,
                            value: _address(),
                            icon: Icons.location_on_outlined,
                            isMultiline: true,
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            s.orderDetailsStatusSectionTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _TimelineItem(
                            dateText: _date(),
                            title: s.timelineConfirmedTitle,
                            subtitle: s.timelineConfirmedBody,
                            isActive: true,
                            icon: Icons.check_circle_outline,
                            iconColor: Colors.green,
                          ),
                          _TimelineItem(
                            dateText: _date(),
                            title: s.timelineShippedTitle,
                            subtitle: s.timelineShippedBody,
                            isActive: completed,
                            icon: Icons.local_shipping_outlined,
                            iconColor: completed ? Colors.green : Colors.grey,
                          ),
                          _TimelineItem(
                            dateText: _date(),
                            title: s.timelineDeliveredTitle,
                            subtitle: s.timelineDeliveredBody,
                            isActive: completed,
                            isLast: true,
                            icon: Icons.delivery_dining_outlined,
                            iconColor: completed ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          if (completed) ...[
                            _RateOrderSection(s: s),
                            const SizedBox(height: 16),
                          ] else ...[
                            _CancelOrderSection(
                              s: s,
                              isCancelling: _isCancelling,
                              onCancelConfirmed: () => _cancelOrder(s),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (completed) ...[
                            const Divider(),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                s.orderDetailsThankYouTitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Center(
                              child: Text(
                                s.orderDetailsThankYouBody,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
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
  final IconData? icon;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isMultiline = false,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment:
            isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 4,
            child: Text(
              '$label :',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
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
              textAlign: TextAlign.end,
              maxLines: isMultiline ? 3 : 1,
              overflow: TextOverflow.ellipsis,
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
  final IconData icon;
  final Color iconColor;

  const _TimelineItem({
    required this.dateText,
    required this.title,
    required this.subtitle,
    required this.isActive,
    this.isLast = false,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = AppStrings.of(context).isArabic;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              dateText,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? iconColor : Colors.grey[300],
                  border: Border.all(
                    color: isActive ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 10,
                  color: isActive ? Colors.white : Colors.grey,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
                  color: Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isActive ? Colors.green.withOpacity(0.05) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? Colors.green.withOpacity(0.2)
                      : Colors.grey[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                isActive ? Colors.green[700] : Colors.black87,
                          ),
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isArabic ? 'مكتمل' : 'Done',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? Colors.green[700] : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateOrderSection extends StatelessWidget {
  final AppStrings s;

  const _RateOrderSection({required this.s});

  @override
  Widget build(BuildContext context) {
    final isArabic = s.isArabic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text(
              s.orderRateSectionTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            s.orderRateSectionBody,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () async {
              final result = await showRateExperienceDialog(context, s);

              if (result != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isArabic
                          ? 'تم إرسال تقييمك بنجاح!'
                          : 'Your rating has been submitted successfully!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Text(
                  s.orderRateButton,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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

class _CancelOrderSection extends StatelessWidget {
  final AppStrings s;
  final bool isCancelling;
  final VoidCallback onCancelConfirmed;

  const _CancelOrderSection({
    required this.s,
    required this.isCancelling,
    required this.onCancelConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.orderCancelSectionTitle,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.deepOrange,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          s.orderCancelSectionBody,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: isCancelling
                ? null
                : () => _showCancelConfirmationDialog(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.deepOrange.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: Colors.deepOrange.withOpacity(0.3),
                ),
              ),
            ),
            child: isCancelling
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cancel_outlined,
                        color: Colors.deepOrange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.orderCancelButton,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _showCancelConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber,
              color: Colors.deepOrange,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.orderCancelDialogTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          s.orderCancelDialogBody,
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              s.orderCancelDialogNo,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: onCancelConfirmed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              s.orderCancelDialogYes,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}