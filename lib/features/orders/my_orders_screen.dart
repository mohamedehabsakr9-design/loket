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
  List<dynamic> _orders = [];

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
      final data = await ApiService.get(
        '/orders',
        withAuth: true,
      );

      if (!mounted) return;

      setState(() {
        _orders = _extractOrders(data);
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

  List<dynamic> _extractOrders(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['content'] is List) return data['content'];
    if (data is Map && data['orders'] is List) return data['orders'];
    if (data is Map && data['data'] is List) return data['data'];
    if (data is Map && data['items'] is List) return data['items'];
    return [];
  }

  bool _isPending(dynamic order) {
    final status = _readString(order, 'status').toLowerCase();

    return status.contains('pending') ||
        status.contains('processing') ||
        status.contains('created') ||
        status.contains('new') ||
        status.contains('waiting');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final pendingOrders =
        _orders.where((order) => _isPending(order)).toList(growable: false);

    final completedOrders =
        _orders.where((order) => !_isPending(order)).toList(growable: false);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: DefaultTabController(
        length: 2,
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
              s.myOrdersTitle,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.deepOrange,
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.black87,
                    tabs: [
                      Tab(text: s.myOrdersPendingTab),
                      Tab(text: s.myOrdersCompletedTab),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _loadOrders,
            child: _buildBody(
              s: s,
              pendingOrders: pendingOrders,
              completedOrders: completedOrders,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required AppStrings s,
    required List<dynamic> pendingOrders,
    required List<dynamic> completedOrders,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          const Icon(Icons.error_outline, color: Colors.red, size: 44),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: _loadOrders,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    return TabBarView(
      children: [
        _OrdersList(
          orders: pendingOrders,
          emptyText: s.myOrdersEmptyText,
        ),
        _OrdersList(
          orders: completedOrders,
          emptyText: s.myOrdersEmptyText,
        ),
      ],
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<dynamic> orders;
  final String emptyText;

  const _OrdersList({
    required this.orders,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    if (orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          const Icon(Icons.receipt_long_outlined, color: Colors.grey, size: 46),
          const SizedBox(height: 12),
          Center(
            child: Text(
              emptyText,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];

        final orderId = _extractOrderId(order);
        final isPending = _isPending(order);
        final amountText = _extractAmount(order);
        final statusText = _extractStatus(order, s);
        final dateText = _extractDate(order);

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailsScreen(
                  orderId: orderId,
                  isCompleted: !isPending,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.receipt_long_outlined,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.myOrdersOrderLabel} $orderId',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.myOrdersDateTimeLabel} : $dateText',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color:
                                isPending ? Colors.deepOrange : Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isPending ? Colors.deepOrange : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.myOrdersDetailsButton,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _extractOrderId(dynamic order) {
    final id = _readDynamic(order, 'id') ??
        _readDynamic(order, 'orderId') ??
        _readDynamic(order, 'orderNumber');

    if (id == null) return '#ORDER';
    final value = id.toString();

    return value.startsWith('#') ? value : '#$value';
  }

  static bool _isPending(dynamic order) {
    final status = _readString(order, 'status').toLowerCase();

    return status.contains('pending') ||
        status.contains('processing') ||
        status.contains('created') ||
        status.contains('new') ||
        status.contains('waiting');
  }

  static String _extractAmount(dynamic order) {
    final amount = _readDynamic(order, 'totalAmount') ??
        _readDynamic(order, 'totalPrice') ??
        _readDynamic(order, 'amount') ??
        _readDynamic(order, 'total');

    if (amount == null) return '0 EGP';

    return '$amount EGP';
  }

  static String _extractStatus(dynamic order, AppStrings s) {
    final status = _readString(order, 'status');

    if (status.isNotEmpty) return status;

    return _isPending(order) ? s.orderStatusPending : s.orderStatusCompleted;
  }

  static String _extractDate(dynamic order) {
    final date = _readString(order, 'createdAt').isNotEmpty
        ? _readString(order, 'createdAt')
        : _readString(order, 'orderDate');

    if (date.isEmpty) return '-';

    return date.replaceFirst('T', ' ').split('.').first;
  }

  static dynamic _readDynamic(dynamic item, String key) {
    if (item is Map && item[key] != null) return item[key];
    return null;
  }

  static String _readString(dynamic item, String key) {
    final value = _readDynamic(item, key);
    if (value == null) return '';
    return value.toString();
  }
}

String _readString(dynamic item, String key) {
  if (item is Map && item[key] != null) return item[key].toString();
  return '';
}