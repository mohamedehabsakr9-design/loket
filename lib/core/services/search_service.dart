import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/product_search_model.dart';

class SearchService {
  final Dio _dio = ApiClient().dio;

  Future<List<ProductSearchModel>> searchProducts({
    String? keyword,
    int? departmentId,
    int? brandId,
    int? categoryId,
    int? colorId,
    int? sizeId,
    double? minPrice,
    double? maxPrice,
  }) async {
    final Map<String, dynamic> params = {};

    final cleanKeyword = keyword?.trim();
    if (cleanKeyword != null && cleanKeyword.isNotEmpty) {
      params['keyword'] = cleanKeyword;
    }

    // Do not send zero values because some dropdown parsers use zero as fallback.
    if (departmentId != null && departmentId > 0) {
      params['departmentId'] = departmentId;
    }
    if (brandId != null && brandId > 0) {
      params['brandId'] = brandId;
    }
    if (categoryId != null && categoryId > 0) {
      params['categoryId'] = categoryId;
    }
    if (colorId != null && colorId > 0) {
      params['colorId'] = colorId;
    }
    if (sizeId != null && sizeId > 0) {
      params['sizeId'] = sizeId;
    }
    if (minPrice != null) params['minPrice'] = minPrice;
    if (maxPrice != null) params['maxPrice'] = maxPrice;

    final response = await _dio.get(
      ApiEndpoints.search,
      queryParameters: params,
    );

    return _extractProducts(response.data)
        .whereType<Map>()
        .map((e) => ProductSearchModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<dynamic> _extractProducts(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      final keys = ['content', 'data', 'products', 'items', 'result', 'results'];
      for (final key in keys) {
        final value = data[key];
        if (value is List) return value;
      }
    }

    return [];
  }
}
