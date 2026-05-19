import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../services/api_service.dart';
import '../orders/my_orders_screen.dart';

const String kBaseUrl = 'https://lokit-production.up.railway.app';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = true;
  bool _isConfirming = false;
  String? _error;

  List<_PaymentCartItem> _items = [];
  double _cartTotalFromServer = 0;

  String _paymentMethod = 'CASH';

  final fullNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final postalCtrl = TextEditingController();

  final cardNumberCtrl = TextEditingController();
  final expCtrl = TextEditingController();
  final cvvCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPaymentData();
  }

  @override
  void dispose() {
    fullNameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    cityCtrl.dispose();
    postalCtrl.dispose();
    cardNumberCtrl.dispose();
    expCtrl.dispose();
    cvvCtrl.dispose();
    super.dispose();
  }

  String _msg({required String ar, required String en}) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic ? ar : en;
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      ),
    );
  }

  Future<void> _loadPaymentData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        ApiService.get('/cart', withAuth: true),
        _safeGet('/account'),
        _safeGet('/addresses'),
      ]);

      final cartResponse = results[0];
      final accountResponse = results[1];
      final addressesResponse = results[2];

      final rawItems = _extractList(cartResponse)
          .map(_PaymentCartItem.fromJson)
          .toList();

      final enrichedItems = await _enrichCartItems(rawItems);
      final serverTotal = _toDouble(_read(cartResponse, 'total'));

      _prefillAccount(accountResponse);
      _prefillAddress(addressesResponse);

      if (!mounted) return;
      setState(() {
        _items = enrichedItems;
        _cartTotalFromServer = serverTotal;
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

  Future<dynamic> _safeGet(String endpoint) async {
    try {
      return await ApiService.get(endpoint, withAuth: true);
    } catch (e) {
      if (kDebugMode) debugPrint('PAYMENT OPTIONAL GET FAILED $endpoint: $e');
      return null;
    }
  }

  void _prefillAccount(dynamic data) {
    if (data is! Map) return;

    final firstName = _text(data['firstName']);
    final lastName = _text(data['lastName']);
    final name = _text(data['name']);
    final phone = _text(data['phone']);

    if (fullNameCtrl.text.trim().isEmpty) {
      fullNameCtrl.text = name.isNotEmpty ? name : '$firstName $lastName'.trim();
    }

    if (phoneCtrl.text.trim().isEmpty && phone.isNotEmpty) {
      phoneCtrl.text = phone;
    }
  }

  void _prefillAddress(dynamic data) {
    final list = _extractList(data);
    if (list.isEmpty || list.first is! Map) return;

    final address = list.first as Map;
    final street = _text(address['street']);
    final city = _text(address['city']);
    final zip = _text(address['zipCode'] ?? address['postalCode']);

    if (addressCtrl.text.trim().isEmpty && street.isNotEmpty) {
      addressCtrl.text = street;
    }

    if (cityCtrl.text.trim().isEmpty && city.isNotEmpty) {
      cityCtrl.text = city;
    }

    if (postalCtrl.text.trim().isEmpty && zip.isNotEmpty) {
      postalCtrl.text = zip;
    }
  }

  Future<List<_PaymentCartItem>> _enrichCartItems(
    List<_PaymentCartItem> items,
  ) async {
    if (items.isEmpty) return items;

    try {
      final productsResponse = await ApiService.get('/products/search');
      final products = _extractList(productsResponse)
          .map(_ProductLookup.fromJson)
          .where((product) => product.id != 0)
          .toList();

      final byName = <String, _ProductLookup>{};
      for (final product in products) {
        final key = _normalize(product.name);
        if (key.isNotEmpty) byName.putIfAbsent(key, () => product);
      }

      final enriched = <_PaymentCartItem>[];

      for (final item in items) {
        final product = byName[_normalize(item.productName)];
        var next = item.copyWith(
          productId: item.productId == 0 ? product?.id : item.productId,
          brandName: item.brandName.isEmpty
              ? (product?.brandName ?? '')
              : item.brandName,
          imageUrl: item.imageUrl.isEmpty ? (product?.imageUrl ?? '') : item.imageUrl,
        );

        if (next.imageUrl.isEmpty && next.productId != 0) {
          final imageUrl = await _loadProductMainImage(next.productId);
          if (imageUrl.isNotEmpty) next = next.copyWith(imageUrl: imageUrl);
        }

        enriched.add(next);
      }

      return enriched;
    } catch (e) {
      if (kDebugMode) debugPrint('PAYMENT CART ENRICH FAILED: $e');
      return items;
    }
  }

  Future<String> _loadProductMainImage(int productId) async {
    try {
      final response = await ApiService.get('/product-images/product/$productId');
      final images = _extractList(response);

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
          _text(
            main['imageUrl'] ??
                main['mainImageUrl'] ??
                main['url'] ??
                main['imagePath'] ??
                main['path'] ??
                main['image'],
          ),
        );
      }
    } catch (_) {}

    return '';
  }

  double get _subTotal {
    if (_cartTotalFromServer > 0) return _cartTotalFromServer;
    return _items.fold<double>(0, (sum, item) => sum + item.lineTotal);
  }

  double get _shippingTotal => 0;
  double get _total => _subTotal + _shippingTotal;

  int get _totalItemsCount {
    return _items.fold<int>(0, (sum, item) => sum + math.max(0, item.quantity));
  }

  Future<void> _confirmOrder(AppStrings s) async {
    final fullName = fullNameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final address = addressCtrl.text.trim();
    final city = cityCtrl.text.trim();
    final postal = postalCtrl.text.trim();

    if (_items.isEmpty) {
      _showMsg(_msg(ar: 'السلة فاضية', en: 'Cart is empty'), isError: true);
      return;
    }

    if (fullName.isEmpty || phone.isEmpty || address.isEmpty || city.isEmpty) {
      _showMsg(
        _msg(
          ar: 'من فضلك املأ بيانات التوصيل الأساسية',
          en: 'Please fill the required delivery information',
        ),
        isError: true,
      );
      return;
    }

    if (_paymentMethod == 'CARD') {
      if (cardNumberCtrl.text.trim().isEmpty ||
          expCtrl.text.trim().isEmpty ||
          cvvCtrl.text.trim().isEmpty) {
        _showMsg(
          _msg(ar: 'من فضلك املأ بيانات البطاقة', en: 'Please fill card details'),
          isError: true,
        );
        return;
      }
    }

    setState(() => _isConfirming = true);

    try {
      final addressBody = <String, dynamic>{
        'country': 'Egypt',
        'city': city,
        'street': address,
        'zipCode': postal.isEmpty ? null : postal,
        'governorate': city,
      }..removeWhere((_, value) => value == null);

      if (kDebugMode) debugPrint('CREATE ADDRESS BODY: $addressBody');

      final addressResponse = await ApiService.post(
        '/addresses',
        body: addressBody,
        withAuth: true,
      );

      final addressId = _extractId(addressResponse);
      if (addressId == 0) {
        throw Exception('Could not create address');
      }

      final checkoutBody = <String, dynamic>{
        'addressId': addressId,
        'notes': 'Payment method: $_paymentMethod | Name: $fullName | Phone: $phone',
      };

      if (kDebugMode) debugPrint('CHECKOUT BODY: $checkoutBody');

      final checkoutResponse = await ApiService.post(
        '/checkout',
        body: checkoutBody,
        withAuth: true,
      );

      if (!mounted) return;

      final orderId = _extractOrderId(checkoutResponse);
      final confirmed = await showOrderConfirmedDialog(
        context,
        s,
        orderId: orderId,
      );

      if (!mounted) return;

      if (confirmed == true) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
          (route) => false,
        );
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      _showMsg(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  int _extractId(dynamic data) {
    if (data is! Map) return 0;

    final id = data['id'] ?? data['addressId'] ?? data['data']?['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse(id?.toString() ?? '') ?? 0;
  }

  String _extractOrderId(dynamic data) {
    if (data is Map) {
      final nested = data['data'];
      final id = data['id'] ??
          data['orderId'] ??
          data['orderNumber'] ??
          (nested is Map ? nested['id'] ?? nested['orderId'] : null);

      if (id != null) {
        final text = id.toString();
        return text.startsWith('#') ? text : '#$text';
      }
    }

    return '#ORDER';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isLoading
            ? _LoadingPaymentView(onBack: () => Navigator.pop(context))
            : _error != null
                ? _ErrorPaymentView(
                    message: _error!,
                    onBack: () => Navigator.pop(context),
                    onRetry: _loadPaymentData,
                  )
                : SafeArea(
                    child: Column(
                      children: [
                        _PaymentHeader(
                          title: s.paymentTitle,
                          onBack: _isConfirming ? null : () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadPaymentData,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(24, 10, 24, 26),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _PaymentStepsHeader(),
                                  const SizedBox(height: 26),
                                  _SectionTitle(s.paymentOrderSummary),
                                  const SizedBox(height: 14),
                                  if (_items.isEmpty)
                                    _EmptyCartSummary(isArabic: s.isArabic)
                                  else ...[
                                    ..._items.map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.only(bottom: 18),
                                        child: _OrderSummaryCard(item: item),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _PriceSummaryBox(
                                      subTotalLabel: '${s.paymentSubTotalLabel} ($_totalItemsCount)',
                                      shippingLabel: s.paymentShipmentTotalLabel,
                                      totalLabel: s.paymentTotalLabel,
                                      subTotal: _subTotal,
                                      shipping: _shippingTotal,
                                      total: _total,
                                    ),
                                  ],
                                  const SizedBox(height: 22),
                                  _SectionTitle(
                                    s.paymentDeliveryInfoTitle,
                                    trailing: Icon(
                                      Icons.edit_square,
                                      color: const Color(0xFF1D282E).withOpacity(0.9),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _PaymentTextField(
                                    hint: s.paymentFullNameHint,
                                    controller: fullNameCtrl,
                                    enabled: !_isConfirming,
                                  ),
                                  const SizedBox(height: 16),
                                  _PaymentTextField(
                                    hint: s.paymentPhoneHint,
                                    controller: phoneCtrl,
                                    enabled: !_isConfirming,
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: 16),
                                  _PaymentTextField(
                                    hint: s.paymentAddressHint,
                                    controller: addressCtrl,
                                    enabled: !_isConfirming,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _PaymentTextField(
                                          hint: s.paymentCityHint,
                                          controller: cityCtrl,
                                          enabled: !_isConfirming,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _PaymentTextField(
                                          hint: s.paymentPostalHint,
                                          controller: postalCtrl,
                                          enabled: !_isConfirming,
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  _SectionTitle(s.paymentMethodTitle),
                                  const SizedBox(height: 14),
                                  _PaymentMethodsRow(
                                    cashLabel: s.paymentCashOnDelivery,
                                    cardLabel: s.paymentCreditCard,
                                    value: _paymentMethod,
                                    enabled: !_isConfirming,
                                    onChanged: (value) {
                                      setState(() => _paymentMethod = value);
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  _SectionTitle(s.paymentCardDetailsTitle),
                                  const SizedBox(height: 16),
                                  _PaymentTextField(
                                    hint: s.paymentCardNumberHint,
                                    controller: cardNumberCtrl,
                                    enabled: !_isConfirming && _paymentMethod == 'CARD',
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _PaymentTextField(
                                          hint: s.paymentExpHint,
                                          controller: expCtrl,
                                          enabled: !_isConfirming && _paymentMethod == 'CARD',
                                          keyboardType: TextInputType.datetime,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _PaymentTextField(
                                          hint: s.paymentCvvHint,
                                          controller: cvvCtrl,
                                          enabled: !_isConfirming && _paymentMethod == 'CARD',
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 40),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isConfirming
                                          ? null
                                          : () => _confirmOrder(s),
                                      style: ElevatedButton.styleFrom(
                                        elevation: 0,
                                        backgroundColor: const Color(0xFF1D282E),
                                        disabledBackgroundColor:
                                            const Color(0xFF1D282E).withOpacity(0.58),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: _isConfirming
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              s.paymentConfirmButton,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
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
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _LoadingPaymentView extends StatelessWidget {
  final VoidCallback onBack;

  const _LoadingPaymentView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          const Center(child: CircularProgressIndicator()),
          PositionedDirectional(
            top: 18,
            start: 24,
            child: _BackCircle(onTap: onBack),
          ),
        ],
      ),
    );
  }
}

class _ErrorPaymentView extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  const _ErrorPaymentView({
    required this.message,
    required this.onBack,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _BackCircle(onTap: onBack),
            ),
            const Spacer(),
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 14),
            Text(
              isArabic ? 'فشل تحميل الدفع' : 'Failed to load payment',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D282E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

class _PaymentHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const _PaymentHeader({
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PositionedDirectional(
            start: 24,
            child: _BackCircle(onTap: onBack),
          ),
          Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackCircle extends StatelessWidget {
  final VoidCallback? onTap;

  const _BackCircle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1D282E),
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _PaymentStepsHeader extends StatelessWidget {
  const _PaymentStepsHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const _StepDoneCircle(),
          const SizedBox(width: 14),
          Expanded(
            child: CustomPaint(
              painter: _DashedLinePainter(),
              child: const SizedBox(height: 1),
            ),
          ),
          const SizedBox(width: 14),
          const _StepNumberCircle(number: '2'),
        ],
      ),
    );
  }
}

class _StepDoneCircle extends StatelessWidget {
  const _StepDoneCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFF1D282E),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

class _StepNumberCircle extends StatelessWidget {
  final String number;

  const _StepNumberCircle({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF1D282E),
        shape: BoxShape.circle,
      ),
      child: Text(
        number,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionTitle(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _EmptyCartSummary extends StatelessWidget {
  final bool isArabic;

  const _EmptyCartSummary({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          isArabic ? 'السلة فاضية' : 'Cart is empty',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final _PaymentCartItem item;

  const _OrderSummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: item.imageUrl.isEmpty
                      ? _ImagePlaceholder(productName: item.productName)
                      : Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return _ImagePlaceholder(productName: item.productName);
                          },
                        ),
                ),
              ),
              PositionedDirectional(
                top: -8,
                end: -8,
                child: Container(
                  width: 19,
                  height: 19,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6A7275),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
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
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.brandName.isEmpty ? 'Brand' : item.brandName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _variantLabel(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Align(
            alignment: Alignment.topRight,
            child: Text(
              '${_formatMoney(item.lineTotal)} EGP',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _variantLabel(_PaymentCartItem item) {
    final color = item.colorName.isEmpty ? 'White' : item.colorName;
    final size = item.sizeName.isEmpty ? 'White' : item.sizeName;
    return '$color / $size';
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String productName;

  const _ImagePlaceholder({required this.productName});

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

class _PriceSummaryBox extends StatelessWidget {
  final String subTotalLabel;
  final String shippingLabel;
  final String totalLabel;
  final double subTotal;
  final double shipping;
  final double total;

  const _PriceSummaryBox({
    required this.subTotalLabel,
    required this.shippingLabel,
    required this.totalLabel,
    required this.subTotal,
    required this.shipping,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _PriceRow(
            label: subTotalLabel,
            value: '${_formatMoney(subTotal)} EGP',
          ),
          const SizedBox(height: 16),
          _PriceRow(
            label: shippingLabel,
            value: '${_formatMoney(shipping)} EGP',
          ),
          const SizedBox(height: 18),
          _PriceRow(
            label: totalLabel,
            value: '${_formatMoney(total)} EGP',
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? const Color(0xFF1F678C) : Colors.black,
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PaymentTextField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool enabled;

  const _PaymentTextField({
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF747A7D),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: enabled ? const Color(0xFFF2F2F2) : const Color(0xFFEDEDED),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1D282E), width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        ),
      ),
    );
  }
}

class _PaymentMethodsRow extends StatelessWidget {
  final String cashLabel;
  final String cardLabel;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _PaymentMethodsRow({
    required this.cashLabel,
    required this.cardLabel,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RadioOption(
            label: cashLabel,
            selected: value == 'CASH',
            enabled: enabled,
            onTap: () => onChanged('CASH'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RadioOption(
            label: cardLabel,
            selected: value == 'CARD',
            enabled: enabled,
            onTap: () => onChanged('CARD'),
          ),
        ),
      ],
    );
  }
}

class _RadioOption extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _RadioOption({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled ? const Color(0xFF1D282E) : Colors.black26,
                width: 1.2,
              ),
            ),
            child: selected
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1D282E),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: enabled ? Colors.black : Colors.black38,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCartItem {
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

  const _PaymentCartItem({
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

  factory _PaymentCartItem.fromJson(dynamic json) {
    final item = json is Map ? json : <String, dynamic>{};
    final product = _readMap(item, 'product');
    final variant = _readMap(item, 'variant') ?? _readMap(item, 'productVariant');

    final qty = _toInt(item['quantity'] ?? item['qty'], fallback: 1);
    final unitPrice = _toDouble(
      item['unitPrice'] ?? item['price'] ?? variant?['price'] ?? product?['price'],
    );
    final lineTotal = _toDouble(item['lineTotal'] ?? item['totalPrice']);

    return _PaymentCartItem(
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

  _PaymentCartItem copyWith({
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

    return _PaymentCartItem(
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

class _ProductLookup {
  final int id;
  final String name;
  final String brandName;
  final String imageUrl;

  const _ProductLookup({
    required this.id,
    required this.name,
    required this.brandName,
    required this.imageUrl,
  });

  factory _ProductLookup.fromJson(dynamic json) {
    final map = json is Map ? json : <String, dynamic>{};

    return _ProductLookup(
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

Future<bool?> showOrderConfirmedDialog(
  BuildContext context,
  AppStrings s, {
  required String orderId,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFF1BC47D),
              child: Icon(Icons.check, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              s.orderConfirmTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '${s.orderConfirmBody}\n$orderId',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D282E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  s.orderConfirmTrackButton,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1D282E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  s.orderConfirmContinueButton,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

List<dynamic> _extractList(dynamic data) {
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
    final text = _text(value);
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _text(dynamic value) {
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
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
