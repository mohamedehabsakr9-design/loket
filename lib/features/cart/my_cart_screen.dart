import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../services/api_service.dart';
import '../../widgets/lokit_bottom_nav_bar.dart';
import '../payment/payment_screen.dart';
import '../products/product_details_screen.dart';

const String kBaseUrl = 'https://lokit-production.up.railway.app';

class MyCartScreen extends StatefulWidget {
  const MyCartScreen({super.key});

  @override
  State<MyCartScreen> createState() => _MyCartScreenState();
}

class _MyCartScreenState extends State<MyCartScreen> {
  bool _loading = true;
  String? _error;
  List<CartItemUiData> _items = [];
  double _serverTotal = 0;
  final Set<int> _processingItemIds = {};
  final TextEditingController _promoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  String _msg({required String ar, required String en}) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic ? ar : en;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      ),
    );
  }

  Future<void> _loadCart() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final cartResponse = await ApiService.get('/cart', withAuth: true);
      final rawItems = _extractItems(cartResponse);
      final baseItems = rawItems.map(CartItemUiData.fromJson).toList();
      final totalFromApi = _toDouble(_read(cartResponse, 'total'));

      final enrichedItems = await _enrichCartItems(baseItems);

      if (!mounted) return;

      setState(() {
        _items = enrichedItems;
        _serverTotal = totalFromApi;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<List<CartItemUiData>> _enrichCartItems(
    List<CartItemUiData> items,
  ) async {
    if (items.isEmpty) return items;

    try {
      final productsResponse = await ApiService.get('/products/search');
      final products = _extractItems(productsResponse)
          .map(ProductLookupData.fromJson)
          .where((product) => product.id != 0)
          .toList();

      final byName = <String, ProductLookupData>{};

      for (final product in products) {
        final key = _normalize(product.name);
        if (key.isNotEmpty) {
          byName.putIfAbsent(key, () => product);
        }
      }

      final enriched = <CartItemUiData>[];

      for (final item in items) {
        final product = byName[_normalize(item.productName)];

        var updated = item.copyWith(
          productId: item.productId == 0 ? product?.id : item.productId,
          brandName:
              item.brandName.isEmpty ? (product?.brandName ?? '') : item.brandName,
          imageUrl:
              item.imageUrl.isEmpty ? (product?.imageUrl ?? '') : item.imageUrl,
        );

        if (updated.imageUrl.isEmpty && updated.productId != 0) {
          final imageUrl = await _loadProductMainImage(updated.productId);
          if (imageUrl.isNotEmpty) {
            updated = updated.copyWith(imageUrl: imageUrl);
          }
        }

        enriched.add(updated);
      }

      return enriched;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CART ENRICH FAILED: $e');
      }

      return items;
    }
  }

  Future<String> _loadProductMainImage(int productId) async {
    try {
      final response = await ApiService.get('/product-images/product/$productId');
      final images = _extractItems(response);

      if (images.isEmpty) return '';

      final main = images.firstWhere(
        (image) =>
            image is Map &&
            (image['isMain'] == true ||
                image['main'] == true ||
                image['primary'] == true),
        orElse: () => images.first,
      );

      if (main is String) return _fullImageUrl(main);

      if (main is Map) {
        return _fullImageUrl(
          _toText(
            main['imageUrl'] ??
                main['mainImageUrl'] ??
                main['url'] ??
                main['imagePath'] ??
                main['path'] ??
                main['image'],
          ),
        );
      }
    } catch (_) {
      // Image is optional.
    }

    return '';
  }

  double get _totalPrice {
    if (_serverTotal > 0) return _serverTotal;

    return _items.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );
  }

  int get _totalItemsCount {
    return _items.fold<int>(
      0,
      (sum, item) => sum + math.max(0, item.quantity),
    );
  }

  Future<void> _updateQuantity(CartItemUiData item, int nextQuantity) async {
    if (nextQuantity < 1) return;
    if (_processingItemIds.contains(item.id)) return;

    setState(() => _processingItemIds.add(item.id));

    try {
      final response = await ApiService.put(
        '/cart/items/${item.id}',
        body: {'quantity': nextQuantity},
        withAuth: true,
      );

      if (!mounted) return;

      final totalFromApi = _toDouble(_read(response, 'total'));

      setState(() {
        _serverTotal = totalFromApi > 0 ? totalFromApi : _serverTotal;
        _items = _items.map((current) {
          if (current.id != item.id) return current;
          return current.copyWith(quantity: nextQuantity);
        }).toList();
      });
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _processingItemIds.remove(item.id));
      }
    }
  }

  Future<bool> _deleteItem(CartItemUiData item) async {
    if (item.id == 0) {
      _showMessage(
        _msg(ar: 'لم يتم العثور على عنصر السلة', en: 'Cart item id not found'),
        isError: true,
      );
      return false;
    }

    if (_processingItemIds.contains(item.id)) return false;

    setState(() => _processingItemIds.add(item.id));

    try {
      final response = await ApiService.delete(
        '/cart/items/${item.id}',
        withAuth: true,
      );

      final totalFromApi = _toDouble(_read(response, 'total'));

      if (mounted && totalFromApi > 0) {
        setState(() => _serverTotal = totalFromApi);
      }

      _showMessage(_msg(ar: 'تم حذف المنتج من السلة', en: 'Removed from cart'));
      return true;
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _processingItemIds.remove(item.id));
      }
    }
  }

  void _removeLocalItem(CartItemUiData item) {
    setState(() {
      _items.removeWhere((element) => element.id == item.id);
      if (_items.isEmpty) _serverTotal = 0;
    });
  }

  void _applyPromoCode() {
    final code = _promoController.text.trim();

    if (code.isEmpty) {
      _showMessage(
        _msg(ar: 'اكتب كود الخصم أولاً', en: 'Enter promo code first'),
      );
      return;
    }

    _showMessage(
      _msg(
        ar: 'كود الخصم غير متاح حالياً',
        en: 'Promo code is not available yet',
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            s.cartTitle,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadCart,
          child: _buildBody(s),
        ),
        bottomNavigationBar: const LokitBottomNavBar(
          currentTab: LokitBottomTab.cart,
        ),
      ),
    );
  }

  Widget _buildBody(AppStrings s) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 110, 24, 24),
        children: [
          const Icon(Icons.error_outline_rounded, size: 46, color: Colors.red),
          const SizedBox(height: 12),
          Center(
            child: Text(
              s.isArabic ? 'فشل تحميل السلة' : 'Failed to load cart',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _loadCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D282E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(s.isArabic ? 'حاول مرة أخرى' : 'Try again'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        children: [
          const _CheckoutStepsHeader(),
          const SizedBox(height: 110),
          Center(
            child: Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F4),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.black38,
                size: 42,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              s.isArabic ? 'السلة فاضية' : 'Your cart is empty',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              s.isArabic
                  ? 'ضيف منتجات للسلة وهتظهر هنا'
                  : 'Add products to cart and they will appear here',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 14),
          child: _CheckoutStepsHeader(),
        ),
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
            itemCount: _items.length + 1,
            itemBuilder: (context, index) {
              if (index == _items.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: _PromoCodeBox(
                    controller: _promoController,
                    hint: s.cartPromoHint,
                    applyLabel: s.cartApplyButton,
                    onApply: _applyPromoCode,
                  ),
                );
              }

              final item = _items[index];
              final isProcessing = _processingItemIds.contains(item.id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _SwipeToDeleteCartItem(
                  item: item,
                  isProcessing: isProcessing,
                  onDismissed: () => _removeLocalItem(item),
                  confirmDismiss: () => _deleteItem(item),
                  onDeleteTap: () async {
                    final ok = await _deleteItem(item);
                    if (ok && mounted) _removeLocalItem(item);
                  },
                  onMinus: () => _updateQuantity(item, item.quantity - 1),
                  onPlus: () => _updateQuantity(item, item.quantity + 1),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: _CartSummaryAndCheckout(
            totalLabel: s.cartTotalLabel,
            itemCount: _totalItemsCount,
            total: _totalPrice,
            buttonLabel: s.cartProceedButton,
            onCheckout: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentScreen()),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CheckoutStepsHeader extends StatelessWidget {
  const _CheckoutStepsHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          const _StepCircle(number: '1', isActive: true),
          const SizedBox(width: 12),
          Expanded(
            child: CustomPaint(
              painter: _DashedLinePainter(),
              child: const SizedBox(height: 1),
            ),
          ),
          const SizedBox(width: 12),
          const _StepCircle(number: '2', isActive: false),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final String number;
  final bool isActive;

  const _StepCircle({
    required this.number,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1D282E) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? const Color(0xFF1D282E) : Colors.black,
          width: 1.2,
        ),
      ),
      child: Text(
        number,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.black,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9C9C9)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    const dashWidth = 4.0;
    const dashGap = 4.0;
    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, size.width), y),
        paint,
      );
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SwipeToDeleteCartItem extends StatelessWidget {
  final CartItemUiData item;
  final bool isProcessing;
  final VoidCallback onDismissed;
  final Future<bool> Function() confirmDismiss;
  final Future<void> Function() onDeleteTap;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _SwipeToDeleteCartItem({
    required this.item,
    required this.isProcessing,
    required this.onDismissed,
    required this.confirmDismiss,
    required this.onDeleteTap,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('cart_item_${item.id}_${item.variantId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDismiss(),
      onDismissed: (_) => onDismissed(),
      background: Container(
        height: 104,
        alignment: Alignment.centerRight,
        padding: const EdgeInsetsDirectional.only(end: 28),
        decoration: BoxDecoration(
          color: const Color(0xFF1D282E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
      child: _CartProductCard(
        item: item,
        isProcessing: isProcessing,
        onDeleteTap: onDeleteTap,
        onMinus: onMinus,
        onPlus: onPlus,
      ),
    );
  }
}

class _CartProductCard extends StatelessWidget {
  final CartItemUiData item;
  final bool isProcessing;
  final Future<void> Function() onDeleteTap;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _CartProductCard({
    required this.item,
    required this.isProcessing,
    required this.onDeleteTap,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: item.productId == 0
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailsScreen(
                    productId: item.productId,
                  ),
                ),
              );
            },
      child: Container(
        height: 104,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: 78,
                height: 78,
                child: item.imageUrl.isEmpty
                    ? _CartImagePlaceholder(productName: item.productName)
                    : Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return _CartImagePlaceholder(
                            productName: item.productName,
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.productName.isEmpty ? 'Product' : item.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.1,
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.brandName.isEmpty ? 'Brand' : item.brandName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (_) => const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFA500),
                            size: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Flexible(
                        child: Text(
                          '(320 Review)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_formatMoney(item.unitPrice)} EGP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _QuantityPill(
                  quantity: item.quantity,
                  isLoading: isProcessing,
                  onMinus: onMinus,
                  onPlus: onPlus,
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: isProcessing ? null : onDeleteTap,
                  child: SizedBox(
                    width: 32,
                    height: 26,
                    child: isProcessing
                        ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Color(0xFF1D282E),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartImagePlaceholder extends StatelessWidget {
  final String productName;

  const _CartImagePlaceholder({required this.productName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE9EFF2),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: Colors.black26,
        size: 28,
      ),
    );
  }
}

class _QuantityPill extends StatelessWidget {
  final int quantity;
  final bool isLoading;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QuantityPill({
    required this.quantity,
    required this.isLoading,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      constraints: const BoxConstraints(minWidth: 70),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: isLoading
          ? const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QtyButton(label: '-', onTap: quantity <= 1 ? null : onMinus),
                const SizedBox(width: 10),
                Text(
                  '$quantity',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                _QtyButton(label: '+', onTap: onPlus),
              ],
            ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _QtyButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 12,
        height: 24,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: onTap == null ? Colors.black26 : Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoCodeBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String applyLabel;
  final VoidCallback onApply;

  const _PromoCodeBox({
    required this.controller,
    required this.hint,
    required this.applyLabel,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFF1D282E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: Text(
                applyLabel.toLowerCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartSummaryAndCheckout extends StatelessWidget {
  final String totalLabel;
  final int itemCount;
  final double total;
  final String buttonLabel;
  final VoidCallback onCheckout;

  const _CartSummaryAndCheckout({
    required this.totalLabel,
    required this.itemCount,
    required this.total,
    required this.buttonLabel,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final itemWord = itemCount == 1 ? 'item' : 'items';

    return Column(
      children: [
        Row(
          children: [
            Text(
              isArabic
                  ? '$totalLabel ($itemCount منتج) :'
                  : '$totalLabel ($itemCount $itemWord) :',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF676767),
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${_formatMoney(total)} EGP',
              style: const TextStyle(
                fontSize: 21,
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onCheckout,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF1D282E),
              foregroundColor: Colors.white,
              padding: const EdgeInsetsDirectional.only(start: 20, end: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    buttonLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF1D282E),
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CartItemUiData {
  final int id;
  final int variantId;
  final int productId;
  final String productName;
  final String brandName;
  final String sizeName;
  final String colorName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String imageUrl;

  const CartItemUiData({
    required this.id,
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.brandName,
    required this.sizeName,
    required this.colorName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.imageUrl,
  });

  factory CartItemUiData.fromJson(dynamic json) {
    final item = json is Map ? json : <String, dynamic>{};
    final product = _readMap(item, 'product');
    final variant = _readMap(item, 'variant') ?? _readMap(item, 'productVariant');

    final qty = _toInt(item['quantity'] ?? item['qty'], fallback: 1);
    final unitPrice = _toDouble(
      item['unitPrice'] ?? item['price'] ?? variant?['price'] ?? product?['price'],
    );
    final lineTotal = _toDouble(item['lineTotal'] ?? item['totalPrice']);

    return CartItemUiData(
      id: _toInt(item['id'] ?? item['cartItemId'] ?? item['itemId']),
      variantId: _toInt(
        item['variantId'] ??
            item['productVariantId'] ??
            variant?['id'] ??
            variant?['variantId'],
      ),
      productId: _toInt(
        item['productId'] ??
            product?['id'] ??
            product?['productId'] ??
            variant?['productId'],
      ),
      productName: _firstText([
        item['productName'],
        item['name'],
        product?['name'],
        product?['productName'],
        variant?['productName'],
      ], fallback: 'Product'),
      brandName: _firstText([
        item['brandName'],
        product?['brandName'],
        _nested(product, ['brand', 'name']),
        _nested(product, ['brandResponse', 'name']),
      ]),
      sizeName: _firstText([
        item['sizeName'],
        item['size'],
        variant?['sizeName'],
        variant?['size'],
        _nested(variant, ['size', 'name']),
      ]),
      colorName: _firstText([
        item['colorName'],
        item['color'],
        variant?['colorName'],
        variant?['color'],
        _nested(variant, ['color', 'name']),
      ]),
      quantity: qty,
      unitPrice: unitPrice,
      lineTotal: lineTotal > 0 ? lineTotal : unitPrice * qty,
      imageUrl: _fullImageUrl(
        _firstText([
          item['imageUrl'],
          item['productImage'],
          item['image'],
          item['thumbnail'],
          product?['imageUrl'],
          product?['mainImageUrl'],
          product?['image'],
          product?['thumbnail'],
        ]),
      ),
    );
  }

  CartItemUiData copyWith({
    int? id,
    int? variantId,
    int? productId,
    String? productName,
    String? brandName,
    String? sizeName,
    String? colorName,
    int? quantity,
    double? unitPrice,
    double? lineTotal,
    String? imageUrl,
  }) {
    final nextQuantity = quantity ?? this.quantity;
    final nextUnitPrice = unitPrice ?? this.unitPrice;

    return CartItemUiData(
      id: id ?? this.id,
      variantId: variantId ?? this.variantId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      brandName: brandName ?? this.brandName,
      sizeName: sizeName ?? this.sizeName,
      colorName: colorName ?? this.colorName,
      quantity: nextQuantity,
      unitPrice: nextUnitPrice,
      lineTotal: lineTotal ?? nextUnitPrice * nextQuantity,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class ProductLookupData {
  final int id;
  final String name;
  final String brandName;
  final String imageUrl;

  const ProductLookupData({
    required this.id,
    required this.name,
    required this.brandName,
    required this.imageUrl,
  });

  factory ProductLookupData.fromJson(dynamic json) {
    final map = json is Map ? json : <String, dynamic>{};

    return ProductLookupData(
      id: _toInt(map['id'] ?? map['productId']),
      name: _firstText([map['name'], map['productName'], map['title']]),
      brandName: _firstText([
        map['brandName'],
        _nested(map, ['brand', 'name']),
        _nested(map, ['brandResponse', 'name']),
      ]),
      imageUrl: _fullImageUrl(
        _firstText([
          map['imageUrl'],
          map['mainImageUrl'],
          map['image'],
          map['thumbnail'],
        ]),
      ),
    );
  }
}

List<dynamic> _extractItems(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['items'] is List) return data['items'] as List;
  if (data is Map && data['cartItems'] is List) return data['cartItems'] as List;
  if (data is Map && data['content'] is List) return data['content'] as List;
  if (data is Map && data['data'] is List) return data['data'] as List;
  if (data is Map && data['products'] is List) return data['products'] as List;
  return [];
}

dynamic _read(dynamic source, String key) {
  return source is Map ? source[key] : null;
}

Map? _readMap(dynamic source, String key) {
  if (source is Map && source[key] is Map) return source[key] as Map;
  return null;
}

dynamic _nested(dynamic source, List<String> path) {
  dynamic current = source;

  for (final key in path) {
    if (current is! Map) return null;
    current = current[key];
  }

  return current;
}

String _firstText(List<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = _toText(value);
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _toText(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null') return '';
  return text;
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

String _fullImageUrl(String url) {
  final clean = url.trim();
  if (clean.isEmpty || clean == 'null') return '';
  if (clean.startsWith('http')) return clean;
  if (clean.startsWith('/')) return '$kBaseUrl$clean';
  return '$kBaseUrl/$clean';
}

String _normalize(String value) {
  return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _formatMoney(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}