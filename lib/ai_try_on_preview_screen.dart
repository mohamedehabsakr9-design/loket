import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_try_on_result_screen.dart';
import 'app/app_strings.dart';

const String _kBase = 'https://lokit-production.up.railway.app';

class AiTryOnPreviewScreen extends StatefulWidget {
  final int? productId;
  const AiTryOnPreviewScreen({super.key, this.productId});

  @override
  State<AiTryOnPreviewScreen> createState() => _AiTryOnPreviewScreenState();
}

class _AiTryOnPreviewScreenState extends State<AiTryOnPreviewScreen> {
  File? _image;
  bool  _loading = false;
  final _picker = ImagePicker();

  // ── Image picking ─────────────────────────────────────────────────────────

  Future<void> _pick(ImageSource src) async {
    try {
      final picked = await _picker.pickImage(
        source: src,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (picked == null || !mounted) return;
      setState(() => _image = File(picked.path));
    } catch (e) {
      _snack('Could not open ${src == ImageSource.camera ? 'camera' : 'gallery'}', err: true);
    }
  }

  // ── Try-On call ───────────────────────────────────────────────────────────
  // POST /ai/try-on?productId={id}
  // Content-Type: multipart/form-data
  // Part name:    userImage
  // Response:     { resultImageUrl: String, message: String }

  Future<void> _tryOn() async {
    if (_image == null) {
      _snack('Please select a photo first', err: true);
      return;
    }
    final productId = widget.productId;
    if (productId == null || productId == 0) {
      _snack('No product selected', err: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = (prefs.getString('token') ??
              prefs.getString('jwt') ??
              prefs.getString('accessToken') ??
              '')
          .replaceFirst('Bearer ', '')
          .trim();

      if (token.isEmpty) {
        _snack('Please login first', err: true);
        return;
      }

      final dio = Dio(BaseOptions(
        baseUrl: _kBase,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 180), // FAL AI can be slow
        validateStatus: (s) => s != null && s < 600,
        headers: {'Authorization': 'Bearer $token'},
      ));

      final formData = FormData.fromMap({
        // Part name MUST match backend: @RequestPart("userImage")
        'userImage': await MultipartFile.fromFile(
          _image!.path,
          filename: 'user_photo.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      });

      debugPrint('POST /ai/try-on?productId=$productId');

      final response = await dio.post(
        '/ai/try-on',
        queryParameters: {'productId': productId},
        data: formData,
      );

      debugPrint('TryOn status: ${response.statusCode}');
      debugPrint('TryOn body:   ${response.data}');

      if (!mounted) return;

      if ((response.statusCode ?? 0) >= 400) {
        _snack(_extractError(response.data), err: true);
        return;
      }

      // TryOnResponse: { resultImageUrl: String, message: String }
      final resultUrl = _extractUrl(response.data);
      if (resultUrl == null || resultUrl.isEmpty) {
        _snack('No result image returned', err: true);
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiTryOnResultScreen(
            resultImageUrl: resultUrl,
            productId: productId,
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response != null
          ? _extractError(e.response!.data)
          : (e.message ?? 'Network error');
      _snack(msg, err: true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractError(dynamic body) {
    if (body is Map) {
      return (body['message'] ?? body['error'] ?? body['detail'] ?? 'Server error').toString();
    }
    return body?.toString() ?? 'Unknown error';
  }

  String? _extractUrl(dynamic body) {
    // TryOnResponse: { resultImageUrl, message }
    if (body is Map) {
      return (body['resultImageUrl'] ??
              body['outputImageUrl'] ??
              body['imageUrl'] ??
              body['url'] ??
              body['result'])
          ?.toString();
    }
    if (body is String && body.startsWith('http')) return body;
    return null;
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: err ? Colors.red : null,
    ));
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            s.aiPreviewTitle,
            style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        body: Column(
          children: [
            // ── Photo preview ──────────────────────────────────────────────
            Expanded(
              child: GestureDetector(
                onTap: _loading ? null : () => _showSheet(context),
                child: _image == null
                    ? _Placeholder(label: s.aiPreviewNoImage)
                    : _Preview(
                        file: _image!,
                        onRetake: _loading ? null : () => _showSheet(context),
                      ),
              ),
            ),

            // ── Processing banner ──────────────────────────────────────────
            if (_loading)
              Container(
                width: double.infinity,
                color: Colors.black.withOpacity(0.04),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isAr ? 'جاري المعالجة... قد يستغرق دقيقة' : 'Processing… this may take a minute',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),

            // ── Bottom actions ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                children: [
                  // Try On button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _tryOn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        disabledBackgroundColor: Colors.black38,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                      label: Text(
                        s.aiPreviewTryOnButton,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Camera / Gallery row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : () => _pick(ImageSource.camera),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(s.aiPreviewCamera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(s.aiPreviewGallery),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tip
                  Text(
                    isAr
                        ? 'للحصول على أفضل نتيجة، استخدم صورة أمامية كاملة الجسم'
                        : 'For best results, use a full-body front-facing photo',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () { Navigator.pop(ctx); _pick(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () { Navigator.pop(ctx); _pick(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder({required this.label});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person_outline, size: 90, color: Colors.grey[300]),
        const SizedBox(height: 14),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        const SizedBox(height: 6),
        Text('Tap to select a photo',
            style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    ),
  );
}

class _Preview extends StatelessWidget {
  final File file;
  final VoidCallback? onRetake;
  const _Preview({required this.file, this.onRetake});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(file, fit: BoxFit.contain),
          ),
        ),
      ),
      if (onRetake != null)
        Positioned(
          top: 24, right: 24,
          child: GestureDetector(
            onTap: onRetake,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          ),
        ),
    ],
  );
}
