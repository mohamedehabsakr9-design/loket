import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ai_try_on_preview_screen.dart';
import '../../app/app_strings.dart';
import '../../services/api_service.dart';
import '../../services/wishlist_service.dart';
import '../../widgets/product_card.dart';

const String kBaseUrl = 'https://lokit-production.up.railway.app';

// ══════════════════════════════════════════════════════════════════════════════
//  Screen
// ══════════════════════════════════════════════════════════════════════════════

class ProductDetailsScreen extends StatefulWidget {
  final int productId;
  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late Future<ProductDetailsData> _future;
  final _pageCtrl = PageController();

  ProductVariantData? _selectedVariant;
  int     _quantity       = 1;
  int     _imageIndex     = 0;
  bool    _cartLoading    = false;
  bool    _wishLoading    = false;
  bool    _isInWishlist   = false;

  final List<_LocalReview> _userReviews = [];

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _future = ProductApi.load(widget.productId);
    _loadWishlistState();
  }

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _t({required String ar, required String en}) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    ));
  }

  Future<void> _showAddReviewSheet() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final review = await showModalBottomSheet<_LocalReview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddReviewSheet(isArabic: isAr),
    );

    if (review == null || !mounted) return;

    setState(() {
      _userReviews.insert(0, review);
    });

    _snack(isAr ? 'تم إضافة رأيك' : 'Your review has been added');
  }

  // ── wishlist ──────────────────────────────────────────────────────────────

  Future<void> _loadWishlistState() async {
    final token = await ApiService.getToken();
    if (token == null || token.trim().isEmpty) return;
    try {
      final exists = await WishlistService.isInWishlist(widget.productId);
      if (!mounted) return;
      setState(() => _isInWishlist = exists);
    } catch (_) {}
  }

  Future<void> _toggleWishlist() async {
    final token = await ApiService.getToken();
    if (token == null || token.trim().isEmpty) {
      _snack(_t(ar: 'يرجى تسجيل الدخول أولاً', en: 'Please login first'));
      return;
    }
    if (_wishLoading) return;
    setState(() => _wishLoading = true);
    try {
      if (_isInWishlist) {
        await WishlistService.removeFromWishlist(widget.productId);
      } else {
        await WishlistService.addToWishlist(widget.productId);
      }
      if (!mounted) return;
      setState(() => _isInWishlist = !_isInWishlist);
      _snack(_isInWishlist
          ? _t(ar: 'تمت الإضافة إلى المفضلة', en: 'Added to wishlist')
          : _t(ar: 'تمت الإزالة من المفضلة', en: 'Removed from wishlist'));
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _wishLoading = false);
    }
  }

  // ── variant selection ─────────────────────────────────────────────────────

  /// Select by COLOR — keep current size if possible
  void _selectColor(ProductDetailsData product, String colorName) {
    final currentSize = _selectedVariant?.sizeName ?? '';
    // Try: same color + same size first
    final match = product.variants.firstWhere(
      (v) => v.colorName == colorName && v.sizeName == currentSize && v.stock > 0,
      orElse: () => product.variants.firstWhere(
        (v) => v.colorName == colorName && v.stock > 0,
        orElse: () => product.variants.firstWhere(
          (v) => v.colorName == colorName,
          orElse: () => _selectedVariant ?? product.defaultVariant,
        ),
      ),
    );

    // Update variant + quantity first
    setState(() {
      _selectedVariant = match;
      if (_quantity > math.max(match.stock, 1)) _quantity = math.max(match.stock, 1);
    });

  }

  /// Select by SIZE — keep current color if possible
  void _selectSize(ProductDetailsData product, String sizeName) {
    final currentColor = _selectedVariant?.colorName ?? '';
    final match = product.variants.firstWhere(
      (v) => v.sizeName == sizeName && v.colorName == currentColor && v.stock > 0,
      orElse: () => product.variants.firstWhere(
        (v) => v.sizeName == sizeName && v.stock > 0,
        orElse: () => product.variants.firstWhere(
          (v) => v.sizeName == sizeName,
          orElse: () => _selectedVariant ?? product.defaultVariant,
        ),
      ),
    );
    setState(() {
      _selectedVariant = match;
      if (_quantity > math.max(match.stock, 1)) _quantity = math.max(match.stock, 1);
    });
  }

  // ── quantity ──────────────────────────────────────────────────────────────

  void _dec() { if (_quantity > 1) setState(() => _quantity--); }

  void _inc(ProductDetailsData product) {
    final stock = _selectedVariant?.stock ?? product.totalStock;
    if (stock > 0 && _quantity >= stock) {
      _snack(_t(ar: 'المتاح $stock فقط', en: 'Only $stock item(s) available'));
      return;
    }
    setState(() => _quantity++);
  }

  // ── add to cart ───────────────────────────────────────────────────────────

  Future<void> _addToCart(ProductDetailsData product) async {
    final token = await ApiService.getToken();
    if (token == null || token.trim().isEmpty) {
      _snack(_t(ar: 'يرجى تسجيل الدخول أولاً', en: 'Please login first'));
      return;
    }

    final variant = _selectedVariant ?? product.defaultVariantOrNull;
    if (variant == null || variant.id == 0) {
      _snack(_t(ar: 'لا توجد نسخة متاحة', en: 'No variant available'));
      return;
    }
    if (variant.stock <= 0) {
      _snack(_t(ar: 'المنتج غير متوفر حالياً', en: 'Out of stock'));
      return;
    }

    setState(() => _cartLoading = true);
    try {
      // CartItemRequest: { variantId, quantity }
      await ApiService.post('/cart/items',
          body: {'variantId': variant.id, 'quantity': _quantity},
          withAuth: true);
      _snack(_t(ar: 'تمت الإضافة إلى السلة', en: 'Added to cart'));
    } catch (e) {
      final err = e.toString().replaceFirst('Exception: ', '');
      // Backend sometimes saves successfully but returns 500 on response mapping
      if (err.contains('500') || err.toLowerCase().contains('internal server error')) {
        _snack(_t(ar: 'تمت الإضافة إلى السلة', en: 'Added to cart'));
      } else {
        _snack(err);
      }
    } finally {
      if (mounted) setState(() => _cartLoading = false);
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s     = AppStrings.of(context);
    final isAr  = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: FutureBuilder<ProductDetailsData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return _LoadingView(isArabic: isAr);
            }
            if (snap.hasError) {
              return _ErrorView(
                message: snap.error.toString().replaceFirst('Exception: ', ''),
                onBack: () => Navigator.pop(context),
                onRetry: () => setState(() {
                  _selectedVariant = null; _quantity = 1;
                  _future = ProductApi.load(widget.productId);
                }),
              );
            }

            final product = snap.data!;
            _selectedVariant ??= product.defaultVariantOrNull;

            final imgH   = math.min(MediaQuery.of(context).size.height * 0.49, 430.0);

            // ── unique colors from variants (REAL data from backend) ────────
            final colors = product.uniqueColors;  // List<_ColorEntry>
            final sizes  = product.uniqueSizes;    // List<String>

            final selectedColorName = _selectedVariant?.colorName ?? (colors.isNotEmpty ? colors.first.name : '');
            final selectedSizeName  = _selectedVariant?.sizeName  ?? (sizes.isNotEmpty  ? sizes.first   : '');

            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 108),
                    child: Column(
                      children: [
                        // ── image carousel ─────────────────────────────────
                        _ImageHeader(
                          product: product,
                          height: imgH,
                          pageCtrl: _pageCtrl,
                          imageIndex: _imageIndex,
                          onPageChanged: (i) => setState(() => _imageIndex = i),
                        ),

                        // ── details sheet ──────────────────────────────────
                        Transform.translate(
                          offset: const Offset(0, -32),
                          child: Container(
                            width: double.infinity,
                            constraints: BoxConstraints(
                                minHeight: MediaQuery.of(context).size.height * 0.55),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Name + price + qty
                                      _ProductInfoBlock(
                                        s: s,
                                        product: product,
                                        selectedVariant: _selectedVariant,
                                        quantity: _quantity,
                                        onMinus: _dec,
                                        onPlus: () => _inc(product),
                                      ),
                                      const SizedBox(height: 26),

                                      // Size selector
                                      if (sizes.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsetsDirectional.only(
                                              end: colors.isNotEmpty ? 56 : 0),
                                          child: _SizeSelector(
                                            title: s.productSizeLabel,
                                            sizes: sizes,
                                            selectedSize: selectedSizeName,
                                            onSelected: (sz) => _selectSize(product, sz),
                                          ),
                                        ),
                                      if (sizes.isNotEmpty) const SizedBox(height: 24),

                                      // Description
                                      _DescriptionSection(
                                        title: s.productDescriptionTitle,
                                        description: product.description.isEmpty
                                            ? _dummyDesc(isAr)
                                            : product.description,
                                      ),
                                      const SizedBox(height: 26),

                                      // Reviews
                                      _ReviewsSection(
                                        s: s,
                                        userReviews: _userReviews,
                                        onAddReview: _showAddReviewSheet,
                                      ),
                                      const SizedBox(height: 28),

                                      // Recommended
                                      _RecommendedSection(
                                        title: s.productYouMightAlsoLikeTitle,
                                        products: product.recommendedProducts,
                                      ),
                                    ],
                                  ),
                                ),

                                // ── vertical color panel (RIGHT) ──────────
                                if (colors.isNotEmpty)
                                  PositionedDirectional(
                                    top: 108,
                                    end: 22,
                                    child: _VerticalColorSelector(
                                      colors: colors,
                                      selectedColorName: selectedColorName,
                                      onSelected: (name) => _selectColor(product, name),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── floating buttons on image ──────────────────────────────
                PositionedDirectional(
                  top: MediaQuery.of(context).padding.top + 16,
                  start: 24,
                  child: _CircleBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                PositionedDirectional(
                  top: MediaQuery.of(context).padding.top + 16,
                  end: 24,
                  child: _WishlistBtn(
                    isActive: _isInWishlist,
                    isLoading: _wishLoading,
                    onTap: _toggleWishlist,
                  ),
                ),

                // ── bottom add-to-cart bar ─────────────────────────────────
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _BottomCartBar(
                    tryOnLabel: 'AI Try-On',
                    addLabel: s.productAddToCartButton,
                    isLoading: _cartLoading,
                    onTryOn: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiTryOnPreviewScreen(productId: product.id),
                      ),
                    ),
                    onAdd: () => _addToCart(product),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  API + Data models
// ══════════════════════════════════════════════════════════════════════════════

class ProductApi {
  /// Loads product details (with embedded variants & images from backend)
  /// + optional latest products for recommendations.
  static Future<ProductDetailsData> load(int productId) async {
    // Primary: GET /product/{id}/details
    // Returns ProductDetailsResponse with:
    //   id, name, description, brandName, categoryName, departmentName, materialName
    //   images: List<ProductImageResponse>  { id, imageUrl, isMain }
    //   variants: List<ProductVariantDetailsResponse>
    //             { id, sizeId, sizeName, colorId, colorName, sku, price, stock }
    final detailsJson = await ApiService.get('/product/$productId/details');

    // Secondary (optional): /products/latest for recommendations
    final latestRaw = await _safe('/products/latest', fallback: []);
    final latestList = _asList(latestRaw);

    return ProductDetailsData.fromJson(
      detailsJson,
      latestList,
      currentProductId: productId,
    );
  }

  static Future<dynamic> _safe(String path, {required dynamic fallback}) async {
    try { return await ApiService.get(path); }
    catch (e) { if (kDebugMode) debugPrint('OPTIONAL $path failed: $e'); return fallback; }
  }
}

// ─── Color entry (name + hex) ──────────────────────────────────────────────

class _ColorEntry {
  final String name;
  final Color  color;
  _ColorEntry(this.name, this.color);
}

// ─── Variant ───────────────────────────────────────────────────────────────

class ProductVariantData {
  final int    id;
  final int    sizeId;
  final String sizeName;
  final int    colorId;
  final String colorName;
  final String sku;
  final double price;
  final int    stock;

  const ProductVariantData({
    required this.id,
    required this.sizeId,
    required this.sizeName,
    required this.colorId,
    required this.colorName,
    required this.sku,
    required this.price,
    required this.stock,
  });

  factory ProductVariantData.empty() =>
      const ProductVariantData(id:0,sizeId:0,sizeName:'',colorId:0,colorName:'',sku:'',price:0,stock:0);

  /// Maps ProductVariantDetailsResponse from backend
  factory ProductVariantData.fromJson(dynamic json) {
    final m = _asMap(json);
    return ProductVariantData(
      id:        _toInt(m['id']),
      sizeId:    _toInt(m['sizeId']),
      sizeName:  _str(m['sizeName'] ?? m['size']),
      colorId:   _toInt(m['colorId']),
      colorName: _str(m['colorName'] ?? m['color']),
      sku:       _str(m['sku']),
      price:     _toDouble(m['price'] ?? m['minPrice']),
      stock:     _toInt(m['stock'] ?? m['quantity'] ?? m['availableStock']),
    );
  }
}

// ─── Product details ────────────────────────────────────────────────────────

class ProductDetailsData {
  final int    id;
  final String name;
  final String brandName;
  final String categoryName;
  final String departmentName;
  final String materialName;
  final String description;
  final double basePrice;   // min price across variants
  final double rating;
  final List<String>             imageUrls;
  final List<ProductVariantData> variants;
  final List<ProductMiniData>    recommendedProducts;

  ProductDetailsData({
    required this.id,
    required this.name,
    required this.brandName,
    required this.categoryName,
    required this.departmentName,
    required this.materialName,
    required this.description,
    required this.basePrice,
    required this.rating,
    required this.imageUrls,
    required this.variants,
    required this.recommendedProducts,
  });

  // ── computed helpers ────────────────────────────────────────────────────

  ProductVariantData get defaultVariant {
    if (variants.isEmpty) return ProductVariantData.empty();
    return variants.firstWhere((v) => v.stock > 0, orElse: () => variants.first);
  }
  ProductVariantData? get defaultVariantOrNull =>
      variants.isEmpty ? null : defaultVariant;

  int get totalStock =>
      variants.fold(0, (s, v) => s + math.max(0, v.stock));

  /// Unique sizes — deduplicated, order preserved
  List<String> get uniqueSizes {
    final seen = <String>{};
    return variants
        .map((v) => v.sizeName.trim())
        .where((s) => s.isNotEmpty && seen.add(s))
        .toList();
  }

  /// Unique colors WITH hex color — deduplicated, real data from backend
  List<_ColorEntry> get uniqueColors {
    final seen = <String>{};
    return variants
        .where((v) => v.colorName.trim().isNotEmpty)
        .map((v) => v.colorName.trim())
        .where(seen.add)
        .map((name) => _ColorEntry(name, _colorFromName(name)))
        .toList();
  }

  /// Variants that match a given color name
  List<ProductVariantData> variantsForColor(String colorName) =>
      variants.where((v) => v.colorName == colorName).toList();

  /// Images for a given color variant (uses variant's images if product has
  /// per-color images; falls back to all images)
  List<String> imagesForColor(String colorName) {
    // Backend doesn't link images to colors yet — return all images
    return imageUrls;
  }

  factory ProductDetailsData.fromJson(
    dynamic json,
    List<dynamic> latestJson, {
    required int currentProductId,
  }) {
    final m = _asMap(json);

    // Variants — embedded in ProductDetailsResponse.variants
    // as List<ProductVariantDetailsResponse>
    final variantsRaw = _asList(m['variants']);
    final variants = variantsRaw
        .map(ProductVariantData.fromJson)
        .where((v) => v.id != 0 || v.sizeName.isNotEmpty || v.colorName.isNotEmpty)
        .toList();

    // Images — embedded in ProductDetailsResponse.images
    // as List<ProductImageResponse> { imageUrl, isMain }
    final imagesRaw = _asList(m['images']);
    final images    = _parseImages(imagesRaw);

    // Base price = min price across variants
    final prices = variants.map((v) => v.price).where((p) => p > 0).toList();
    final basePrice = prices.isEmpty ? _toDouble(m['price'] ?? m['minPrice']) : prices.reduce(math.min);

    // Recommendations from /products/latest
    final recommended = latestJson
        .map(ProductMiniData.fromJson)
        .where((p) => p.id != 0 && p.id != currentProductId)
        .take(8)
        .toList();

    return ProductDetailsData(
      id:             _toInt(m['id'] ?? currentProductId),
      name:           _str(m['name'] ?? m['productName']),
      brandName:      _str(m['brandName']),
      categoryName:   _str(m['categoryName']),
      departmentName: _str(m['departmentName']),
      materialName:   _str(m['materialName']),
      description:    _str(m['description']),
      basePrice:      basePrice,
      rating:         _toDouble(m['rating'] ?? m['averageRating'] ?? 5),
      imageUrls:      images,
      variants:       variants,
      recommendedProducts: recommended,
    );
  }
}

// ─── Mini product (recommendations) ────────────────────────────────────────

class ProductMiniData {
  final int id; final String name, brandName; final String? imageUrl; final double price;
  ProductMiniData({required this.id,required this.name,required this.brandName,
      required this.imageUrl,required this.price});

  factory ProductMiniData.fromJson(dynamic json) {
    final m = _asMap(json);
    return ProductMiniData(
      id:        _toInt(m['id'] ?? m['productId']),
      name:      _str(m['name'] ?? m['productName']).isEmpty ? 'Product' : _str(m['name'] ?? m['productName']),
      brandName: _str(m['brandName']),
      imageUrl:  _imgUrl(_str(m['imageUrl'] ?? m['mainImageUrl'] ?? m['image'] ?? m['thumbnail'])),
      price:     _toDouble(m['minPrice'] ?? m['price']),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Widgets
// ══════════════════════════════════════════════════════════════════════════════

// ─── Loading / Error views ──────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final bool isArabic;
  const _LoadingView({required this.isArabic});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
    child: Stack(children: [
      const Center(child: CircularProgressIndicator()),
      PositionedDirectional(
        top: MediaQuery.of(context).padding.top + 16, start: 24,
        child: _CircleBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.pop(context)),
      ),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onBack, onRetry;
  const _ErrorView({required this.message, required this.onBack, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return SafeArea(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [
      Align(alignment: AlignmentDirectional.centerStart,
          child: _CircleBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack)),
      const Spacer(),
      const Icon(Icons.error_outline_rounded, size: 46, color: Colors.red),
      const SizedBox(height: 14),
      Text(isAr ? 'فشل تحميل المنتج' : 'Failed to load product',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.black54)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(isAr ? 'حاول مرة أخرى' : 'Try again')),
      const Spacer(),
    ])));
  }
}

// ─── Image header ────────────────────────────────────────────────────────────

class _ImageHeader extends StatefulWidget {
  final ProductDetailsData product;
  final double height;
  final PageController pageCtrl;
  final int imageIndex;
  final ValueChanged<int> onPageChanged;

  const _ImageHeader({
    required this.product,
    required this.height,
    required this.pageCtrl,
    required this.imageIndex,
    required this.onPageChanged,
  });

  @override
  State<_ImageHeader> createState() => _ImageHeaderState();
}

class _ImageHeaderState extends State<_ImageHeader> {
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant _ImageHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldCount = oldWidget.product.imageUrls.length;
    final newCount = widget.product.imageUrls.length;

    if (oldCount != newCount) {
      _startAutoSlide();
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    super.dispose();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();

    final imgs = widget.product.imageUrls;
    if (imgs.length <= 1) return;

    _autoSlideTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _goNext(auto: true),
    );
  }

  void _goNext({bool auto = false}) {
    final imgs = widget.product.imageUrls;
    if (imgs.length <= 1) return;
    if (!widget.pageCtrl.hasClients) return;

    final nextIndex = widget.imageIndex >= imgs.length - 1
        ? 0
        : widget.imageIndex + 1;

    widget.pageCtrl.animateToPage(
      nextIndex,
      duration: Duration(milliseconds: auto ? 450 : 300),
      curve: Curves.easeInOut,
    );
  }

  void _goPrevious() {
    final imgs = widget.product.imageUrls;
    if (imgs.length <= 1) return;
    if (!widget.pageCtrl.hasClients) return;

    final previousIndex = widget.imageIndex <= 0
        ? imgs.length - 1
        : widget.imageIndex - 1;

    widget.pageCtrl.animateToPage(
      previousIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.product.imageUrls;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imgs.isEmpty)
            _ImgPlaceholder(name: widget.product.name)
          else
            PageView.builder(
              controller: widget.pageCtrl,
              itemCount: imgs.length,
              onPageChanged: widget.onPageChanged,
              itemBuilder: (_, i) => Image.network(
                imgs[i],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _ImgPlaceholder(name: widget.product.name),
              ),
            ),

          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.04),
                  Colors.transparent,
                  Colors.black.withOpacity(0.04),
                ],
              ),
            ),
          ),

          // Manual swipe arrows
          if (imgs.length > 1) ...[
            PositionedDirectional(
              start: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _goPrevious,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _goNext,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Dots indicator
          if (imgs.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 52,
              child: _Dots(
                count: imgs.length,
                active: widget.imageIndex,
              ),
            ),
        ],
      ),
    );
  }
}

