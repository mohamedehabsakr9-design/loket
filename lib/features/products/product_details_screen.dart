import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../services/api_service.dart';
import '../../ai_try_on_preview_screen.dart';

const String kBaseUrl = 'https://lokit-production.up.railway.app';

class ProductDetailsScreen extends StatefulWidget {
  final int productId;

  const ProductDetailsScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late Future<ProductDetailsData> _future;
  int quantity = 1;
  ProductVariantData? selectedVariant;
  bool cartLoading = false;
  bool wishlistLoading = false;

  @override
  void initState() {
    super.initState();
    _future = ProductApi.getProductDetails(widget.productId);
  }

  String _msg({required String ar, required String en}) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic ? ar : en;
  }

  Future<void> addToCart(ProductDetailsData product) async {
    final token = await ApiService.getToken();

    if (token == null || token.isEmpty) {
      showMsg(_msg(ar: 'يرجى تسجيل الدخول أولاً', en: 'Please login first'));
      return;
    }

    final variant = selectedVariant ??
        (product.variants.isNotEmpty ? product.variants.first : null);

    if (variant == null || variant.id == 0) {
      showMsg(_msg(
        ar: 'لا توجد نسخة متاحة من المنتج',
        en: 'No product variant available',
      ));
      return;
    }

    setState(() => cartLoading = true);

    try {
      await ApiService.post(
        '/cart/items',
        body: {
          'variantId': variant.id,   // ✅ matches CartItemRequest.variantId
          'quantity': quantity,
        },
        withAuth: true,
      );

      showMsg(_msg(ar: 'تمت الإضافة إلى السلة', en: 'Added to cart'));
    } catch (e) {
      showMsg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => cartLoading = false);
    }
  }

  Future<void> addToWishlist() async {
    final token = await ApiService.getToken();

    if (token == null || token.isEmpty) {
      showMsg(_msg(ar: 'يرجى تسجيل الدخول أولاً', en: 'Please login first'));
      return;
    }

    setState(() => wishlistLoading = true);

    try {
      await ApiService.post(
        '/wishlist',
        body: {'productId': widget.productId},
        withAuth: true,
      );
      showMsg(_msg(ar: 'تمت الإضافة إلى المفضلة', en: 'Added to wishlist'));
    } catch (e) {
      showMsg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => wishlistLoading = false);
    }
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
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
        body: FutureBuilder<ProductDetailsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final product = snapshot.data!;
            selectedVariant ??=
                product.variants.isNotEmpty ? product.variants.first : null;

            final price = selectedVariant?.price ?? product.price;
            final total = price * quantity;

            return SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      children: [
                        _ProductImageHeader(
                          s: s,
                          imageUrl: product.mainImageUrl,
                          productId: product.id,
                          onWishlistTap: addToWishlist,
                          wishlistLoading: wishlistLoading,
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TitlePriceQty(
                                name: product.name,
                                brand: product.brandName,
                                price: price,
                                quantity: quantity,
                                onMinus: () {
                                  if (quantity > 1) setState(() => quantity--);
                                },
                                onPlus: () => setState(() => quantity++),
                              ),
                              const SizedBox(height: 16),
                              _RatingRow(rating: product.rating),
                              const SizedBox(height: 24),
                              _SizeSection(
                                s: s,
                                variants: product.variants,
                                selected: selectedVariant,
                                onSelected: (v) =>
                                    setState(() => selectedVariant = v),
                              ),
                              const SizedBox(height: 24),
                              _ColorSection(
                                variants: product.variants,
                                selected: selectedVariant,
                                onSelected: (v) =>
                                    setState(() => selectedVariant = v),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                s.productDescriptionTitle,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                product.description.isEmpty
                                    ? s.productDescriptionBody
                                    : product.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _BottomBar(
                      total: total,
                      cartLoading: cartLoading,
                      totalLabel: s.productTotalPriceLabel,
                      addToCartLabel: s.productAddToCartButton,
                      onAddToCart: () => addToCart(product),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final double total;
  final bool cartLoading;
  final String totalLabel;
  final String addToCartLabel;
  final VoidCallback onAddToCart;

  const _BottomBar({
    required this.total,
    required this.cartLoading,
    required this.totalLabel,
    required this.addToCartLabel,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                totalLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${total.toStringAsFixed(2)} EGP',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: cartLoading ? null : onAddToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: Colors.black38,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: cartLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            addToCartLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImageHeader extends StatelessWidget {
  final AppStrings s;
  final String? imageUrl;
  final int productId;
  final VoidCallback onWishlistTap;
  final bool wishlistLoading;

  const _ProductImageHeader({
    required this.s,
    required this.imageUrl,
    required this.productId,
    required this.onWishlistTap,
    required this.wishlistLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 430 / 430,
          child: imageUrl == null || imageUrl!.isEmpty
              ? _imagePlaceholder()
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                ),
        ),
        Positioned.fill(
          child: Container(color: Colors.white.withOpacity(0.08)),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: _CircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: _TryOnChip(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AiTryOnPreviewScreen(productId: productId),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 20,
          child: _CircleButton(
            icon: wishlistLoading
                ? Icons.hourglass_empty_rounded
                : Icons.favorite_border_rounded,
            onTap: wishlistLoading ? () {} : onWishlistTap,
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() => Container(
        color: Colors.grey[200],
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 48,
          color: Colors.grey,
        ),
      );
}

class _TryOnChip extends StatelessWidget {
  final VoidCallback onTap;
  const _TryOnChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
            SizedBox(width: 6),
            Text(
              'Try On',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductApi {
  static Future<ProductDetailsData> getProductDetails(int productId) async {
    final responses = await Future.wait([
      ApiService.get('/product/$productId/details'),
      ApiService.get('/variants/product/$productId'),
      ApiService.get('/product-images/product/$productId'),
    ]);

    final detailsJson = responses[0];
    final variantsJson = responses[1] is List ? responses[1] as List : [];
    final imagesJson = responses[2] is List ? responses[2] as List : [];

    return ProductDetailsData.fromJson(detailsJson, variantsJson, imagesJson);
  }
}

class ProductDetailsData {
  final int id;
  final String name;
  final String brandName;
  final String description;
  final double price;
  final double rating;
  final String? mainImageUrl;
  final List<ProductVariantData> variants;

  ProductDetailsData({
    required this.id,
    required this.name,
    required this.brandName,
    required this.description,
    required this.price,
    required this.rating,
    required this.mainImageUrl,
    required this.variants,
  });

  factory ProductDetailsData.fromJson(
    dynamic json,
    List variantsJson,
    List imagesJson,
  ) {
    final map = json is Map ? Map<String, dynamic>.from(json) : {};

    final imageMaps = imagesJson
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    Map<String, dynamic>? mainImage;
    if (imageMaps.isNotEmpty) {
      mainImage = imageMaps.firstWhere(
        (e) =>
            e['main'] == true ||
            e['isMain'] == true ||
            e['mainImage'] == true,
        orElse: () => imageMaps.first,
      );
    }

    final imageUrl = mainImage == null
        ? null
        : _fullImageUrl(_str(
            mainImage['imageUrl'] ??
                mainImage['url'] ??
                mainImage['imagePath'] ??
                mainImage['path'],
          ));

    final variants =
        variantsJson.map((e) => ProductVariantData.fromJson(e)).toList();

    return ProductDetailsData(
      id: _int(map['id'] ?? map['productId']),
      name: _str(map['name'] ?? map['productName'] ?? map['title']),
      brandName: _str(
        map['brandName'] ??
            map['brand']?['name'] ??
            map['brandResponse']?['name'],
      ),
      description: _str(map['description']),
      price: _double(
        map['price'] ?? (variants.isNotEmpty ? variants.first.price : 0),
      ),
      rating: _double(map['rating'] ?? map['averageRating']),
      mainImageUrl: imageUrl,
      variants: variants,
    );
  }
}

class ProductVariantData {
  final int id;
  final String size;
  final String color;
  final double price;
  final int stock;

  ProductVariantData({
    required this.id,
    required this.size,
    required this.color,
    required this.price,
    required this.stock,
  });

  factory ProductVariantData.fromJson(dynamic json) {
    final map = json is Map ? Map<String, dynamic>.from(json) : {};

    return ProductVariantData(
      id: _int(map['id'] ?? map['variantId'] ?? map['productVariantId']),
      size: _str(map['sizeName'] ?? map['size'] ?? map['sizeResponse']?['name']),
      color: _str(
        map['colorName'] ?? map['color'] ?? map['colorResponse']?['name'],
      ),
      price: _double(map['price']),
      stock: _int(map['stock'] ?? map['quantity']),
    );
  }
}

String _str(dynamic value) => value?.toString() ?? '';

int _int(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String? _fullImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  if (url.startsWith('/')) return '$kBaseUrl$url';
  return '$kBaseUrl/$url';
}

class _TitlePriceQty extends StatelessWidget {
  final String name;
  final String brand;
  final double price;
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _TitlePriceQty({
    required this.name,
    required this.brand,
    required this.price,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Product Name' : name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                brand.isEmpty ? 'Brand' : brand,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 8),
              Text(
                '${price.toStringAsFixed(2)} EGP',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              _QtyButton(icon: Icons.remove, onTap: onMinus),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$quantity',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              _QtyButton(icon: Icons.add, onTap: onPlus),
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  final double rating;
  const _RatingRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    final value = rating == 0 ? 4.5 : rating;
    return Row(
      children: [
        Row(
          children: List.generate(
            5,
            (_) => const Icon(Icons.star, size: 18, color: Color(0xffF6B23C)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SizeSection extends StatelessWidget {
  final AppStrings s;
  final List<ProductVariantData> variants;
  final ProductVariantData? selected;
  final ValueChanged<ProductVariantData> onSelected;

  const _SizeSection({
    required this.s,
    required this.variants,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final list =
        variants.where((e) => e.size.isNotEmpty && seen.add(e.size)).toList();
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(s.productSizeLabel,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (selected != null && selected!.size.isNotEmpty)
              Text(selected!.size,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: list.map((variant) {
            final isSelected = selected?.size == variant.size;
            final isLong = variant.size.length > 3;
            return GestureDetector(
              onTap: () => onSelected(variant),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minWidth: 48),
                padding: EdgeInsets.symmetric(
                  horizontal: isLong ? 14 : 0,
                  vertical: isLong ? 10 : 0,
                ),
                width: isLong ? null : 48,
                height: isLong ? null : 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(isLong ? 14 : 100),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 3))]
                      : [],
                ),
                child: Text(
                  variant.size,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.black87,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ColorSection extends StatelessWidget {
  final List<ProductVariantData> variants;
  final ProductVariantData? selected;
  final ValueChanged<ProductVariantData> onSelected;

  const _ColorSection({
    required this.variants,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final list =
        variants.where((e) => e.color.isNotEmpty && seen.add(e.color)).toList();
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Color',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (selected != null && selected!.color.isNotEmpty)
              Text(selected!.color,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: list.map((variant) {
            final isSelected = selected?.color == variant.color;
            final bg = _colorFromName(variant.color);
            final isLight = _isLight(bg);
            return GestureDetector(
              onTap: () => onSelected(variant),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Colors.black
                        : (isLight ? Colors.grey.shade300 : Colors.transparent),
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(color: bg.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 18, color: isLight ? Colors.black : Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  static Color _colorFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('black')) return Colors.black;
    if (n.contains('white') || n.contains('cream') || n.contains('ivory')) return const Color(0xFFF5F5F0);
    if (n.contains('red') || n.contains('maroon')) return const Color(0xFFD32F2F);
    if (n.contains('navy') || n.contains('dark blue')) return const Color(0xFF1A237E);
    if (n.contains('blue')) return const Color(0xFF1565C0);
    if (n.contains('sky')) return const Color(0xFF4FC3F7);
    if (n.contains('green') || n.contains('olive')) return const Color(0xFF388E3C);
    if (n.contains('mint')) return const Color(0xFF80CBC4);
    if (n.contains('yellow') || n.contains('mustard')) return const Color(0xFFFBC02D);
    if (n.contains('pink') || n.contains('rose')) return const Color(0xFFEC407A);
    if (n.contains('grey') || n.contains('gray')) return const Color(0xFF9E9E9E);
    if (n.contains('brown') || n.contains('camel')) return const Color(0xFF795548);
    if (n.contains('orange')) return const Color(0xFFF57C00);
    if (n.contains('purple') || n.contains('violet')) return const Color(0xFF7B1FA2);
    if (n.contains('beige') || n.contains('sand')) return const Color(0xFFD7CCC8);
    if (n.contains('teal')) return const Color(0xFF00897B);
    return const Color(0xFFB0BEC5);
  }

  static bool _isLight(Color c) =>
      (c.red * 299 + c.green * 587 + c.blue * 114) / 1000 > 180;
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.85),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 19, color: Colors.grey.shade800),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, size: 16),
      ),
    );
  }
}
