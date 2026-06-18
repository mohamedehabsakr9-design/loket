import 'package:flutter/foundation.dart';

import '../api/api_endpoints.dart';
import '../models/product_search_model.dart';
import '../../services/api_service.dart';

class SearchService {
  Future<List<ProductSearchModel>> searchProducts({
    String? keyword,
    int? departmentId,
    int? brandId,
    int? categoryId,
    double? minPrice,
    double? maxPrice,
  }) async {
    final params = <String, dynamic>{};

    final cleanKeyword = keyword?.trim();

    if (cleanKeyword != null && cleanKeyword.isNotEmpty) {
      params['keyword'] = cleanKeyword;
    }

    if (departmentId != null && departmentId > 0) {
      params['departmentId'] = departmentId;
    }

    if (brandId != null && brandId > 0) {
      params['brandId'] = brandId;
    }

    if (categoryId != null && categoryId > 0) {
      params['categoryId'] = categoryId;
    }

    // colorId و sizeId مقصود إنهم مش موجودين هنا
    // لأنهم UI فقط ومش بيتبعتوا للباك إند.

    if (minPrice != null && minPrice > 0) {
      params['minPrice'] = minPrice;
    }

    if (maxPrice != null && maxPrice > 0) {
      params['maxPrice'] = maxPrice;
    }

    if (kDebugMode) {
      debugPrint('SEARCH PARAMS: $params');
    }

    final data = await ApiService.get(
      ApiEndpoints.search,
      queryParameters: params,
    );

    if (kDebugMode) {
      debugPrint('SEARCH RESPONSE: $data');
    }

    final list = _extractList(data);

    if (kDebugMode) {
      debugPrint('SEARCH LIST LENGTH: ${list.length}');
    }

    return list
        .whereType<Map<dynamic, dynamic>>()
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
      const possibleKeys = [
        'content',
        'data',
        'products',
        'items',
        'result',
        'results',
      ];

      for (final key in possibleKeys) {
        final value = data[key];

        if (value is List) {
          return value;
        }

        if (value is Map) {
          final nestedList = _extractList(value);

          if (nestedList.isNotEmpty) {
            return nestedList;
          }
        }
      }
    }

    return [];
  }
}
