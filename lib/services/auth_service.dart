import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AuthService {
  static Future<dynamic> login({
    required String email,
    required String password,
  }) async {
    final data = await ApiService.post(
      '/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    debugPrint('=== LOGIN RESPONSE ===');
    debugPrint(data.toString());
    debugPrint('======================');

    final token = _extractToken(data);

    if (token != null && token.isNotEmpty) {
      await ApiService.saveToken(token);
      debugPrint('✅ Token saved!');
    } else {
      debugPrint('❌ No token found in response!');
    }

    return data;
  }

  static Future<dynamic> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
  }) async {
    final data = await ApiService.post(
      '/auth/register',
      body: {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'password': password,
        'phone': phone.trim(),
      },
    );

    debugPrint('=== REGISTER RESPONSE ===');
    debugPrint(data.toString());
    debugPrint('=========================');

    final token = _extractToken(data);

    if (token != null && token.isNotEmpty) {
      await ApiService.saveToken(token);
      debugPrint('✅ Token saved!');
    }

    return data;
  }

  static Future<dynamic> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    final token = await ApiService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('User not logged in / الرجاء تسجيل الدخول أولاً');
    }

    return ApiService.patch(
      '/account/password',
      body: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      },
      withAuth: true,
    );
  }

  static Future<bool> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await ApiService.post(
        '/auth/forgot-password',
        body: {
          'email': email.trim(),
        },
      );

      return _isSuccess(response);
    } catch (e) {
      debugPrint('❌ forgotPassword error: $e');
      return false;
    }
  }

  static Future<bool> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await ApiService.post(
        '/auth/verify-reset-code',
        body: {
          'email': email.trim(),
          'code': code.trim(),
        },
      );

      return _isSuccess(response);
    } catch (e) {
      debugPrint('❌ verifyResetCode error: $e');
      return false;
    }
  }

  static Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await ApiService.post(
        '/auth/reset-password',
        body: {
          'email': email.trim(),
          'otp': otp.trim(),
          'newPassword': newPassword,
        },
      );

      return _isSuccess(response);
    } catch (e) {
      debugPrint('❌ resetPassword error: $e');
      return false;
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await ApiService.getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<String?> getToken() async {
    return ApiService.getToken();
  }

  static Future<void> logout() async {
    await ApiService.clearToken();
    debugPrint('✅ Token cleared — user logged out');
  }

  static String? _extractToken(dynamic data) {
    if (data == null) return null;

    if (data is String && data.isNotEmpty) {
      return data.replaceFirst('Bearer ', '').trim();
    }

    if (data is Map) {
      final directToken = data['token'] ??
          data['accessToken'] ??
          data['access_token'] ??
          data['jwt'] ??
          data['Authorization'] ??
          data['authorization'];

      if (directToken != null) {
        return directToken.toString().replaceFirst('Bearer ', '').trim();
      }

      final nestedData = data['data'];
      if (nestedData is Map) {
        final nestedToken = nestedData['token'] ??
            nestedData['accessToken'] ??
            nestedData['access_token'] ??
            nestedData['jwt'];

        if (nestedToken != null) {
          return nestedToken.toString().replaceFirst('Bearer ', '').trim();
        }
      }

      final user = data['user'];
      if (user is Map) {
        final userToken = user['token'] ??
            user['accessToken'] ??
            user['access_token'] ??
            user['jwt'];

        if (userToken != null) {
          return userToken.toString().replaceFirst('Bearer ', '').trim();
        }
      }
    }

    return null;
  }

  static bool _isSuccess(dynamic response) {
    if (response == null) return true;
    if (response is bool) return response;

    if (response is String) {
      final value = response.toLowerCase();

      return value.contains('success') ||
          value.contains('sent') ||
          value.contains('done') ||
          value.contains('ok');
    }

    if (response is Map) {
      if (response['success'] != null) {
        return response['success'] == true;
      }

      if (response['status'] != null) {
        final status = response['status'].toString().toLowerCase();

        if (status == 'success' || status == 'ok') {
          return true;
        }
      }

      if (response['message'] != null ||
          response['token'] != null ||
          response['accessToken'] != null ||
          response['data'] != null) {
        return true;
      }
    }

    return true;
  }
}