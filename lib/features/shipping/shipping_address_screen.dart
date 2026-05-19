import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../services/shipping_service.dart';

class ShippingAddressScreen extends StatefulWidget {
  const ShippingAddressScreen({super.key});

  @override
  State<ShippingAddressScreen> createState() => _ShippingAddressScreenState();
}

class _ShippingAddressScreenState extends State<ShippingAddressScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  List<AddressItem> _addresses = [];

  bool _showNewAddress = true;
  bool _setAsDefault = false;

  final cityCtrl = TextEditingController();
  final streetCtrl = TextEditingController();
  final buildingCtrl = TextEditingController();
  final postalCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    cityCtrl.dispose();
    streetCtrl.dispose();
    buildingCtrl.dispose();
    postalCtrl.dispose();
    super.dispose();
  }

  String _msg({required String ar, required String en}) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic ? ar : en;
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      ),
    );
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ShippingService.getAddresses();
      final list = data.map(AddressItem.fromJson).toList();

      if (!mounted) return;
      setState(() {
        _addresses = list;
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

  void _clearForm() {
    cityCtrl.clear();
    streetCtrl.clear();
    buildingCtrl.clear();
    postalCtrl.clear();
    _setAsDefault = false;
  }

  Future<void> _saveAddress() async {
    final city = cityCtrl.text.trim();
    final street = streetCtrl.text.trim();
    final building = buildingCtrl.text.trim();
    final postal = postalCtrl.text.trim();

    if (city.isEmpty || street.isEmpty) {
      _showSnack(
        _msg(ar: 'من فضلك اكتب المدينة والشارع', en: 'Please enter city and street'),
        error: true,
      );
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final fullStreet = building.isEmpty ? street : '$street, Building $building';

      final body = <String, dynamic>{
        'country': 'Egypt',
        'city': city,
        'street': fullStreet,
        'governorate': city,
        if (postal.isNotEmpty) 'zipCode': postal,
      };

      await ShippingService.addAddress(body);

      if (!mounted) return;
      _clearForm();
      _showSnack(_msg(ar: 'تم حفظ العنوان', en: 'Address saved'));
      await _loadAddresses();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAddress(AddressItem item) async {
    if (item.id == 0) return;

    try {
      await ShippingService.deleteAddress(item.id);
      if (!mounted) return;
      setState(() => _addresses.removeWhere((a) => a.id == item.id));
      _showSnack(_msg(ar: 'تم حذف العنوان', en: 'Address deleted'));
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), error: true);
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
        body: SafeArea(
          child: Column(
            children: [
              _PageHeader(
                title: s.isArabic ? 'عنوان الشحن' : 'Shipping Address',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadAddresses,
                  child: _buildBody(s),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          elevation: 0,
          backgroundColor: const Color(0xFF1D282E),
          foregroundColor: Colors.white,
          onPressed: () {
            setState(() => _showNewAddress = true);
          },
          child: const Icon(Icons.add, size: 30),
        ),
      ),
    );
  }

  Widget _buildBody(AppStrings s) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 130, 24, 24),
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 46),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Center(
            child: ElevatedButton(
              onPressed: _loadAddresses,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D282E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(s.isArabic ? 'حاول مرة أخرى' : 'Try again'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        if (_addresses.isNotEmpty) ...[
          ..._addresses.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _AddressCompactCard(
                item: item,
                onTap: () {
                  Navigator.pop(context, item);
                },
                onDelete: () => _deleteAddress(item),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        _AddressFormCard(
          title: s.isArabic ? 'عنوان جديد' : 'New Address',
          expanded: _showNewAddress,
          onToggle: () => setState(() => _showNewAddress = !_showNewAddress),
          cityCtrl: cityCtrl,
          streetCtrl: streetCtrl,
          buildingCtrl: buildingCtrl,
          postalCtrl: postalCtrl,
          setAsDefault: _setAsDefault,
          isSaving: _isSaving,
          onDefaultChanged: (value) => setState(() => _setAsDefault = value),
          onDelete: _clearForm,
          onSave: _saveAddress,
        ),
        if (_addresses.isEmpty && !_showNewAddress) ...[
          const SizedBox(height: 100),
          const Icon(Icons.location_off_outlined, color: Colors.black26, size: 48),
          const SizedBox(height: 12),
          Center(
            child: Text(
              s.isArabic ? 'لا توجد عناوين محفوظة' : 'No saved addresses yet',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _PageHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          _CircleBackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Color(0xFFF4F4F4),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
    );
  }
}

class _AddressFormCard extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final TextEditingController cityCtrl;
  final TextEditingController streetCtrl;
  final TextEditingController buildingCtrl;
  final TextEditingController postalCtrl;
  final bool setAsDefault;
  final bool isSaving;
  final ValueChanged<bool> onDefaultChanged;
  final VoidCallback onDelete;
  final VoidCallback onSave;

  const _AddressFormCard({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.cityCtrl,
    required this.streetCtrl,
    required this.buildingCtrl,
    required this.postalCtrl,
    required this.setAsDefault,
    required this.isSaving,
    required this.onDefaultChanged,
    required this.onDelete,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = AppStrings.of(context).isArabic;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _LabeledInput(
                    label: isArabic ? 'المدينة' : 'City',
                    controller: cityCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _LabeledInput(
                    label: isArabic ? 'الشارع' : 'Street',
                    controller: streetCtrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _LabeledInput(
                    label: isArabic ? 'المبنى' : 'Building',
                    controller: buildingCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _LabeledInput(
                    label: isArabic ? 'الرمز البريدي' : 'Postal Code',
                    controller: postalCtrl,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                InkWell(
                  onTap: () => onDefaultChanged(!setAsDefault),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                          color: setAsDefault ? const Color(0xFF1D282E) : Colors.white,
                        ),
                        child: setAsDefault
                            ? const Icon(Icons.check, size: 11, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isArabic ? 'اجعله افتراضي' : 'Set as Default',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onDelete,
                  child: const SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(Icons.delete_rounded, color: Color(0xFFE54B42), size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 42,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : onSave,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF1D282E),
                  disabledBackgroundColor: const Color(0xFF1D282E).withOpacity(0.5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isArabic ? 'حفظ' : 'Save',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _LabeledInput({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: Color(0xFF555555), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 45,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD7D7D7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD7D7D7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1D282E), width: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressCompactCard extends StatelessWidget {
  final AddressItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AddressCompactCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: onDelete,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(Icons.delete_rounded, color: Color(0xFFE54B42), size: 23),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddressItem {
  final int id;
  final String title;
  final String details;
  final String city;
  final String street;
  final String postalCode;
  final bool isDefault;

  const AddressItem({
    required this.id,
    required this.title,
    required this.details,
    required this.city,
    required this.street,
    required this.postalCode,
    required this.isDefault,
  });

  factory AddressItem.fromJson(dynamic json) {
    final map = json is Map ? json : <String, dynamic>{};
    final city = _read(map, 'city');
    final street = _read(map, 'street');
    final postal = _read(map, 'zipCode').isNotEmpty ? _read(map, 'zipCode') : _read(map, 'postalCode');
    final title = _firstText([
      map['title'],
      map['addressName'],
      map['label'],
      city.isNotEmpty ? city : null,
    ], fallback: 'New Address');

    final details = _firstText([
      map['details'],
      map['fullAddress'],
      map['address'],
      [street, city, postal].where((e) => e.toString().trim().isNotEmpty).join(' - '),
    ], fallback: '-');

    return AddressItem(
      id: _toInt(map['id'] ?? map['addressId']),
      title: title,
      details: details,
      city: city,
      street: street,
      postalCode: postal,
      isDefault: map['isDefault'] == true || map['default'] == true || map['primary'] == true,
    );
  }
}

String _read(Map map, String key) {
  final value = map[key];
  if (value == null) return '';
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

String _firstText(List<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != 'null') return text;
  }
  return fallback;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
