import 'package:flutter/material.dart';
import '../../app/app_strings.dart';
import '../../services/product_service.dart';
import '../cart/my_cart_screen.dart';
import '../products/product_details_screen.dart';
import '../products/search_screen.dart';
import '../profile/profile_menu_screen.dart';
import '../wishlist/wishlist_screen.dart';

const String kBaseUrl = 'https://lokit-production.up.railway.app';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> newArrivals = [];
  List<dynamic> latestProducts = [];
  bool loading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        ProductService.getNewArrivals(),
        ProductService.getLatestProducts(),
      ]);
      if (!mounted) return;
      setState(() {
        newArrivals = results[0];
        latestProducts = results[1];
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

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: loadProducts,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(
                          onSearchTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const SearchScreen()),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _TopBanner(),
                        const SizedBox(height: 18),
                        const _DepartmentRow(),
                        const SizedBox(height: 24),
                        _ProductSection(
                          title: s.homeNewArrivals,
                          products: newArrivals,
                          searchQuery: searchQuery,
                        ),
                        const SizedBox(height: 24),
                        _ProductSection(
                          title: s.homeRecommended,
                          products: latestProducts,
                          searchQuery: searchQuery,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BottomItem(icon: Icons.home_filled, label: 'Home', isActive: true, onTap: () {}),
                _BottomItem(
                  icon: Icons.search,
                  label: 'Search',
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                ),
                _BottomItem(
                  icon: Icons.favorite_border,
                  label: 'Wishlist',
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const WishlistScreen()),
                  ),
                ),
                _BottomItem(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Cart',
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MyCartScreen()),
                  ),
                ),
                _BottomItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileMenuScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onSearchTap;
  const _Header({required this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(
              'lib/assets/logo.png',
              height: 42,
              errorBuilder: (_, __, ___) => const Text(
                'LOKIT',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ),
            const Spacer(),
            IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onSearchTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  AppStrings.of(context).homeSearchHint,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Banner ───────────────────────────────────────────────────────────────────

class _TopBanner extends StatelessWidget {
  const _TopBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 380 / 108,
        child: Image.asset(
          'lib/assets/Group 3.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Icon(Icons.image_outlined, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

// ─── Department chips ─────────────────────────────────────────────────────────

class _DepartmentRow extends StatelessWidget {
  const _DepartmentRow();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: const [
          _DeptChip(label: 'Men'),
          _DeptChip(label: 'Women'),
          _DeptChip(label: 'Kids'),
          _DeptChip(label: 'Sport'),
        ],
      ),
    );
  }
}

class _DeptChip extends StatelessWidget {
  final String label;
  const _DeptChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }
}

// ─── Product Section ──────────────────────────────────────────────────────────

class _ProductSection extends StatelessWidget {
  final String title;
  final List<dynamic> products;
  final String searchQuery;

  const _ProductSection({
    required this.title,
    required this.products,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    final filtered = searchQuery.trim().isEmpty
        ? products
        : products.where((p) {
            final name = _str(p, 'name').toLowerCase();
            final brand = _str(p, 'brandName').toLowerCase();
            final dept = _str(p, 'departmentName').toLowerCase();
            final q = searchQuery.toLowerCase();
            return name.contains(q) || brand.contains(q) || dept.contains(q);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: filtered.isEmpty
              ? Center(child: Text(s.homeNoResults, style: const TextStyle(fontSize: 13)))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final productId = _int(product, 'id');

                    return _ProductCard(
                      name: _str(product, 'name').isEmpty ? s.homeProductName : _str(product, 'name'),
                      brand: _str(product, 'brandName').isEmpty ? s.homeBrand : _str(product, 'brandName'),
                      // ProductSearchResponse returns minPrice
                      price: _price(product),
                      imageUrl: _imageUrl(product),
                      onTap: () {
                        if (productId == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.isArabic ? 'لم يتم العثور على المنتج' : 'Product not found')),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProductDetailsScreen(productId: productId)),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  static String _str(dynamic p, String key) {
    if (p is Map && p[key] != null) return p[key].toString();
    return '';
  }

  static int _int(dynamic p, String key) {
    if (p is! Map) return 0;
    final v = p[key];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _price(dynamic p) {
    if (p is! Map) return '0.00 EGP';
    // API returns minPrice for ProductSearchResponse
    final raw = p['minPrice'] ?? p['price'];
    if (raw == null) return '0.00 EGP';
    final value = double.tryParse(raw.toString()) ?? 0;
    return '${value.toStringAsFixed(2)} EGP';
  }

  static String? _imageUrl(dynamic p) {
    if (p is! Map) return null;
    // ProductSearchResponse has mainImageUrl
    final url = p['mainImageUrl'] ?? p['imageUrl'] ?? p['thumbnail'];
    if (url == null || url.toString().isEmpty) return null;
    return _fullUrl(url.toString());
  }

  static String _fullUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$kBaseUrl$url';
    return '$kBaseUrl/$url';
  }
}

// ─── Product Card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final String name;
  final String brand;
  final String price;
  final String? imageUrl;
  final VoidCallback onTap;

  const _ProductCard({
    required this.name,
    required this.brand,
    required this.price,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 166,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: Container(
                height: 160,
                width: double.infinity,
                color: Colors.grey.shade200,
                child: imageUrl == null || imageUrl!.isEmpty
                    ? const Center(child: Icon(Icons.image_outlined, color: Colors.grey))
                    : Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Center(child: Icon(Icons.image_outlined, color: Colors.grey)),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.25)),
                    ),
                    const SizedBox(height: 6),
                    Text(price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
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

// ─── Bottom nav ───────────────────────────────────────────────────────────────

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.black : Colors.grey;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }
}
