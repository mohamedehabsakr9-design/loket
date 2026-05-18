import 'package:flutter/material.dart';
import '../../app/app_strings.dart';
import '../../services/wishlist_service.dart';
import '../products/product_details_screen.dart';

import '../home/home_screen.dart';
import '../products/search_screen.dart';
import '../cart/my_cart_screen.dart';
import '../profile/profile_menu_screen.dart';

const String kBaseUrl = 'https://lokit-production.up.railway.app';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _wishlistItems = [];

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await WishlistService.getWishlist();

      if (!mounted) return;

      setState(() {
        _wishlistItems = items;
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

  Future<void> _removeFromWishlist(dynamic item) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final productId = _extractProductId(item);

    if (productId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'لم يتم العثور على المنتج' : 'Product id not found',
          ),
        ),
      );
      return;
    }

    try {
      await WishlistService.removeFromWishlist(productId);

      if (!mounted) return;

      setState(() {
        _wishlistItems.removeWhere(
          (element) => _extractProductId(element) == productId,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'تمت الإزالة من المفضلة' : 'Removed from wishlist',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  int _extractProductId(dynamic item) {
    if (item is! Map) return 0;

    final product = item['product'];

    final id = item['productId'] ??
        item['idProduct'] ??
        item['product_id'] ??
        item['productID'] ??
        (product is Map ? product['id'] : null) ??
        item['id'];

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
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F7F7),
          elevation: 0,
          centerTitle: true,
          title: Text(
            s.wishlistTitle,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadWishlist,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBody(s),
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
                _BottomItem(
                  icon: Icons.home_filled,
                  label: 'Home',
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  },
                ),
                _BottomItem(
                  icon: Icons.search,
                  label: 'Search',
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                ),
                _BottomItem(
                  icon: Icons.favorite,
                  label: 'Wishlist',
                  isActive: true,
                  onTap: () {},
                ),
                _BottomItem(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Cart',
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MyCartScreen()),
                    );
                  },
                ),
                _BottomItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileMenuScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppStrings s) {
    final isArabic = s.isArabic;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          const Icon(Icons.error_outline, color: Colors.red, size: 42),
          const SizedBox(height: 12),
          Center(
            child: Text(
              isArabic ? 'فشل تحميل المفضلة' : 'Failed to load wishlist',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: _loadWishlist,
              child: Text(isArabic ? 'حاول مرة أخرى' : 'Try again'),
            ),
          ),
        ],
      );
    }

    if (_wishlistItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          const Icon(Icons.favorite_border, color: Colors.grey, size: 52),
          const SizedBox(height: 12),
          Center(
            child: Text(
              isArabic ? 'المفضلة فارغة' : 'Your wishlist is empty',
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      ),
      itemCount: _wishlistItems.length,
      itemBuilder: (context, index) {
        final item = _wishlistItems[index];
        final productId = _extractProductId(item);

        return _WishlistCard(
          s: s,
          item: item,
          onTap: () {
            if (productId == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isArabic
                        ? 'لم يتم العثور على المنتج'
                        : 'Product id not found',
                  ),
                ),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailsScreen(productId: productId),
              ),
            );
          },
          onFavoriteToggle: () {
            _removeFromWishlist(item);
          },
        );
      },
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final AppStrings s;
  final dynamic item;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const _WishlistCard({
    required this.s,
    required this.item,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  dynamic get product {
    if (item is Map && item['product'] is Map) {
      return item['product'];
    }
    return item;
  }

  String _readString(String key) {
    if (product is Map && product[key] != null) {
      return product[key].toString();
    }

    if (item is Map && item[key] != null) {
      return item[key].toString();
    }

    return '';
  }

  String _name() {
    final value = _readString('name').isNotEmpty
        ? _readString('name')
        : _readString('productName');

    return value.isEmpty ? s.wishlistProductName : value;
  }

  String _brand() {
    final value = _readString('brandName').isNotEmpty
        ? _readString('brandName')
        : _readString('brand');

    return value.isEmpty ? s.wishlistBrand : value;
  }

  String _price() {
    final value = _readString('price');

    if (value.isNotEmpty && value != 'null') {
      return '$value EGP';
    }

    return s.wishlistPriceExample;
  }

  String? _imageUrl() {
    final direct = _readString('imageUrl').isNotEmpty
        ? _readString('imageUrl')
        : _readString('mainImageUrl');

    if (direct.isNotEmpty) return _fullImageUrl(direct);

    final images = product is Map
        ? product['images'] ?? product['productImages']
        : null;

    if (images is List && images.isNotEmpty) {
      final first = images.first;

      if (first is String) {
        return _fullImageUrl(first);
      }

      if (first is Map) {
        final url = first['imageUrl'] ??
            first['url'] ??
            first['imagePath'] ??
            first['path'];

        if (url != null) {
          return _fullImageUrl(url.toString());
        }
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl();

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: SizedBox(
                    height: 175,
                    width: double.infinity,
                    child: imageUrl == null || imageUrl.isEmpty
                        ? _imagePlaceholder()
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return _imagePlaceholder();
                            },
                          ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: InkWell(
                    onTap: onFavoriteToggle,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _brand(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        _name(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _price(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.grey),
      ),
    );
  }

  String _fullImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$kBaseUrl$url';
    return '$kBaseUrl/$url';
  }
}

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
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}