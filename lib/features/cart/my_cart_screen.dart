import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../services/api_service.dart';
import '../payment/payment_screen.dart';
import '../home/home_screen.dart';
import '../products/search_screen.dart';
import '../wishlist/wishlist_screen.dart';
import '../profile/profile_menu_screen.dart';

const String kBaseUrl = 'https://lokit-production.up.railway.app';

class MyCartScreen extends StatefulWidget {
  const MyCartScreen({super.key});

  @override
  State<MyCartScreen> createState() => _MyCartScreenState();
}

class _MyCartScreenState extends State<MyCartScreen> {
  bool loading = true;
  bool deleting = false;
  List<dynamic> cartItems = [];

  @override
  void initState() {
    super.initState();
    loadCart();
  }

  Future<void> loadCart() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.get('/cart', withAuth: true);
      if (!mounted) return;
      setState(() {
        cartItems = _extractItems(data);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// CartResponse: { id: Long, items: [CartItemResponse] }
  /// CartItemResponse: { id, productVariantId, productName, brandName,
  ///                     sizeName, colorName, quantity, unitPrice, totalPrice, imageUrl }
  List<dynamic> _extractItems(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['items'] is List) return data['items'];
    if (data is Map && data['cartItems'] is List) return data['cartItems'];
    if (data is Map && data['content'] is List) return data['content'];
    if (data is Map && data['data'] is List) return data['data'];
    return [];
  }

  Future<void> deleteItem(dynamic item) async {
    final itemId = _extractItemId(item);
    if (itemId == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cart item id not found')));
      return;
    }
    setState(() => deleting = true);
    try {
      await ApiService.delete('/cart/items/$itemId', withAuth: true);
      if (!mounted) return;
      setState(() => cartItems.removeWhere((e) => _extractItemId(e) == itemId));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Removed from cart')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  int _extractItemId(dynamic item) {
    if (item is! Map) return 0;
    final id = item['id'] ?? item['cartItemId'] ?? item['itemId'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '') ?? 0;
  }

  double get totalPrice {
    double total = 0;
    for (final item in cartItems) {
      // prefer totalPrice field from API, then unitPrice * quantity
      final totalPriceField = _toDouble(_read(item, 'totalPrice'));
      if (totalPriceField > 0) {
        total += totalPriceField;
      } else {
        final price = _toDouble(_read(item, 'unitPrice') ?? _read(item, 'price'));
        final qty = _toInt(_read(item, 'quantity') ?? 1);
        total += price * qty;
      }
    }
    return total;
  }

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
          centerTitle: true,
          title: Text(s.cartTitle,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        ),
        body: RefreshIndicator(
          onRefresh: loadCart,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : cartItems.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 180),
                        Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 52),
                        SizedBox(height: 12),
                        Center(child: Text('Cart is empty')),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: cartItems.length,
                            itemBuilder: (context, index) {
                              final item = cartItems[index];
                              return _CartItemCard(
                                item: item,
                                onDelete: deleting ? null : () => deleteItem(item),
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, -4))
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(s.cartTotalLabel,
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.grey.shade600)),
                                  const Spacer(),
                                  Text('${totalPrice.toStringAsFixed(2)} EGP',
                                      style: const TextStyle(
                                          fontSize: 20, fontWeight: FontWeight.w800)),
                                ],
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: cartItems.isEmpty
                                      ? null
                                      : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => const PaymentScreen()),
                                          ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    disabledBackgroundColor: Colors.black54,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18)),
                                  ),
                                  child: Text(s.cartCheckoutButton,
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(.05),
                    blurRadius: 18,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavItem(icon: Icons.home_outlined,
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()))),
                _NavItem(icon: Icons.search,
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()))),
                _NavItem(icon: Icons.favorite_border,
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const WishlistScreen()))),
                _NavItem(icon: Icons.shopping_bag, active: true, onTap: () {}),
                _NavItem(icon: Icons.person_outline,
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const ProfileMenuScreen()))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Cart Item Card ───────────────────────────────────────────────────────────

class _CartItemCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback? onDelete;

  const _CartItemCard({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    // CartItemResponse fields from API
    final image = _imageUrl(item);
    final name = _text(_read(item, 'productName') ?? _readProduct(item, 'name'), fallback: 'Product');
    final brand = _text(_read(item, 'brandName') ?? _readProduct(item, 'brandName'));
    final size = _text(_read(item, 'sizeName'));
    final color = _text(_read(item, 'colorName'));
    final price = _toDouble(_read(item, 'unitPrice') ?? _read(item, 'price') ?? _readProduct(item, 'price'));
    final quantity = _toInt(_read(item, 'quantity') ?? _read(item, 'qty') ?? 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 90,
              height: 110,
              child: image.isEmpty
                  ? _imagePlaceholder()
                  : Image.network(image, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder()),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (brand.isNotEmpty)
                  Text(brand, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade500)),
                if (size.isNotEmpty || color.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [if (size.isNotEmpty) 'Size: $size', if (color.isNotEmpty) 'Color: $color'].join('  '),
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                const SizedBox(height: 8),
                Text('${price.toStringAsFixed(2)} EGP',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                      child: Text('Qty: $quantity'),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() =>
      Container(color: Colors.grey[200], child: const Icon(Icons.image));
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Icon(icon, color: active ? Colors.black : Colors.grey),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

dynamic _read(dynamic item, String key) => item is Map ? item[key] : null;
dynamic _readProduct(dynamic item, String key) =>
    item is Map && item['product'] is Map ? item['product'][key] : null;
String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString() ?? '';
  return text.trim().isEmpty ? fallback : text;
}
double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
int _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 1;
}
String _imageUrl(dynamic item) {
  final raw = _read(item, 'imageUrl') ??
      _read(item, 'productImage') ??
      _read(item, 'image') ??
      _readProduct(item, 'imageUrl') ??
      '';
  final url = raw.toString();
  if (url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  if (url.startsWith('/')) return '$kBaseUrl$url';
  return '$kBaseUrl/$url';
}
