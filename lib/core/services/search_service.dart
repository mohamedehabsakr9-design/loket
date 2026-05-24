import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/product_search_model.dart';

class SearchService {
  final Dio _dio = ApiClient().dio;

  // GET /products/search
  // Supported params: keyword, brandId, categoryId, colorId, sizeId, minPrice, maxPrice
  // NOTE: departmentId is NOT supported by the backend search endpoint
  Future<List<ProductSearchModel>> searchProducts({
    String? keyword,
    int? brandId,
    int? categoryId,
    int? colorId,
    int? sizeId,
    double? minPrice,
    double? maxPrice,
  }) async {
    final Map<String, dynamic> params = {};

    final clean = keyword?.trim();
    if (clean != null && clean.isNotEmpty) params['keyword'] = clean;

    if (brandId    != null && brandId    > 0) params['brandId']    = brandId;
    if (categoryId != null && categoryId > 0) params['categoryId'] = categoryId;
    if (colorId    != null && colorId    > 0) params['colorId']    = colorId;
    if (sizeId     != null && sizeId     > 0) params['sizeId']     = sizeId;
    if (minPrice   != null)                   params['minPrice']   = minPrice;
    if (maxPrice   != null)                   params['maxPrice']   = maxPrice;

    final response = await _dio.get(
      ApiEndpoints.search,
      queryParameters: params,
    );

    return _extractList(response.data)
        .whereType<Map>()
        .map((e) => ProductSearchModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in ['content', 'data', 'products', 'items', 'result', 'results']) {
        if (data[key] is List) return data[key] as List;
      }
    }
    return [];
  }
}