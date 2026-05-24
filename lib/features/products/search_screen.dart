import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/models/product_search_model.dart';
import '../../core/services/search_service.dart';
import '../../services/api_service.dart';
import '../cart/my_cart_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_menu_screen.dart';
import '../wishlist/wishlist_screen.dart';
import '../products/product_details_screen.dart';

const String _kBase = 'https://lokit-production.up.railway.app';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchSvc = SearchService();
  final _queryCtrl = TextEditingController();
  final _focusNode = FocusNode();

  String   _query       = '';
  bool     _isLoading   = false;
  bool     _hasSearched = false;
  String?  _errorMsg;
  List<ProductSearchModel> _results = [];
  DateTime? _lastTyped;

  // ── Filters ────────────────────────────────────────────────────────────────
  List<_Opt> _departments = [];
  List<_Opt> _categories  = [];
  List<_Opt> _brands      = [];
  // Color & Size — extracted from product variants (no dedicated endpoint)
  List<_Opt> _colors      = [];
  List<_Opt> _sizes       = [];

  int? _selDeptId;
  int? _selCatId;
  int? _selBrandId;
  int? _selColorId;
  int? _selSizeId;

  bool get _hasActiveFilters =>
      _selDeptId != null || _selCatId != null ||
      _selBrandId != null || _selColorId != null || _selSizeId != null;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Load filters ──────────────────────────────────────────────────────────

  Future<void> _loadFilters() async {
    try {
      // Load department, category, brand in parallel
      // Color & Size have no dedicated endpoint → extract from latest products
      final results = await Future.wait([
        ApiService.get('/department'),
        ApiService.get('/category'),
        ApiService.get('/brand'),
      ]);

      if (!mounted) return;

      setState(() {
        _departments = _parseOpts(results[0]);
        _categories  = _parseOpts(results[1]);
        _brands      = _parseOpts(results[2]);
        // Color & Size not available from backend search endpoint
        // chips will be hidden since lists remain empty
      });
    } catch (_) {}
  }

  Future<dynamic> _safeGet(String path) async {
    try { return await ApiService.get(path); } catch (_) { return []; }
  }

  List<_Opt> _parseOpts(dynamic data) {
    final list = _asList(data);
    return list.whereType<Map>().map<_Opt>((e) {
      final id   = _toInt(e['id'] ?? e['departmentId'] ?? e['categoryId'] ?? e['brandId']);
      final name = _str(e['name'] ?? e['departmentName'] ?? e['categoryName'] ?? e['brandName']);
      return _Opt(id, name);
    }).where((e) => e.id > 0 && e.name.isNotEmpty).toList();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onQueryChanged(String v) {
    setState(() {
      _query = v;
      if (v.trim().isEmpty && !_hasActiveFilters) {
        _hasSearched = false;
        _results     = [];
        _errorMsg    = null;
        _isLoading   = false;
      }
    });
    if (v.trim().length < 2) return;
    final t = DateTime.now();
    _lastTyped = t;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_lastTyped == t && mounted) _search();
    });
  }

  Future<void> _search() async {
    if (_query.trim().isEmpty && !_hasActiveFilters) return;
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      // departmentId NOT supported by backend → append dept name to keyword
      final deptName = _selDeptId != null
          ? (_departments.firstWhere((d) => d.id == _selDeptId,
              orElse: () => _Opt(0, '')).name)
          : '';

      final keyword = [
        if (_query.trim().isNotEmpty) _query.trim(),
        if (deptName.isNotEmpty) deptName,
      ].join(' ');

      final r = await _searchSvc.searchProducts(
        keyword:    keyword.isEmpty ? null : keyword,
        brandId:    _selBrandId,
        categoryId: _selCatId,
        colorId:    _selColorId,
        sizeId:     _selSizeId,
      );

      if (!mounted) return;
      setState(() { _results = r; _hasSearched = true; _isLoading = false; });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading   = false;
        _hasSearched = true;
        _errorMsg    = e.response?.data is Map
            ? e.response?.data['message']?.toString()
            : 'Connection error. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading   = false;
        _hasSearched = true;
        _errorMsg    = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selDeptId = null; _selCatId  = null; _selBrandId = null;
      _selColorId = null; _selSizeId = null;
    });
    if (_query.trim().isNotEmpty) _search();
    else setState(() { _hasSearched = false; _results = []; });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s    = AppStrings.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F7F7),
          elevation: 0,
          centerTitle: true,
          title: Text(s.searchTitle,
              style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),

            // ── Search + filter card ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    // Search field
                    TextField(
                      controller: _queryCtrl,
                      focusNode: _focusNode,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _search(),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: s.searchHint,
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.black54, size: 22),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, color: Colors.black38, size: 18),
                                onPressed: () { _queryCtrl.clear(); _onQueryChanged(''); })
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),

                    Container(height: 1, color: Colors.grey.shade100),

                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          // Department — radio style bottom sheet
                          _RadioFilterChip(
                            label: 'Department',
                            options: _departments,
                            selectedId: _selDeptId,
                            onSelected: (id) {
                              setState(() => _selDeptId = id);
                              _search();
                            },
                          ),
                          const SizedBox(width: 8),
                          _RadioFilterChip(
                            label: 'Category',
                            options: _categories,
                            selectedId: _selCatId,
                            onSelected: (id) {
                              setState(() => _selCatId = id);
                              _search();
                            },
                          ),
                          const SizedBox(width: 8),
                          _RadioFilterChip(
                            label: 'Brand',
                            options: _brands,
                            selectedId: _selBrandId,
                            onSelected: (id) {
                              setState(() => _selBrandId = id);
                              _search();
                            },
                          ),
                          // Color & Size — UI only, disabled until DB has data
                          const SizedBox(width: 8),
                          _DisabledChip(label: 'Color'),
                          const SizedBox(width: 8),
                          _DisabledChip(label: 'Size'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            Expanded(child: _buildBody(s)),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(context),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(AppStrings s) {
    if (!_hasSearched && !_isLoading) {
      return _EmptyState(
        icon: Icons.search_rounded,
        title: s.searchExploreNow,
        subtitle: 'Search for clothes, brands, and more',
      );
    }
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.black));
    if (_errorMsg != null) return _EmptyState(icon: Icons.wifi_off_outlined, title: _errorMsg!, isError: true);
    if (_results.isEmpty) return _EmptyState(
      icon: Icons.search_off_rounded,
      title: s.searchNoResults,
      subtitle: 'Try different keywords or filters',
      isError: true,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${s.searchResultsTitle} (${_results.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.close, size: 14, color: Colors.black54),
                  label: const Text('Clear filters',
                      style: TextStyle(color: Colors.black54, fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _results.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.58,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              itemBuilder: (_, i) => _ProductCard(product: _results[i]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavItem(icon: Icons.home_outlined, label: 'Home',
                onTap: () => Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false)),
            _NavItem(icon: Icons.search, label: 'Search', isActive: true, onTap: () {}),
            _NavItem(icon: Icons.favorite_border, label: 'Wishlist',
                onTap: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const WishlistScreen()))),
            _NavItem(icon: Icons.shopping_bag_outlined, label: 'Cart',
                onTap: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const MyCartScreen()))),
            _NavItem(icon: Icons.person_outline, label: 'Profile',
                onTap: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const ProfileMenuScreen()))),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Radio Filter Chip — بيفتح bottom sheet بـ radio buttons + Apply & Clear
