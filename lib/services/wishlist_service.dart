import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class WishlistService {
  static const String _removedWishlistPrefix = 'lokit_removed_wishlist_products';

  static Future<List<dynamic>> getWishlist() async {
    final data = await ApiService.get(
      '/wishlist',
      withAuth: true,
    );

    debugPrint('WISHLIST RESPONSE: $data');

    final wishlist = _extractList(data);
    final removedIds = await _getLocallyRemovedProductIds();

    return wishlist.where((item) {
      final productId = _extractProductId(item);
      return productId != 0 && !removedIds.contains(productId);
    }).toList();
  }

  static Future<dynamic> addToWishlist(int productId) async {
    await _unhideProductLocally(productId);

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

      /*
        Important:
        If delete failed before, the product still exists in backend wishlist.
        So backend may return "Product already in wishlist".
        In this case we treat add as success after un-hiding it locally.
      */
      final rawWishlist = await _getRawWishlist();

      final existsOnServer = rawWishlist.any((item) {
        return _extractProductId(item) == productId;
      });

      if (existsOnServer) {
        return {
          'success': true,
          'message': 'Product already exists in wishlist',
          'productId': productId,
        };
      }

      rethrow;
    }
  }

  static Future<void> removeFromWishlist(int productId) async {
    /*
      Backend currently returns 500 for DELETE /wishlist/{productId}.
      We still try the real API first.
      If it fails, we hide the product locally so the UI works.
    */
    try {
      await ApiService.delete(
        '/wishlist/$productId',
        withAuth: true,
      );

      debugPrint('REMOVED FROM SERVER WISHLIST PRODUCT ID: $productId');
    } catch (e) {
      debugPrint('REMOVE WISHLIST SERVER ERROR, HIDING LOCALLY: $e');
    }

    await _hideProductLocally(productId);
  }

  static Future<bool> isInWishlist(int productId) async {
    final removedIds = await _getLocallyRemovedProductIds();

    if (removedIds.contains(productId)) {
      return false;
    }

    final rawWishlist = await _getRawWishlist();

    return rawWishlist.any((item) {
      return _extractProductId(item) == productId;
    });
  }

  static Future<List<dynamic>> _getRawWishlist() async {
    final data = await ApiService.get(
      '/wishlist',
      withAuth: true,
    );

    return _extractList(data);
  }

  static Future<void> _hideProductLocally(int productId) async {
    if (productId == 0) return;

    final prefs = await SharedPreferences.getInstance();
    final key = await _removedWishlistKey();
    final ids = await _getLocallyRemovedProductIds();

    ids.add(productId);

    await prefs.setStringList(
      key,
      ids.map((id) => id.toString()).toList(),
    );

    debugPrint('HIDDEN WISHLIST PRODUCT LOCALLY: $productId');
  }

  static Future<void> _unhideProductLocally(int productId) async {
    if (productId == 0) return;

    final prefs = await SharedPreferences.getInstance();
    final key = await _removedWishlistKey();
    final ids = await _getLocallyRemovedProductIds();

    ids.remove(productId);

    await prefs.setStringList(
      key,
      ids.map((id) => id.toString()).toList(),
    );

    debugPrint('UNHIDDEN WISHLIST PRODUCT LOCALLY: $productId');
  }

  static Future<Set<int>> _getLocallyRemovedProductIds() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _removedWishlistKey();
    final saved = prefs.getStringList(key) ?? [];

    return saved
        .map((id) => int.tryParse(id))
        .whereType<int>()
        .where((id) => id != 0)
        .toSet();
  }

  static Future<String> _removedWishlistKey() async {
    final token = await ApiService.getToken();
    final userKey = _userKeyFromToken(token);

    return '${_removedWishlistPrefix}_$userKey';
  }

  static String _userKeyFromToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      return 'guest';
    }

    try {
      final cleanToken = token.replaceFirst('Bearer ', '').trim();
      final parts = cleanToken.split('.');

      if (parts.length < 2) {
        return 'default';
      }

      final normalizedPayload = base64Url.normalize(parts[1]);
      final decodedPayload = utf8.decode(base64Url.decode(normalizedPayload));
      final payload = jsonDecode(decodedPayload);

      if (payload is Map) {
        final id = payload['id'] ??
            payload['userId'] ??
            payload['user_id'] ??
            payload['sub'] ??
            payload['email'];

        if (id != null && id.toString().trim().isNotEmpty) {
          return id.toString();
        }
      }

      return 'default';
    } catch (_) {
      return 'default';
    }
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

  final product = item['product'] ??
      item['productResponse'] ??
      item['productDto'] ??
      item['productDTO'] ??
      item['productDetails'];

  final id = item['productId'] ??
      item['idProduct'] ??
      item['product_id'] ??
      item['productID'] ??
      item['product_id_fk'] ??
      item['wishlistProductId'] ??
      (product is Map
          ? product['id'] ??
              product['productId'] ??
              product['product_id'] ??
              product['productID']
          : null);

  if (id is int) return id;

  return int.tryParse(id?.toString() ?? '') ?? 0;
}