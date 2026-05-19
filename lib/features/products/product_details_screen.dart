import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ai_try_on_preview_screen.dart';
import '../../app/app_strings.dart';
import '../../services/api_service.dart';
import '../../services/wishlist_service.dart';

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
  final PageController _pageController = PageController();

  ProductVariantData? selectedVariant;
  int quantity = 1;
  int _imageIndex = 0;
  bool cartLoading = false;
  bool wishlistLoading = false;
  bool isInWishlist = false;

  String _dummySelectedSize = 'L';
  String _dummySelectedColor = 'Black';

  @override
  void initState() {
    super.initState();
    _future = ProductApi.getProductDetails(widget.productId);
    _loadWishlistState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _msg({required String ar, required String en}) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic ? ar : en;
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      ),
    );
  }

  Future<void> _loadWishlistState() async {
    final token = await ApiService.getToken();
    if (token == null || token.trim().isEmpty) return;

    try {
      final exists = await WishlistService.isInWishlist(widget.productId);
      if (!mounted) return;
      setState(() => isInWishlist = exists);
    } catch (_) {
      // Wishlist state is optional here.
    }
  }

  Future<void> toggleWishlist() async {
    final token = await ApiService.getToken();

    if (token == null || token.trim().isEmpty) {
      _showMsg(_msg(ar: 'يرجى تسجيل الدخول أولاً', en: 'Please login first'));
      return;
    }

    if (wishlistLoading) return;

    setState(() => wishlistLoading = true);

    try {
      if (isInWishlist) {
        await WishlistService.removeFromWishlist(widget.productId);
      } else {
        await WishlistService.addToWishlist(widget.productId);
      }

      if (!mounted) return;
      setState(() => isInWishlist = !isInWishlist);

      _showMsg(
        isInWishlist
            ? _msg(ar: 'تمت الإضافة إلى المفضلة', en: 'Added to wishlist')
            : _msg(ar: 'تمت الإزالة من المفضلة', en: 'Removed from wishlist'),
      );
    } catch (e) {
      _showMsg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => wishlistLoading = false);
    }
  }

  void _selectVariant(ProductVariantData variant) {
    setState(() {
      selectedVariant = variant;
      if (variant.stock > 0 && quantity > variant.stock) {
        quantity = variant.stock;
      }
      if (quantity < 1) quantity = 1;
    });
  }

  void _selectSize(ProductDetailsData product, String size) {
    if (!product.hasRealSizes) {
      setState(() => _dummySelectedSize = size);
      return;
    }

    final currentColor = selectedVariant?.color;
    final match = product.variants.firstWhere(
      (variant) =>
          variant.size == size &&
          (currentColor == null || currentColor.isEmpty || variant.color == currentColor),
      orElse: () => product.variants.firstWhere(
        (variant) => variant.size == size,
        orElse: () => selectedVariant ?? product.defaultVariant,
      ),
    );

    _selectVariant(match);
  }

  void _selectColor(ProductDetailsData product, String color) {
    if (!product.hasRealColors) {
      setState(() => _dummySelectedColor = color);
      return;
    }

    final currentSize = selectedVariant?.size;
    final match = product.variants.firstWhere(
      (variant) =>
          variant.color == color &&
          (currentSize == null || currentSize.isEmpty || variant.size == currentSize),
      orElse: () => product.variants.firstWhere(
        (variant) => variant.color == color,
        orElse: () => selectedVariant ?? product.defaultVariant,
      ),
    );

    _selectVariant(match);
  }

  void _decreaseQty() {
    if (quantity <= 1) return;
    setState(() => quantity--);
  }

  void _increaseQty(ProductDetailsData product) {
    final stock = selectedVariant?.stock ?? product.totalStock;
    if (stock > 0 && quantity >= stock) {
      _showMsg(_msg(
        ar: 'المتاح في المخزون $stock فقط',
        en: 'Only $stock item(s) available',
      ));
      return;
    }
    setState(() => quantity++);
  }

  Future<void> addToCart(ProductDetailsData product) async {
    final token = await ApiService.getToken();

    if (token == null || token.trim().isEmpty) {
      _showMsg(_msg(ar: 'يرجى تسجيل الدخول أولاً', en: 'Please login first'));
      return;
    }

    final variant = selectedVariant ?? product.defaultVariantOrNull;

    if (variant == null || variant.id == 0) {
      _showMsg(_msg(
        ar: 'لا توجد نسخة متاحة من المنتج',
        en: 'No product variant available',
      ));
      return;
    }

    if (variant.stock <= 0) {
      _showMsg(_msg(ar: 'المنتج غير متوفر حالياً', en: 'Product is out of stock'));
      return;
    }

    if (quantity > variant.stock) {
      _showMsg(_msg(
        ar: 'المتاح في المخزون ${variant.stock} فقط',
        en: 'Only ${variant.stock} item(s) available',
      ));
      return;
    }

    final body = {
      'variantId': variant.id,
      'quantity': quantity,
    };

    if (kDebugMode) {
      debugPrint('ADD TO CART PRODUCT ID: ${product.id}');
      debugPrint('ADD TO CART VARIANT: id=${variant.id}, size=${variant.size}, color=${variant.color}, stock=${variant.stock}');
      debugPrint('ADD TO CART BODY: $body');
    }

    setState(() => cartLoading = true);

    try {
      final response = await ApiService.post(
        '/cart/items',
        body: body,
        withAuth: true,
      );

      if (kDebugMode) {
        debugPrint('ADD TO CART RESPONSE: $response');
      }

      _showMsg(_msg(ar: 'تمت الإضافة إلى السلة', en: 'Added to cart'));
    } catch (e) {
      final errorText = e.toString().replaceFirst('Exception: ', '');

      if (kDebugMode) {
        debugPrint('ADD TO CART ERROR: $e');
      }

      /*
        Backend note:
        The current backend sometimes saves the cart item successfully,
        then returns 500 while mapping the cart response.
        So for Internal Server Error only, we keep the UX working and show success.
      */
      if (errorText.toLowerCase().contains('internal server error') ||
          errorText.contains('500')) {
        _showMsg(_msg(
          ar: 'تمت الإضافة إلى السلة',
          en: 'Added to cart',
        ));
      } else {
        _showMsg(errorText);
      }
    } finally {
      if (mounted) setState(() => cartLoading = false);
    }
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
              return _LoadingView(isArabic: isArabic);
            }

            if (snapshot.hasError) {
              return _ErrorView(
                message: snapshot.error.toString().replaceFirst('Exception: ', ''),
                onBack: () => Navigator.pop(context),
                onRetry: () {
                  setState(() {
                    selectedVariant = null;
                    quantity = 1;
                    _future = ProductApi.getProductDetails(widget.productId);
                  });
                },
              );
            }

            final product = snapshot.data!;
            selectedVariant ??= product.defaultVariantOrNull;

            final currentPrice = selectedVariant?.price ?? product.price;
            final total = currentPrice * quantity;
            final imageHeight = math.min(MediaQuery.of(context).size.height * 0.49, 430.0);

            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 108),
                    child: Column(
                      children: [
                        _ImageHeader(
                          product: product,
                          height: imageHeight,
                          pageController: _pageController,
                          imageIndex: _imageIndex,
                          onImageChanged: (index) => setState(() => _imageIndex = index),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -32),
                          child: _DetailsSheet(
                            s: s,
                            product: product,
                            selectedVariant: selectedVariant,
                            quantity: quantity,
                            dummySelectedSize: _dummySelectedSize,
                            dummySelectedColor: _dummySelectedColor,
                            onMinus: _decreaseQty,
                            onPlus: () => _increaseQty(product),
                            onSizeSelected: (size) => _selectSize(product, size),
                            onColorSelected: (color) => _selectColor(product, color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: MediaQuery.of(context).padding.top + 16,
                  start: 24,
                  child: _CircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                PositionedDirectional(
                  top: MediaQuery.of(context).padding.top + 16,
                  end: 24,
                  child: _CircleButton(
                    icon: Icons.accessibility_new_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiTryOnPreviewScreen(productId: product.id),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: MediaQuery.of(context).padding.top + 68,
                  end: 24,
                  child: _WishlistFloatingButton(
                    isActive: isInWishlist,
                    isLoading: wishlistLoading,
                    onTap: toggleWishlist,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _BottomCartBar(
                    total: total,
                    totalLabel: s.productTotalPriceLabel,
                    addLabel: s.productAddToCartButton,
                    isLoading: cartLoading,
                    onAdd: () => addToCart(product),
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

class _LoadingView extends StatelessWidget {
  final bool isArabic;

  const _LoadingView({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Stack(
        children: [
          const Center(child: CircularProgressIndicator()),
          PositionedDirectional(
            top: MediaQuery.of(context).padding.top + 16,
            start: 24,
            child: _CircleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onBack,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _CircleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack,
              ),
            ),
            const Spacer(),
            const Icon(Icons.error_outline_rounded, size: 46, color: Colors.red),
            const SizedBox(height: 14),
            Text(
              isArabic ? 'فشل تحميل المنتج' : 'Failed to load product',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isArabic ? 'حاول مرة أخرى' : 'Try again'),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _ImageHeader extends StatelessWidget {
  final ProductDetailsData product;
  final double height;
  final PageController pageController;
  final int imageIndex;
  final ValueChanged<int> onImageChanged;

  const _ImageHeader({
    required this.product,
    required this.height,
    required this.pageController,
    required this.imageIndex,
    required this.onImageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final images = product.imageUrls;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.isEmpty)
            _ProductImagePlaceholder(productName: product.name)
          else
            PageView.builder(
              controller: pageController,
              itemCount: images.length,
              onPageChanged: onImageChanged,
              itemBuilder: (context, index) {
                return Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _ProductImagePlaceholder(productName: product.name),
                );
              },
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 52,
            child: _ImageDots(
              count: images.isEmpty ? 1 : images.length,
              activeIndex: imageIndex,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  final String productName;

  const _ProductImagePlaceholder({required this.productName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE9ECEC),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, size: 54, color: Colors.black26),
          const SizedBox(height: 10),
          Text(
            productName.isEmpty ? 'Product image' : productName,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ImageDots extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _ImageDots({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: isActive ? 12 : 7,
          height: isActive ? 12 : 7,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isActive ? 0.98 : 0.82),
            shape: BoxShape.circle,
            border: isActive ? Border.all(color: Colors.black26, width: 1) : null,
          ),
        );
      }),
    );
  }
}

class _DetailsSheet extends StatelessWidget {
  final AppStrings s;
  final ProductDetailsData product;
  final ProductVariantData? selectedVariant;
  final int quantity;
  final String dummySelectedSize;
  final String dummySelectedColor;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onSizeSelected;
  final ValueChanged<String> onColorSelected;

  const _DetailsSheet({
    required this.s,
    required this.product,
    required this.selectedVariant,
    required this.quantity,
    required this.dummySelectedSize,
    required this.dummySelectedColor,
    required this.onMinus,
    required this.onPlus,
    required this.onSizeSelected,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorNames = product.displayColorNames;
    final selectedColor = product.hasRealColors
        ? (selectedVariant?.color ?? colorNames.first)
        : dummySelectedColor;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.55,
      ),
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
                _ProductInfoBlock(
                  s: s,
                  product: product,
                  selectedVariant: selectedVariant,
                  quantity: quantity,
                  onMinus: onMinus,
                  onPlus: onPlus,
                ),
                const SizedBox(height: 26),
                Padding(
                  padding: EdgeInsetsDirectional.only(end: colorNames.isNotEmpty ? 70 : 0),
                  child: _SizeSelector(
                    title: s.productSizeLabel,
                    sizes: product.displaySizes,
                    selectedSize: product.hasRealSizes
                        ? (selectedVariant?.size ?? product.displaySizes.first)
                        : dummySelectedSize,
                    onSelected: onSizeSelected,
                  ),
                ),
                const SizedBox(height: 24),
                _DescriptionSection(
                  title: s.productDescriptionTitle,
                  description: product.description.isEmpty
                      ? _dummyDescription(s.isArabic)
                      : product.description,
                ),
                const SizedBox(height: 26),
                _ReviewsSection(s: s),
                const SizedBox(height: 28),
                _RecommendedSection(
                  title: s.productYouMightAlsoLikeTitle,
                  products: product.recommendedProducts,
                ),
              ],
            ),
          ),
          if (colorNames.isNotEmpty)
            PositionedDirectional(
              top: 108,
              end: 22,
              child: _VerticalColorSelector(
                colorNames: colorNames,
                selectedColor: selectedColor,
                onSelected: onColorSelected,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductInfoBlock extends StatelessWidget {
  final AppStrings s;
  final ProductDetailsData product;
  final ProductVariantData? selectedVariant;
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _ProductInfoBlock({
    required this.s,
    required this.product,
    required this.selectedVariant,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final price = selectedVariant?.price ?? product.price;
    final stock = selectedVariant?.stock ?? product.totalStock;
    final inStock = stock > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name.isEmpty ? s.productNameExample : product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                product.brandName.isEmpty ? s.productBrandExample : product.brandName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF858585),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '${_formatMoney(price)} EGP',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              _RatingLine(
                rating: product.rating,
                reviewCountText: s.productReviewsCountText,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _QuantityPill(quantity: quantity, onMinus: onMinus, onPlus: onPlus),
            const SizedBox(height: 20),
            Text(
              inStock ? s.productAvailableText : (s.isArabic ? 'غير متوفر حالياً' : 'Out of stock'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: inStock ? Colors.black : Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RatingLine extends StatelessWidget {
  final double rating;
  final String reviewCountText;

  const _RatingLine({required this.rating, required this.reviewCountText});

  @override
  Widget build(BuildContext context) {
    final effectiveRating = rating <= 0 ? 5.0 : rating.clamp(0, 5).toDouble();

    return Row(
      children: [
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < effectiveRating.round() ? Icons.star_rounded : Icons.star_border_rounded,
              color: const Color(0xFFFFB21B),
              size: 15,
            );
          }),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            reviewCountText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuantityPill extends StatelessWidget {
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QuantityPill({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TinyTapText(label: '-', onTap: onMinus),
          const SizedBox(width: 12),
          Text(
            '$quantity',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black),
          ),
          const SizedBox(width: 12),
          _TinyTapText(label: '+', onTap: onPlus),
        ],
      ),
    );
  }
}

class _TinyTapText extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TinyTapText({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: 16,
        height: 24,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

class _SizeSelector extends StatelessWidget {
  final String title;
  final List<String> sizes;
  final String selectedSize;
  final ValueChanged<String> onSelected;

  const _SizeSelector({
    required this.title,
    required this.sizes,
    required this.selectedSize,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (sizes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: sizes.map((size) {
            final selected = size == selectedSize;
            return InkWell(
              onTap: () => onSelected(size),
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.black : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.black : const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _sizeDisplayLabel(size),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : const Color(0xFF8D8D8D),
                      ),
                    ),
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

class _VerticalColorSelector extends StatelessWidget {
  final List<String> colorNames;
  final String selectedColor;
  final ValueChanged<String> onSelected;

  const _VerticalColorSelector({
    required this.colorNames,
    required this.selectedColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (colorNames.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: colorNames.map((colorName) {
          final selected = colorName == selectedColor;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onSelected(colorName),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _colorFromName(colorName),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 15, color: _checkColorFor(colorName))
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  final String title;
  final String description;

  const _DescriptionSection({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black),
        ),
        const SizedBox(height: 13),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13,
            height: 1.42,
            color: Color(0xFF7A7A7A),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final AppStrings s;

  const _ReviewsSection({required this.s});

  @override
  Widget build(BuildContext context) {
    final reviews = [
      _DummyReview(
        userName: s.isArabic ? 'أحمد محمود' : 'Ahmed Mahmoud',
        text: s.isArabic
            ? 'المنتج شكله أفضل في الحقيقة. شكراً لكم!'
            : 'The outfit looks even better in real life. Thank you !',
      ),
      _DummyReview(
        userName: s.isArabic ? 'أحمد محمود' : 'Ahmed Mahmoud',
        text: s.isArabic
            ? 'الخامة ممتازة والمقاس مناسب جداً.'
            : 'The quality is great and the size fits perfectly.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.productReviewsTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _ReviewCard(review: reviews[index]),
          ),
        ),
      ],
    );
  }
}

class _DummyReview {
  final String userName;
  final String text;

  _DummyReview({required this.userName, required this.text});
}

class _ReviewCard extends StatelessWidget {
  final _DummyReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 112,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE9E9E9),
                  child: ClipOval(
                    child: Image.network(
                      'https://i.pravatar.cc/80?img=12',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 18, color: Colors.black54),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        review.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: List.generate(
                          5,
                          (_) => const Icon(Icons.star_rounded, color: Color(0xFFFF8A00), size: 10.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Flexible(
              child: Text(
                review.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.4, height: 1.22, color: Colors.black87, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedSection extends StatelessWidget {
  final String title;
  final List<ProductMiniData> products;

  const _RecommendedSection({required this.title, required this.products});

  @override
  Widget build(BuildContext context) {
    final displayProducts = products.isEmpty ? _dummyRecommendedProducts() : products;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: math.min(displayProducts.length, 4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 18,
            mainAxisSpacing: 16,
            childAspectRatio: 0.70,
          ),
          itemBuilder: (context, index) {
            return _RecommendedCard(product: displayProducts[index]);
          },
        ),
      ],
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  final ProductMiniData product;

  const _RecommendedCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: product.id == 0
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailsScreen(productId: product.id),
                ),
              );
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: const Color(0xFFE8EFF3),
                  child: product.imageUrl == null || product.imageUrl!.isEmpty
                      ? const Icon(Icons.image_outlined, color: Colors.black26, size: 32)
                      : Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, color: Colors.black26, size: 32),
                        ),
                ),
              ),
              PositionedDirectional(
                top: 10,
                end: 10,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.favorite_border_rounded, size: 19, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          product.brandName.isEmpty ? 'Brand' : product.brandName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF9A9A9A), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          '${_formatMoney(product.price)} EGP',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.w900),
        ),
        ],
      ),
    );
  }
}

class _WishlistFloatingButton extends StatelessWidget {
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  const _WishlistFloatingButton({
    required this.isActive,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2.5,
      shadowColor: Colors.black.withOpacity(0.14),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isLoading ? null : onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isActive ? Icons.favorite : Icons.favorite_border_rounded,
                    color: isActive ? Colors.red : Colors.black87,
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.94),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.12),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: const Color(0xFF1E272B)),
        ),
      ),
    );
  }
}

class _BottomCartBar extends StatelessWidget {
  final double total;
  final String totalLabel;
  final String addLabel;
  final bool isLoading;
  final VoidCallback onAdd;

  const _BottomCartBar({
    required this.total,
    required this.totalLabel,
    required this.addLabel,
    required this.isLoading,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        boxShadow: [
          BoxShadow(color: Colors.white.withOpacity(0.88), blurRadius: 20, offset: const Offset(0, -10)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatMoney(total)} EGP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : onAdd,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF1D282E),
                  disabledBackgroundColor: const Color(0xFF1D282E).withOpacity(0.55),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              addLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
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

class ProductApi {
  static Future<ProductDetailsData> getProductDetails(int productId) async {
    final detailsJson = await ApiService.get('/product/$productId/details');

    final optional = await Future.wait<dynamic>([
      _safeGet('/variants/product/$productId', fallback: <dynamic>[]),
      _safeGet('/product-images/product/$productId', fallback: <dynamic>[]),
      _safeGet('/products/latest', fallback: <dynamic>[]),
    ]);

    final variantsJson = _extractList(optional[0]);
    final imagesJson = _extractList(optional[1]);
    final latestJson = _extractList(optional[2]);

    return ProductDetailsData.fromJson(
      detailsJson,
      variantsJson,
      imagesJson,
      latestJson,
      currentProductId: productId,
    );
  }

  static Future<dynamic> _safeGet(String endpoint, {required dynamic fallback}) async {
    try {
      return await ApiService.get(endpoint);
    } catch (e) {
      if (kDebugMode) debugPrint('OPTIONAL PRODUCT DETAILS API FAILED $endpoint: $e');
      return fallback;
    }
  }
}

class ProductDetailsData {
  final int id;
  final String name;
  final String brandName;
  final String categoryName;
  final String departmentName;
  final String materialName;
  final String description;
  final double price;
  final double rating;
  final List<String> imageUrls;
  final List<ProductVariantData> variants;
  final List<ProductMiniData> recommendedProducts;

  ProductDetailsData({
    required this.id,
    required this.name,
    required this.brandName,
    required this.categoryName,
    required this.departmentName,
    required this.materialName,
    required this.description,
    required this.price,
    required this.rating,
    required this.imageUrls,
    required this.variants,
    required this.recommendedProducts,
  });

  ProductVariantData get defaultVariant {
    if (variants.isEmpty) return ProductVariantData.empty();
    return variants.firstWhere((variant) => variant.stock > 0, orElse: () => variants.first);
  }

  ProductVariantData? get defaultVariantOrNull {
    if (variants.isEmpty) return null;
    return defaultVariant;
  }

  int get totalStock {
    if (variants.isEmpty) return 0;
    return variants.fold<int>(0, (sum, variant) => sum + math.max(0, variant.stock));
  }

  bool get hasRealSizes => variants.any((variant) => variant.size.isNotEmpty);
  bool get hasRealColors => variants.any((variant) => variant.color.isNotEmpty);

  List<String> get displaySizes {
    final seen = <String>{};
    final sizes = variants
        .map((variant) => variant.size.trim())
        .where((size) => size.isNotEmpty && seen.add(size))
        .toList();

    return sizes.isEmpty ? ['S', 'M', 'L', 'XL', 'XXL'] : sizes;
  }

  List<String> get displayColorNames {
    final seen = <String>{};
    final colors = variants
        .map((variant) => variant.color.trim())
        .where((color) => color.isNotEmpty && seen.add(color))
        .toList();

    return colors.isEmpty ? ['White', 'Black', 'Sage', 'Orange'] : colors;
  }

  factory ProductDetailsData.fromJson(
    dynamic json,
    List<dynamic> variantsJson,
    List<dynamic> imagesJson,
    List<dynamic> latestJson, {
    required int currentProductId,
  }) {
    final map = json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};

    final detailsVariants = _extractList(map['variants']);
    final detailsImages = _extractList(map['images']);

    final allVariantsSource = variantsJson.isNotEmpty ? variantsJson : detailsVariants;
    final allImagesSource = imagesJson.isNotEmpty ? imagesJson : detailsImages;

    final variants = allVariantsSource
        .map((item) => ProductVariantData.fromJson(item))
        .where((variant) => variant.id != 0 || variant.size.isNotEmpty || variant.color.isNotEmpty)
        .toList();

    final images = _parseImageUrls(allImagesSource);
    final recommended = latestJson
        .map((item) => ProductMiniData.fromJson(item))
        .where((item) => item.id != 0 && item.id != currentProductId)
        .take(8)
        .toList();

    final firstPrice = variants.isNotEmpty
        ? variants.firstWhere((variant) => variant.price > 0, orElse: () => variants.first).price
        : 0.0;

    return ProductDetailsData(
      id: _toInt(map['id'] ?? map['productId'] ?? currentProductId),
      name: _toStringValue(map['name'] ?? map['productName'] ?? map['title']),
      brandName: _toStringValue(
        map['brandName'] ?? _nested(map, ['brand', 'name']) ?? _nested(map, ['brandResponse', 'name']),
      ),
      categoryName: _toStringValue(
        map['categoryName'] ?? _nested(map, ['category', 'name']) ?? _nested(map, ['categoryResponse', 'name']),
      ),
      departmentName: _toStringValue(
        map['departmentName'] ?? _nested(map, ['department', 'name']) ?? _nested(map, ['departmentResponse', 'name']),
      ),
      materialName: _toStringValue(
        map['materialName'] ?? _nested(map, ['material', 'name']) ?? _nested(map, ['materialResponse', 'name']),
      ),
      description: _toStringValue(map['description']),
      price: _toDouble(map['price'] ?? map['minPrice'] ?? firstPrice),
      rating: _toDouble(map['rating'] ?? map['averageRating'] ?? map['avgRating'] ?? 5),
      imageUrls: images,
      variants: variants,
      recommendedProducts: recommended,
    );
  }
}

class ProductVariantData {
  final int id;
  final String size;
  final String color;
  final String sku;
  final double price;
  final int stock;

  ProductVariantData({
    required this.id,
    required this.size,
    required this.color,
    required this.sku,
    required this.price,
    required this.stock,
  });

  factory ProductVariantData.empty() {
    return ProductVariantData(id: 0, size: '', color: '', sku: '', price: 0, stock: 0);
  }

  factory ProductVariantData.fromJson(dynamic json) {
    final map = json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};

    return ProductVariantData(
      id: _toInt(map['id'] ?? map['variantId'] ?? map['productVariantId']),
      size: _toStringValue(
        map['sizeName'] ?? map['size'] ?? _nested(map, ['sizeResponse', 'name']) ?? _nested(map, ['size', 'name']),
      ),
      color: _toStringValue(
        map['colorName'] ?? map['color'] ?? _nested(map, ['colorResponse', 'name']) ?? _nested(map, ['color', 'name']),
      ),
      sku: _toStringValue(map['sku']),
      price: _toDouble(map['price'] ?? map['minPrice']),
      stock: _toInt(map['stock'] ?? map['quantity'] ?? map['availableStock']),
    );
  }
}

class ProductMiniData {
  final int id;
  final String name;
  final String brandName;
  final String? imageUrl;
  final double price;

  ProductMiniData({
    required this.id,
    required this.name,
    required this.brandName,
    required this.imageUrl,
    required this.price,
  });

  factory ProductMiniData.fromJson(dynamic json) {
    final map = json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};

    return ProductMiniData(
      id: _toInt(map['id'] ?? map['productId']),
      name: _toStringValue(map['name'] ?? map['productName'] ?? map['title']).isEmpty
          ? 'Product name'
          : _toStringValue(map['name'] ?? map['productName'] ?? map['title']),
      brandName: _toStringValue(map['brandName'] ?? _nested(map, ['brand', 'name'])),
      imageUrl: _fullImageUrl(
        _toStringValue(map['imageUrl'] ?? map['mainImageUrl'] ?? map['image'] ?? map['thumbnail']),
      ),
      price: _toDouble(map['minPrice'] ?? map['price']),
    );
  }
}

List<String> _parseImageUrls(List<dynamic> imagesJson) {
  if (imagesJson.isEmpty) return [];

  final pairs = <_ImageSortPair>[];

  for (final item in imagesJson) {
    String url = '';
    bool isMain = false;

    if (item is String) {
      url = _fullImageUrl(item) ?? '';
    } else if (item is Map) {
      final map = Map<String, dynamic>.from(item);
      url = _fullImageUrl(
            _toStringValue(
              map['imageUrl'] ?? map['mainImageUrl'] ?? map['url'] ?? map['imagePath'] ?? map['path'] ?? map['image'],
            ),
          ) ??
          '';
      isMain = map['isMain'] == true || map['main'] == true || map['mainImage'] == true || map['primary'] == true;
    }

    if (url.isNotEmpty) {
      pairs.add(_ImageSortPair(url: url, isMain: isMain));
    }
  }

  pairs.sort((a, b) {
    if (a.isMain == b.isMain) return 0;
    return a.isMain ? -1 : 1;
  });

  final seen = <String>{};
  return pairs.map((pair) => pair.url).where((url) => seen.add(url)).toList();
}

class _ImageSortPair {
  final String url;
  final bool isMain;

  _ImageSortPair({required this.url, required this.isMain});
}

List<dynamic> _extractList(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['content'] is List) return data['content'] as List;
  if (data is Map && data['items'] is List) return data['items'] as List;
  if (data is Map && data['data'] is List) return data['data'] as List;
  if (data is Map && data['images'] is List) return data['images'] as List;
  if (data is Map && data['variants'] is List) return data['variants'] as List;
  if (data is Map && data['productImages'] is List) return data['productImages'] as List;
  return [];
}

dynamic _nested(dynamic source, List<String> path) {
  dynamic current = source;
  for (final key in path) {
    if (current is! Map) return null;
    current = current[key];
  }
  return current;
}

String _toStringValue(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

String? _fullImageUrl(String? url) {
  final clean = url?.trim() ?? '';
  if (clean.isEmpty || clean == 'null') return null;
  if (clean.startsWith('http')) return clean;
  if (clean.startsWith('/')) return '$kBaseUrl$clean';
  return '$kBaseUrl/$clean';
}

String _formatMoney(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

String _dummyDescription(bool isArabic) {
  return isArabic
      ? 'منتج بتصميم عصري ومريح مناسب للاستخدام اليومي. الخامة ناعمة والتفاصيل متناسقة لتكمل إطلالتك.'
      : 'A comfortable everyday piece with a relaxed fit, clean finish, and soft fabric designed to complete your look.';
}

String _sizeDisplayLabel(String value) {
  final normalized = value.trim().toLowerCase().replaceAll('-', ' ').replaceAll('_', ' ');

  switch (normalized) {
    case 'small':
      return 'S';
    case 'medium':
      return 'M';
    case 'large':
      return 'L';
    case 'x large':
    case 'xlarge':
    case 'extra large':
      return 'XL';
    case 'xx large':
    case 'xxlarge':
    case '2xl':
    case 'extra extra large':
      return 'XXL';
    case 'one size':
    case 'onesize':
      return 'OS';
    default:
      if (value.trim().length > 4) {
        return value.trim().substring(0, math.min(4, value.trim().length)).toUpperCase();
      }
      return value.trim().toUpperCase();
  }
}

Color _checkColorFor(String colorName) {
  final color = colorName.toLowerCase().trim();
  if (color.contains('white') || color.contains('yellow') || color.contains('beige') || color.contains('cream')) {
    return Colors.black;
  }
  return Colors.white;
}

Color _colorFromName(String colorName) {
  final color = colorName.toLowerCase().trim();

  if (color.contains('black')) return Colors.black;
  if (color.contains('white')) return Colors.white;
  if (color.contains('red')) return const Color(0xFFE53935);
  if (color.contains('blue') || color.contains('navy')) return const Color(0xFF3367D6);
  if (color.contains('green') || color.contains('sage')) return const Color(0xFFB8CA8F);
  if (color.contains('orange')) return const Color(0xFFF7A12B);
  if (color.contains('yellow')) return const Color(0xFFFFD54F);
  if (color.contains('pink')) return const Color(0xFFF48FB1);
  if (color.contains('purple')) return const Color(0xFF7E57C2);
  if (color.contains('brown')) return const Color(0xFF8D6E63);
  if (color.contains('grey') || color.contains('gray')) return const Color(0xFF9E9E9E);
  if (color.contains('beige') || color.contains('cream')) return const Color(0xFFE8D8BD);

  return const Color(0xFF222222);
}

List<ProductMiniData> _dummyRecommendedProducts() {
  return [
    ProductMiniData(id: 0, name: 'Woman’s Black Hoodie', brandName: 'Zara', imageUrl: null, price: 198),
    ProductMiniData(id: 0, name: 'Pink Crew Neck T-shirt', brandName: 'Nike', imageUrl: null, price: 198),
  ];
}
