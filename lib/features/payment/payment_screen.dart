import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../services/api_service.dart';
import '../orders/my_orders_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = true;
  bool _isConfirming = false;

  List<dynamic> cartItems = [];
  String paymentMethod = 'CASH_ON_DELIVERY';

  // Address fields — sent to POST /addresses then use returned id for checkout
  final countryCtrl    = TextEditingController();
  final cityCtrl       = TextEditingController();
  final streetCtrl     = TextEditingController();
  final zipCtrl        = TextEditingController();
  final governorateCtrl = TextEditingController();

  // Card fields
  final cardNumberCtrl = TextEditingController();
  final expCtrl        = TextEditingController();
  final cvvCtrl        = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  @override
  void dispose() {
    countryCtrl.dispose(); cityCtrl.dispose(); streetCtrl.dispose();
    zipCtrl.dispose(); governorateCtrl.dispose();
    cardNumberCtrl.dispose(); expCtrl.dispose(); cvvCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCart() async {
    try {
      final data = await ApiService.get('/cart', withAuth: true);
      if (!mounted) return;
      setState(() {
        cartItems = _extractItems(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMsg(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  List<dynamic> _extractItems(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['items'] is List) return data['items'];
    if (data is Map && data['cartItems'] is List) return data['cartItems'];
    if (data is Map && data['content'] is List) return data['content'];
    return [];
  }

  double get _subTotal {
    double t = 0;
    for (final item in cartItems) {
      final tp = _toDouble(_read(item, 'totalPrice'));
      if (tp > 0) { t += tp; continue; }
      t += _toDouble(_read(item, 'unitPrice') ?? _read(item, 'price')) *
           _toInt(_read(item, 'quantity') ?? 1);
    }
    return t;
  }

  Future<void> _confirmOrder(AppStrings s) async {
    final country     = countryCtrl.text.trim();
    final city        = cityCtrl.text.trim();
    final street      = streetCtrl.text.trim();

    if (cartItems.isEmpty) { _showMsg('Cart is empty', isError: true); return; }
    if (country.isEmpty || city.isEmpty || street.isEmpty) {
      _showMsg('Please fill country, city and street', isError: true);
      return;
    }
    if (paymentMethod == 'CARD') {
      if (cardNumberCtrl.text.trim().isEmpty ||
          expCtrl.text.trim().isEmpty ||
          cvvCtrl.text.trim().isEmpty) {
        _showMsg('Please fill card details', isError: true);
        return;
      }
    }

    setState(() => _isConfirming = true);

    try {
      // Step 1 — Create address → get addressId
      final addrBody = {
        'country':     country,
        'city':        city,
        'street':      street,
        'zipCode':     zipCtrl.text.trim().isEmpty ? null : zipCtrl.text.trim(),
        'governorate': governorateCtrl.text.trim().isEmpty ? null : governorateCtrl.text.trim(),
      }..removeWhere((_, v) => v == null);

      final addrResp = await ApiService.post('/addresses', body: addrBody, withAuth: true);
      final addressId = _extractId(addrResp);

      if (addressId == 0) {
        _showMsg('Could not create address', isError: true);
        setState(() => _isConfirming = false);
        return;
      }

      // Step 2 — Checkout with addressId
      // CheckoutRequest: { addressId: Long, notes: String? }
      final checkoutBody = <String, dynamic>{
        'addressId': addressId,
      };

      final response = await ApiService.post('/checkout', body: checkoutBody, withAuth: true);

      if (!mounted) return;

      final orderId = _extractOrderId(response);
      final confirmed = await showOrderConfirmedDialog(context, s, orderId: orderId);

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
      if (!mounted) return;
      _showMsg(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  int _extractId(dynamic resp) {
    if (resp is Map) {
      final id = resp['id'] ?? resp['addressId'];
      if (id is int) return id;
      return int.tryParse(id?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  String _extractOrderId(dynamic response) {
    if (response is Map) {
      final data = response['data'];
      final id = response['id'] ?? response['orderId'] ?? response['orderNumber'] ??
          (data is Map ? data['id'] : null) ?? (data is Map ? data['orderId'] : null);
      if (id != null) {
        final v = id.toString();
        return v.startsWith('#') ? v : '#$v';
      }
    }
    return '#ORDER';
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : null,
    ));
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _isConfirming ? null : () => Navigator.pop(context),
          ),
          title: Text(s.paymentTitle,
              style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadCart,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Step indicator ──────────────────────────────────
                      Row(children: [
                        const _StepCircle(isActive: true),
                        Expanded(child: Container(height: 2, color: Colors.grey[300])),
                        const _StepCircle(isActive: true),
                      ]),
                      const SizedBox(height: 16),

                      // ── Order summary ───────────────────────────────────
                      Text(s.paymentOrderSummary,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (cartItems.isEmpty)
                        _emptyCart()
                      else ...[
                        ...cartItems.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SummaryItemCard(item: item),
                            )),
                        const SizedBox(height: 12),
                        _PriceBox(subTotal: _subTotal),
                      ],
                      const SizedBox(height: 20),

                      // ── Delivery address ────────────────────────────────
                      Text(s.paymentDeliveryInfoTitle,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('A new address will be saved to your account',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(height: 12),
                      _TF(hint: 'Country *',     ctrl: countryCtrl,     enabled: !_isConfirming),
                      const SizedBox(height: 10),
                      _TF(hint: 'City *',        ctrl: cityCtrl,        enabled: !_isConfirming),
                      const SizedBox(height: 10),
                      _TF(hint: 'Street *',      ctrl: streetCtrl,      enabled: !_isConfirming),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _TF(hint: 'Governorate', ctrl: governorateCtrl, enabled: !_isConfirming)),
                        const SizedBox(width: 8),
                        Expanded(child: _TF(hint: 'Zip Code', ctrl: zipCtrl,
                            keyboardType: TextInputType.number, enabled: !_isConfirming)),
                      ]),
                      const SizedBox(height: 20),

                      // ── Payment method ──────────────────────────────────
                      Text(s.paymentMethodTitle,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _PaymentOption(
                        title: s.paymentCashOnDelivery,
                        value: 'CASH_ON_DELIVERY',
                        groupValue: paymentMethod,
                        onChanged: _isConfirming ? null : (v) => setState(() => paymentMethod = v),
                      ),
                      _PaymentOption(
                        title: s.paymentCreditCard,
                        value: 'CARD',
                        groupValue: paymentMethod,
                        onChanged: _isConfirming ? null : (v) => setState(() => paymentMethod = v),
                      ),
                      if (paymentMethod == 'CARD') ...[
                        const SizedBox(height: 12),
                        Text(s.paymentCardDetailsTitle,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        _TF(hint: s.paymentCardNumberHint, ctrl: cardNumberCtrl,
                            keyboardType: TextInputType.number, enabled: !_isConfirming),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _TF(hint: s.paymentExpHint, ctrl: expCtrl, enabled: !_isConfirming)),
                          const SizedBox(width: 8),
                          Expanded(child: _TF(hint: s.paymentCvvHint, ctrl: cvvCtrl,
                              keyboardType: TextInputType.number, enabled: !_isConfirming)),
                        ]),
                      ],
                      const SizedBox(height: 24),

                      // ── Confirm button ──────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isConfirming ? null : () => _confirmOrder(s),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            disabledBackgroundColor: Colors.black54,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          child: _isConfirming
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(s.paymentConfirmButton,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _emptyCart() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(16)),
    child: const Center(child: Text('Cart is empty')),
  );
}

// ── Price summary box ─────────────────────────────────────────────────────────

class _PriceBox extends StatelessWidget {
  final double subTotal;
  const _PriceBox({required this.subTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        _TotalRow(label: 'Sub total', value: '${subTotal.toStringAsFixed(2)} EGP'),
        const _TotalRow(label: 'Shipment', value: '0.00 EGP'),
        const Divider(height: 20),
        _TotalRow(label: 'Total', value: '${subTotal.toStringAsFixed(2)} EGP', bold: true),
      ]),
    );
  }
}

// ── Summary Item Card ─────────────────────────────────────────────────────────

class _SummaryItemCard extends StatelessWidget {
  final dynamic item;
  const _SummaryItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final name  = _text(_read(item, 'productName') ?? _readProd(item, 'name'), fallback: 'Product');
    final brand = _text(_read(item, 'brandName')   ?? _readProd(item, 'brandName'));
    final price = _toDouble(_read(item, 'unitPrice') ?? _read(item, 'price') ?? _readProd(item, 'price'));
    final qty   = _toInt(_read(item, 'quantity') ?? 1);
    final img   = _imgUrl(item);

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
          child: SizedBox(width: 90, height: 90,
            child: img.isEmpty ? _ph() : Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph())),
        ),
        const SizedBox(width: 10),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (brand.isNotEmpty) Text(brand, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            Text('Qty: $qty', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
        )),
        Padding(padding: const EdgeInsets.only(right: 12),
          child: Text('${(price * qty).toStringAsFixed(2)} EGP',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _ph() => Container(color: Colors.grey[300], child: const Icon(Icons.image_outlined, color: Colors.grey));
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _PaymentOption extends StatelessWidget {
  final String title, value, groupValue;
  final ValueChanged<String>? onChanged;
  const _PaymentOption({required this.title, required this.value, required this.groupValue, required this.onChanged});

  @override
  Widget build(BuildContext context) => RadioListTile<String>(
    value: value, groupValue: groupValue,
    onChanged: onChanged == null ? null : (v) => onChanged!(v!),
    title: Text(title), activeColor: Colors.black, contentPadding: EdgeInsets.zero,
  );
}

class _StepCircle extends StatelessWidget {
  final bool isActive;
  const _StepCircle({required this.isActive});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 14,
    backgroundColor: isActive ? Colors.black : Colors.white,
    child: Icon(isActive ? Icons.check : Icons.circle_outlined,
        color: isActive ? Colors.white : Colors.black54, size: 16),
  );
}

class _TotalRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _TotalRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      Text(value,  style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: bold ? Colors.blue : Colors.black)),
    ],
  );
}

