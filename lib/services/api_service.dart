import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/api_constants.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ??
        prefs.getString('jwt') ??
        prefs.getString('accessToken');
  }

  static Future<void> saveToken(String token) async {
    final clean = token.replaceFirst('Bearer ', '').trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', clean);
    await prefs.setString('jwt', clean);
    await prefs.setString('accessToken', clean);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('jwt');
    await prefs.remove('accessToken');
  }

  static Future<Options> _options({bool withAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final token = await getToken();

      if (kDebugMode) {
        debugPrint('Has Token: ${token != null && token.isNotEmpty}');
      }

      if (token != null && token.isNotEmpty) {
        final clean = token.replaceFirst('Bearer ', '').trim();
        headers['Authorization'] = 'Bearer $clean';
      }
    }

    return Options(headers: headers);
  }

  static Future<dynamic> get(
    String endpoint, {
    bool withAuth = false,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
        options: await _options(withAuth: withAuth),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  static Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = false,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('POST $endpoint');
      }

      final response = await _dio.post(
        endpoint,
        data: body,
        options: await _options(withAuth: withAuth),
      );

      return _handleResponse(response);
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  static Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = false,
  }) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: body,
        options: await _options(withAuth: withAuth),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  static Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = false,
  }) async {
    try {
      final response = await _dio.patch(
        endpoint,
        data: body,
        options: await _options(withAuth: withAuth),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  static Future<dynamic> delete(
    String endpoint, {
    bool withAuth = false,
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.delete(
        endpoint,
        data: body,
        options: await _options(withAuth: withAuth),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  static Future<dynamic> postMultipart(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    Duration receiveTimeout = const Duration(seconds: 180),
  }) async {
    try {
      final token = await getToken();
      final cleanToken = token?.replaceFirst('Bearer ', '').trim();

      final response = await _dio.post(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (cleanToken != null && cleanToken.isNotEmpty)
              'Authorization': 'Bearer $cleanToken',
          },
          contentType: 'multipart/form-data',
          validateStatus: (s) => s != null && s < 600,
          receiveTimeout: receiveTimeout,
        ),
      );

      return _handleResponse(response);
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  static dynamic _handleResponse(Response response) {
    final statusCode = response.statusCode ?? 0;
    final body = response.data;

    if (kDebugMode) {
      debugPrint('STATUS: $statusCode');
      debugPrint('URL: ${response.realUri}');

      if (body is List) {
        debugPrint('BODY TYPE: List (${body.length} items)');
      } else if (body is Map) {
        debugPrint('BODY TYPE: Map (${body.keys.length} keys)');
      } else if (body == null) {
        debugPrint('BODY TYPE: null');
      } else {
        debugPrint('BODY TYPE: ${body.runtimeType}');
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      return body;
    }

    String errorMessage = 'Request failed: $statusCode';

    if (statusCode == 401) {
      errorMessage = 'Unauthorized. Please login again.';
    } else if (statusCode == 403) {
      errorMessage = 'Forbidden. You do not have permission.';
    } else if (statusCode == 404) {
      errorMessage = 'Not found.';
    } else if (statusCode >= 500) {
      errorMessage = 'Server error. Please try again later.';
    }

    if (body is Map) {
      final msg = body['message'] ??
          body['error'] ??
          body['msg'] ??
          body['detail'] ??
          body['errors'];

      if (msg != null) {
        errorMessage = msg.toString();
      }
    } else if (body != null && body.toString().length < 300) {
      errorMessage = body.toString();
    }

    throw Exception(errorMessage);
  }

  static String _dioErrorMessage(DioException e) {
    final response = e.response;

    if (response != null) {
      try {
        _handleResponse(response);
      } catch (err) {
        return err.toString().replaceFirst('Exception: ', '');
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Check your internet.';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout. Try again.';
      case DioExceptionType.sendTimeout:
        return 'Send timeout. Try again.';
      case DioExceptionType.connectionError:
        return 'Connection error. Check your internet.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return e.message ?? 'Network error.';
    }
  }
}