// ══════════════════════════════════════════════════════════════════════════════

class _Opt {
  final int id;
  final String name;
  _Opt(this.id, this.name);
}

// ── Disabled chip — ظاهر بس مش شغال ──────────────────────────────────────────

class _DisabledChip extends StatelessWidget {
  final String label;
  const _DisabledChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Coming soon',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade400)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: Colors.grey.shade300),
        ]),
      ),
    );
  }
}

class _RadioFilterChip extends StatelessWidget {
  final String label;
  final List<_Opt> options;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  const _RadioFilterChip({
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  String get _displayLabel {
    if (selectedId == null) return label;
    return options
        .firstWhere((e) => e.id == selectedId, orElse: () => _Opt(0, label))
        .name;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = selectedId != null;
    return GestureDetector(
      onTap: () => _showSheet(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_displayLabel,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : Colors.black87)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: isActive ? Colors.white : Colors.black54),
        ]),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    // Temp local state inside the sheet
    int? tempSelected = selectedId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                const SizedBox(height: 10),
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Text('Sort by :',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 8),

                // Radio list
                if (options.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Loading…', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: options.map((opt) => RadioListTile<int?>(
                        value: opt.id,
                        groupValue: tempSelected,
                        onChanged: (v) => setSheet(() => tempSelected = v),
                        title: Text(opt.name,
                            style: TextStyle(
                                fontWeight: tempSelected == opt.id
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                        activeColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        tileColor: tempSelected == opt.id
                            ? Colors.grey.shade100
                            : null,
                      )).toList(),
                    ),
                  ),

