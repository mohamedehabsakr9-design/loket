import 'package:flutter/material.dart';
import '../../app/app_strings.dart';
import '../../services/shipping_service.dart';

class ShippingAddressScreen extends StatefulWidget {
  const ShippingAddressScreen({super.key});

  @override
  State<ShippingAddressScreen> createState() => _ShippingAddressScreenState();
}

class _ShippingAddressScreenState extends State<ShippingAddressScreen> {
  List<AddressItem> addresses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ShippingService.getAddresses();
      if (!mounted) return;
      setState(() {
        addresses = data.map<AddressItem>((e) {
          final map = Map<String, dynamic>.from(e as Map);
          return AddressItem(
            id: _str(map, 'id'),
            title: _str(map, 'title').isNotEmpty
                ? _str(map, 'title')
                : _str(map, 'addressName').isNotEmpty
                    ? _str(map, 'addressName')
                    : _str(map, 'label').isNotEmpty
                        ? _str(map, 'label')
                        : 'Address',
            details: _buildDetails(map),
            isDefault: map['isDefault'] == true || map['default'] == true || map['primary'] == true,
          );
        }).toList();
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

  static String _str(Map<String, dynamic> map, String key) =>
      (map[key] ?? '').toString();

  static String _buildDetails(Map<String, dynamic> map) {
    final direct = _str(map, 'details').isNotEmpty
        ? _str(map, 'details')
        : _str(map, 'fullAddress').isNotEmpty
            ? _str(map, 'fullAddress')
            : _str(map, 'address');
    if (direct.isNotEmpty) return direct;

    final parts = [
      _str(map, 'street'),
      _str(map, 'city'),
      _str(map, 'area'),
      _str(map, 'building'),
      _str(map, 'floor'),
      _str(map, 'apartment'),
    ].where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? '-' : parts.join(' - ');
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(s.shippingTitle, style: const TextStyle(color: Colors.black)),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black),
              onPressed: () => _showAddDialog(context, isArabic),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadAddresses,
          child: _buildBody(isArabic),
        ),
      ),
    );
  }

  Widget _buildBody(bool isArabic) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 160),
          const Icon(Icons.error_outline, color: Colors.red, size: 44),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          Center(child: ElevatedButton(onPressed: _loadAddresses, child: const Text('Try again'))),
        ],
      );
    }

    if (addresses.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 160),
          Icon(Icons.location_off_outlined, color: Colors.grey, size: 48),
          SizedBox(height: 12),
          Center(child: Text('No addresses found', style: TextStyle(color: Colors.black54))),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: addresses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _AddressCard(
        item: addresses[index],
        isArabic: isArabic,
        onTap: () => Navigator.pop(context, addresses[index]),
        onDelete: () => _deleteAddress(addresses[index]),
      ),
    );
  }

  Future<void> _deleteAddress(AddressItem item) async {
    final id = int.tryParse(item.id) ?? 0;
    if (id == 0) return;
    try {
      await ShippingService.deleteAddress(id);
      if (!mounted) return;
      setState(() => addresses.removeWhere((a) => a.id == item.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _showAddDialog(BuildContext context, bool isArabic) {
    // AddressRequest: { country*, city*, street*, zipCode, governorate }
    final countryCtrl     = TextEditingController();
    final cityCtrl        = TextEditingController();
    final streetCtrl      = TextEditingController();
    final zipCtrl         = TextEditingController();
    final governorateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Address'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: countryCtrl,     decoration: const InputDecoration(hintText: 'Country *')),
              const SizedBox(height: 8),
              TextField(controller: cityCtrl,        decoration: const InputDecoration(hintText: 'City *')),
              const SizedBox(height: 8),
              TextField(controller: streetCtrl,      decoration: const InputDecoration(hintText: 'Street *')),
              const SizedBox(height: 8),
              TextField(controller: governorateCtrl, decoration: const InputDecoration(hintText: 'Governorate')),
              const SizedBox(height: 8),
              TextField(controller: zipCtrl,         decoration: const InputDecoration(hintText: 'Zip Code'),
                  keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final country = countryCtrl.text.trim();
              final city    = cityCtrl.text.trim();
              final street  = streetCtrl.text.trim();
              if (country.isEmpty || city.isEmpty || street.isEmpty) return;
              Navigator.pop(context);
              try {
                final body = <String, dynamic>{
                  'country': country,
                  'city':    city,
                  'street':  street,
                };
                if (governorateCtrl.text.trim().isNotEmpty) body['governorate'] = governorateCtrl.text.trim();
                if (zipCtrl.text.trim().isNotEmpty)         body['zipCode']     = zipCtrl.text.trim();
                await ShippingService.addAddress(body);
                _loadAddresses();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class AddressItem {
  final String id;
  final String title;
  final String details;
  final bool isDefault;

  AddressItem({required this.id, required this.title, required this.details, required this.isDefault});
}

// ─── Address Card ─────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final AddressItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isArabic;

  const _AddressCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = item.isDefault ? Colors.black : Colors.grey[300]!;
    final badgeColor = item.isDefault ? Colors.green : Colors.grey[400]!;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(Icons.location_on_outlined, color: badgeColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    if (item.isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text(isArabic ? 'افتراضي' : 'Default',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(item.details, maxLines: 2, overflow: TextOverflow.ellipsis,
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4)),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
