class ProductSearchModel {
  final int id;
  final String name;
  final String? description;
  final String brandName;
  final String categoryName;
  final String? imageUrl;
  final double minPrice;

  ProductSearchModel({
    required this.id,
    required this.name,
    this.description,
    required this.brandName,
    required this.categoryName,
    this.imageUrl,
    required this.minPrice,
  });

  factory ProductSearchModel.fromJson(Map<String, dynamic> json) {
    return ProductSearchModel(
      id: _toInt(
        json['id'] ??
            json['productId'] ??
            json['productID'] ??
            json['product_id'],
      ),
      name: _toString(
        json['name'] ??
            json['productName'] ??
            json['title'],
      ),
      description: _nullableString(json['description']),
      brandName: _toString(
        json['brandName'] ??
            json['brand']?['name'] ??
            json['brandResponse']?['name'],
      ),
      categoryName: _toString(
        json['categoryName'] ??
            json['category']?['name'] ??
            json['categoryResponse']?['name'],
      ),
      imageUrl: _nullableString(
        json['imageUrl'] ??
            json['mainImageUrl'] ??
            json['mainImage'] ??
            json['thumbnail'],
      ),
      minPrice: _toDouble(
        json['minPrice'] ??
            json['price'] ??
            json['lowestPrice'],
      ),
    );
  }
}

String _toString(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

String? _nullableString(dynamic value) {
  if (value == null) return null;

  final text = value.toString();

  if (text.isEmpty || text == 'null') return null;

  return text;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}