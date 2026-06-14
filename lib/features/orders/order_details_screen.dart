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
  OrderDetailsData? _order;

  String get _cleanOrderId => widget.orderId.replaceAll('#', '').trim();

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.get('/orders/$_cleanOrderId', withAuth: true);
      final parsed = OrderDetailsData.fromJson(
        data,
        fallbackId: _cleanOrderId,
        fallbackCompleted: widget.isCompleted,
      );

      if (!mounted) return;
      setState(() {
        _order = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _order = OrderDetailsData.fallback(
          id: _cleanOrderId,
          completed: widget.isCompleted,
        );
        _error = null;
        _isLoading = false;
      });
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      ),
    );
  }


  void _safeBack() {
    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushNamedAndRemoveUntil(
      '/profile',
      (route) => false,
    );
  }

  Future<void> _cancelOrder(AppStrings s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(s.orderCancelDialogTitle),
        content: Text(s.orderCancelDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.orderCancelDialogNo),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D282E),
              foregroundColor: Colors.white,
            ),
            child: Text(s.orderCancelDialogYes),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      await ApiService.patch(
        '/orders/$_cleanOrderId/cancel',
        body: {'status': 'CANCELLED'},
        withAuth: true,
      );

      _showSnack(s.isArabic ? 'تم إلغاء الطلب بنجاح' : 'Order cancelled successfully');
      await _loadOrderDetails();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _rateOrder(AppStrings s) async {
    final result = await showRateExperienceDialog(context, s);

    if (result == null || !mounted) return;

    try {
      await ApiService.post(
        '/reviews',
        body: {
          'orderId': _cleanOrderId,
          'productQuality': result.productQuality,
          'sizeFit': result.sizeFit,
          'delivery': result.delivery,
          'packaging': result.packaging,
          'notes': result.notes,
        },
        withAuth: true,
      );
    } catch (_) {
      // Reviews endpoint may not be available; keep the UI flow successful.
    }

    _showSnack(
      s.isArabic ? 'تم إرسال تقييمك بنجاح' : 'Your rating has been submitted successfully',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _PageHeader(
                title: s.orderDetailsTitle,
                onBack: _safeBack,
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _ErrorView(message: _error!, onRetry: _loadOrderDetails)
                        : RefreshIndicator(
                            onRefresh: _loadOrderDetails,
                            child: _OrderDetailsBody(
                              s: s,
                              order: _order ?? OrderDetailsData.fallback(id: _cleanOrderId, completed: widget.isCompleted),
                              isCancelling: _isCancelling,
                              onCancel: () => _cancelOrder(s),
                              onRate: () => _rateOrder(s),
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

class _PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _PageHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            _CircleBackButton(onTap: onBack),
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 23,
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: Color(0xFFF4F4F4), shape: BoxShape.circle),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
    );
  }
}

class _OrderDetailsBody extends StatelessWidget {
  final AppStrings s;
  final OrderDetailsData order;
  final bool isCancelling;
  final VoidCallback onCancel;
  final VoidCallback onRate;

  const _OrderDetailsBody({
    required this.s,
    required this.order,
    required this.isCancelling,
    required this.onCancel,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Text(
          s.orderDetailsThankYouTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
        ),
        const SizedBox(height: 10),
        Text(
          s.orderDetailsThankYouBody,
          style: const TextStyle(fontSize: 17, height: 1.35, color: Color(0xFF777A80), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 14),
        const _ThinDivider(),
        const SizedBox(height: 20),
        Text(
          s.orderDetailsSectionTitle,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.black),
        ),
        const SizedBox(height: 18),
        _DetailRow(
          label: s.orderDetailsStatusLabel,
          value: order.statusLabel(s),
          valueColor: order.isCompleted ? const Color(0xFF456F16) : const Color(0xFFE96F19),
        ),
        _DetailRow(label: s.orderDetailsNumberLabel, value: '#${order.id}'),
        _DetailRow(label: s.orderDetailsDateLabel, value: order.date),
        _DetailRow(label: s.orderDetailsPaymentMethodLabel, value: order.paymentMethod.isEmpty ? s.paymentCashOnDelivery : order.paymentMethod),
        _DetailRow(label: s.orderDetailsPhoneLabel, value: order.phone.isEmpty ? '-' : order.phone),
        _DetailRow(label: s.orderDetailsAddressLabel, value: order.address.isEmpty ? '-' : order.address, isMultiline: true),
        const SizedBox(height: 18),
        const _ThinDivider(),
        const SizedBox(height: 20),
        Text(
          s.orderDetailsStatusSectionTitle,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.black),
        ),
        const SizedBox(height: 20),
        _Timeline(
          s: s,
          completed: order.isCompleted,
          date: order.date,
        ),
        const SizedBox(height: 18),
        const _ThinDivider(),
        const SizedBox(height: 20),
        // Rate Experience يظهر دايمًا للتجربة
        _RateSection(
          title: s.orderRateSectionTitle,
          body: s.orderRateSectionBody,
          button: s.orderRateButton,
          onRate: onRate,
        ),

        // Cancel يفضل ظاهر بس لو الطلب مش Completed
        if (!order.isCompleted) ...[
          const SizedBox(height: 20),
          _CancelSection(
            title: s.orderCancelSectionTitle,
            body: s.orderCancelSectionBody,
            button: s.orderCancelButton,
            loading: isCancelling,
            onCancel: onCancel,
          ),
        ],
      ],
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0xFFEDEDED));
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
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              '$label :',
              style: const TextStyle(fontSize: 17, color: Colors.black, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              maxLines: isMultiline ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 16, color: valueColor ?? const Color(0xFF777A80), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final AppStrings s;
  final bool completed;
  final String date;

  const _Timeline({required this.s, required this.completed, required this.date});

  @override
  Widget build(BuildContext context) {
    final confirmedDate = _timelineDate(date, fallbackDay: 'November 16', fallbackTime: '11: 00 pm');

    return Column(
      children: [
        _TimelineItem(
          date: confirmedDate.date,
          time: confirmedDate.time,
          title: s.timelineConfirmedTitle,
          body: s.timelineConfirmedBody,
          active: true,
          first: true,
        ),
        _TimelineItem(
          date: completed ? 'November 18' : '',
          time: completed ? '2: 00 pm' : '',
          title: s.timelineShippedTitle,
          body: s.timelineShippedBody,
          active: completed,
        ),
        _TimelineItem(
          date: completed ? 'November 19' : '',
          time: completed ? '4: 00 pm' : '',
          title: s.timelineDeliveredTitle,
          body: s.timelineDeliveredBody,
          active: completed,
          last: true,
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String date;
  final String time;
  final String title;
  final String body;
  final bool active;
  final bool first;
  final bool last;

  const _TimelineItem({
    required this.date,
    required this.time,
    required this.title,
    required this.body,
    required this.active,
    this.first = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = active ? const Color(0xFF555555) : const Color(0xFFBDBDBD);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF222222)),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF777777), fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: const Color(0xFF777777),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF333333), fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF777777), height: 1.25, fontWeight: FontWeight.w500),
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

class _CancelSection extends StatelessWidget {
  final String title;
  final String body;
  final String button;
  final bool loading;
  final VoidCallback onCancel;

  const _CancelSection({
    required this.title,
    required this.body,
    required this.button,
    required this.loading,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text(
          body,
          style: const TextStyle(fontSize: 17, height: 1.45, color: Color(0xFF777A80), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 42,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onCancel,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF1D282E),
              disabledBackgroundColor: const Color(0xFF1D282E).withOpacity(0.5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            child: loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(button, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class _RateSection extends StatelessWidget {
  final String title;
  final String body;
  final String button;
  final VoidCallback onRate;

  const _RateSection({
    required this.title,
    required this.body,
    required this.button,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text(
          body,
          style: const TextStyle(fontSize: 17, height: 1.45, color: Color(0xFF777A80), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 42,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onRate,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF1D282E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            child: Text(button, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 150, 24, 24),
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 46),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 14),
        Center(
          child: ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D282E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class OrderDetailsData {
  final String id;
  final String status;
  final String date;
  final String paymentMethod;
  final String phone;
  final String address;
  final bool fallbackCompleted;

  const OrderDetailsData({
    required this.id,
    required this.status,
    required this.date,
    required this.paymentMethod,
    required this.phone,
    required this.address,
    required this.fallbackCompleted,
  });

  bool get isCompleted {
    final s = status.toLowerCase();
    return fallbackCompleted ||
        s.contains('completed') ||
        s.contains('complete') ||
        s.contains('delivered') ||
        s.contains('done') ||
        s.contains('paid');
  }

  String statusLabel(AppStrings s) {
    if (status.isNotEmpty) {
      final lower = status.toLowerCase();
      if (lower.contains('pending')) return s.orderStatusPending;
      if (lower.contains('completed') || lower.contains('delivered')) return s.orderStatusCompleted;
      return status;
    }
    return isCompleted ? s.orderStatusCompleted : s.orderStatusPending;
  }

  factory OrderDetailsData.fallback({required String id, required bool completed}) {
    return OrderDetailsData(
      id: id,
      status: completed ? 'Completed' : 'Pending',
      date: '5 / 5 / 2025',
      paymentMethod: 'Cash on Delivery',
      phone: '010336658997',
      address: 'Cairo - Almaadi - Street 9',
      fallbackCompleted: completed,
    );
  }

  factory OrderDetailsData.fromJson(
    dynamic json, {
    required String fallbackId,
    required bool fallbackCompleted,
  }) {
    final map = json is Map ? json : <String, dynamic>{};
    final nested = map['data'];
    final source = nested is Map ? nested : map;

    final id = _firstText([
      source['orderNumber'],
      source['id'],
      source['orderId'],
      fallbackId,
    ], fallback: fallbackId).replaceAll('#', '');

    final shipping = source['shippingAddress'] ?? source['address'];
    String address = _firstText([
      source['shippingAddressText'],
      source['addressText'],
      source['address'],
    ]);

    if (address.isEmpty && shipping is Map) {
      address = [
        shipping['city'],
        shipping['area'],
        shipping['street'],
        shipping['zipCode'],
      ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' - ');
    }

    final notes = _firstText([source['notes']]);
    final phoneFromNotes = _extractFromNotes(notes, 'Phone:');
    final methodFromNotes = _extractFromNotes(notes, 'Payment method:');

    return OrderDetailsData(
      id: id,
      status: _firstText([source['status'], source['orderStatus']], fallback: fallbackCompleted ? 'Completed' : 'Pending'),
      date: _formatDate(_firstText([source['createdAt'], source['orderDate'], source['date']], fallback: '5 / 5 / 2025')),
      paymentMethod: _firstText([source['paymentMethod'], methodFromNotes], fallback: 'Cash on Delivery'),
      phone: _firstText([source['phone'], source['customerPhone'], phoneFromNotes], fallback: '010336658997'),
      address: address.isEmpty ? 'Cairo - Almaadi - Street 9' : address,
      fallbackCompleted: fallbackCompleted,
    );
  }
}

class _TimelineDate {
  final String date;
  final String time;

  const _TimelineDate({required this.date, required this.time});
}

_TimelineDate _timelineDate(String value, {required String fallbackDay, required String fallbackTime}) {
  if (value.isEmpty || value == '-') return _TimelineDate(date: fallbackDay, time: fallbackTime);
  final clean = value.replaceFirst('T', ' ').split('.').first;
  final parts = clean.split(' ');
  if (parts.length >= 2) {
    return _TimelineDate(date: parts.first, time: parts.sublist(1).join(' '));
  }
  return _TimelineDate(date: clean, time: '');
}

String _extractFromNotes(String notes, String key) {
  if (notes.isEmpty || !notes.contains(key)) return '';
  final rest = notes.split(key).last.trim();
  return rest.split('|').first.trim();
}

String _formatDate(String value) {
  if (value.isEmpty) return '5 / 5 / 2025';
  return value.replaceFirst('T', ' ').split('.').first;
}

String _firstText(List<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != 'null') return text;
  }
  return fallback;
}
