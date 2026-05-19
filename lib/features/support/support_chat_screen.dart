import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../products/product_details_screen.dart';

const String kBaseUrl = 'https://lokit-production.up.railway.app';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  static const String _storageKey = 'lokit_support_chat_messages_v2';

  // غير الرقم ده لرقم الدعم الحقيقي بصيغة دولية من غير + أو مسافات.
  // مثال مصر: 201001234567
  static const String _whatsAppPhoneNumber = '201022361089';
  static const String _whatsAppDisplayNumber = '+20 102 236 1089';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  List<_ProductSuggestion> _products = [];

  bool _loadingMessages = true;
  bool _loadingProducts = false;
  bool _botTyping = false;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    await _loadSavedMessages();
  }

  Future<void> _loadSavedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_storageKey) ?? [];

    final loaded = <_ChatMessage>[];

    for (final raw in saved) {
      try {
        final json = jsonDecode(raw);
        if (json is Map) {
          loaded.add(_ChatMessage.fromJson(Map<String, dynamic>.from(json)));
        }
      } catch (_) {
        // Ignore corrupted local messages.
      }
    }

    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..addAll(loaded);

      if (_messages.isEmpty) {
        _messages.add(
          _ChatMessage.bot(
            text: _isArabic
                ? 'أهلاً بيك في دعم Lokit 👋\nأقدر أساعدك في الطلبات، الشحن، المقاسات، الاسترجاع، أو أرشح لك منتجات مناسبة.'
                : 'Welcome to Lokit support 👋\nI can help with orders, shipping, sizes, returns, or recommend products for you.',
          ),
        );
      }

      _loadingMessages = false;
    });

    await _saveMessages();
    _scrollToBottomSoon();
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _messages
        .map((message) => jsonEncode(message.toJson()))
        .toList(growable: false);

    await prefs.setStringList(_storageKey, encoded);
  }

  Future<void> _ensureProductsLoaded() async {
    if (_products.isNotEmpty || _loadingProducts) return;

    if (mounted) {
      setState(() => _loadingProducts = true);
    }

    try {
      final response = await ApiService.get('/products/search');
      final list = _extractList(response);
      final products = list
          .map(_ProductSuggestion.fromJson)
          .where((product) => product.id != 0)
          .take(40)
          .toList();

      if (!mounted) return;

      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = (quickText ?? _messageController.text).trim();
    if (text.isEmpty || _botTyping) return;

    setState(() {
      _messages.add(_ChatMessage.user(text: text));
      _messageController.clear();
      _botTyping = true;
    });

    await _saveMessages();
    _scrollToBottomSoon();

    if (_isRecommendationRequest(text)) {
      await _ensureProductsLoaded();
    }

    await Future.delayed(const Duration(milliseconds: 450));

    final botMessages = _buildBotResponse(text);

    if (!mounted) return;

    setState(() {
      _messages.addAll(botMessages);
      _botTyping = false;
    });

    await _saveMessages();
    _scrollToBottomSoon();
  }

  bool _isRecommendationRequest(String text) {
    final lower = text.toLowerCase();

    return _containsAny(lower, text, [
      'recommend',
      'suggest',
      'products',
      'product',
      'outfit',
      'ترشيح',
      'رشح',
      'منتجات',
      'منتج',
      'لبس',
      'اوتفيت',
      'إطلالة',
      'اطلالة',
      'jeans',
      'tee',
      't-shirt',
      'shirt',
      'hoodie',
      'pants',
      'جينز',
      'تيشيرت',
      'هودي',
      'بنطلون',
    ]);
  }

  List<_ChatMessage> _buildBotResponse(String userText) {
    final lower = userText.toLowerCase();
    final ar = _isArabic;

    if (_containsAny(lower, userText, [
      'recommend',
      'suggest',
      'products',
      'product',
      'outfit',
      'ترشيح',
      'رشح',
      'منتجات',
      'منتج',
      'لبس',
      'اوتفيت',
      'إطلالة',
      'اطلالة',
      'jeans',
      'tee',
      't-shirt',
      'shirt',
      'hoodie',
      'pants',
      'جينز',
      'تيشيرت',
      'هودي',
      'بنطلون',
    ])) {
      final suggestions = _pickProductSuggestions(userText);

      if (suggestions.isEmpty) {
        return [
          _ChatMessage.bot(
            text: ar
                ? 'حالياً مش قادر أجيب ترشيحات منتجات، جرّب تفتح صفحة البحث أو ابعتلي نوع المنتج اللي محتاجه.'
                : 'I cannot load product suggestions right now. Try the search page or tell me what type of product you need.',
          ),
        ];
      }

      return [
        _ChatMessage.bot(
          text: ar
              ? 'أكيد، دي ترشيحات مناسبة من المنتجات المتاحة عندك:'
              : 'Sure, here are some product suggestions from the available catalog:',
        ),
        _ChatMessage.recommendations(
          text: ar ? 'ترشيحات المنتجات' : 'Product suggestions',
          productIds: suggestions.map((product) => product.id).toList(),
        ),
      ];
    }

    if (_containsAny(lower, userText, [
      'order',
      'orders',
      'طلب',
      'اوردر',
      'أوردر',
      'تتبع',
      'status',
    ])) {
      return [
        _ChatMessage.bot(
          text: ar
              ? 'تقدر تتابع حالة طلبك من Profile > My Orders. لو الطلب Pending استنى تأكيده، ولو Completed تقدر تقيّم التجربة.'
              : 'You can track your order from Profile > My Orders. Pending orders are waiting for confirmation, and completed orders can be rated.',
        ),
      ];
    }

    if (_containsAny(lower, userText, [
      'shipping',
      'delivery',
      'address',
      'شحن',
      'توصيل',
      'عنوان',
      'العنوان',
    ])) {
      return [
        _ChatMessage.bot(
          text: ar
              ? 'بالنسبة للشحن، تأكد إن عنوانك محفوظ صح من Profile > Shipping Address. مدة التوصيل بتختلف حسب المنطقة وحالة الطلب.'
              : 'For shipping, make sure your address is saved correctly from Profile > Shipping Address. Delivery time depends on your area and order status.',
        ),
      ];
    }

    if (_containsAny(lower, userText, [
      'size',
      'fit',
      'مقاس',
      'المقاس',
      'سايز',
      'مناسب',
    ])) {
      return [
        _ChatMessage.bot(
          text: ar
              ? 'عشان أساعدك في المقاس، ابعتلي طولك ووزنك والمقاس اللي بتلبسه عادة. ولو المنتج فيه Size من صفحة التفاصيل اختار الأقرب ليك.'
              : 'To help with sizing, send your height, weight, and usual size. If the product has sizes on its details page, pick the closest fit.',
        ),
      ];
    }

    if (_containsAny(lower, userText, [
      'return',
      'refund',
      'exchange',
      'استرجاع',
      'استبدال',
      'فلوس',
      'مرتجع',
    ])) {
      return [
        _ChatMessage.bot(
          text: ar
              ? 'لو محتاج استرجاع أو استبدال، افتح My Orders واختار الطلب. لو الطلب لسه Pending تقدر تلغيه، ولو Completed تواصل مع الدعم من هنا.'
              : 'For returns or exchanges, open My Orders and select the order. Pending orders can be cancelled, and completed orders can be discussed here.',
        ),
      ];
    }

    if (_containsAny(lower, userText, [
      'payment',
      'pay',
      'cash',
      'card',
      'دفع',
      'كاش',
      'فيزا',
      'بطاقة',
    ])) {
      return [
        _ChatMessage.bot(
          text: ar
              ? 'حالياً الدفع الأساسي المتاح هو Cash on Delivery. لو ظهرتلك بيانات كارت في صفحة Payment فهي شكل UI فقط لحد ما يتضاف بوابة دفع حقيقية.'
              : 'Currently, the main available payment method is Cash on Delivery. Card fields in Payment are UI-only until a payment gateway is added.',
        ),
      ];
    }

    if (_containsAny(lower, userText, [
      'hello',
      'hi',
      'hey',
      'السلام',
      'مرحبا',
      'اهلا',
      'أهلا',
    ])) {
      return [
        _ChatMessage.bot(
          text: ar
              ? 'أهلاً بيك 👋 تحب أساعدك في طلب، شحن، مقاس، أو أرشح لك منتجات؟'
              : 'Hi 👋 Would you like help with an order, shipping, sizing, or product recommendations?',
        ),
      ];
    }

    return [
      _ChatMessage.bot(
        text: ar
            ? 'تمام، أقدر أساعدك في الطلبات، الشحن، المقاسات، الاسترجاع، أو أرشح لك منتجات. اكتب مثلاً: "رشحلي تيشيرت" أو "فين طلبي؟".'
            : 'I can help with orders, shipping, sizes, returns, or product recommendations. Try: “recommend a t-shirt” or “where is my order?”.',
      ),
    ];
  }

  List<_ProductSuggestion> _pickProductSuggestions(String query) {
    if (_products.isEmpty) return [];

    final normalized = query.toLowerCase();
    final keywords = _keywordsFor(normalized);

    List<_ProductSuggestion> filtered = [];

    if (keywords.isNotEmpty) {
      filtered = _products.where((product) {
        final text = [
          product.name,
          product.brandName,
          product.categoryName,
          product.departmentName,
        ].join(' ').toLowerCase();

        return keywords.any(text.contains);
      }).toList();
    }

    if (filtered.isEmpty) {
      filtered = List<_ProductSuggestion>.from(_products);
    }

    filtered.sort((a, b) {
      final aScore = (a.price > 0 ? 1 : 0) + (a.imageUrl.isNotEmpty ? 1 : 0);
      final bScore = (b.price > 0 ? 1 : 0) + (b.imageUrl.isNotEmpty ? 1 : 0);
      return bScore.compareTo(aScore);
    });

    final seen = <int>{};
    return filtered.where((product) => seen.add(product.id)).take(6).toList();
  }

  List<String> _keywordsFor(String query) {
    final keywords = <String>[];

    void addAll(List<String> values) => keywords.addAll(values);

    if (query.contains('jeans') || query.contains('جينز')) {
      addAll(['jeans', 'pants', 'denim', 'جينز', 'pants']);
    }
    if (query.contains('tee') ||
        query.contains('t-shirt') ||
        query.contains('shirt') ||
        query.contains('تيشيرت') ||
        query.contains('تي شيرت')) {
      addAll(['tee', 'shirt', 't-shirt', 'tshirts', 't-shirts', 'تيشيرت']);
    }
    if (query.contains('hoodie') || query.contains('هودي')) {
      addAll(['hoodie', 'sweatshirt', 'هودي']);
    }
    if (query.contains('pants') || query.contains('بنطلون')) {
      addAll(['pants', 'trousers', 'بنطلون']);
    }
    if (query.contains('dress') || query.contains('فستان')) {
      addAll(['dress', 'فستان']);
    }
    if (query.contains('black') || query.contains('اسود') || query.contains('أسود')) {
      addAll(['black', 'اسود', 'أسود']);
    }
    if (query.contains('white') || query.contains('ابيض') || query.contains('أبيض')) {
      addAll(['white', 'ابيض', 'أبيض']);
    }

    return keywords.toSet().toList();
  }

  bool _containsAny(String lower, String original, List<String> words) {
    for (final word in words) {
      if (lower.contains(word.toLowerCase()) || original.contains(word)) {
        return true;
      }
    }
    return false;
  }


  Future<void> _openWhatsApp() async {
    final ar = _isArabic;

    // يفتح واتساب على رقم التطبيق فقط بدون أي رسالة جاهزة.
    final appUri = Uri.parse('whatsapp://send?phone=$_whatsAppPhoneNumber');
    final webUri = Uri.parse('https://wa.me/$_whatsAppPhoneNumber');

    var opened = false;

    try {
      opened = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }

    if (!opened) {
      try {
        opened = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ar
                ? 'تعذر فتح واتساب. تأكد إن واتساب مثبت على الجهاز.'
                : 'Could not open WhatsApp. Make sure WhatsApp is installed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _clearChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);

    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..add(
          _ChatMessage.bot(
            text: _isArabic
                ? 'أهلاً بيك في دعم Lokit 👋\nأقدر أساعدك في الطلبات، الشحن، المقاسات، الاسترجاع، أو أرشح لك منتجات مناسبة.'
                : 'Welcome to Lokit support 👋\nI can help with orders, shipping, sizes, returns, or recommend products for you.',
          ),
        );
    });

    await _saveMessages();
    _scrollToBottomSoon();
  }

  List<_ProductSuggestion> _productsForMessage(_ChatMessage message) {
    final ids = message.productIds.toSet();

    if (ids.isEmpty) return [];

    if (_products.isEmpty && !_loadingProducts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureProductsLoaded();
      });
    }

    return _products.where((product) {
      return ids.contains(product.id);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ar = _isArabic;

    final suggestions = ar
        ? [
            'رشحلي منتجات',
            'فين طلبي؟',
            'محتاج مقاس مناسب',
            'معلومات الشحن',
          ]
        : [
            'Recommend products',
            'Where is my order?',
            'Help me choose size',
            'Shipping info',
          ];

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _ChatHeader(
              title: ar ? 'الدعم والشات' : 'Support & Chat with us',
              onBack: () => Navigator.pop(context),
              onClear: _clearChat,
              clearLabel: ar ? 'مسح المحادثة' : 'Clear chat',
            ),
            Expanded(
              child: _loadingMessages
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                      itemCount: _messages.length + (_botTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_botTyping && index == _messages.length) {
                          return const _TypingBubble();
                        }

                        final message = _messages[index];

                        if (message.type == _ChatMessageType.recommendations) {
                          return _ProductRecommendationsBubble(
                            title: message.text,
                            products: _productsForMessage(message),
                            isLoading: _loadingProducts,
                          );
                        }

                        return _MessageBubble(
                          message: message,
                          onCopy: () async {
                            await Clipboard.setData(
                              ClipboardData(text: message.text),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ar ? 'تم النسخ' : 'Copied'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: _WhatsAppContactButton(
                label: ar ? 'تواصل معنا على واتساب' : 'Contact us on WhatsApp',
                phoneNumber: _whatsAppDisplayNumber,
                onTap: _openWhatsApp,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions.map((label) {
                    return _SuggestionChip(
                      label: label,
                      onTap: () => _sendMessage(label),
                    );
                  }).toList(),
                ),
              ),
            ),
            _ChatInputBar(
              controller: _messageController,
              hint: ar ? 'اكتب رسالتك...' : 'Type your message...',
              onSend: () => _sendMessage(),
              onCameraTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ar
                          ? 'رفع الصور غير متاح حالياً'
                          : 'Image upload is not available yet',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChatMessageType {
  text,
  recommendations,
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final _ChatMessageType type;
  final List<int> productIds;
  final DateTime createdAt;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.type,
    required this.productIds,
    required this.createdAt,
  });

  factory _ChatMessage.user({required String text}) {
    return _ChatMessage(
      text: text,
      isUser: true,
      type: _ChatMessageType.text,
      productIds: const [],
      createdAt: DateTime.now(),
    );
  }

  factory _ChatMessage.bot({required String text}) {
    return _ChatMessage(
      text: text,
      isUser: false,
      type: _ChatMessageType.text,
      productIds: const [],
      createdAt: DateTime.now(),
    );
  }

  factory _ChatMessage.recommendations({
    required String text,
    required List<int> productIds,
  }) {
    return _ChatMessage(
      text: text,
      isUser: false,
      type: _ChatMessageType.recommendations,
      productIds: productIds,
      createdAt: DateTime.now(),
    );
  }

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    final productIdsRaw = json['productIds'];

    return _ChatMessage(
      text: json['text']?.toString() ?? '',
      isUser: json['isUser'] == true,
      type: json['type'] == 'recommendations'
          ? _ChatMessageType.recommendations
          : _ChatMessageType.text,
      productIds: productIdsRaw is List
          ? productIdsRaw
              .map((id) => int.tryParse(id.toString()))
              .whereType<int>()
              .toList()
          : const [],
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'type': type == _ChatMessageType.recommendations
          ? 'recommendations'
          : 'text',
      'productIds': productIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class _ProductSuggestion {
  final int id;
  final String name;
  final String brandName;
  final String categoryName;
  final String departmentName;
  final String imageUrl;
  final double price;

  const _ProductSuggestion({
    required this.id,
    required this.name,
    required this.brandName,
    required this.categoryName,
    required this.departmentName,
    required this.imageUrl,
    required this.price,
  });

  factory _ProductSuggestion.fromJson(dynamic json) {
    final map = json is Map ? json : <String, dynamic>{};

    return _ProductSuggestion(
      id: _toInt(map['id'] ?? map['productId'] ?? map['productID']),
      name: _firstText([
        map['name'],
        map['productName'],
        map['title'],
      ], fallback: 'Product'),
      brandName: _firstText([
        map['brandName'],
        _nested(map, ['brand', 'name']),
        _nested(map, ['brandResponse', 'name']),
      ]),
      categoryName: _firstText([
        map['categoryName'],
        _nested(map, ['category', 'name']),
        _nested(map, ['categoryResponse', 'name']),
      ]),
      departmentName: _firstText([
        map['departmentName'],
        _nested(map, ['department', 'name']),
        _nested(map, ['departmentResponse', 'name']),
      ]),
      imageUrl: _fullImageUrl(
        _firstText([
          map['imageUrl'],
          map['mainImageUrl'],
          map['image'],
          map['thumbnail'],
          _firstImageFromList(map['images']),
          _firstImageFromList(map['productImages']),
        ]),
      ),
      price: _toDouble(map['minPrice'] ?? map['price'] ?? map['lowestPrice']),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final String clearLabel;

  const _ChatHeader({
    required this.title,
    required this.onBack,
    required this.onClear,
    required this.clearLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).padding.top + 104,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 24,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Material(
              color: const Color(0xFFF4F4F4),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack,
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.black),
              onSelected: (_) => onClear(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'clear',
                  child: Text(clearLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final VoidCallback onCopy;

  const _MessageBubble({
    required this.message,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: 18,
        start: isUser ? 72 : 0,
        end: isUser ? 0 : 42,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1D282E) : const Color(0xFFF6F6F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.33,
                  color: isUser ? Colors.white : const Color(0xFF2E3437),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (!isUser) ...[
            const SizedBox(width: 10),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: onCopy,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: Color(0xFF9B9B9B),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 18, end: 120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'Typing...',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductRecommendationsBubble extends StatelessWidget {
  final String title;
  final List<_ProductSuggestion> products;
  final bool isLoading;

  const _ProductRecommendationsBubble({
    required this.title,
    required this.products,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (isLoading && products.isEmpty) {
      return const Padding(
        padding: EdgeInsetsDirectional.only(bottom: 20, end: 48),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 20, end: 48),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isArabic ? 'لا توجد ترشيحات حالياً' : 'No recommendations now',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 22, end: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, bottom: 10),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            height: 228,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _ProductSuggestionCard(product: products[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductSuggestionCard extends StatelessWidget {
  final _ProductSuggestion product;

  const _ProductSuggestionCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(productId: product.id),
          ),
        );
      },
      child: Container(
        width: 145,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: SizedBox(
                width: 145,
                height: 130,
                child: product.imageUrl.isEmpty
                    ? _ProductImagePlaceholder(name: product.name)
                    : Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return _ProductImagePlaceholder(name: product.name);
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.brandName.isEmpty ? 'Lokit' : product.brandName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatMoney(product.price)} EGP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
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

class _ProductImagePlaceholder extends StatelessWidget {
  final String name;

  const _ProductImagePlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE9EFF2),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: Colors.black26,
        size: 34,
      ),
    );
  }
}


class _WhatsAppContactButton extends StatelessWidget {
  final String label;
  final String phoneNumber;
  final VoidCallback onTap;

  const _WhatsAppContactButton({
    required this.label,
    required this.phoneNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF25D366).withOpacity(0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phoneNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1D282E), width: 1.1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1D282E),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;
  final VoidCallback onCameraTap;

  const _ChatInputBar({
    required this.controller,
    required this.hint,
    required this.onSend,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onCameraTap,
                      icon: const Icon(
                        Icons.camera_alt_outlined,
                        color: Color(0xFF8D8D8D),
                        size: 23,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: const Color(0xFFDADADA),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        decoration: InputDecoration(
                          hintText: hint,
                          hintStyle: const TextStyle(
                            color: Color(0xFF474747),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: onSend,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF1D282E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<dynamic> _extractList(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['content'] is List) return data['content'] as List;
  if (data is Map && data['items'] is List) return data['items'] as List;
  if (data is Map && data['data'] is List) return data['data'] as List;
  if (data is Map && data['products'] is List) return data['products'] as List;
  return [];
}

dynamic _nested(dynamic source, List<String> path) {
  dynamic current = source;

  for (final key in path) {
    if (current is! Map) return null;
    current = current[key];
  }

  return current;
}

String _firstImageFromList(dynamic data) {
  if (data is! List || data.isEmpty) return '';

  final first = data.first;

  if (first is String) return first;

  if (first is Map) {
    return _firstText([
      first['imageUrl'],
      first['mainImageUrl'],
      first['url'],
      first['imagePath'],
      first['path'],
      first['image'],
      first['thumbnail'],
    ]);
  }

  return '';
}

String _firstText(List<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = _toText(value);
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _toText(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null') return '';
  return text;
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

String _fullImageUrl(String url) {
  final clean = url.trim();
  if (clean.isEmpty || clean == 'null') return '';
  if (clean.startsWith('http')) return clean;
  if (clean.startsWith('/')) return '$kBaseUrl$clean';
  return '$kBaseUrl/$clean';
}

String _formatMoney(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
