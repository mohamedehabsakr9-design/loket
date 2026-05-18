import 'api_service.dart';

class ProductService {
  // ── Home page ──────────────────────────────────────────────────────────────

  /// New-arrivals section on home screen
  static Future<List<dynamic>> getNewArrivals() async {
    final data = await ApiService.get('/products/new-arrivals');
    return _extractList(data);
  }

  /// Latest / recommended section on home screen
  static Future<List<dynamic>> getLatestProducts() async {
    final data = await ApiService.get('/products/latest');
    return _extractList(data);
  }

  // ── Product detail ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProductDetails(int productId) async {
    final data = await ApiService.get('/product/$productId/details');
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  static Future<List<dynamic>> getProductVariants(int productId) async {
    final data = await ApiService.get('/variants/product/$productId');
    return _extractList(data);
  }

  static Future<List<dynamic>> getProductImages(int productId) async {
    final data =
        await ApiService.get('/product-images/product/$productId', withAuth: true);
    return _extractList(data);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['content'] is List) return data['content'];
    if (data is Map && data['data'] is List) return data['data'];
    if (data is Map && data['products'] is List) return data['products'];
    return [];
  }
}
