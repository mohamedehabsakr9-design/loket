import 'package:flutter/material.dart';

class AppStrings {
  final bool isArabic;

  AppStrings._(this.isArabic);

  factory AppStrings.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return AppStrings._(locale.languageCode == 'ar');
  }

  String get appName => isArabic ? 'لوكيت' : 'Lokit';

  // ===================== Home =====================
  String get homeSearchHint =>
      isArabic ? 'ابحث عن الملابس...' : 'Search clothes...';
  String get homeShopByBrand =>
      isArabic ? 'تسوّق حسب الماركة' : 'Shop by Brand';
  String get homeTopRated =>
      isArabic ? 'أعلى المنتجات تقييماً' : 'Top Rated Products';
  String get homeNewArrivals =>
      isArabic ? 'وصل حديثًا' : 'New Arrivals';
  String get homeRecommended =>
      isArabic ? 'مقترح لك' : 'Recommended';

  String get homeMen => isArabic ? 'رجالي' : 'Men';
  String get homeWomen => isArabic ? 'حريمي' : 'Women';
  String get homeKids => isArabic ? 'أطفال' : 'Kids';
  String get homeUnisex => isArabic ? 'للجنسين' : 'Unisex';
  String get homeSportsWear => isArabic ? 'ملابس رياضية' : 'Sports Wear';

  String get homeSuccessTitle => isArabic ? 'تم بنجاح!' : 'Successful!';
  String get homeSuccessBody => isArabic
      ? 'تم تسجيلك بنجاح في التطبيق ويمكنك الآن البدء في استخدامه.'
      : 'You have successfully registered and can now start using the app.';
  String get homeSuccessOk => isArabic ? 'حسناً' : 'OK';

  String get homeProductName => isArabic ? 'اسم المنتج' : 'Product name';
  String get homeBrand => isArabic ? 'الماركة' : 'Brand';
  String get homeNoResults =>
      isArabic ? 'لا توجد نتائج مطابقة' : 'No matching results';

  // ===================== Profile =====================
  String get profilePersonalInfo =>
      isArabic ? 'المعلومات الشخصية' : 'Personal Information';
  String get profileEditProfile =>
      isArabic ? 'تعديل الملف الشخصي' : 'Edit Profile';
  String get profileMyOrders => isArabic ? 'طلباتي' : 'My Orders';
  String get profileShippingAddress =>
      isArabic ? 'عنوان الشحن' : 'Shipping Address';
  String get profileSupportInfo =>
      isArabic ? 'الدعم والمعلومات' : 'Support & Information';
  String get profilePrivacyPolicy =>
      isArabic ? 'سياسة الخصوصية' : 'Privacy Policy';
  String get profileSupportChat =>
      isArabic ? 'الدعم والدردشة معنا' : 'Support & Chat with us';
  String get profileAbout => isArabic ? 'حول التطبيق' : 'About';
  String get profileSettings => isArabic ? 'الإعدادات' : 'Settings';
  String get profileLanguage => isArabic ? 'اللغة' : 'Language';
  String get profileChangePassword =>
      isArabic ? 'تغيير كلمة المرور' : 'Change Password';
  String get profileReplicate => 'Replicate';
  String get profileLogout => isArabic ? 'تسجيل الخروج' : 'Log out';
  String get profileVersion => isArabic ? 'لوكيت v1.0.0' : 'Lokit v1.0.0';

  // ===================== About =====================
  String get aboutTitle => isArabic ? 'حول التطبيق' : 'About';
  String get aboutBody => isArabic
      ? 'هذا النص التعريفي بالتطبيق يمكن استبداله لاحقاً بمحتوى ديناميكي من الخادم.'
      : 'This about text can be replaced later with dynamic content from the server.';

  // ===================== Change Password =====================
  String get changePasswordTitle =>
      isArabic ? 'تغيير كلمة المرور' : 'Change Password';
  String get changePasswordOld =>
      isArabic ? 'كلمة المرور الحالية' : 'Old Password';
  String get changePasswordNew =>
      isArabic ? 'كلمة المرور الجديدة' : 'New Password';
  String get changePasswordConfirm =>
      isArabic ? 'تأكيد كلمة المرور الجديدة' : 'Confirm New Password';
  String get changePasswordSave => isArabic ? 'حفظ' : 'Save';

  // ===================== Edit Profile =====================
  String get editProfileTitle =>
      isArabic ? 'تعديل الملف الشخصي' : 'Edit Profile';
  String get editProfileEmail => isArabic ? 'البريد الإلكتروني' : 'Email';
  String get editProfileUserName => isArabic ? 'اسم المستخدم' : 'User Name';
  String get editProfileFirstName => isArabic ? 'الاسم الأول' : 'First Name';
  String get editProfileLastName => isArabic ? 'اسم العائلة' : 'Last Name';
  String get editProfilePhone => isArabic ? 'رقم الهاتف' : 'Phone Number';
  String get editProfileSaveChanges =>
      isArabic ? 'حفظ التغييرات' : 'Save Changes';

  // ===================== Auth =====================
  String get emailLabel => isArabic ? 'البريد الإلكتروني' : 'Email';
  String get pleaseFillAllFields =>
      isArabic ? 'يرجى ملء جميع الحقول' : 'Please fill all fields';
  String get failedToLoadProfile =>
      isArabic ? 'فشل تحميل البيانات' : 'Failed to load profile';

  // ===================== Forget Password =====================
  String get forgetPasswordTitle =>
      isArabic ? 'نسيت كلمة المرور' : 'Forget Password';
  String get forgetPasswordEmail => isArabic ? 'البريد الإلكتروني' : 'Email';
  String get forgetPasswordSend => isArabic ? 'إرسال' : 'Send';
  String get forgetPasswordRemember =>
      isArabic ? 'هل تتذكر كلمة المرور؟ ' : 'Remember Your Password? ';
  String get forgetPasswordSignIn =>
      isArabic ? 'تسجيل الدخول' : 'Sign In';

  String get sendResetCode =>
      isArabic ? 'إرسال رمز إعادة التعيين' : 'Send Reset Code';
  String get resetCodeSent =>
      isArabic ? 'تم إرسال رمز إعادة التعيين إلى بريدك' : 'Reset code sent to your email';
  String get passwordResetSuccessfully =>
      isArabic ? 'تم إعادة تعيين كلمة المرور بنجاح' : 'Password reset successfully';

  // ===================== Reset Password =====================
  String get resetPasswordTitle =>
      isArabic ? 'إعادة تعيين كلمة المرور' : 'Reset Password';
  String get resetPasswordSubtitle =>
      isArabic ? 'من فضلك أعد تعيين كلمة المرور' : 'Please reset your password';
  String get resetPasswordNew =>
      isArabic ? 'كلمة المرور الجديدة' : 'New Password';
  String get resetPasswordConfirm =>
      isArabic ? 'تأكيد كلمة المرور الجديدة' : 'Confirm New Password';
  String get resetPasswordButton =>
      isArabic ? 'إعادة تعيين كلمة المرور' : 'Reset Password';
  String get otpLabel => isArabic ? 'رمز التحقق' : 'OTP';
  String get newPasswordLabel =>
      isArabic ? 'كلمة المرور الجديدة' : 'New Password';
  String get confirmPasswordLabel =>
      isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password';

  // ===================== Notifications =====================
  String get notificationsTitle => isArabic ? 'الإشعارات' : 'Notifications';
  String get notificationsEmpty => isArabic ? 'لا توجد إشعارات' : 'No Notification';
  String get notificationsDelete => isArabic ? 'حذف' : 'Delete';

  // ===================== Privacy Policy =====================
  String get privacyPolicyTitle =>
      isArabic ? 'سياسة الخصوصية' : 'Privacy Policy';
  String get privacyPolicyBody => isArabic
      ? 'سيتم تحميل نص سياسة الخصوصية هنا من الـ API أو الاحتفاظ به كنص ثابت.'
      : 'Privacy policy content will be loaded here from API or kept as a static page.';

  // ===================== Shipping =====================
  String get shippingTitle => isArabic ? 'عناوين الشحن' : 'Shipping Addresses';
  String get shippingNewAddress =>
      isArabic ? 'إضافة عنوان جديد' : 'Add New Address';
  String get shippingCity => isArabic ? 'المدينة' : 'City';
  String get shippingStreet => isArabic ? 'الشارع' : 'Street';
  String get shippingBuilding => isArabic ? 'المبنى' : 'Building';
  String get shippingPostalCode => isArabic ? 'الرمز البريدي' : 'Postal Code';
  String get shippingSave => isArabic ? 'حفظ' : 'Save';

  // ===================== Sign In =====================
  String get signInTitle => isArabic ? 'تسجيل الدخول' : 'Sign In';
  String get signInEmailLabel => isArabic ? 'البريد الإلكتروني' : 'Email';
  String get signInEmailHint =>
      isArabic ? 'أدخل بريدك الإلكتروني' : 'Enter your email';
  String get signInPasswordLabel => isArabic ? 'كلمة المرور' : 'Password';
  String get signInPasswordHint =>
      isArabic ? 'أدخل كلمة المرور' : 'Enter your password';
  String get signInForgotPassword =>
      isArabic ? 'نسيت كلمة المرور؟' : 'Forgot your password ?';
  String get signInButton => isArabic ? 'تسجيل الدخول' : 'Sign In';
  String get signInOrContinue =>
      isArabic ? 'أو تابع باستخدام' : 'or continue with';
  String get signInGoogle => isArabic ? 'جوجل' : 'Google';
  String get signInFacebook => isArabic ? 'فيسبوك' : 'Facebook';
  String get signInApple => isArabic ? 'آبل' : 'Apple';
  String get signInNoAccount =>
      isArabic ? 'ليس لديك حساب؟ ' : "Don't have an account? ";
  String get signInSignUp => isArabic ? 'إنشاء حساب' : 'Sign up';

  // ===================== Sign Up =====================
  String get signUpTitle => isArabic ? 'إنشاء حساب' : 'Sign Up';
  String get signUpEmailLabel => isArabic ? 'البريد الإلكتروني' : 'Email';
  String get signUpFirstName => isArabic ? 'الاسم الأول' : 'First Name';
  String get signUpLastName => isArabic ? 'اسم العائلة' : 'Last Name';
  String get signUpPhone => isArabic ? 'رقم الهاتف' : 'Phone Number';
  String get signUpPassword => isArabic ? 'كلمة المرور' : 'Password';
  String get signUpConfirmPassword =>
      isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password';
  String get signUpButton => isArabic ? 'إنشاء حساب' : 'Sign Up';
  String get signUpOrContinue =>
      isArabic ? 'أو تابع باستخدام' : 'or continue with';
  String get signUpGoogle => isArabic ? 'جوجل' : 'Google';
  String get signUpFacebook => isArabic ? 'فيسبوك' : 'Facebook';
  String get signUpApple => isArabic ? 'آبل' : 'Apple';
  String get signUpAlreadyHave =>
      isArabic ? 'لديك حساب بالفعل؟ ' : 'Already have an account? ';
  String get signUpSignIn => isArabic ? 'تسجيل الدخول' : 'Sign In';

  // ===================== Onboarding =====================
  String get onboardingTitle1 =>
      isArabic ? 'أفضل مجموعة لهذا الشهر' : "Best of this month's\nCollection";
  String get onboardingTitle2 =>
      isArabic ? 'أفضل مجموعة صيفية' : 'Best Summer\nCollection.';
  String get onboardingSkip => isArabic ? 'تخطي' : 'Skip';
  String get onboardingCta =>
      isArabic ? 'إنشاء حساب وتسجيل الدخول' : 'Sign Up & Login';

  // ===================== Support Chat =====================
  String get chatTitle => isArabic ? 'الدعم والدردشة' : 'Chat';
  String get chatDeleteMenu => isArabic ? 'حذف المحادثة' : 'Delete chat';
  String get chatSuggestionTrending =>
      isArabic ? 'ما هي صيحات الموضة الآن؟' : "What's trending ?";
  String get chatSuggestionWedding =>
      isArabic ? 'ابحث عن إطلالة لحفل زفاف' : 'Find outfit for wedding';
  String get chatSuggestionSize =>
      isArabic ? 'توصية بالحجم المناسب' : 'Size Recommendation';
  String get chatSuggestionStyle =>
      isArabic ? 'نصائح حول الستايل' : 'Style Advice';
  String get chatInputHint => isArabic ? 'اكتب الرسالة...' : 'Type message...';

  // ===================== Phone Validation =====================
  String get phoneValidationTitle =>
      isArabic ? 'التحقق من رقم الهاتف' : 'Phone Validation';
  String get phoneValidationSubtitle => isArabic
      ? 'أدخل رمز التحقق المرسل إلى رقم هاتفك'
      : 'Enter the verification code sent to your phone number';
  String get phoneValidationCodeLabel =>
      isArabic ? 'رمز التحقق' : 'Verification Code';
  String get phoneValidationHint =>
      isArabic ? 'أدخل رمز التحقق' : 'Enter verification code';
  String get phoneValidationResend =>
      isArabic ? 'لم يصلك الرمز؟ إعادة الإرسال' : "Didn't receive code? Resend";
  String get phoneValidationButton => isArabic ? 'تأكيد' : 'Verify';

  // ===================== Search =====================
  String get searchTitle => isArabic ? 'البحث' : 'Search';
  String get searchHint => isArabic ? 'ابحث عن الملابس...' : 'Search clothes...';
  String get searchResultsTitle => isArabic ? 'النتائج' : 'Results';
  String get searchExploreNow => isArabic ? 'استكشف الآن!' : 'Explore Now !';
  String get searchNoResults =>
      isArabic ? 'عذراً، لا توجد نتائج' : 'Sorry, no results found';
  String get searchFilterDepartment => isArabic ? 'القسم' : 'Department';
  String get searchFilterCategory => isArabic ? 'الفئة' : 'Category';
  String get searchFilterBrand => isArabic ? 'الماركة' : 'Brand';
  String get searchFilterColor => isArabic ? 'اللون' : 'Color';
  String get searchFilterSize => isArabic ? 'المقاس' : 'Size';
  String get searchSortBy => isArabic ? 'ترتيب حسب :' : 'Sort by :';
  String get searchApply => isArabic ? 'تطبيق' : 'Apply';
  String get searchClear => isArabic ? 'مسح' : 'Clear';

  String get searchMen => isArabic ? 'رجالي' : 'Men';
  String get searchWomen => isArabic ? 'حريمي' : 'Women';
  String get searchUnisex => isArabic ? 'للجنسين' : 'Unisex';
  String get searchKids => isArabic ? 'أطفال' : 'Kids';
  String get searchSportswear => isArabic ? 'ملابس رياضية' : 'Sportswear';

  // ===================== Product Details =====================
  String get productNameExample => isArabic ? 'اسم المنتج' : 'Product name';
  String get productBrandExample => isArabic ? 'الماركة' : 'Brand';
  String get productAvailableText =>
      isArabic ? 'متوفر في المخزون' : 'Available in stock';
  String get productReviewsCountText =>
      isArabic ? '(320 مراجعة)' : '(320 Review)';
  String get productSizeLabel => isArabic ? 'المقاس' : 'Size';
  String get productColorLabel => isArabic ? 'اللون' : 'Color';
  String get productDescriptionTitle => isArabic ? 'الوصف' : 'Description';
  String get productDescriptionBody => isArabic
      ? 'سيتم استبدال هذا النص بوصف حقيقي للمنتج عند ربط البيانات.'
      : 'Product description will be loaded here once you connect real data.';
  String get productReviewsTitle => isArabic ? 'التقييمات' : 'Reviews';
  String get productReviewUserName => isArabic ? 'اسم العميل' : 'User Name';
  String get productReviewText => isArabic
      ? 'نص التقييم هنا، سيتم استبداله لاحقاً ببيانات حقيقية.'
      : 'Review text placeholder. Will be replaced with real data.';
  String get productYouMightAlsoLikeTitle =>
      isArabic ? 'قد يعجبك أيضاً.' : 'You might also like.';
  String get productAddToCartButton =>
      isArabic ? 'أضف إلى السلة' : 'Add to cart';
  String get productTotalPriceLabel =>
      isArabic ? 'السعر الإجمالي' : 'Total Price';

  // ===================== Cart =====================
  String get cartTitle => isArabic ? 'سلة المشتريات' : 'My cart';
  String get cartPromoHint => isArabic ? 'رمز الخصم' : 'Promo Code';
  String get cartApplyButton => isArabic ? 'تطبيق' : 'Apply';
  String get cartTotalItemsLabel =>
      isArabic ? 'الإجمالي' : 'Total';
  String get cartTotalLabel => isArabic ? 'الإجمالي' : 'Total';
  String get cartCheckoutButton =>
      isArabic ? 'إتمام الشراء' : 'Checkout';
  String get cartProceedButton =>
      isArabic ? 'متابعة لإتمام الشراء' : 'Proceed to Checkout';
  String get cartProductName => isArabic ? 'اسم المنتج' : 'Product name';
  String get cartBrand => isArabic ? 'الماركة' : 'Brand';
  String get cartPriceExample => isArabic ? '1000 ج.م' : '1000 EGP';

  // ===================== Payment =====================
  String get paymentTitle => isArabic ? 'الدفع' : 'Payment';
  String get paymentOrderSummary => isArabic ? 'ملخص الطلب' : 'Order Summary';
  String get paymentDeliveryInfoTitle =>
      isArabic ? 'بيانات التوصيل' : 'Delivery Information';
  String get paymentMethodTitle => isArabic ? 'طريقة الدفع' : 'Payment Method';
  String get paymentCardDetailsTitle =>
      isArabic ? 'بيانات البطاقة' : 'Card Details';
  String get paymentConfirmButton =>
      isArabic ? 'تأكيد الطلب' : 'Confirm Order';
  String get paymentSubTotalLabel =>
      isArabic ? 'الإجمالي الفرعي' : 'Sub total';
  String get paymentShipmentTotalLabel =>
      isArabic ? 'تكلفة الشحن' : 'Shipment total';
  String get paymentTotalLabel => isArabic ? 'الإجمالي' : 'Total';
  String get paymentFullNameHint => isArabic ? 'الاسم الكامل' : 'Full Name';
  String get paymentPhoneHint => isArabic ? 'رقم الهاتف' : 'Phone Number';
  String get paymentAddressHint => isArabic ? 'العنوان' : 'Address';
  String get paymentCityHint => isArabic ? 'المدينة' : 'City';
  String get paymentPostalHint => isArabic ? 'الرمز البريدي' : 'Postal Code';
  String get paymentCashOnDelivery =>
      isArabic ? 'الدفع عند الاستلام' : 'Cash on Delivery';
  String get paymentCreditCard => isArabic ? 'بطاقة ائتمان' : 'Credit Card';
  String get paymentCardNumberHint => isArabic ? 'رقم البطاقة' : 'Card Number';
  String get paymentExpHint => isArabic ? 'تاريخ الانتهاء' : 'Exp date';
  String get paymentCvvHint => isArabic ? 'رمز التحقق CVV' : 'CVV';

  // ===================== Order Confirmed Dialog =====================
  String get orderConfirmTitle =>
      isArabic ? 'تم تأكيد الطلب!' : 'Order Confirmed !';
  String get orderConfirmBody => isArabic
      ? 'تم إنشاء طلبك بنجاح.\nرقم الطلب #ORD-5804'
      : 'Your Order has been placed successfully\nOrder #ORD-5804';
  String get orderConfirmTrackButton => isArabic ? 'تتبع الطلب' : 'Track Order';
  String get orderConfirmContinueButton =>
      isArabic ? 'متابعة التسوّق' : 'Continue Shopping';

  // ===================== Wishlist =====================
  String get wishlistTitle => isArabic ? 'المفضلة' : 'Wishlist';
  String get wishlistProductName => isArabic ? 'اسم المنتج' : 'Product name';
  String get wishlistBrand => isArabic ? 'الماركة' : 'Brand';
  String get wishlistPriceExample => isArabic ? '1000 ج.م' : '1000 EGP';

  // ===================== My Orders =====================
  String get myOrdersTitle => isArabic ? 'طلباتي' : 'My Orders';
  String get myOrdersPendingTab => isArabic ? 'قيد الانتظار' : 'Pending';
  String get myOrdersCompletedTab => isArabic ? 'مكتملة' : 'Completed';
  String get myOrdersEmptyText => isArabic ? 'لا توجد طلبات حالياً' : 'No orders yet';
  String get myOrdersOrderLabel => isArabic ? 'طلب' : 'Order';
  String get myOrdersDateTimeLabel => isArabic ? 'التاريخ والوقت' : 'Date & Time';
  String get myOrdersPendingStatus => isArabic ? 'قيد الانتظار' : 'Pending';
  String get myOrdersCompletedStatus => isArabic ? 'مكتمل' : 'Completed';
  String get myOrdersDetailsButton => isArabic ? 'التفاصيل' : 'Details';

  // ===================== Order Details =====================
  String get orderDetailsTitle => isArabic ? 'تفاصيل الطلب' : 'Order Details';
  String get orderDetailsThankYouTitle =>
      isArabic ? 'شكراً لاختيارك لوكيت. ❤️' : 'Thank You for Choosing Lokit. ❤️';
  String get orderDetailsThankYouBody => isArabic
      ? 'نتمنى أن تحب منتجاتنا وتستمتع بتجربة التسوّق معنا!'
      : 'We hope you love your items and enjoy your shopping experience with us!';
  String get orderDetailsSectionTitle => isArabic ? 'بيانات الطلب' : 'Order details';
  String get orderDetailsStatusLabel => isArabic ? 'حالة الطلب' : 'Order Status';
  String get orderDetailsNumberLabel => isArabic ? 'رقم الطلب' : 'Order Number';
  String get orderDetailsDateLabel => isArabic ? 'تاريخ الطلب' : 'Order Date';
  String get orderDetailsPaymentMethodLabel =>
      isArabic ? 'طريقة الدفع' : 'Payment Method';
  String get orderDetailsPhoneLabel => isArabic ? 'رقم الهاتف' : 'Phone Number';
  String get orderDetailsAddressLabel => isArabic ? 'عنوان الشحن' : 'Shipping Address';

  String get orderStatusPending => isArabic ? 'قيد الانتظار' : 'Pending';
  String get orderStatusCompleted => isArabic ? 'مكتمل' : 'Completed';
  String get orderDetailsStatusSectionTitle => isArabic ? 'حالة الطلب' : 'Order Status';

  String get timelineConfirmedTitle => isArabic ? 'تم تأكيد الطلب' : 'Order Confirmed';
  String get timelineConfirmedBody =>
      isArabic ? 'استلمنا طلبك وبدأنا في تحضيره' : 'We have received your order and started preparing it';
  String get timelineShippedTitle => isArabic ? 'تم الشحن' : 'Shipped';
  String get timelineShippedBody =>
      isArabic ? 'طلبك في الطريق إليك مع شركة الشحن' : 'Your package is on its way to you with the courier';
  String get timelineDeliveredTitle => isArabic ? 'تم التوصيل' : 'Delivered';
  String get timelineDeliveredBody =>
      isArabic ? 'تم توصيل طلبك بنجاح' : 'Your order has been successfully delivered';

  String get orderRateSectionTitle => isArabic ? 'قيّم طلبك' : 'Rate Your Order';
  String get orderRateSectionBody =>
      isArabic ? 'بعد استلام طلبك، نود معرفة رأيك وتجربتك.' : 'After receiving your order, we would love to know your feedback.';
  String get orderRateButton => isArabic ? 'قيّم طلبك' : 'Rate Your Order';

  String get orderCancelSectionTitle =>
      isArabic ? 'هل تريد إلغاء الطلب؟' : 'Want to Cancel Your Order?';
  String get orderCancelSectionBody =>
      isArabic ? 'يمكنك إلغاء طلبك في أي وقت قبل الشحن.' : 'You can cancel your order anytime before it is shipped.';
  String get orderCancelButton => isArabic ? 'إلغاء الطلب' : 'Cancel Order';

  String get orderCancelDialogTitle => isArabic ? 'تأكيد الإلغاء' : 'Confirm Cancellation';
  String get orderCancelDialogBody => isArabic
      ? 'هل أنت متأكد من إلغاء هذا الطلب؟ سيتم إلغاء الطلب نهائياً.'
      : 'Are you sure you want to cancel this order? The order will be permanently cancelled.';
  String get orderCancelDialogNo => isArabic ? 'رجوع' : 'Back';
  String get orderCancelDialogYes => isArabic ? 'إلغاء الطلب' : 'Cancel Order';

  // ===================== Rate Experience Dialog =====================
  String get rateDialogTitle => isArabic ? 'كيف كانت تجربتك؟' : 'How Was Your Experience?';
  String get rateProductQualityLabel => isArabic ? 'جودة المنتج' : 'Product Quality';
  String get rateSizeFitLabel => isArabic ? 'المقاس والملاءمة' : 'Size & Fit';
  String get rateDeliveryLabel => isArabic ? 'تجربة التوصيل' : 'Delivery Experience';
  String get ratePackagingLabel => isArabic ? 'التغليف' : 'Packaging';
  String get rateNotesLabel => isArabic ? 'ملاحظات' : 'Notes';
  String get rateNotesHint => isArabic ? 'اكتب تقييمك هنا...' : 'Write your review here...';
  String get rateSubmitButton => isArabic ? 'إرسال' : 'Submit';
  String get rateCancelButton => isArabic ? 'إلغاء' : 'Cancel';

  // ===================== AI Try-On =====================
  String get aiPreviewTitle =>
      isArabic ? 'معاينة التجربة بالذكاء الاصطناعي' : 'AI Try - On Preview';
  String get aiPreviewNoImage => isArabic ? 'لم يتم اختيار صورة' : 'No image selected';
  String get aiPreviewTryOnButton => isArabic ? '✨ جرّب المنتج' : '✨ Try On Product';
  String get aiPreviewCamera => isArabic ? 'الكاميرا' : 'Camera';
  String get aiPreviewGallery => isArabic ? 'المعرض' : 'Gallery';

  String get aiResultTitle    => isArabic ? 'نتيجة التجربة' : 'Try-On Result';
  String get aiResultRetryButton => isArabic ? 'حاول مجدداً' : 'Try Again';
  String get aiResultBuyButton   => isArabic ? 'اشترِ الآن' : 'Buy Now';

  String get aiSheetTitle =>
      isArabic ? 'جرّب قبل ما تشتري ✨' : 'AI Try - Before - you - Buy ✨';
  String get aiSheetSubtitle => isArabic ? 'اختر مصدر الصورة' : 'Select an image source';
  String get aiSheetInstructionsTitle => isArabic ? 'إرشادات الصورة' : 'Photo Instructions';
  String get aiSheetInstructionsBody => isArabic
      ? '1. استخدم صورة واضحة بكامل الجسم.\n2. تأكد من إضاءة جيدة بدون ظلال قوية.\n3. لا تستخدم صور جماعية أو خلفيات مزدحمة.\n4. يفضّل أن تكون الملابس الحالية بسيطة بدون نقوش قوية.'
      : '1. Use a clear full-body photo.\n2. Make sure lighting is good with no harsh shadows.\n3. Avoid group photos or busy backgrounds.\n4. Prefer simple current outfits without heavy patterns.';
}