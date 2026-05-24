import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../services/product_service.dart';
import '../../services/wishlist_service.dart';
import '../../widgets/lokit_bottom_nav_bar.dart';
import '../../widgets/product_card.dart';
import '../products/product_details_screen.dart';

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
  final Map<int, String> _productImageUrls = {};
  final Set<int> _removingProductIds = {};

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
      final imageUrls = await _loadProductImages(items);

      if (!mounted) return;

      setState(() {
        _wishlistItems = items;
        _productImageUrls
          ..clear()
          ..addAll(imageUrls);
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

  Future<Map<int, String>> _loadProductImages(List<dynamic> items) async {
    final imageUrls = <int, String>{};

    await Future.wait(
      items.map((item) async {
        final productId = _extractProductId(item);
        if (productId == 0) return;

        final directImage = _extractDirectImageUrl(item);
        if (directImage != null && directImage.isNotEmpty) {
          imageUrls[productId] = directImage;
          return;
        }

        try {
          final images = await ProductService.getProductImages(productId);
          final apiImage = _extractImageUrlFromImages(images);

          if (apiImage != null && apiImage.isNotEmpty) {
            imageUrls[productId] = apiImage;
          }
        } catch (_) {
          // Keep the card visible even if image loading fails.
        }
      }),
    );

    return imageUrls;
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

    if (_removingProductIds.contains(productId)) return;

    setState(() {
      _removingProductIds.add(productId);
    });

    try {
      await WishlistService.removeFromWishlist(productId);

      if (!mounted) return;

      setState(() {
        _wishlistItems.removeWhere(
          (element) => _extractProductId(element) == productId,
        );
        _productImageUrls.remove(productId);
        _removingProductIds.remove(productId);
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

      setState(() {
        _removingProductIds.remove(productId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  int _extractProductId(dynamic item) {
    if (item is! Map) return 0;

    final product = _productMap(item);

    final id = item['productId'] ??
        item['idProduct'] ??
        item['product_id'] ??
        item['productID'] ??
        item['product_id_fk'] ??
        (product is Map
            ? product['id'] ??
                product['productId'] ??
                product['product_id'] ??
                product['productID']
            : null) ??
        item['id'];

    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '') ?? 0;
  }

  String? _imageForItem(dynamic item) {
    final productId = _extractProductId(item);
    final directImage = _extractDirectImageUrl(item);

    if (directImage != null && directImage.isNotEmpty) return directImage;
    return _productImageUrls[productId];
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
        bottomNavigationBar: const LokitBottomNavBar(
          currentTab: LokitBottomTab.wishlist,
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
      return _EmptyWishlistView(isArabic: isArabic);
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.52,
        mainAxisSpacing: 22,
        crossAxisSpacing: 14,
      ),
      itemCount: _wishlistItems.length,
      itemBuilder: (context, index) {
        final item = _wishlistItems[index];
        final productId = _extractProductId(item);

        return _WishlistCard(
          s: s,
          item: item,
          productId: productId,
          imageUrl: _imageForItem(item),
          isRemoving: _removingProductIds.contains(productId),
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
          onFavoriteToggle: () => _removeFromWishlist(item),
        );
      },
    );
  }
}

class _EmptyWishlistView extends StatelessWidget {
  final bool isArabic;

  const _EmptyWishlistView({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 150),
        Center(
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              color: Colors.black38,
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            isArabic ? 'Wishlist فاضية' : 'Your wishlist is empty',
            style: const TextStyle(
              fontSize: 17,
              color: Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            isArabic
                ? 'ضيف المنتجات اللي بتحبها وهتظهر هنا'
                : 'Add products you like and they will appear here',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final AppStrings s;
  final dynamic item;
  final int productId;
  final String? imageUrl;
  final bool isRemoving;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const _WishlistCard({
    required this.s,
    required this.item,
    required this.productId,
    required this.imageUrl,
    required this.isRemoving,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  dynamic get product => _productMap(item) ?? item;

  String _readString(String key) {
    final value = _readValue(product, key) ?? _readValue(item, key);
    return value?.toString() ?? '';
  }

  String _name() {
    final value = _firstText([
      _readString('name'),
      _readString('productName'),
      _readString('title'),
    ]);

    return value.isEmpty ? s.wishlistProductName : value;
  }

  String _brand() {
    final value = _firstText([
      _readString('brandName'),
      _readString('brand'),
      _nestedText(product, ['brand', 'name']),
      _nestedText(product, ['brandResponse', 'name']),
      _nestedText(item, ['brand', 'name']),
      _nestedText(item, ['brandResponse', 'name']),
    ]);

    return value.isEmpty ? s.wishlistBrand : value;
  }

  String _price() {
    final value = _firstText([
      _readString('price'),
      _readString('minPrice'),
      _readString('unitPrice'),
      _readString('lowestPrice'),
      _nestedText(item, ['variant', 'price']),
      _nestedText(item, ['productVariant', 'price']),
    ]);

    if (value.isNotEmpty && value != 'null') {
      return value.toLowerCase().contains('egp') ? value : '$value EGP';
    }

    return s.wishlistPriceExample;
  }

  @override
  Widget build(BuildContext context) {
    return ProductCard(
      productId: productId,
      name: _name(),
      brand: _brand(),
      price: _price(),
      imageUrl: imageUrl,
      isFavorite: true,
      isWishlistLoading: isRemoving,
      onWishlistTap: () {
        if (!isRemoving) {
          onFavoriteToggle();
        }
      },
      onTap: onTap,
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
}

Map? _productMap(dynamic item) {
  if (item is! Map) return null;

  final product = item['product'] ??
      item['productResponse'] ??
      item['productDto'] ??
      item['productDTO'] ??
      item['productDetails'];

  return product is Map ? product : null;
}

String? _extractDirectImageUrl(dynamic item) {
  final direct = _firstText([
    _readValue(item, 'imageUrl')?.toString(),
    _readValue(item, 'mainImageUrl')?.toString(),
    _readValue(item, 'productImage')?.toString(),
    _readValue(item, 'image')?.toString(),
    _readValue(item, 'thumbnail')?.toString(),
    _readValue(item, 'imagePath')?.toString(),
    _readValue(item, 'path')?.toString(),
    _readValue(item, 'url')?.toString(),
  ]);

  if (direct.isNotEmpty && direct != 'null') {
    return _fullImageUrl(direct);
  }

  final product = _productMap(item);
  final productDirect = _firstText([
    _readValue(product, 'imageUrl')?.toString(),
    _readValue(product, 'mainImageUrl')?.toString(),
    _readValue(product, 'productImage')?.toString(),
    _readValue(product, 'image')?.toString(),
    _readValue(product, 'thumbnail')?.toString(),
    _readValue(product, 'imagePath')?.toString(),
    _readValue(product, 'path')?.toString(),
    _readValue(product, 'url')?.toString(),
  ]);

  if (productDirect.isNotEmpty && productDirect != 'null') {
    return _fullImageUrl(productDirect);
  }

  final itemImageList = _readValue(item, 'images') ??
      _readValue(item, 'productImages') ??
      _readValue(item, 'imageUrls');
  final listImage = _extractImageUrlFromImages(itemImageList);
  if (listImage != null) return listImage;

  final productImageList = _readValue(product, 'images') ??
      _readValue(product, 'productImages') ??
      _readValue(product, 'imageUrls');
  return _extractImageUrlFromImages(productImageList);
}

String? _extractImageUrlFromImages(dynamic data) {
  final images = _extractList(data);
  if (images.isEmpty) return null;

  final mainImage = images.firstWhere(
    (image) {
      if (image is! Map) return false;
      return image['main'] == true ||
          image['isMain'] == true ||
          image['mainImage'] == true ||
          image['primary'] == true;
    },
    orElse: () => images.first,
  );

  if (mainImage is String) return _fullImageUrl(mainImage);

  if (mainImage is Map) {
    final url = _firstText([
      mainImage['imageUrl']?.toString(),
      mainImage['mainImageUrl']?.toString(),
      mainImage['url']?.toString(),
      mainImage['imagePath']?.toString(),
      mainImage['path']?.toString(),
      mainImage['image']?.toString(),
      mainImage['thumbnail']?.toString(),
    ]);

    if (url.isNotEmpty && url != 'null') return _fullImageUrl(url);
  }

  return null;
}

List<dynamic> _extractList(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['content'] is List) return data['content'] as List;
  if (data is Map && data['items'] is List) return data['items'] as List;
  if (data is Map && data['data'] is List) return data['data'] as List;
  if (data is Map && data['images'] is List) return data['images'] as List;
  if (data is Map && data['productImages'] is List) {
    return data['productImages'] as List;
  }
  return [];
}

dynamic _readValue(dynamic source, String key) {
  return source is Map ? source[key] : null;
}

String _nestedText(dynamic source, List<String> path) {
  dynamic current = source;

  for (final key in path) {
    if (current is! Map) return '';
    current = current[key];
  }

  return current?.toString() ?? '';
}

String _firstText(List<String?> values) {
  for (final value in values) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty && text != 'null') return text;
  }
  return '';
}

String _fullImageUrl(String url) {
  final clean = url.trim();
  if (clean.isEmpty || clean == 'null') return '';
  if (clean.startsWith('http')) return clean;
  if (clean.startsWith('/')) return '$kBaseUrl$clean';
  return '$kBaseUrl/$clean';
}