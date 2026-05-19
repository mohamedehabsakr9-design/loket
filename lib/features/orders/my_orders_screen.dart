import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../services/api_service.dart';
import 'order_details_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool _isLoading = true;
  String? _error;
  List<OrderListItem> _orders = [];
  bool _showPending = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.get('/orders', withAuth: true);
      final list = _extractList(data).map(OrderListItem.fromJson).toList();

      if (!mounted) return;
      setState(() {
        _orders = list;
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

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final pending = _orders.where((o) => !o.isCompleted).toList();
    final completed = _orders.where((o) => o.isCompleted).toList();
    final visibleOrders = _showPending ? pending : completed;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _PageHeader(
                title: s.myOrdersTitle,
                onBack: _safeBack,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: _buildBody(s, visibleOrders),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppStrings s, List<OrderListItem> visibleOrders) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 150, 24, 24),
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 46),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Center(
            child: ElevatedButton(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D282E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(s.isArabic ? 'حاول مرة أخرى' : 'Try again'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      children: [
        _OrdersTabs(
          pendingLabel: s.myOrdersPendingTab,
          completedLabel: s.myOrdersCompletedTab,
          showPending: _showPending,
          onPending: () => setState(() => _showPending = true),
          onCompleted: () => setState(() => _showPending = false),
        ),
        const SizedBox(height: 32),
        if (visibleOrders.isEmpty)
          _EmptyOrdersView(
            text: s.myOrdersEmptyText,
            isPending: _showPending,
          )
        else
          ...visibleOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _OrderCard(
                order: order,
                detailsLabel: s.myOrdersDetailsButton,
                statusLabel: order.isCompleted
                    ? s.myOrdersCompletedStatus
                    : s.myOrdersPendingStatus,
                dateTimeLabel: s.myOrdersDateTimeLabel,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailsScreen(
                        orderId: order.idText,
                        isCompleted: order.isCompleted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _PageHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
      ),
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

class _OrdersTabs extends StatelessWidget {
  final String pendingLabel;
  final String completedLabel;
  final bool showPending;
  final VoidCallback onPending;
  final VoidCallback onCompleted;

  const _OrdersTabs({
    required this.pendingLabel,
    required this.completedLabel,
    required this.showPending,
    required this.onPending,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TabButton(
            label: pendingLabel,
            color: const Color(0xFFE96F19),
            active: showPending,
            onTap: onPending,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _TabButton(
            label: completedLabel,
            color: const Color(0xFF456F16),
            active: !showPending,
            onTap: onCompleted,
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color : color.withOpacity(0.22),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderListItem order;
  final String detailsLabel;
  final String statusLabel;
  final String dateTimeLabel;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.detailsLabel,
    required this.statusLabel,
    required this.dateTimeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = order.isCompleted ? const Color(0xFF456F16) : const Color(0xFFE96F19);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 104,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.055),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 76,
                height: 76,
                child: order.imageUrl.isNotEmpty
                    ? Image.network(
                        order.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _OrderImagePlaceholder(),
                      )
                    : const _OrderImagePlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Order #${order.idText}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        order.totalText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$dateTimeLabel : ${order.dateText}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF333333), fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 15,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$detailsLabel  ›',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF777777), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderImagePlaceholder extends StatelessWidget {
  const _OrderImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE6EEF4),
      child: const Icon(Icons.receipt_long_outlined, color: Colors.black26, size: 32),
    );
  }
}

class _EmptyOrdersView extends StatelessWidget {
  final String text;
  final bool isPending;

  const _EmptyOrdersView({required this.text, required this.isPending});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 90),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(color: Color(0xFFF4F4F4), shape: BoxShape.circle),
            child: Icon(
              isPending ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded,
              color: Colors.black26,
              size: 42,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class OrderListItem {
  final String idText;
  final String status;
  final String dateText;
  final double total;
  final String imageUrl;

  const OrderListItem({
    required this.idText,
    required this.status,
    required this.dateText,
    required this.total,
    required this.imageUrl,
  });

  bool get isCompleted {
    final s = status.toLowerCase();
    return s.contains('completed') ||
        s.contains('complete') ||
        s.contains('delivered') ||
        s.contains('done') ||
        s.contains('paid');
  }

  String get totalText => '${_formatMoney(total)} EGP';

  factory OrderListItem.fromJson(dynamic json) {
    final map = json is Map ? json : <String, dynamic>{};
    final id = _firstText([
      map['orderNumber'],
      map['id'],
      map['orderId'],
      map['number'],
    ], fallback: 'ORDER');
    final cleanId = id.replaceAll('#', '');
    final status = _firstText([map['status'], map['orderStatus']], fallback: 'Pending');
    final date = _formatDate(_firstText([map['createdAt'], map['orderDate'], map['date']]));
    final total = _toDouble(
      map['totalAmount'] ?? map['totalPrice'] ?? map['grandTotal'] ?? map['amount'] ?? map['total'],
    );
    final imageUrl = _extractOrderImage(map);

    return OrderListItem(
      idText: cleanId,
      status: status,
      dateText: date,
      total: total,
      imageUrl: imageUrl,
    );
  }
}

List<dynamic> _extractList(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['content'] is List) return data['content'] as List;
  if (data is Map && data['orders'] is List) return data['orders'] as List;
  if (data is Map && data['data'] is List) return data['data'] as List;
  if (data is Map && data['items'] is List) return data['items'] as List;
  return [];
}

String _extractOrderImage(Map map) {
  final direct = _firstText([
    map['imageUrl'],
    map['productImage'],
    map['thumbnail'],
  ]);
  if (direct.isNotEmpty) return _fullImageUrl(direct);

  final items = _extractList(map['items'] ?? map['orderItems'] ?? map['products']);
  if (items.isNotEmpty && items.first is Map) {
    final item = items.first as Map;
    final product = item['product'];
    final image = _firstText([
      item['imageUrl'],
      item['productImage'],
      product is Map ? product['imageUrl'] : null,
      product is Map ? product['mainImageUrl'] : null,
    ]);
    if (image.isNotEmpty) return _fullImageUrl(image);
  }

  return '';
}

String _formatDate(String value) {
  if (value.isEmpty) return '5 / 5 / 2025 3:45 Pm';
  final clean = value.replaceFirst('T', ' ').split('.').first;
  return clean;
}

String _firstText(List<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != 'null') return text;
  }
  return fallback;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

String _formatMoney(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _fullImageUrl(String url) {
  const base = 'https://lokit-production.up.railway.app';
  final clean = url.trim();
  if (clean.isEmpty || clean == 'null') return '';
  if (clean.startsWith('http')) return clean;
  if (clean.startsWith('/')) return '$base$clean';
  return '$base/$clean';
}
