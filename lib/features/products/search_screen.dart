import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/models/product_search_model.dart';
import '../../core/services/search_service.dart';
import '../../services/api_service.dart';
import '../../services/wishlist_service.dart';
import '../../widgets/lokit_bottom_nav_bar.dart';
import 'product_details_screen.dart';

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

  final Set<int> _wishlistProductIds = <int>{};
  final Set<int> _wishlistLoadingIds = <int>{};

  List<_FilterOption> _departments = [];
  List<_FilterOption> _categories = [];
  List<_FilterOption> _brands = [];
  List<_FilterOption> _colors = [];

  int? _selDeptId;
  int? _selCatId;
  int? _selBrandId;
  int? _selColorId;

  bool get _hasActiveFilters =>
      _selDeptId != null || _selCatId != null || _selBrandId != null;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadWishlist();
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
        _departments = _parseOpts(
          results[0],
          idKeys: const ['id', 'departmentId', 'departmentID'],
          nameKeys: const ['name', 'departmentName', 'title'],
        );
        _categories = _parseOpts(
          results[1],
          idKeys: const ['id', 'categoryId', 'categoryID'],
          nameKeys: const ['name', 'categoryName', 'title'],
        );
        _brands = _parseOpts(
          results[2],
          idKeys: const ['id', 'brandId', 'brandID'],
          nameKeys: const ['name', 'brandName', 'title'],
        );

        _colors = [
          _FilterOption(0, 'All'),
        ];
      });
    } catch (_) {}
  }

  List<_FilterOption> _parseOpts(
    dynamic data, {
    required List<String> idKeys,
    required List<String> nameKeys,
  }) {
    final list = data is List
        ? data
        : (data is Map && data['content'] is List
            ? data['content']
            : (data is Map && data['data'] is List ? data['data'] : []));

    return (list as List)
        .whereType<Map>()
        .map<_FilterOption>((raw) {
          final e = Map<String, dynamic>.from(raw);
          final id = _firstInt(e, idKeys);
          final name = _firstString(e, nameKeys);
          return _FilterOption(id, name);
        })
        .where((e) => e.id > 0 && e.name.isNotEmpty)
        .toList();
  }

  int _firstInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  String _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  Future<void> _loadWishlist() async {
    try {
      final wishlist = await WishlistService.getWishlist();
      final ids = wishlist
          .map(_extractWishlistProductId)
          .where((id) => id != 0)
          .toSet();

      if (!mounted) return;
      setState(() {
        _wishlistProductIds
          ..clear()
          ..addAll(ids);
      });
    } catch (_) {}
  }

  int _extractWishlistProductId(dynamic item) {
    if (item is! Map) return 0;

    final product = item['product'];
    final id = item['productId'] ??
        item['idProduct'] ??
        item['product_id'] ??
        item['productID'] ??
        item['wishlistProductId'] ??
        (product is Map ? product['id'] : null) ??
        item['id'];

    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '') ?? 0;
  }

  Future<void> _toggleWishlist(int productId) async {
    final s = AppStrings.of(context);

    if (productId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isArabic ? 'لم يتم العثور على المنتج' : 'Product not found',
          ),
        ),
      );
      return;
    }

    if (_wishlistLoadingIds.contains(productId)) return;

    final wasFavorite = _wishlistProductIds.contains(productId);

    setState(() {
      _wishlistLoadingIds.add(productId);
    });

    try {
      if (wasFavorite) {
        await WishlistService.removeFromWishlist(productId);
      } else {
        await WishlistService.addToWishlist(productId);
      }

      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          _wishlistProductIds.remove(productId);
        } else {
          _wishlistProductIds.add(productId);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasFavorite
                ? (s.isArabic
                    ? 'تمت الإزالة من المفضلة'
                    : 'Removed from wishlist')
                : (s.isArabic
                    ? 'تمت الإضافة إلى المفضلة'
                    : 'Added to wishlist'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _wishlistLoadingIds.remove(productId);
      });
    }
  }

  void _onQueryChanged(String v) {
    final text = v.trim();

    setState(() {
      _query = v;
      if (text.isEmpty && !_hasActiveFilters) {
        _hasSearched = false;
        _results = [];
        _errorMsg = null;
        _isLoading = false;
      }
    });

    if (text.isEmpty) {
      if (_hasActiveFilters) _search();
      return;
    }

    if (text.length < 2) return;

    final t = DateTime.now();
    _lastTyped = t;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (_lastTyped == t && mounted) _search();
    });
  }

  Future<void> _search() async {
    final keyword = _query.trim();

    if (keyword.isEmpty && !_hasActiveFilters) {
      setState(() {
        _isLoading = false;
        _hasSearched = false;
        _results = [];
        _errorMsg = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final r = await _searchSvc.searchProducts(
        keyword: keyword.isEmpty ? null : keyword,
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
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasSearched = true;
        _errorMsg = e.response?.data is Map
            ? e.response?.data['message']?.toString()
            : 'Connection error. Please try again.';
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

  void _applyFilter() {
    if (_query.trim().isEmpty && !_hasActiveFilters) {
      setState(() {
        _hasSearched = false;
        _results = [];
        _errorMsg = null;
        _isLoading = false;
      });
      return;
    }

    _search();
  }

  void _clearFilters() {
    setState(() {
      _selDeptId = null;
      _selCatId = null;
      _selBrandId = null;
    });

    _applyFilter();
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
                          _FilterChip(
                            label: 'Department',
                            options: _departments,
                            selectedId: _selDeptId,
                            onSelected: (id) {
                              setState(() => _selDeptId = id);
                              _applyFilter();
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Category',
                            options: _categories,
                            selectedId: _selCatId,
                            onSelected: (id) {
                              setState(() => _selCatId = id);
                              _applyFilter();
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Brand',
                            options: _brands,
                            selectedId: _selBrandId,
                            onSelected: (id) {
                              setState(() => _selBrandId = id);
                              _applyFilter();
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
        bottomNavigationBar: const LokitBottomNavBar(
          currentTab: LokitBottomTab.search,
        ),
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
                  onPressed: _clearFilters,
                  icon: const Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.black54,
                  ),
                  label: const Text(
                    'Clear filters',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
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
                childAspectRatio: 0.62,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              itemBuilder: (_, i) {
                final product = _results[i];

                return _ProductCard(
                  product: product,
                  isFavorite: _wishlistProductIds.contains(product.id),
                  isWishlistLoading: _wishlistLoadingIds.contains(product.id),
                  onWishlistTap: () => _toggleWishlist(product.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterOption {
  final int id;
  final String name;

  _FilterOption(this.id, this.name);
}

class _FilterChip extends StatelessWidget {
  final String label;
  final List<_FilterOption> options;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  const _FilterChip({
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = selectedId != null;
    final displayLabel = isActive
        ? options
            .firstWhere(
              (e) => e.id == selectedId,
              orElse: () => _FilterOption(0, label),
            )
            .name
        : label;

    return GestureDetector(
      onTap: () => _showPicker(context),
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
              displayLabel,
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

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
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
                  const Spacer(),
                  if (selectedId != null)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onSelected(null);
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                ],
              ),
            ),
            if (options.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Loading…',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: options.map((opt) {
                    final isSelected = opt.id == selectedId;

                    return ListTile(
                      title: Text(
                        opt.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.black,
                              size: 18,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(opt.id);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: isSelected ? Colors.grey.shade100 : null,
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductSearchModel product;
  final bool isFavorite;
  final bool isWishlistLoading;
  final VoidCallback onWishlistTap;

  const _ProductCard({
    required this.product,
    required this.isFavorite,
    required this.isWishlistLoading,
    required this.onWishlistTap,
  });

  @override
  Widget build(BuildContext context) {
    final img = _fullImg(product.imageUrl);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(productId: product.id),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: SizedBox(
                    height: 175,
                    width: double.infinity,
                    child: img.isEmpty
                        ? _placeholder()
                        : Image.network(
                            img,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, p) => p == null
                                ? child
                                : Container(
                                    color: Colors.grey[100],
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black26,
                                      ),
                                    ),
                                  ),
                            errorBuilder: (_, __, ___) => _placeholder(),
                          ),
                  ),
                ),
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: InkWell(
                    onTap: onWishlistTap,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: isWishlistLoading
                          ? const Padding(
                              padding: EdgeInsets.all(9),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 19,
                              color: isFavorite ? Colors.red : Colors.black54,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brandName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${product.minPrice.toStringAsFixed(2)} EGP',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.grey),
      ),
    );
  }

  String _fullImg(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$_kBase$url';
    return '$_kBase/$url';
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
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isError ? Colors.red.shade50 : const Color(0xFFF2F2F2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 52,
              color: isError ? Colors.redAccent.shade100 : Colors.black38,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}