class ApiEndpoints {
  static const String baseUrl = 'https://lokit-production.up.railway.app';

  // Auth
  static const String login           = '/auth/login';
  static const String register        = '/auth/register';
  static const String forgotPassword  = '/auth/forgot-password';
  static const String verifyResetCode = '/auth/verify-reset-code';
  static const String resetPassword   = '/auth/reset-password';

  // Account
  static const String account         = '/account';
  static const String changePassword  = '/account/password';

  // Products
  static const String allProducts     = '/product';
  static const String newArrivals     = '/products/new-arrivals';
  static const String latestProducts  = '/products/latest';
  static const String search           = '/products/search';
  static const String searchProducts  = '/products/search';

  // Cart
  static const String cart            = '/cart';
  static const String cartItems       = '/cart/items';

  // Wishlist
  static const String wishlist        = '/wishlist';

  // Orders
  static const String orders          = '/orders';

  // Addresses
  static const String addresses       = '/addresses';

  // Checkout
  static const String checkout        = '/checkout';

  // Brands / Departments / Categories
  static const String brands          = '/brand';
  static const String departments     = '/department';
  static const String categories      = '/category';
}
