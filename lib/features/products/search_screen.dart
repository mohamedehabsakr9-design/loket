import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/models/product_search_model.dart';
import '../../core/services/search_service.dart';
import '../../services/api_service.dart';
import '../products/product_details_screen.dart';
import '../../widgets/lokit_bottom_nav_bar.dart';
import '../../widgets/product_card.dart';

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

  String _query = '';
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMsg;
  List<ProductSearchModel> _results = [];
  DateTime? _lastTyped;

  List<_Opt> _departments = [];
  List<_Opt> _categories = [];
  List<_Opt> _brands = [];

  final List<_Opt> _colors = [
    _Opt(1, 'Black'),
    _Opt(2, 'White'),
    _Opt(3, 'Red'),
    _Opt(4, 'Blue'),
    _Opt(5, 'Green'),
    _Opt(6, 'Beige'),
  ];

  final List<_Opt> _sizes = [
    _Opt(1, 'XS'),
    _Opt(2, 'S'),
    _Opt(3, 'M'),
    _Opt(4, 'L'),
    _Opt(5, 'XL'),
    _Opt(6, 'XXL'),
  ];

  int? _selDeptId;
  int? _selCatId;
  int? _selBrandId;
  int? _selColorId;
  int? _selSizeId;

  bool get _hasActiveFilters =>
      _selDeptId != null ||
      _selCatId != null ||
      _selBrandId != null;

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

  Future<void> _loadFilters() async {
    try {
      final results = await Future.wait([
        ApiService.get('/department'),
        ApiService.get('/category'),
        ApiService.get('/brand'),
      ]);

      if (!mounted) return;

      setState(() {
        _departments = _parseOpts(results[0]);
        _categories = _parseOpts(results[1]);
        _brands = _parseOpts(results[2]);
      });
    } catch (_) {}
  }

  List<_Opt> _parseOpts(dynamic data) {
    final list = _asList(data);

    return list
        .whereType<Map>()
        .map<_Opt>((e) {
          final id = _toInt(
            e['id'] ?? e['departmentId'] ?? e['categoryId'] ?? e['brandId'],
          );

          final name = _str(
            e['name'] ??
                e['departmentName'] ??
                e['categoryName'] ??
                e['brandName'],
          );

          return _Opt(id, name);
        })
        .where((e) => e.id > 0 && e.name.isNotEmpty)
        .toList();
  }

  void _onQueryChanged(String v) {
    setState(() {
      _query = v;

      if (v.trim().isEmpty && !_hasActiveFilters) {
        _hasSearched = false;
        _results = [];
        _errorMsg = null;
        _isLoading = false;
      }
    });

    if (v.trim().length < 2) return;

    final t = DateTime.now();
    _lastTyped = t;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (_lastTyped == t && mounted) {
        _search();
      }
    });
  }

  Future<void> _search() async {
    if (_query.trim().isEmpty && !_hasActiveFilters) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final r = await _searchSvc.searchProducts(
        keyword: _query.trim().isEmpty ? null : _query.trim(),
        departmentId: _selDeptId,
        brandId: _selBrandId,
        categoryId: _selCatId,
      );

      if (!mounted) return;

      setState(() {
        _results = r;
        _hasSearched = true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasSearched = true;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selDeptId = null;
      _selCatId = null;
      _selBrandId = null;
      _selColorId = null;
      _selSizeId = null;
    });

    if (_query.trim().isNotEmpty) {
      _search();
    } else {
      setState(() {
        _hasSearched = false;
        _results = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F7F7),
          elevation: 0,
          centerTitle: true,
          title: Text(
            s.searchTitle,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _queryCtrl,
                      focusNode: _focusNode,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _search(),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: s.searchHint,
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.black54,
                          size: 22,
                        ),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.black38,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _queryCtrl.clear();
                                  _onQueryChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    Container(height: 1, color: Colors.grey.shade100),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
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
                          const SizedBox(width: 8),
                          _RadioFilterChip(
                            label: 'Color',
                            options: _colors,
                            selectedId: _selColorId,
                            onSelected: (id) {
                              // UI فقط — لا يتم إرسال اللون للباك إند ولا يعمل Search
                              setState(() => _selColorId = id);
                            },
                          ),
                          const SizedBox(width: 8),
                          _RadioFilterChip(
                            label: 'Size',
                            options: _sizes,
                            selectedId: _selSizeId,
                            onSelected: (id) {
                              // UI فقط — لا يتم إرسال المقاس للباك إند ولا يعمل Search
                              setState(() => _selSizeId = id);
                            },
                          ),
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
        bottomNavigationBar:
            const LokitBottomNavBar(currentTab: LokitBottomTab.search),
      ),
    );
  }

  Widget _buildBody(AppStrings s) {
    if (!_hasSearched && !_isLoading) {
      return _EmptyState(
        icon: Icons.search_rounded,
        title: s.searchExploreNow,
        subtitle: 'Search for clothes, brands, and more',
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (_errorMsg != null) {
      return _EmptyState(
        icon: Icons.wifi_off_outlined,
        title: _errorMsg!,
        isError: true,
      );
    }

    if (_results.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: s.searchNoResults,
        subtitle: 'Try different keywords or filters',
        isError: true,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${s.searchResultsTitle} (${_results.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.black54,
                  ),
                  label: const Text(
                    'Clear filters',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
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
                childAspectRatio: 0.52,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              itemBuilder: (_, i) {
                  final product = _results[i];

                  return ProductCard(
                    productId: product.id,
                    name: product.name.isEmpty ? 'Product' : product.name,
                    brand: product.brandName.isEmpty ? 'Brand' : product.brandName,
                    price: '${product.minPrice.toStringAsFixed(2)} EGP',
                    imageUrl: _fullProductImageUrl(product.imageUrl),
                    showWishlist: false,
                    onTap: () {
                      if (product.id == 0) return;

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
          ),
        ],
      ),
    );
  }
}

class _Opt {
  final int id;
  final String name;

  _Opt(this.id, this.name);
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
        .firstWhere(
          (e) => e.id == selectedId,
          orElse: () => _Opt(0, label),
        )
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _displayLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isActive ? Colors.white : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    int? tempSelected = selectedId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (options.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Loading…',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: options
                          .map(
                            (opt) => RadioListTile<int?>(
                              value: opt.id,
                              groupValue: tempSelected,
                              onChanged: (v) {
                                setSheet(() => tempSelected = v);
                              },
                              title: Text(
                                opt.name,
                                style: TextStyle(
                                  fontWeight: tempSelected == opt.id
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                              activeColor: Colors.black,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
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
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: const Text('Clear'),
                          ),
                        ),
                      ),
                    ],
                  ),
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isError;

  const _EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

List<dynamic> _asList(dynamic v) {
  if (v is List) return v;

  if (v is Map) {
    for (final k in ['content', 'data', 'items', 'variants', 'results']) {
      if (v[k] is List) return v[k] as List;
    }
  }

  return [];
}

String _str(dynamic v) {
  if (v == null) return '';
  final s = v.toString().trim();
  return s == 'null' ? '' : s;
}


String? _fullProductImageUrl(String? url) {
  final value = url?.trim() ?? '';

  if (value.isEmpty) return null;
  if (value.startsWith('http')) return value;
  if (value.startsWith('/')) return '$_kBase$value';

  return '$_kBase/$value';
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}