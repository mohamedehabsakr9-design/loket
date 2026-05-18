import 'api_service.dart';

/// Addresses service — uses /addresses (correct backend endpoint)
class ShippingService {
  static Future<List<dynamic>> getAddresses() async {
    final data = await ApiService.get('/addresses', withAuth: true);
    if (data is List) return data;
    if (data is Map && data['content'] is List) return data['content'];
    if (data is Map && data['data'] is List) return data['data'];
    return [];
  }

  static Future<bool> addAddress(Map<String, dynamic> address) async {
    final response = await ApiService.post(
      '/addresses',
      body: address,
      withAuth: true,
    );
    return response != null;
  }

  static Future<bool> updateAddress(
      int addressId, Map<String, dynamic> address) async {
    final response = await ApiService.put(
      '/addresses/$addressId',
      body: address,
      withAuth: true,
    );
    return response != null;
  }

  static Future<void> deleteAddress(int addressId) async {
    await ApiService.delete('/addresses/$addressId', withAuth: true);
  }
}