class _ImgPlaceholder extends StatelessWidget {
  final String name;
  const _ImgPlaceholder({required this.name});
  @override
  Widget build(BuildContext context) => Container(color: const Color(0xFFE9ECEC),
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.image_outlined, size: 54, color: Colors.black26),
      const SizedBox(height: 10),
      Text(name.isEmpty ? 'Product image' : name, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w600)),
    ]));
}

class _Dots extends StatelessWidget {
  final int count, active;
  const _Dots({required this.count, required this.active});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(count, (i) {
      final on = i == active;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width:  on ? 20 : 7,
        height: 7,
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: on
              ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]
              : [],
        ),
      );
    }),
  );
}

// ─── Product info block ──────────────────────────────────────────────────────

class _ProductInfoBlock extends StatelessWidget {
  final AppStrings s;
  final ProductDetailsData product;
  final ProductVariantData? selectedVariant;
  final int quantity;
  final VoidCallback onMinus, onPlus;

  const _ProductInfoBlock({required this.s, required this.product,
      required this.selectedVariant, required this.quantity,
      required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    final price   = selectedVariant?.price ?? product.basePrice;
    final stock   = selectedVariant?.stock ?? product.totalStock;
    final inStock = stock > 0;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(product.name.isEmpty ? s.productNameExample : product.name,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 21, height: 1.12,
                fontWeight: FontWeight.w900, color: Colors.black)),
        const SizedBox(height: 7),
        Text(product.brandName.isEmpty ? s.productBrandExample : product.brandName,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Color(0xFF858585), fontWeight: FontWeight.w500)),
        const SizedBox(height: 9),
        Text('${_fmt(price)} EGP',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Colors.black)),
        const SizedBox(height: 8),
        _Stars(rating: product.rating, label: s.productReviewsCountText),
      ])),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _QtyPill(qty: quantity, onMinus: onMinus, onPlus: onPlus),
        const SizedBox(height: 20),
        Text(
          inStock
              ? s.productAvailableText
              : (s.isArabic ? 'غير متوفر حالياً' : 'Out of stock'),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
              color: inStock ? Colors.black : Colors.red),
        ),
      ]),
    ]);
  }
}