                const SizedBox(height: 12),

                // Apply + Clear buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    // Apply
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onSelected(tempSelected);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26)),
                          ),
                          child: const Text('Apply',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Clear
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onSelected(null);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black26),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26)),
                          ),
                          child: const Text('Clear',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Product card
// ══════════════════════════════════════════════════════════════════════════════

class _ProductCard extends StatelessWidget {
  final ProductSearchModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final img = _fullImg(product.imageUrl);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductDetailsScreen(productId: product.id))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: SizedBox(
                height: 160, width: double.infinity,
                child: img.isEmpty
                    ? _placeholder()
                    : Image.network(img, fit: BoxFit.cover,
                        loadingBuilder: (_, child, p) => p == null ? child
                            : Container(color: Colors.grey[100],
                                child: const Center(child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black26))),
                        errorBuilder: (_, __, ___) => _placeholder()),
              ),
            ),
            Positioned(top: 10, right: 10,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.08), blurRadius: 6)],
                ),
                child: const Icon(Icons.favorite_border, size: 18, color: Colors.black54),
              )),
          ]),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.brandName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 3),
                Text(product.name, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, height: 1.3)),
                const Spacer(),
                Row(children: [
                  Expanded(
                    child: Text('${product.minPrice.toStringAsFixed(2)} EGP',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    width: 30, height: 30,
                    decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(color: Colors.grey[200],
      child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey)));

  String _fullImg(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$_kBase$url';
    return '$_kBase/$url';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Empty state
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isError;

  const _EmptyState({required this.icon, required this.title,
      this.subtitle, this.isError = false});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 120, height: 120,
        decoration: BoxDecoration(
          color: isError ? Colors.red.shade50 : const Color(0xFFF2F2F2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 52,
            color: isError ? Colors.redAccent.shade100 : Colors.black38),
      ),
      const SizedBox(height: 20),
      Text(title, textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle!, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      ],
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  Nav item
// ══════════════════════════════════════════════════════════════════════════════

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavItem({required this.icon, required this.label,
      this.isActive = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.black : Colors.grey;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Pure helpers
// ══════════════════════════════════════════════════════════════════════════════

List<dynamic> _asList(dynamic v) {
  if (v is List) return v;
  if (v is Map) {
    for (final k in ['content', 'data', 'items', 'variants', 'results']) {
      if (v[k] is List) return v[k] as List;
    }
  }
  return [];
}

dynamic _readMap(dynamic obj, String key) => obj is Map ? obj[key] : null;

String _str(dynamic v) {
  if (v == null) return '';
  final s = v.toString().trim();
  return s == 'null' ? '' : s;
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}