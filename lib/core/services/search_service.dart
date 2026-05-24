import '../api/api_endpoints.dart';
import '../models/product_search_model.dart';
import '../../services/api_service.dart';

class SearchService {
  Future<List<ProductSearchModel>> searchProducts({
    String? keyword,
    int? brandId,
    int? categoryId,
    int? colorId,
    int? sizeId,
    double? minPrice,
    double? maxPrice,
  }) async {
    final params = <String, dynamic>{};

    final clean = keyword?.trim();

    if (clean != null && clean.isNotEmpty) {
      params['keyword'] = clean;
    }

    if (brandId != null && brandId > 0) {
      params['brandId'] = brandId;
    }

    if (categoryId != null && categoryId > 0) {
      params['categoryId'] = categoryId;
    }

    // colorId و sizeId dummy في الواجهة فقط
    // لذلك لا يتم إرسالهم للباك إند عشان البحث يفضل يطلع نتائج
    // if (colorId != null && colorId > 0) {
    //   params['colorId'] = colorId;
    // }
    //
    // if (sizeId != null && sizeId > 0) {
    //   params['sizeId'] = sizeId;
    // }

    if (minPrice != null) {
      params['minPrice'] = minPrice;
    }

    if (maxPrice != null) {
      params['maxPrice'] = maxPrice;
    }

    final data = await ApiService.get(
      ApiEndpoints.search,
      queryParameters: params,
    );

    return _extractList(data)
        .whereType<Map>()
        .map(
          (e) => ProductSearchModel.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) {
      return data;
    }

    if (data is Map) {
      for (final k in [
        'content',
        'data',
        'products',
        'items',
        'result',
        'results',
      ]) {
        if (data[k] is List) {
          return data[k] as List;
        }
      }
    }

    return [];
  }
}