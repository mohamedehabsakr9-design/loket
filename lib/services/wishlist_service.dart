import 'package:flutter/foundation.dart';

import 'api_service.dart';

class WishlistService {
  static Future<List<dynamic>> getWishlist() async {
    final data = await ApiService.get(
      '/wishlist',
      withAuth: true,
    );

    debugPrint('WISHLIST RESPONSE: $data');

    return _extractList(data);
  }

  static Future<dynamic> addToWishlist(int productId) async {
    try {
      final response = await ApiService.post(
        '/wishlist',
        body: {
          'productId': productId,
        },
        withAuth: true,
      );

      debugPrint('ADD TO WISHLIST RESPONSE: $response');

      return response;
    } catch (e) {
      debugPrint('ADD TO WISHLIST ERROR: $e');

      return ApiService.post(
        '/wishlist/add',
        body: {
          'productId': productId,
        },
        withAuth: true,
      );
    }
  }

  static Future<void> removeFromWishlist(int productId) async {
    try {
      await ApiService.delete(
        '/wishlist/$productId',
        withAuth: true,
      );
    } catch (e) {
      debugPrint('REMOVE WISHLIST ERROR: $e');

      await ApiService.delete(
        '/wishlist/remove/$productId',
        withAuth: true,
      );
    }
  }

  static Future<bool> isInWishlist(int productId) async {
    final wishlist = await getWishlist();

    return wishlist.any((item) {
      final id = _extractProductId(item);
      return id == productId;
    });
  }
}

List<dynamic> _extractList(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['content'] is List) return data['content'];
  if (data is Map && data['items'] is List) return data['items'];
  if (data is Map && data['data'] is List) return data['data'];
  if (data is Map && data['wishlist'] is List) return data['wishlist'];
  return [];
}

int _extractProductId(dynamic item) {
  if (item is! Map) return 0;

  final product = item['product'];

  final id = item['productId'] ??
      item['id'] ??
      item['wishlistProductId'] ??
      item['product_id'] ??
      (product is Map ? product['id'] : null);

  if (id is int) return id;

  return int.tryParse(id?.toString() ?? '') ?? 0;
}