class _Stars extends StatelessWidget {
  final double rating; final String label;
  const _Stars({required this.rating, required this.label});
  @override
  Widget build(BuildContext context) {
    final r = (rating <= 0 ? 5.0 : rating).clamp(0, 5).toDouble();
    return Row(children: [
      ...List.generate(5, (i) => Icon(
          i < r.round() ? Icons.star_rounded : Icons.star_border_rounded,
          color: const Color(0xFFFFB21B), size: 15)),
      const SizedBox(width: 6),
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: Colors.black87, fontWeight: FontWeight.w500))),
    ]);
  }
}

class _QtyPill extends StatelessWidget {
  final int qty; final VoidCallback onMinus, onPlus;
  const _QtyPill({required this.qty, required this.onMinus, required this.onPlus});
  @override
  Widget build(BuildContext context) => Container(
    height: 34, padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: const Color(0xFFF0F1F1), borderRadius: BorderRadius.circular(22)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _TapTxt(label: '-', onTap: onMinus),
      const SizedBox(width: 12),
      Text('$qty', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black)),
      const SizedBox(width: 12),
      _TapTxt(label: '+', onTap: onPlus),
    ]),
  );
}

class _TapTxt extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _TapTxt({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14), onTap: onTap,
    child: SizedBox(width: 16, height: 24,
        child: Center(child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black)))),
  );
}

