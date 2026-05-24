import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  final int productId;
  final String name;
  final String brand;
  final String price;
  final String? imageUrl;

  final bool isFavorite;
  final bool isWishlistLoading;

  final VoidCallback onWishlistTap;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.productId,
    required this.name,
    required this.brand,
    required this.price,
    required this.onTap,
    required this.isFavorite,
    required this.isWishlistLoading,
    required this.onWishlistTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Product Image
          Stack(
            children: [

              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 0.78,
                  child: _ProductImage(
                    imageUrl: imageUrl,
                  ),
                ),
              ),

              // Wishlist Button
              PositionedDirectional(
                top: 14,
                end: 14,
                child: InkWell(
                  onTap: onWishlistTap,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),

                    child: isWishlistLoading
                        ? const Padding(
                            padding: EdgeInsets.all(11),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )

                        : Icon(
                            isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,

                            color: const Color(0xFF1D282E),
                            size: 25,
                          ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Product Name
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 4),

          // Brand
          Text(
            brand,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w400,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 8),

          // Price
          Text(
            '\$$price',

            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;

  const _ProductImage({
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {

    if (imageUrl == null || imageUrl!.isEmpty) {
      return _placeholder();
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,

      loadingBuilder: (_, child, progress) {

        if (progress == null) {
          return child;
        }

        return Container(
          color: Colors.grey.shade100,

          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.black26,
            ),
          ),
        );
      },

      errorBuilder: (_, __, ___) {
        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,

      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.grey,
          size: 40,
        ),
      ),
    );
  }
}