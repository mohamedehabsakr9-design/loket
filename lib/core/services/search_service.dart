import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/product_search_model.dart';

class SearchService {
  final Dio _dio = ApiClient().dio;

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

    if (keyword != null && keyword.trim().isNotEmpty) {
      params['keyword'] = keyword.trim();
    }

    if (brandId != null) params['brandId'] = brandId;
    if (categoryId != null) params['categoryId'] = categoryId;
    if (colorId != null) params['colorId'] = colorId;
    if (sizeId != null) params['sizeId'] = sizeId;
    if (minPrice != null) params['minPrice'] = minPrice;
    if (maxPrice != null) params['maxPrice'] = maxPrice;

    final response = await _dio.get(
      ApiEndpoints.search,
      queryParameters: params,
    );

    final data = response.data;

    List<dynamic> list = [];

    if (data is List) {
      list = data;
    } else if (data is Map && data['content'] is List) {
      list = data['content'];
    } else if (data is Map && data['data'] is List) {
      list = data['data'];
    } else if (data is Map && data['products'] is List) {
      list = data['products'];
    } else if (data is Map && data['items'] is List) {
      list = data['items'];
    }

    return list
        .whereType<Map>()
        .map(
          (e) => ProductSearchModel.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }
}