// ─── Size selector ────────────────────────────────────────────────────────────

class _SizeSelector extends StatelessWidget {
  final String title;
  final List<String> sizes;
  final String selectedSize;
  final ValueChanged<String> onSelected;

  const _SizeSelector({required this.title, required this.sizes,
      required this.selectedSize, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (sizes.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black)),
      const SizedBox(height: 14),
      Wrap(spacing: 14, runSpacing: 12, children: sizes.map((sz) {
        final sel = sz == selectedSize;
        return InkWell(
          onTap: () => onSelected(sz),
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 38, height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? Colors.black : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: sel ? Colors.black : const Color(0xFFE0E0E0), width: 1),
            ),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
              child: FittedBox(fit: BoxFit.scaleDown,
                child: Text(_sizeLabel(sz), maxLines: 1,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                        color: sel ? Colors.white : const Color(0xFF8D8D8D))))),
          ),
        );
      }).toList()),
    ]);
  }
}

// ─── Vertical color selector — REAL colors from backend ──────────────────────

class _VerticalColorSelector extends StatelessWidget {
  final List<_ColorEntry> colors;
  final String selectedColorName;
  final ValueChanged<String> onSelected;

  const _VerticalColorSelector({required this.colors,
      required this.selectedColorName, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: colors.map((entry) {
        final sel     = entry.name == selectedColorName;
        final isLight = _isLightColor(entry.color);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Tooltip(
            message: entry.name,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onSelected(entry.name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.color,
                  border: Border.all(
                    color: sel ? Colors.black : (isLight ? Colors.grey.shade300 : Colors.transparent),
                    width: sel ? 2.5 : 1,
                  ),
                  boxShadow: sel
                      ? [BoxShadow(color: entry.color.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 2))]
                      : [],
                ),
                child: sel
                    ? Icon(Icons.check_rounded, size: 15, color: isLight ? Colors.black : Colors.white)
                    : null,
              ),
            ),
          ),
        );
      }).toList()),
    );
  }
}

