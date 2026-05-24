import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../services/product_service.dart';
import '../../services/wishlist_service.dart';
import '../../widgets/lokit_bottom_nav_bar.dart';
import '../../widgets/product_card.dart';
import '../products/product_details_screen.dart';
import '../products/search_screen.dart';
import '../notifications/notification_screen.dart';

const String kBaseUrl = 'https://lokit-production.up.railway.app';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<_BrandOption> brands = [];
  List<dynamic> allProducts = [];
  List<dynamic> newArrivals = [];
  List<dynamic> latestProducts = [];
  List<dynamic> brandProducts = [];

  bool loading = true;
  bool brandLoading = false;

  int? selectedBrandId;
  String? selectedBrandName;
  String searchQuery = '';

  final Set<int> wishlistProductIds = <int>{};
  final Set<int> wishlistLoadingIds = <int>{};

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    setState(() => loading = true);

    try {
      final results = await Future.wait<dynamic>([
        ProductService.getBrands(),
        ProductService.getAllProducts(),
        ProductService.getNewArrivals(),
        ProductService.getLatestProducts(),
      ]);

      final loadedNewArrivals = List<dynamic>.from(results[2] as List);
      final loadedLatestProducts = List<dynamic>.from(results[3] as List);
      final loadedAllProducts = List<dynamic>.from(results[1] as List);

      List<dynamic> refreshedBrandProducts = brandProducts;
      if (selectedBrandId != null) {
        refreshedBrandProducts =
            await ProductService.getProductsByBrand(selectedBrandId!);
      }

      final refreshedWishlistIds = await _safeLoadWishlistIds();

      if (!mounted) return;
      setState(() {
        brands = _parseBrands(results[0]);
        newArrivals = loadedNewArrivals;
        latestProducts = loadedLatestProducts;
        allProducts = loadedAllProducts.isNotEmpty
            ? loadedAllProducts
            : _uniqueProducts([
                ...loadedNewArrivals,
                ...loadedLatestProducts,
              ]);
        brandProducts = refreshedBrandProducts;
        wishlistProductIds
          ..clear()
          ..addAll(refreshedWishlistIds);
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

  Future<Set<int>> _safeLoadWishlistIds() async {
    try {
      final wishlist = await WishlistService.getWishlist();
      return wishlist
          .map(_extractWishlistProductId)
          .where((id) => id != 0)
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  Future<void> _selectBrand(_BrandOption brand) async {
    if (selectedBrandId == brand.id && brandProducts.isNotEmpty) return;

    setState(() {
      selectedBrandId = brand.id;
      selectedBrandName = brand.name;
      brandLoading = true;
      brandProducts = [];
    });

    try {
      final products = await ProductService.getProductsByBrand(brand.id);
      if (!mounted) return;
      setState(() {
        brandProducts = products;
        brandLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => brandLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _clearBrandFilter() {
    if (brandLoading) return;
    setState(() {
      selectedBrandId = null;
      selectedBrandName = null;
      brandProducts = [];
    });
  }

  Future<void> _toggleWishlist(int productId) async {
    final s = AppStrings.of(context);

    if (productId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isArabic ? 'لم يتم العثور على المنتج' : 'Product not found',
          ),
        ),
      );
      return;
    }

    if (wishlistLoadingIds.contains(productId)) return;

    final wasFavorite = wishlistProductIds.contains(productId);

    setState(() {
      wishlistLoadingIds.add(productId);
    });

    try {
      if (wasFavorite) {
        await WishlistService.removeFromWishlist(productId);
      } else {
        await WishlistService.addToWishlist(productId);
      }

      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          wishlistProductIds.remove(productId);
        } else {
          wishlistProductIds.add(productId);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasFavorite
                ? (s.isArabic
                    ? 'تمت الإزالة من المفضلة'
                    : 'Removed from wishlist')
                : (s.isArabic
                    ? 'تمت الإضافة إلى المفضلة'
                    : 'Added to wishlist'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        wishlistLoadingIds.remove(productId);
      });
    }
  }

  List<_BrandOption> _parseBrands(dynamic data) {
    final list = data is List
        ? data
        : (data is Map && data['content'] is List ? data['content'] : []);

    return List<dynamic>.from(list)
        .map<_BrandOption?>((e) {
          if (e is! Map) return null;

          final id = _readInt(e, ['id', 'brandId']);
          final name = _readString(e, [
            'name',
            'brandName',
            'title',
            'nameEn',
            'nameAr',
          ]);

          if (id == 0 || name.isEmpty) return null;
          return _BrandOption(id: id, name: name);
        })
        .whereType<_BrandOption>()
        .toList();
  }

  int _readInt(Map data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  String _readString(Map data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  int _extractWishlistProductId(dynamic item) {
    if (item is! Map) return 0;

    final product = item['product'];
    final id = item['productId'] ??
        item['idProduct'] ??
        item['product_id'] ??
        item['productID'] ??
        item['wishlistProductId'] ??
        (product is Map ? product['id'] : null) ??
        item['id'];

    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '') ?? 0;
  }

  List<dynamic> _uniqueProducts(List<dynamic> products) {
    final seen = <int>{};
    final result = <dynamic>[];

    for (final product in products) {
      final id = _productId(product);
      if (id == 0) {
        result.add(product);
        continue;
      }
      if (seen.add(id)) result.add(product);
    }

    return result;
  }

  int _productId(dynamic product) {
    if (product is! Map) return 0;
    final id = product['id'] ??
        product['productId'] ??
        product['productID'] ??
        product['product_id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '') ?? 0;
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
                          onNotificationTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                          },
                          onSearchTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SearchScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _TopBanner(),
                        const SizedBox(height: 18),
                        _BrandRow(
                          brands: brands,
                          selectedBrandId: selectedBrandId,
                          onAllTap: _clearBrandFilter,
                          onBrandTap: _selectBrand,
                        ),
                        const SizedBox(height: 24),
                        if (brandLoading)
                          const SizedBox(
                            height: 260,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (selectedBrandId != null)
                          _ProductSection(
                            title: selectedBrandName ?? s.homeShopByBrand,
                            products: brandProducts,
                            searchQuery: searchQuery,
                            wishlistProductIds: wishlistProductIds,
                            wishlistLoadingIds: wishlistLoadingIds,
                            onWishlistTap: _toggleWishlist,
                          )
                        else ...[
                          _ProductSection(
                            title: s.isArabic ? 'كل المنتجات' : 'All Products',
                            products: allProducts,
                            searchQuery: searchQuery,
                            wishlistProductIds: wishlistProductIds,
                            wishlistLoadingIds: wishlistLoadingIds,
                            onWishlistTap: _toggleWishlist,
                          ),
                          const SizedBox(height: 24),
                          _ProductSection(
                            title: s.homeNewArrivals,
                            products: newArrivals,
                            searchQuery: searchQuery,
                            wishlistProductIds: wishlistProductIds,
                            wishlistLoadingIds: wishlistLoadingIds,
                            onWishlistTap: _toggleWishlist,
                          ),
                          const SizedBox(height: 24),
                          _ProductSection(
                            title: s.homeRecommended,
                            products: latestProducts,
                            searchQuery: searchQuery,
                            wishlistProductIds: wishlistProductIds,
                            wishlistLoadingIds: wishlistLoadingIds,
                            onWishlistTap: _toggleWishlist,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
        bottomNavigationBar: const LokitBottomNavBar(
          currentTab: LokitBottomTab.home,
        ),
      ),
    );
  }
}

class _BrandOption {
  final int id;
  final String name;

  const _BrandOption({required this.id, required this.name});
}

class _Header extends StatelessWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationTap;

  const _Header({
    required this.onSearchTap,
    required this.onNotificationTap,
  });

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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onNotificationTap,
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.black87,
              ),
            ),
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

class _BrandRow extends StatelessWidget {
  final List<_BrandOption> brands;
  final int? selectedBrandId;
  final VoidCallback onAllTap;
  final ValueChanged<_BrandOption> onBrandTap;

  const _BrandRow({
    required this.brands,
    required this.selectedBrandId,
    required this.onAllTap,
    required this.onBrandTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final allLabel = s.isArabic ? 'الكل' : 'All';
    final emptyLabel = s.isArabic ? 'لا توجد ماركات' : 'No brands found';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.homeShopByBrand,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (brands.isEmpty)
          Text(
            emptyLabel,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _BrandChip(
                  label: allLabel,
                  selected: selectedBrandId == null,
                  onTap: onAllTap,
                ),
                ...brands.map(
                  (brand) => _BrandChip(
                    label: brand.name,
                    selected: selectedBrandId == brand.id,
                    onTap: () => onBrandTap(brand),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BrandChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BrandChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? Colors.black : Colors.grey.shade200,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: selected ? Colors.white : Colors.black,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductSection extends StatelessWidget {
  final String title;
  final List<dynamic> products;
  final String searchQuery;
  final Set<int> wishlistProductIds;
  final Set<int> wishlistLoadingIds;
  final ValueChanged<int> onWishlistTap;

  const _ProductSection({
    required this.title,
    required this.products,
    required this.searchQuery,
    required this.wishlistProductIds,
    required this.wishlistLoadingIds,
    required this.onWishlistTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    final filtered = searchQuery.trim().isEmpty
        ? products
        : products.where((p) {
            final name = _str(p, 'name').toLowerCase();
            final brand = _productBrand(p).toLowerCase();
            final dept = _str(p, 'departmentName').toLowerCase();
            final category = _str(p, 'categoryName').toLowerCase();
            final q = searchQuery.toLowerCase();

            return name.contains(q) ||
                brand.contains(q) ||
                dept.contains(q) ||
                category.contains(q);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Container(
            height: 130,
            alignment: Alignment.center,
            child: Text(
              s.homeNoResults,
              style: const TextStyle(fontSize: 13),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.52,
              mainAxisSpacing: 22,
              crossAxisSpacing: 14,
            ),
            itemBuilder: (context, index) {
              final product = filtered[index];
              final productId = _intAny(product, [
                'id',
                'productId',
                'productID',
                'product_id',
              ]);

              return ProductCard(
                productId: productId,
                name: _str(product, 'name').isEmpty
                    ? s.homeProductName
                    : _str(product, 'name'),
                brand: _productBrand(product).isEmpty
                    ? s.homeBrand
                    : _productBrand(product),
                price: _price(product),
                imageUrl: _imageUrl(product),
                isFavorite: wishlistProductIds.contains(productId),
                isWishlistLoading: wishlistLoadingIds.contains(productId),
                onWishlistTap: () => onWishlistTap(productId),
                onTap: () {
                  if (productId == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          s.isArabic
                              ? 'لم يتم العثور على المنتج'
                              : 'Product not found',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailsScreen(
                        productId: productId,
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  static String _str(dynamic p, String key) {
    if (p is Map && p[key] != null) return p[key].toString();
    return '';
  }

  static int _intAny(dynamic p, List<String> keys) {
    if (p is! Map) return 0;

    for (final key in keys) {
      final v = p[key];
      if (v is int) return v;
      final parsed = int.tryParse(v?.toString() ?? '');
      if (parsed != null) return parsed;
    }

    return 0;
  }

  static String _productBrand(dynamic p) {
    if (p is! Map) return '';

    final direct = p['brandName']?.toString() ?? '';
    if (direct.trim().isNotEmpty) return direct.trim();

    final brand = p['brand'];
    if (brand is Map && brand['name'] != null) {
      return brand['name'].toString();
    }

    final brandResponse = p['brandResponse'];
    if (brandResponse is Map && brandResponse['name'] != null) {
      return brandResponse['name'].toString();
    }

    return '';
  }

  static String _price(dynamic p) {
    if (p is! Map) return '0.00 EGP';

    final raw = p['minPrice'] ?? p['price'] ?? p['lowestPrice'];
    if (raw == null) return '0.00 EGP';

    final value = double.tryParse(raw.toString()) ?? 0;
    return '${value.toStringAsFixed(2)} EGP';
  }

  static String? _imageUrl(dynamic p) {
    if (p is! Map) return null;

    final direct = p['mainImageUrl'] ??
        p['imageUrl'] ??
        p['mainImage'] ??
        p['thumbnail'];

    if (direct != null && direct.toString().isNotEmpty) {
      return _fullUrl(direct.toString());
    }

    final images = p['images'] ?? p['productImages'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;

      if (first is String) return _fullUrl(first);

      if (first is Map) {
        final url = first['imageUrl'] ??
            first['url'] ??
            first['imagePath'] ??
            first['path'];

        if (url != null && url.toString().isNotEmpty) {
          return _fullUrl(url.toString());
        }
      }
    }

    return null;
  }

  static String _fullUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$kBaseUrl$url';
    return '$kBaseUrl/$url';
  }
}
