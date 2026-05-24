import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/api_constants.dart';

class ApiService {
  // ⚠️ NO Content-Type in BaseOptions — set per-request so:
  //   1) multipart can omit it (Dio sets boundary automatically)
  //   2) Authorization header merges correctly in all Dio versions
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 600,
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

  // ── Build options per-request ─────────────────────────────────────────────
  static Future<Options> _options({
    bool withAuth = false,
    bool isMultipart = false,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      // Only set Content-Type for JSON — multipart sets its own with boundary
      if (!isMultipart) 'Content-Type': 'application/json',
    };

    if (withAuth) {
      final token = await getToken();
      if (kDebugMode) {
        debugPrint('[ApiService] Has Token: ${token != null && token.isNotEmpty}');
      }
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        if (kDebugMode) debugPrint('[ApiService] Authorization header set ✅');
      } else {
        if (kDebugMode) debugPrint('[ApiService] ⚠️ No token — request will be 401');
      }
    }

    return Options(headers: headers);
  }

  // ── HTTP verbs ─────────────────────────────────────────────────────────────

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
      if (kDebugMode) debugPrint('[ApiService] POST $endpoint body: $body');
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

  // ── Multipart — used by Try-On (NO Content-Type override, auth included) ──
  static Future<dynamic> postMultipart(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    Duration receiveTimeout = const Duration(seconds: 240),
  }) async {
    try {
      final opts = await _options(withAuth: true, isMultipart: true);
      opts.receiveTimeout = receiveTimeout;

      if (kDebugMode) debugPrint('[ApiService] POST multipart $path');
      final response = await _dio.post(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: opts,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  // ── Response handler ───────────────────────────────────────────────────────

  static dynamic _handleResponse(Response response) {
    final statusCode = response.statusCode ?? 0;
    final body = response.data;

    if (kDebugMode) {
      debugPrint('[ApiService] STATUS: $statusCode  URL: ${response.realUri}');
      if (body is List) {
        debugPrint('[ApiService] BODY: List(${body.length})');
      } else if (body is Map) {
        debugPrint('[ApiService] BODY: Map(${body.keys.length} keys)');
      } else {
        debugPrint('[ApiService] BODY: $body');
      }
    }

    if (statusCode >= 200 && statusCode < 300) return body;

    String errorMessage = 'Request failed ($statusCode)';
    if (statusCode == 401) errorMessage = 'Session expired. Please login again.';
    else if (statusCode == 403) errorMessage = 'You do not have permission for this action.';
    else if (statusCode == 404) errorMessage = 'Not found.';
    else if (statusCode == 400 || statusCode == 422) errorMessage = 'Invalid request data.';
    else if (statusCode >= 500) errorMessage = 'Server error. Please try again later.';

    if (body is Map) {
      final msg = body['message'] ?? body['error'] ?? body['msg'] ??
          body['detail'] ?? body['errors'];
      if (msg != null) errorMessage = msg.toString();
    } else if (body != null && body.toString().length < 300) {
      errorMessage = body.toString();
    }

    throw Exception(errorMessage);
  }

  static String _dioErrorMessage(DioException e) {
    if (e.response != null) {
      try {
        _handleResponse(e.response!);
      } catch (err) {
        return err.toString().replaceFirst('Exception: ', '');
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Check your internet.';
      case DioExceptionType.receiveTimeout:
        return 'The server took too long to respond. Try again.';
      case DioExceptionType.sendTimeout:
        return 'Upload timeout. Try again.';
      case DioExceptionType.connectionError:
        return 'Connection error. Check your internet.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return e.message ?? 'Network error.';
    }
  }
}