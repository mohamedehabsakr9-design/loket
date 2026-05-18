import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_strings.dart';

const String _kBase = 'https://lokit-production.up.railway.app';

class AiTryOnResultScreen extends StatefulWidget {
  final String resultImageUrl;
  final int? productId;

  const AiTryOnResultScreen({
    super.key,
    required this.resultImageUrl,
    this.productId,
  });

  @override
  State<AiTryOnResultScreen> createState() => _AiTryOnResultScreenState();
}

class _AiTryOnResultScreenState extends State<AiTryOnResultScreen> {
  bool _retrying = false;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.resultImageUrl;
  }

  Future<Response> _sendTryOnRequest({
    required Dio dio,
    required String imagePath,
    required int productId,
  }) async {
    final formData = FormData.fromMap({
      'userImage': await MultipartFile.fromFile(
        imagePath,
        filename: 'user_photo.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
      'productId': productId.toString(),
    });

    if (kDebugMode) {
      debugPrint('POST /ai/try-on');
      debugPrint('multipart => userImage + productId=$productId');
    }

    return await dio.post(
      '/ai/try-on',
      data: formData,
    );
  }

  Future<void> _retry() async {
    final productId = widget.productId;

    if (productId == null || productId == 0) {
      _snack('No product to retry', err: true);
      return;
    }

    final src = await _askSource();
    if (src == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: src,
      imageQuality: 75,
      maxWidth: 900,
    );

    if (picked == null || !mounted) return;

    setState(() => _retrying = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = (prefs.getString('token') ??
              prefs.getString('jwt') ??
              prefs.getString('accessToken') ??
              '')
          .replaceFirst('Bearer ', '')
          .trim();

      final file = File(picked.path);

      if (!await file.exists()) {
        _snack('Selected image not found', err: true);
        return;
      }

      final fileSize = await file.length();

      final dio = Dio(
        BaseOptions(
          baseUrl: _kBase,
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 180),
          validateStatus: (status) => status != null && status < 600,
          headers: {
            'Accept': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        ),
      );

      if (kDebugMode) {
        debugPrint('token exists: ${token.isNotEmpty}');
        debugPrint('picked image size: $fileSize bytes');
      }

      final response = await _sendTryOnRequest(
        dio: dio,
        imagePath: picked.path,
        productId: productId,
      );

      if (kDebugMode) {
        debugPrint('TryOn status: ${response.statusCode}');
        debugPrint('TryOn body: ${response.data}');
      }

      if (!mounted) return;

      if ((response.statusCode ?? 0) >= 400) {
        _snack(_extractError(response.data), err: true);
        return;
      }

      final url = _extractUrl(response.data);

      if (url == null || url.isEmpty) {
        _snack('No result image returned', err: true);
        return;
      }

      setState(() => _currentUrl = url);
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('DioException: ${e.message}');
        debugPrint('Dio status: ${e.response?.statusCode}');
        debugPrint('Dio body: ${e.response?.data}');
      }

      if (!mounted) return;

      _snack(
        e.response != null
            ? _extractError(e.response!.data)
            : (e.message ?? 'Network error'),
        err: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TryOn exception: $e');
      }

      if (!mounted) return;

      _snack(e.toString().replaceFirst('Exception: ', ''), err: true);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<ImageSource?> _askSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _extractError(dynamic body) {
    if (body is Map) {
      return (body['message'] ??
              body['error'] ??
              body['detail'] ??
              'Server error')
          .toString();
    }

    return body?.toString() ?? 'Unknown error';
  }

  String? _extractUrl(dynamic body) {
    if (body is Map) {
      return (body['resultImageUrl'] ??
              body['outputImageUrl'] ??
              body['imageUrl'] ??
              body['url'] ??
              body['result'])
          ?.toString();
    }

    if (body is String && body.startsWith('http')) {
      return body;
    }

    return null;
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: err ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final url = _currentUrl ?? widget.resultImageUrl;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _retrying ? null : () => Navigator.pop(context),
          ),
          title: Text(
            s.aiResultTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          actions: [
            if (_retrying)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Try again with a new photo',
                onPressed: _retry,
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _retrying
                  ? const _GeneratingView()
                  : _ResultImageView(
                      imageUrl: url,
                      failedText:
                          isAr ? 'تعذّر تحميل الصورة' : 'Failed to load image',
                    ),
            ),
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _retrying ? null : _retry,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(s.aiResultRetryButton),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _retrying ? null : () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: Text(s.aiResultBuyButton),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Generating result…',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultImageView extends StatelessWidget {
  final String imageUrl;
  final String failedText;

  const _ResultImageView({
    required this.imageUrl,
    required this.failedText,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          cacheWidth: 1080,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;

            final expected = progress.expectedTotalBytes;
            final loaded = progress.cumulativeBytesLoaded;

            return Center(
              child: CircularProgressIndicator(
                value: expected != null ? loaded / expected : null,
                color: Colors.white,
              ),
            );
          },
          errorBuilder: (_, __, ___) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
                const SizedBox(height: 12),
                Text(
                  failedText,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}