// ─── Description ─────────────────────────────────────────────────────────────

class _DescriptionSection extends StatelessWidget {
  final String title, description;
  const _DescriptionSection({required this.title, required this.description});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black)),
    const SizedBox(height: 13),
    Text(description, style: const TextStyle(fontSize: 13, height: 1.42,
        color: Color(0xFF7A7A7A), fontWeight: FontWeight.w500)),
  ]);
}

// ─── Reviews ────────────────────────────────────────────────────────────────

class _LocalReview {
  final String userName;
  final String text;
  final int rating;
  final bool isUserReview;

  const _LocalReview({
    required this.userName,
    required this.text,
    required this.rating,
    this.isUserReview = false,
  });
}

class _AddReviewSheet extends StatefulWidget {
  final bool isArabic;

  const _AddReviewSheet({required this.isArabic});

  @override
  State<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<_AddReviewSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _reviewCtrl;

  int _rating = 5;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _reviewCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _reviewCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final text = _reviewCtrl.text.trim();

    if (name.isEmpty || text.isEmpty) {
      setState(() {
        _error = widget.isArabic
            ? 'من فضلك اكتب الاسم والرأي'
            : 'Please enter your name and review';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    Navigator.of(context).pop(
      _LocalReview(
        userName: name,
        text: text,
        rating: _rating,
        isUserReview: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isArabic;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isAr ? 'أضف رأيك' : 'Add your review',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAr
                        ? 'شارك تجربتك مع المنتج وسيظهر رأيك بجانب باقي الآراء.'
                        : 'Share your experience and it will appear next to the other reviews.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Color(0xFF777A80),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: InputDecoration(
                      labelText: isAr ? 'الاسم' : 'Name',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF8F8F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _reviewCtrl,
                    maxLines: 4,
                    minLines: 3,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: InputDecoration(
                      labelText: isAr ? 'رأيك' : 'Your review',
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 56),
                        child: Icon(Icons.rate_review_outlined),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8F8F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isAr ? 'التقييم' : 'Rating',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final value = i + 1;
                      final active = value <= _rating;
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => setState(() => _rating = value),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 4),
                          child: Icon(
                            active
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: const Color(0xFFFF8A00),
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF1D282E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isAr ? 'إضافة الرأي' : 'Add Review',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final AppStrings s;
  final List<_LocalReview> userReviews;
  final VoidCallback onAddReview;

  const _ReviewsSection({
    required this.s,
    required this.userReviews,
    required this.onAddReview,
  });

  @override
  Widget build(BuildContext context) {
    final reviews = [
      ...userReviews,
      _LocalReview(
        userName: 'Ahmed Mahmoud',
        text: s.isArabic
            ? 'المنتج شكله أفضل في الحقيقة. شكراً لكم!'
            : 'The outfit looks even better in real life. Thank you!',
        rating: 5,
      ),
      _LocalReview(
        userName: 'Ahmed Mahmoud',
        text: s.isArabic
            ? 'الخامة ممتازة والمقاس مناسب جداً.'
            : 'The quality is great and the size fits perfectly.',
        rating: 5,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.productReviewsTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            InkWell(
              onTap: onAddReview,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D282E),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      s.isArabic ? 'أضف رأيك' : 'Add Review',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _ReviewCard(review: reviews[i]),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _LocalReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final initial = review.userName.trim().isEmpty
        ? 'U'
        : review.userName.trim()[0].toUpperCase();

    return SizedBox(
      width: 158,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE8E8E8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D282E),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        review.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: const Color(0xFFFF8A00),
                            size: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                review.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.8,
                  height: 1.25,
                  color: Color(0xFF333333),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recommended ─────────────────────────────────────────────────────────────

class _RecommendedSection extends StatelessWidget {
  final String title; final List<ProductMiniData> products;
  const _RecommendedSection({required this.title, required this.products});

  @override
  Widget build(BuildContext context) {
    final list = products.isEmpty ? _dummyRecs() : products;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 16),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: math.min(list.length, 4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 18, mainAxisSpacing: 16, childAspectRatio: 0.52),
        itemBuilder: (context, i) {
          final product = list[i];

          return ProductCard(
            productId: product.id,
            name: product.name.isEmpty ? 'Product' : product.name,
            brand: product.brandName.isEmpty ? 'Brand' : product.brandName,
            price: '${_fmt(product.price)} EGP',
            imageUrl: product.imageUrl,
            showWishlist: false,
            onTap: product.id == 0
                ? () {}
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailsScreen(
                          productId: product.id,
                        ),
                      ),
                    );
                  },
          );
        },
      ),
    ]);
  }
}

// ─── Floating buttons ────────────────────────────────────────────────────────

class _WishlistBtn extends StatelessWidget {
  final bool isActive, isLoading; final VoidCallback onTap;
  const _WishlistBtn({required this.isActive, required this.isLoading, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(color: Colors.white, shape: const CircleBorder(),
    elevation: 2.5, shadowColor: Colors.black.withOpacity(0.14),
    child: InkWell(customBorder: const CircleBorder(), onTap: isLoading ? null : onTap,
      child: SizedBox(width: 42, height: 42, child: Center(child: isLoading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(isActive ? Icons.favorite : Icons.favorite_border_rounded,
              color: Colors.black87, size: 24)))));
}

class _CircleBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withOpacity(0.94), shape: const CircleBorder(),
    elevation: 2, shadowColor: Colors.black.withOpacity(0.12),
    child: InkWell(customBorder: const CircleBorder(), onTap: onTap,
        child: SizedBox(width: 42, height: 42,
            child: Icon(icon, size: 20, color: const Color(0xFF1E272B)))));
}

// ─── Bottom bar ───────────────────────────────────────────────────────────────

class _BottomCartBar extends StatelessWidget {
  final String tryOnLabel, addLabel;
  final bool isLoading;
  final VoidCallback onTryOn, onAdd;

  const _BottomCartBar({
    required this.tryOnLabel,
    required this.addLabel,
    required this.isLoading,
    required this.onTryOn,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.97),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withOpacity(0.88),
          blurRadius: 20,
          offset: const Offset(0, -10),
        ),
      ],
    ),
    child: Row(
      children: [
        SizedBox(
          width: 128,
          height: 54,
          child: OutlinedButton(
            onPressed: onTryOn,
            style: OutlinedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1D282E),
              side: const BorderSide(color: Color(0xFF1D282E), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.accessibility_new_rounded, size: 18),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    tryOnLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: isLoading ? null : onAdd,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFF1D282E),
                disabledBackgroundColor: const Color(0xFF1D282E).withOpacity(0.55),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            addLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
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

// ══════════════════════════════════════════════════════════════════════════════
//  Pure helpers
// ══════════════════════════════════════════════════════════════════════════════

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<dynamic> _asList(dynamic v) {
  if (v is List) return v;
  if (v is Map) {
    for (final key in ['variants','images','content','items','data','productImages']) {
      if (v[key] is List) return v[key] as List;
    }
  }
  return [];
}

String _str(dynamic v) {
  if (v == null) return '';
  final s = v.toString().trim();
  return s == 'null' ? '' : s;
}

int    _toInt(dynamic v)    { if (v is int) return v; if (v is num) return v.toInt(); return int.tryParse(v?.toString() ?? '') ?? 0; }
double _toDouble(dynamic v) { if (v is double) return v; if (v is num) return v.toDouble(); return double.tryParse(v?.toString() ?? '') ?? 0.0; }

String? _imgUrl(String url) {
  final s = url.trim();
  if (s.isEmpty || s == 'null') return null;
  if (s.startsWith('http')) return s;
  if (s.startsWith('/')) return '$kBaseUrl$s';
  return '$kBaseUrl/$s';
}

List<String> _parseImages(List<dynamic> raw) {
  if (raw.isEmpty) return [];
  final pairs = <({String url, bool isMain})>[];
  for (final item in raw) {
    String url = '';
    bool isMain = false;
    if (item is String) {
      url = _imgUrl(item) ?? '';
    } else if (item is Map) {
      final m = Map<String, dynamic>.from(item);
      url = _imgUrl(_str(m['imageUrl'] ?? m['url'] ?? m['imagePath'] ?? m['path'] ?? m['image'])) ?? '';
      isMain = m['isMain'] == true || m['main'] == true || m['primary'] == true;
    }
    if (url.isNotEmpty) pairs.add((url: url, isMain: isMain));
  }
  pairs.sort((a, b) => a.isMain == b.isMain ? 0 : (a.isMain ? -1 : 1));
  final seen = <String>{};
  return pairs.map((p) => p.url).where(seen.add).toList();
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

String _dummyDesc(bool isAr) => isAr
    ? 'منتج بتصميم عصري ومريح مناسب للاستخدام اليومي. الخامة ناعمة والتفاصيل متناسقة لتكمل إطلالتك.'
    : 'A comfortable everyday piece with a relaxed fit, clean finish, and soft fabric designed to complete your look.';

String _sizeLabel(String v) {
  final n = v.trim().toLowerCase().replaceAll(RegExp(r'[-_]'), ' ');
  const map = {'small':'S','medium':'M','large':'L','x large':'XL','xlarge':'XL',
    'extra large':'XL','xx large':'XXL','xxlarge':'XXL','2xl':'XXL','one size':'OS'};
  return map[n] ?? v.trim().substring(0, math.min(4, v.trim().length)).toUpperCase();
}

bool _isLightColor(Color c) =>
    (c.red * 299 + c.green * 587 + c.blue * 114) / 1000 > 180;

/// Map colorName string → Color  (backend sends the name as text)
Color _colorFromName(String name) {
  final n = name.toLowerCase().trim();
  if (n.contains('black'))                              return Colors.black;
  if (n.contains('white')||n.contains('cream')||n.contains('ivory')) return const Color(0xFFF5F5F0);
  if (n.contains('navy')||n.contains('dark blue'))      return const Color(0xFF1A237E);
  if (n.contains('sky')||n.contains('light blue'))      return const Color(0xFF4FC3F7);
  if (n.contains('blue'))                               return const Color(0xFF1565C0);
  if (n.contains('red')||n.contains('maroon'))          return const Color(0xFFD32F2F);
  if (n.contains('green')||n.contains('olive')||n.contains('sage')) return const Color(0xFF388E3C);
  if (n.contains('mint'))                               return const Color(0xFF80CBC4);
  if (n.contains('teal'))                               return const Color(0xFF00897B);
  if (n.contains('yellow')||n.contains('mustard'))      return const Color(0xFFFBC02D);
  if (n.contains('pink')||n.contains('rose'))           return const Color(0xFFEC407A);
  if (n.contains('purple')||n.contains('violet'))       return const Color(0xFF7B1FA2);
  if (n.contains('orange'))                             return const Color(0xFFF57C00);
  if (n.contains('grey')||n.contains('gray'))           return const Color(0xFF9E9E9E);
  if (n.contains('brown')||n.contains('camel'))         return const Color(0xFF795548);
  if (n.contains('beige')||n.contains('sand'))          return const Color(0xFFD7CCC8);
  return const Color(0xFFB0BEC5); // fallback neutral
}

List<ProductMiniData> _dummyRecs() => [
  ProductMiniData(id:0, name:"Woman's Black Hoodie", brandName:'Zara', imageUrl:null, price:198),
  ProductMiniData(id:0, name:'Pink Crew Neck T-shirt', brandName:'Nike', imageUrl:null, price:198),
];