class _TF extends StatelessWidget {
  final String hint;
  final TextEditingController ctrl;
  final TextInputType? keyboardType;
  final bool enabled;
  const _TF({required this.hint, required this.ctrl, this.keyboardType, this.enabled = true});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: keyboardType, enabled: enabled,
    decoration: InputDecoration(
      hintText: hint, filled: true,
      fillColor: enabled ? const Color(0xFFF5F5F5) : Colors.grey.shade200,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );
}

// ── Order Confirmed Dialog ────────────────────────────────────────────────────

Future<bool?> showOrderConfirmedDialog(BuildContext context, AppStrings s, {required String orderId}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircleAvatar(radius: 26, backgroundColor: Color(0xFF1BC47D),
              child: Icon(Icons.check, color: Colors.white, size: 30)),
          const SizedBox(height: 16),
          Text(s.orderConfirmTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('${s.orderConfirmBody}\n$orderId', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
              child: Text(s.orderConfirmTrackButton,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
              child: Text(s.orderConfirmContinueButton, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    ),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

dynamic _read(dynamic item, String key)    => item is Map ? item[key] : null;
dynamic _readProd(dynamic item, String key) =>
    item is Map && item['product'] is Map ? item['product'][key] : null;
String _text(dynamic v, {String fallback = ''}) {
  final t = v?.toString() ?? ''; return t.trim().isEmpty ? fallback : t;
}
double _toDouble(dynamic v) { if (v is num) return v.toDouble(); return double.tryParse(v?.toString() ?? '') ?? 0; }
int    _toInt(dynamic v)    { if (v is int) return v; return int.tryParse(v?.toString() ?? '') ?? 1; }
String _imgUrl(dynamic item) {
  final raw = _read(item, 'imageUrl') ?? _read(item, 'image') ?? _readProd(item, 'imageUrl') ?? '';
  final url = raw.toString();
  if (url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  return 'https://lokit-production.up.railway.app${url.startsWith('/') ? '' : '/'}$url';
}
