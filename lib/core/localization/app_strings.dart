/// Supported app languages.
enum AppLanguage { hindi, english }

/// Central copy deck for the app. Each key holds a pure-Hindi and a
/// pure-English line — no transliteration/Hinglish mixing, matching how
/// large consumer apps localize.
class AppStrings {
  final AppLanguage language;
  const AppStrings(this.language);

  bool get _isHindi => language == AppLanguage.hindi;

  String get appName => 'कुसबिलो';
  String get appNameEnglish => 'Kusbilo';

  String get tagline =>
      _isHindi ? 'आपके गाँव का बाज़ार, अब ऐप में' : 'Your village market, now in an app';

  String get loginHeading =>
      _isHindi ? 'मोबाइल नंबर से शुरू करें' : 'Get started with your mobile number';

  String get loginSubtext =>
      _isHindi ? 'हम आपको इस नंबर पर एक OTP भेजेंगे' : "We'll send a one-time code to this number";

  String get phoneHint => '98765 43210';

  String get continueButton => _isHindi ? 'आगे बढ़ें' : 'Continue';

  String get termsPrefix =>
      _isHindi ? 'जारी रखकर आप कुसबिलो की' : "By continuing, you agree to Kusbilo's";

  String get termsOfService => _isHindi ? 'नियम व शर्तों' : 'Terms of Service';

  String get termsMiddle => _isHindi ? 'और' : 'and';

  String get privacyPolicy => _isHindi ? 'गोपनीयता नीति' : 'Privacy Policy';

  String get termsSuffix => _isHindi ? 'से सहमत होते हैं।' : '.';

  String get back => _isHindi ? 'वापस' : 'Back';

  String get otpTitle => _isHindi ? 'OTP सत्यापित करें' : 'Verify OTP';

  String get otpSubtext =>
      _isHindi ? '6 अंकों का कोड इस नंबर पर भेजा गया है' : 'A 6-digit code has been sent to';

  String get otpResendQuestion => _isHindi ? 'कोड नहीं मिला?' : "Didn't receive the code?";

  String get otpResend => _isHindi ? 'दोबारा भेजें' : 'Resend';

  String get otpResent =>
      _isHindi ? 'OTP दोबारा भेज दिया गया है' : 'OTP has been resent';

  String get verifyButton => _isHindi ? 'सत्यापित करें' : 'Verify';

  String get welcomeTitle => _isHindi ? 'स्वागत है!' : 'Welcome!';

  String get verifiedSuffix =>
      _isHindi ? 'सफलतापूर्वक सत्यापित हो गया है' : 'has been verified successfully';

  String get comingSoonNote => _isHindi
      ? 'होम स्क्रीन, श्रेणियाँ और कार्ट अगले चरणों में जोड़े जाएँगे'
      : 'Home, categories, and cart will be added in the next steps';

  String get redirectingToHome =>
      _isHindi ? 'आपको होम पेज पर ले जाया जा रहा है...' : 'Taking you to the home page...';

  String get restartLogin => _isHindi ? 'लॉगिन दोबारा देखें' : 'View login again';

  String get invalidPhone =>
      _isHindi ? 'कृपया सही 10 अंकों का मोबाइल नंबर डालें' : 'Please enter a valid 10-digit mobile number';

  // ---- Home screen ----

  String get homeGreeting => _isHindi ? 'नमस्ते! 👋' : 'Hello! 👋';

  String get homeSubGreeting =>
      _isHindi ? 'आज क्या खरीदना है?' : 'What would you like to buy today?';

  String get searchHint =>
      _isHindi ? 'सब्ज़ी, फल, अनाज खोजें...' : 'Search vegetables, fruits, grains...';

  String get categoriesTitle => _isHindi ? 'श्रेणियाँ' : 'Categories';

  String get seeAll => _isHindi ? 'सभी देखें' : 'See all';

  String get featuredTitle => _isHindi ? 'आज के ताज़ा सामान' : "Today's Fresh Picks";

  String get addToCart => _isHindi ? 'जोड़ें' : 'Add';

  String get navHome => _isHindi ? 'होम' : 'Home';

  String get navCart => _isHindi ? 'कार्ट' : 'Cart';

  String get navProfile => _isHindi ? 'प्रोफ़ाइल' : 'Profile';

  String get comingSoonTab =>
      _isHindi ? 'यह सुविधा जल्द आ रही है' : 'This feature is coming soon';

  // Category and product names now live on the Category/Product models
  // themselves (nameHi/nameEn) instead of here — see
  // features/home/data/models/category.dart and product.dart. Keeping
  // display copy on the data models mirrors how a real backend document
  // would carry bilingual fields, and avoids UI code depending on a
  // fixed, hardcoded set of string keys per catalog item.

  String itemsCount(int n) => _isHindi ? '$n वस्तुएँ' : '$n items';

  String get cartEmptyTitle => _isHindi ? 'आपका कार्ट खाली है' : 'Your cart is empty';

  String get cartEmptySubtitle =>
      _isHindi ? 'सामान जोड़ें और यहाँ देखें' : 'Add items to see them here';

  String get subtotal => _isHindi ? 'उप-योग' : 'Subtotal';

  String get checkoutButton => _isHindi ? 'चेकआउट करें' : 'Checkout';

  String get checkoutComingSoon =>
      _isHindi ? 'चेकआउट जल्द आ रहा है' : 'Checkout is coming soon';

  // ---- Profile screen ----

  String get profileGuestName => _isHindi ? 'नमस्ते!' : 'Hello!';

  String get myAccount => _isHindi ? 'मेरा खाता' : 'My Account';

  String get myOrders => _isHindi ? 'मेरे ऑर्डर' : 'My Orders';

  String get myAddresses => _isHindi ? 'मेरे पते' : 'My Addresses';

  String get paymentMethods => _isHindi ? 'भुगतान के तरीके' : 'Payment Methods';

  String get paymentMethodsInfo => _isHindi
      ? 'अभी सिर्फ Cash on Delivery (डिलीवरी पर नकद भुगतान) उपलब्ध है। सामान मिलने पर आप विक्रेता को सीधे नकद भुगतान करते हैं। अन्य भुगतान तरीके जल्द जोड़े जाएंगे।'
      : 'Only Cash on Delivery is available right now — pay the seller directly in cash when your order arrives. More payment options will be added soon.';

  String get wishlist => _isHindi ? 'पसंदीदा' : 'Wishlist';

  String get sellerSection => _isHindi ? 'विक्रेता' : 'Seller';

  String get becomeMerchant => _isHindi ? 'विक्रेता बनें' : 'Become a Merchant';

  String get becomeMerchantSubtitle =>
      _isHindi ? 'अपने उत्पाद बेचें — KYC ज़रूरी है' : 'Sell your products — KYC required';

  String get supportSection => _isHindi ? 'सहायता' : 'Support';

  String get helpSupport => _isHindi ? 'सहायता केंद्र' : 'Help & Support';

  String get aboutUs => _isHindi ? 'हमारे बारे में' : 'About Us';


  String get rateApp => _isHindi ? 'ऐप को रेट करें' : 'Rate the App';

  String get logoutButton => _isHindi ? 'लॉग आउट' : 'Logout';

  String get logoutConfirmTitle =>
      _isHindi ? 'क्या आप लॉग आउट करना चाहते हैं?' : 'Are you sure you want to logout?';

  String get logoutConfirmYes => _isHindi ? 'हाँ, लॉग आउट करें' : 'Yes, Logout';

  String get cancel => _isHindi ? 'रद्द करें' : 'Cancel';

  String get appVersion => _isHindi ? 'वर्शन 1.0.0' : 'Version 1.0.0';

  String get featureComingSoon =>
      _isHindi ? 'यह सुविधा जल्द आ रही है' : 'This feature is coming soon';

  // ---- Merchant KYC ----

  String get kycFormTitle => _isHindi ? 'विक्रेता KYC' : 'Merchant KYC';

  String get businessInfoSection => _isHindi ? 'व्यवसाय की जानकारी' : 'Business Information';

  String get addressSection => _isHindi ? 'पता' : 'Address';

  String get bankDetailsSection => _isHindi ? 'बैंक विवरण' : 'Bank Details';

  String get shopNameLabel => _isHindi ? 'दुकान का नाम' : 'Shop Name';

  String get ownerNameLabel => _isHindi ? "मालिक का पूरा नाम" : "Owner's Full Name";

  String get aadhaarLabel => _isHindi ? 'आधार नंबर' : 'Aadhaar Number';

  String get panLabel => _isHindi ? 'पैन नंबर (वैकल्पिक)' : 'PAN Number (optional)';

  String get addressLabel => _isHindi ? 'पूरा पता' : 'Full Address';

  String get villageLabel => _isHindi ? 'गाँव/शहर' : 'Village/Town';

  String get districtLabel => _isHindi ? 'ज़िला' : 'District';

  String get stateLabel => _isHindi ? 'राज्य' : 'State';

  String get pincodeLabel => _isHindi ? 'पिनकोड' : 'Pincode';

  String get bankAccountLabel => _isHindi ? 'बैंक खाता नंबर' : 'Bank Account Number';

  String get ifscLabel => _isHindi ? 'IFSC कोड' : 'IFSC Code';

  String get submitKycButton => _isHindi ? 'KYC जमा करें' : 'Submit KYC';

  String get fieldRequiredError => _isHindi ? 'यह भरना ज़रूरी है' : 'This field is required';

  String get aadhaarInvalidError =>
      _isHindi ? '12 अंकों का सही आधार नंबर डालें' : 'Enter a valid 12-digit Aadhaar number';

  String get pincodeInvalidError =>
      _isHindi ? '6 अंकों का सही पिनकोड डालें' : 'Enter a valid 6-digit pincode';

  String get ifscInvalidError => _isHindi
      ? 'सही IFSC कोड डालें (जैसे SBIN0001234)'
      : 'Enter a valid IFSC code (e.g., SBIN0001234)';

  String get panInvalidError => _isHindi
      ? 'सही पैन नंबर डालें (जैसे ABCDE1234F)'
      : 'Enter a valid PAN number (e.g., ABCDE1234F)';

  String get bankAccountInvalidError =>
      _isHindi ? 'सही खाता नंबर डालें' : 'Enter a valid account number';

  String get kycPendingTitle => _isHindi ? 'आवेदन सत्यापन में है' : 'Application under review';

  String get kycPendingSubtitle => _isHindi
      ? 'हम आपकी जानकारी जांच रहे हैं, आमतौर पर 2-3 दिन लगते हैं'
      : "We're reviewing your details — this usually takes 2-3 days";

  String get kycApprovedTitle =>
      _isHindi ? 'बधाई हो! आप अब विक्रेता हैं' : "Congratulations! You're now a merchant";

  String get kycApprovedSubtitle =>
      _isHindi ? 'उत्पाद जोड़ना जल्द उपलब्ध होगा' : 'Adding products will be available soon';

  String get kycRejectedTitle => _isHindi ? 'आवेदन अस्वीकृत हो गया' : 'Application was rejected';

  String get kycRejectedSubtitle => _isHindi
      ? 'कृपया अपनी जानकारी जांचें और दोबारा आवेदन करें'
      : 'Please check your details and re-apply';

  String get reapplyButton => _isHindi ? 'दोबारा आवेदन करें' : 'Re-apply';

  String get kycStatusPendingShort => _isHindi ? 'सत्यापन लंबित है' : 'Verification pending';

  String get kycStatusApprovedShort => _isHindi ? 'स्वीकृत विक्रेता' : 'Approved merchant';

  String get kycStatusRejectedShort => _isHindi ? 'आवेदन अस्वीकृत हुआ' : 'Application rejected';

  // ---- Seller Dashboard ----

  String get sellerDashboardTitle => _isHindi ? 'विक्रेता डैशबोर्ड' : 'Seller Dashboard';

  String get approvedBadge => _isHindi ? 'स्वीकृत विक्रेता' : 'Approved Seller';

  String get myProductsStat => _isHindi ? 'मेरे उत्पाद' : 'My Products';

  String get ordersStat => _isHindi ? 'ऑर्डर' : 'Orders';

  String get earningsStat => _isHindi ? 'कमाई' : 'Earnings';

  String get addProductButton => _isHindi ? 'उत्पाद जोड़ें' : 'Add Product';

  String get noProductsTitle => _isHindi ? 'अभी कोई उत्पाद नहीं जोड़ा' : 'No products added yet';

  String get noProductsSubtitle => _isHindi
      ? 'अपना पहला उत्पाद जोड़कर बेचना शुरू करें'
      : 'Add your first product to start selling';

  String get manageOrders => _isHindi ? 'ऑर्डर प्रबंधित करें' : 'Manage Orders';

  String get storeSettings => _isHindi ? 'दुकान सेटिंग्स' : 'Store Settings';

  String get shopDescriptionLabel => _isHindi ? 'दुकान का विवरण' : 'Shop Description';

  String get shopDescriptionHint => _isHindi
      ? 'जैसे: ताज़ी सब्ज़ियां और फल, हर सुबह मंडी से सीधे'
      : 'e.g. Fresh vegetables and fruit, straight from the market every morning';

  String get prepMinutesLabel => _isHindi ? 'तैयारी का समय (मिनट)' : 'Prep Time (minutes)';

  String get prepMinutesHint => _isHindi
      ? 'ऑर्डर तैयार करने में औसतन कितने मिनट लगते हैं'
      : 'Average minutes to get an order ready';

  String get saveButton => _isHindi ? 'सेव करें' : 'Save';

  String get settingsSavedMessage => _isHindi ? 'सेटिंग्स सेव हो गईं' : 'Settings saved';

  String get settingsSaveFailedMessage =>
      _isHindi ? 'सेव नहीं हो पाया, फिर से कोशिश करें' : "Couldn't save, please try again";

  String get backToShopping => _isHindi ? 'खरीदारी पर वापस जाएं' : 'Back to Shopping';

  String get devTestApproveLabel =>
      _isHindi ? '(डेव टेस्ट) स्वीकृत के रूप में चिह्नित करें' : '(Dev test) Mark as approved';

  // ---- Add Product ----

  String get addProductTitle => _isHindi ? 'नया उत्पाद जोड़ें' : 'Add New Product';

  String get productNameLabel => _isHindi ? 'उत्पाद का नाम' : 'Product Name';

  String get categoryFieldLabel => _isHindi ? 'श्रेणी चुनें' : 'Select Category';

  String get priceLabel => _isHindi ? 'कीमत (₹)' : 'Price (₹)';

  String get unitLabel => _isHindi ? 'इकाई' : 'Unit';

  String get stockLabel => _isHindi ? 'स्टॉक मात्रा' : 'Stock Quantity';

  String get chooseIconLabel => _isHindi ? 'एक आइकॉन चुनें' : 'Choose an Icon';

  String get saveProductButton => _isHindi ? 'उत्पाद सेव करें' : 'Save Product';

  String get productAddedMessage =>
      _isHindi ? 'उत्पाद जोड़ दिया गया है' : 'Product has been added';

  String get priceInvalidError => _isHindi ? 'सही कीमत डालें' : 'Enter a valid price';

  String get stockInvalidError => _isHindi ? 'सही मात्रा डालें' : 'Enter a valid quantity';

  String get selectCategoryError => _isHindi ? 'कृपया श्रेणी चुनें' : 'Please select a category';

  String get selectIconError => _isHindi ? 'कृपया एक आइकॉन चुनें' : 'Please choose an icon';

  // ---- Checkout ----

  String get checkoutTitle => _isHindi ? 'ऑर्डर पूरा करें' : 'Complete your order';

  String get deliveryAddressSection => _isHindi ? 'डिलीवरी का पता' : 'Delivery address';

  String get detectLocationButton =>
      _isHindi ? 'मेरी जगह पता लगाएं' : 'Detect my location';

  String get detectingLocation => _isHindi ? 'जगह पता लगाई जा रही है...' : 'Detecting location...';

  String get locationDetected => _isHindi ? 'जगह मिल गई' : 'Location detected';

  String get changeLocation => _isHindi ? 'बदलें' : 'Change';

  String get locationServiceDisabledError => _isHindi
      ? 'कृपया फ़ोन में लोकेशन (GPS) चालू करें'
      : 'Please turn on Location (GPS) on your phone';

  String get locationPermissionDeniedError => _isHindi
      ? 'ऑर्डर डिलीवर करने के लिए लोकेशन की अनुमति ज़रूरी है'
      : 'Location permission is needed to deliver your order';

  String get locationPermissionDeniedForeverError => _isHindi
      ? 'कृपया फ़ोन की सेटिंग्स में जाकर लोकेशन की अनुमति दें'
      : 'Please allow location permission from your phone settings';

  String get locationUnknownError =>
      _isHindi ? 'जगह पता नहीं लग पाई, दोबारा कोशिश करें' : "Couldn't detect location, please try again";

  String get orderSummarySection => _isHindi ? 'ऑर्डर का सारांश' : 'Order summary';

  String get totalLabel => _isHindi ? 'कुल राशि' : 'Total amount';

  String get codNote => _isHindi
      ? 'डिलीवरी पर नकद भुगतान करें (Cash on Delivery)'
      : 'Pay with cash on delivery (COD)';

  String get paymentMethodSection => _isHindi ? 'भुगतान का तरीका' : 'Payment method';

  String get paymentMethodCod => _isHindi ? 'नकद (डिलीवरी पर)' : 'Cash on delivery';

  String get paymentMethodCodSubtitle =>
      _isHindi ? 'सामान मिलने पर पैसे दें' : 'Pay when your order arrives';

  String get paymentMethodUpi => _isHindi ? 'UPI से अभी भुगतान करें' : 'Pay now with UPI';

  String get paymentMethodUpiSubtitle =>
      _isHindi ? 'GPay, PhonePe, Paytm आदि' : 'GPay, PhonePe, Paytm, etc.';

  String get upiPaymentOpeningApp =>
      _isHindi ? 'भुगतान ऐप खोला जा रहा है...' : 'Opening your payment app...';

  String get upiPaymentWaiting =>
      _isHindi ? 'भुगतान की पुष्टि का इंतज़ार है...' : 'Waiting for payment confirmation...';

  String get upiPaymentSuccess => _isHindi ? 'भुगतान सफल हुआ ✅' : 'Payment successful ✅';

  String get upiPaymentFailed => _isHindi
      ? 'भुगतान नहीं हो पाया। कृपया दोबारा कोशिश करें या नकद भुगतान चुनें।'
      : "Payment couldn't go through. Please try again or choose cash on delivery.";

  String get upiPaymentTimedOut => _isHindi
      ? 'भुगतान की पुष्टि नहीं मिली। अगर पैसे कट गए हैं तो थोड़ी देर बाद फिर देखें, या नकद भुगतान चुनें।'
      : "Couldn't confirm your payment yet. If money was deducted, check back shortly, or choose cash on delivery instead.";

  String get upiPaymentNotConfigured => _isHindi
      ? 'UPI भुगतान अभी उपलब्ध नहीं है। कृपया नकद भुगतान चुनें।'
      : 'UPI payment is not available right now. Please choose cash on delivery.';

  String get upiRetryButton => _isHindi ? 'दोबारा कोशिश करें' : 'Try again';

  String get placeOrderButton => _isHindi ? 'ऑर्डर करें' : 'Place order';

  String get searchPromptMessage =>
      _isHindi ? 'सब्ज़ी, फल, अनाज या कुछ भी टाइप करें' : 'Type a vegetable, fruit, grain, or anything else';

  String get searchNoResultsMessage =>
      _isHindi ? 'कुछ नहीं मिला। कुछ और खोजने की कोशिश करें।' : "Nothing found. Try searching something else.";

  String get cancelOrderButton => _isHindi ? 'ऑर्डर रद्द करें' : 'Cancel order';

  String get cancelOrderConfirmTitle => _isHindi ? 'ऑर्डर रद्द करें?' : 'Cancel this order?';

  String get cancelOrderConfirmBody => _isHindi
      ? 'क्या आप वाकई इस ऑर्डर को रद्द करना चाहते हैं? यह वापस नहीं हो सकता।'
      : "Are you sure you want to cancel this order? This can't be undone.";

  String get cancelOrderKeepButton => _isHindi ? 'नहीं, रहने दें' : 'No, keep it';

  String get cancelOrderConfirmButton => _isHindi ? 'हाँ, रद्द करें' : 'Yes, cancel';

  String get cancelOrderSuccessMessage => _isHindi ? 'ऑर्डर रद्द हो गया' : 'Order cancelled';

  String get cancelOrderFailedMessage =>
      _isHindi ? 'ऑर्डर रद्द नहीं हो पाया। फिर कोशिश करें।' : "Couldn't cancel the order. Please try again.";

  String get editNameTitle => _isHindi ? 'अपना नाम बदलें' : 'Edit your name';

  String get editNameHint => _isHindi ? 'अपना नाम लिखें' : 'Enter your name';

  String get reorderButton => _isHindi ? 'फिर से मंगाएं' : 'Reorder';

  String reorderAllAddedMessage(int count) => _isHindi
      ? '$count चीज़ें कार्ट में जोड़ दी गईं'
      : '$count item${count == 1 ? '' : 's'} added to cart';

  String reorderPartiallyAddedMessage(int added, int skipped) => _isHindi
      ? '$added चीज़ें कार्ट में जोड़ी गईं। $skipped चीज़ें अब उपलब्ध नहीं हैं।'
      : '$added item${added == 1 ? '' : 's'} added to cart. $skipped item${skipped == 1 ? '' : 's'} no longer available.';

  String get rateOrderTitle => _isHindi ? 'रेटिंग दें' : 'Rate your order';

  String get submitReviewButton => _isHindi ? 'जमा करें' : 'Submit';

  String get reviewSubmittedMessage => _isHindi ? 'धन्यवाद! आपकी रेटिंग जमा हो गई' : 'Thanks! Your rating was saved';

  String get reviewSubmitFailedMessage =>
      _isHindi ? 'रेटिंग जमा नहीं हो पाई। फिर कोशिश करें।' : "Couldn't save your rating. Please try again.";

  String get rateOrderButton => _isHindi ? 'रेटिंग दें' : 'Rate & review';

  String get noReviewsYetMessage => _isHindi ? 'अभी तक कोई रेटिंग नहीं' : 'No ratings yet';

  String reviewCountLabel(int count) =>
      _isHindi ? '($count रेटिंग)' : '($count rating${count == 1 ? '' : 's'})';

  String get placingOrder => _isHindi ? 'ऑर्डर किया जा रहा है...' : 'Placing your order...';

  String get addressRequiredError =>
      _isHindi ? 'कृपया पहले अपनी जगह बताएं' : 'Please detect your location first';

  // ---- Order success / history ----

  String get orderPlacedTitle => _isHindi ? 'ऑर्डर हो गया! 🎉' : 'Order placed! 🎉';

  String get orderPlacedSubtitle => _isHindi
      ? 'आपका सामान जल्द ही आपके गाँव पहुँच जाएगा'
      : 'Your items will reach your village soon';

  String orderIdLabel(String id) => _isHindi ? 'ऑर्डर नंबर: $id' : 'Order ID: $id';

  String get continueShoppingButton => _isHindi ? 'खरीदारी जारी रखें' : 'Continue shopping';

  String get viewOrderButton => _isHindi ? 'ऑर्डर देखें' : 'View order';

  // ---- Seller / merchant storefront ----

  String get soldByLabel => _isHindi ? 'विक्रेता' : 'Sold by';

  String get exploreAllProductsLabel =>
      _isHindi ? 'सभी सामान देखें' : 'Explore all products';

  String sellerProductsTitle(String shopName) => shopName;

  String get noOtherProductsMessage =>
      _isHindi ? 'इस विक्रेता के फ़िलहाल और सामान नहीं हैं' : 'This seller has no other products right now';

  // ---- Added-to-cart toast ----

  String addedToCartMessage(String productName) =>
      _isHindi ? '$productName कार्ट में जुड़ गया' : '$productName added to cart';

  String get inclusiveOfTaxesLabel =>
      _isHindi ? 'सभी टैक्स सहित' : 'Inclusive of all taxes';

  String get myOrdersTitle => _isHindi ? 'मेरे ऑर्डर' : 'My Orders';

  String get noOrdersTitle => _isHindi ? 'अभी कोई ऑर्डर नहीं' : 'No orders yet';

  String get noOrdersSubtitle =>
      _isHindi ? 'खरीदारी शुरू करें और यहाँ अपने ऑर्डर देखें' : 'Start shopping to see your orders here';

  String get orderStatusPlaced => _isHindi ? 'ऑर्डर मिल गया' : 'Order placed';

  String get orderStatusConfirmed => _isHindi ? 'विक्रेता ने पुष्टि की' : 'Confirmed by seller';

  String get orderStatusOutForDelivery => _isHindi ? 'डिलीवरी के लिए निकला' : 'Out for delivery';

  String get orderStatusDelivered => _isHindi ? 'डिलीवर हो गया' : 'Delivered';

  String get orderStatusCancelled => _isHindi ? 'रद्द हो गया' : 'Cancelled';

  // ---- Voice ordering ----

  String get voiceOrderHint =>
      _isHindi ? 'बोलकर ऑर्डर करें, जैसे "1 किलो आलू दो"' : 'Order by voice, e.g. "1 kg potato"';

  String get voiceListening => _isHindi ? 'सुन रहे हैं... बोलिए' : 'Listening... please speak';

  String get voiceProcessing => _isHindi ? 'समझा जा रहा है...' : 'Understanding...';

  String get voiceTapToSpeak => _isHindi ? 'बोलने के लिए दबाएं' : 'Tap to speak';

  String get voiceNotAvailableError => _isHindi
      ? 'इस फ़ोन में आवाज़ पहचानना उपलब्ध नहीं है'
      : "Voice recognition isn't available on this phone";

  String get voiceMicPermissionError =>
      _isHindi ? 'बोलने के लिए माइक्रोफ़ोन की अनुमति दें' : 'Please allow microphone access to speak your order';

  String get voiceNoMatchTitle =>
      _isHindi ? 'समझ नहीं आया' : "Didn't quite catch that";

  String voiceHeardLabel(String text) => _isHindi ? 'आपने कहा: "$text"' : 'You said: "$text"';

  String voiceAddedToCartSpoken(String itemName, int qty, String unit) => _isHindi
      ? '$itemName, $qty $unit कार्ट में जोड़ दिया'
      : '$itemName, $qty $unit added to your cart';

  String get voiceNoMatchSpoken => _isHindi
      ? 'माफ़ करें, समझ नहीं आया। कृपया फिर से बोलें, जैसे 1 किलो आलू'
      : "Sorry, I didn't understand. Please try again, like 1 kg potato";

  String get voiceTryAgainButton => _isHindi ? 'फिर से बोलें' : 'Try again';

  String get voiceDoneButton => _isHindi ? 'हो गया' : 'Done';

  // ---- Admin: KYC review ----

  String get adminMenuLabel => _isHindi ? 'KYC आवेदन जांचें' : 'Review KYC Applications';

  String get adminKycQueueTitle => _isHindi ? 'लंबित KYC आवेदन' : 'Pending KYC Applications';

  String get adminNoPendingTitle => _isHindi ? 'कोई लंबित आवेदन नहीं' : 'No pending applications';

  String get adminNoPendingSubtitle =>
      _isHindi ? 'सभी आवेदन जांचे जा चुके हैं' : 'All applications have been reviewed';

  String get adminApproveButton => _isHindi ? 'स्वीकृत करें' : 'Approve';

  String get adminRejectButton => _isHindi ? 'अस्वीकार करें' : 'Reject';

  String get adminReviewFailed =>
      _isHindi ? 'कुछ गलत हो गया, दोबारा कोशिश करें' : 'Something went wrong, please try again';

  // ---- Product photo / description / tags ----

  String get productPhotoLabel => _isHindi ? 'उत्पाद की फोटो' : 'Product photo';

  String get addPhotoHint => _isHindi ? 'फोटो जोड़ने के लिए दबाएं' : 'Tap to add a photo';

  String get productDescriptionLabel => _isHindi ? 'विवरण' : 'Description';

  String get similarProductsTitle => _isHindi ? 'मिलते-जुलते सामान' : 'Similar Products';

  String get aiSuggestButton =>
      _isHindi ? '✨ AI से नाम, विवरण, टैग बनवाएं' : '✨ Get AI suggestions for name, description, tags';

  String get aiSuggestFailedMessage =>
      _isHindi ? 'सुझाव नहीं मिल पाए, फिर से कोशिश करें' : "Couldn't get suggestions, please try again";

  String get productDescriptionHint => _isHindi
      ? 'जैसे: ताज़ा देसी आलू, खेत से सीधा'
      : 'e.g. Fresh local potatoes, straight from the farm';

  String get productTagsLabel => _isHindi ? 'टैग' : 'Tags';

  String get productTagsHint => _isHindi ? 'जैसे: देसी, ताज़ा, जैविक' : 'e.g. local, fresh, organic';

  String get productTagsHelper =>
      _isHindi ? 'कॉमा (,) से अलग करके लिखें' : 'Separate tags with a comma (,)';

  String get savingProductLabel => _isHindi ? 'सेव हो रहा है...' : 'Saving...';

  String get chooseIconOptionalLabel =>
      _isHindi ? 'आइकॉन चुनें (वैकल्पिक — अगर फोटो नहीं है)' : 'Choose an icon (optional — if no photo)';

  String get productSaveFailed =>
      _isHindi ? 'सेव नहीं हो पाया' : 'Could not save';

  String get categoriesLoadFailedMessage => _isHindi
      ? 'श्रेणियाँ लोड नहीं हो पाईं'
      : 'Categories could not be loaded';

  String get retryButton => _isHindi ? 'दोबारा कोशिश करें' : 'Retry';

  String get noProductsInCategory =>
      _isHindi ? 'इस श्रेणी में अभी कोई उत्पाद नहीं है' : 'No products in this category yet';

  String get catalogLoadFailedMessage =>
      _isHindi ? 'दुकान लोड नहीं हो पाई' : 'Could not load the shop';

  // ---- Addresses ----

  String get addAddressTitle => _isHindi ? 'पता जोड़ें' : 'Add address';

  String get addressLabelHint => _isHindi ? 'नाम दें, जैसे घर, दुकान' : 'Label, e.g. Home, Shop';

  String get saveAddressButton => _isHindi ? 'पता सेव करें' : 'Save address';

  String get addressIncompleteError =>
      _isHindi ? 'कृपया नाम लिखें और जगह पता लगाएं' : 'Please enter a label and detect a location';

  String get noAddressesTitle => _isHindi ? 'अभी कोई पता सेव नहीं है' : 'No saved addresses yet';

  String get noAddressesSubtitle =>
      _isHindi ? 'नीचे दिए बटन से एक पता जोड़ें' : 'Add one using the button below';

  // ---- Favorites ----

  String get noFavoritesTitle => _isHindi ? 'अभी कोई पसंदीदा नहीं' : 'No favorites yet';

  String get noFavoritesSubtitle => _isHindi
      ? 'उत्पादों पर दिल के निशान को दबाकर उन्हें यहाँ जोड़ें'
      : 'Tap the heart on a product to add it here';

  // ---- Help & Support / About / Terms / Rate ----

  String get callUsButton => _isHindi ? 'कॉल करें' : 'Call us';

  String get whatsappUsButton => _isHindi ? 'व्हाट्सऐप करें' : 'WhatsApp us';

  String get emailUsButton => _isHindi ? 'ईमेल करें' : 'Email us';

  String get helpSupportIntro => _isHindi
      ? 'कोई सवाल या समस्या है? हमें संपर्क करें, हम मदद के लिए यहाँ हैं।'
      : "Have a question or facing an issue? We're here to help.";

  String get aboutUsBody => _isHindi
      ? 'कुसबिलो एक ऐसा बाज़ार है जो पूरे भारत के दुकानदारों और खरीदारों को सीधे जोड़ता है — बिना किसी बिचौलिए के। स्थानीय उत्पाद, आवाज़ से ऑर्डर, और आपकी अपनी भाषा में — यह सब खरीदारी को थोड़ा आसान बनाने के लिए बनाया गया है।'
      : "Kusbilo is a marketplace that connects local shopkeepers directly with buyers across India — no middleman. Local products, voice ordering, and your own language — all built to make shopping a little easier, wherever you are.";

  String get privacyPolicyTitle => _isHindi ? 'गोपनीयता नीति' : 'Privacy Policy';

  String get termsOfServiceTitle => _isHindi ? 'नियम व शर्तें' : 'Terms of Service';

  /// (heading, body) pairs rendered by StaticInfoScreen. Kept as plain
  /// tuples here (not StaticInfoSection objects) so this file stays a
  /// pure copy-deck with no Flutter widget imports — home_screen.dart
  /// maps these into StaticInfoSection.
  List<(String?, String)> get privacyPolicySections => _isHindi
      ? [
          (
            null,
            'यह गोपनीयता नीति बताती है कि Kusbilo ऐप आपकी जानकारी कैसे इकट्ठा करता है, उपयोग करता है, और सुरक्षित रखता है। ऐप इस्तेमाल करके आप इस नीति से सहमत होते हैं।',
          ),
          (
            'हम खरीदारों से क्या जानकारी लेते हैं',
            '• फ़ोन नंबर (लॉगिन के लिए OTP सत्यापन)\n• डिलीवरी की सटीक लोकेशन (GPS)\n• ऑर्डर हिस्ट्री, कार्ट, और पसंदीदा (wishlist) सामान\n• पुश नोटिफिकेशन भेजने के लिए डिवाइस टोकन\n• आवाज़ से ऑर्डर करते समय: आपकी आवाज़ को आपके ही फ़ोन पर टेक्स्ट में बदला जाता है — असली ऑडियो कहीं भेजा या सेव नहीं किया जाता, केवल लिखा हुआ टेक्स्ट हमारे सर्वर पर प्रोसेस होता है।',
          ),
          (
            'हम विक्रेताओं (सेलर) से क्या जानकारी लेते हैं',
            'सेलर बनने के लिए दुकान का नाम, मालिक का नाम, आधार नंबर, PAN नंबर, बैंक खाता व IFSC कोड, और दुकान की जगह ली जाती है — यह जानकारी सिर्फ पहचान सत्यापन (KYC) और भुगतान के लिए इस्तेमाल होती है, और केवल संबंधित सेलर व एडमिन ही इसे देख सकते हैं।',
          ),
          (
            'जानकारी का उपयोग कैसे होता है',
            'आपकी जानकारी सिर्फ ऑर्डर पूरा करने, डिलीवरी दिखाने, ज़रूरी सूचनाएं भेजने, और (सेलर के मामले में) पहचान सत्यापित करने के लिए उपयोग होती है। हम आपकी जानकारी किसी को बेचते नहीं हैं।',
          ),
          (
            'तीसरे पक्ष की सेवाएं (Third-party services)',
            'ऐप इन भरोसेमंद सेवाओं का उपयोग करता है: Google Firebase (लॉगिन, डेटाबेस, नोटिफिकेशन), Google Gemini AI (आवाज़ से ऑर्डर समझने के लिए, सिर्फ टेक्स्ट भेजा जाता है), और Google Cloud Text-to-Speech (आवाज़ में जवाब देने के लिए)। इन सबकी अपनी गोपनीयता नीतियां भी लागू होती हैं।',
          ),
          (
            'आपका अधिकार',
            'आप कभी भी हमसे अपनी जानकारी हटाने या देखने का अनुरोध कर सकते हैं — नीचे दिए संपर्क के ज़रिए।',
          ),
          (
            'संपर्क करें',
            'सवाल या शिकायत के लिए: support@kusbilo.in',
          ),
        ]
      : [
          (
            null,
            'This Privacy Policy explains how the Kusbilo app collects, uses, and protects your information. By using the app, you agree to this policy.',
          ),
          (
            'What we collect from buyers',
            '• Phone number (for OTP login)\n• Precise delivery location (GPS)\n• Order history, cart, and wishlist items\n• A device token for sending push notifications\n• Voice ordering: your speech is converted to text on your own phone — the raw audio is never sent or stored; only the resulting text is processed on our server.',
          ),
          (
            'What we collect from sellers',
            'To become a seller, we collect shop name, owner name, Aadhaar number, PAN number, bank account and IFSC code, and shop location — used only for identity verification (KYC) and payments, and visible only to that seller and an admin.',
          ),
          (
            'How we use this information',
            'Your information is used only to fulfil orders, show delivery tracking, send necessary notifications, and (for sellers) verify identity. We never sell your information.',
          ),
          (
            'Third-party services',
            'The app relies on these trusted services: Google Firebase (login, database, notifications), Google Gemini AI (to understand spoken orders — only text is sent), and Google Cloud Text-to-Speech (for spoken replies). Each has its own privacy policy as well.',
          ),
          (
            'Your rights',
            'You may request access to or deletion of your data at any time using the contact below.',
          ),
          (
            'Contact us',
            'For questions or complaints: support@kusbilo.in',
          ),
        ];

  List<(String?, String)> get termsOfServiceSections => _isHindi
      ? [
          (
            null,
            'Kusbilo ऐप इस्तेमाल करने से पहले कृपया ये शर्तें ध्यान से पढ़ें। ऐप इस्तेमाल करके आप इनसे सहमत होते हैं।',
          ),
          (
            'भुगतान',
            'ऑर्डर के लिए UPI (ऑनलाइन) या Cash on Delivery (डिलीवरी पर नकद) — दोनों में से कोई भी तरीका चुन सकते हैं। UPI भुगतान हमारे भुगतान पार्टनर के ज़रिए सुरक्षित तरीके से प्रोसेस होता है।',
          ),
          (
            'डिलीवरी का समय',
            'दिखाया गया अनुमानित समय (ETA) एक अनुमान है, दूरी और तैयारी के समय पर आधारित — यह एक गारंटी नहीं है। असली समय ट्रैफ़िक, मौसम, या अन्य वजहों से अलग हो सकता है।',
          ),
          (
            'ऑर्डर रद्द करना',
            'जब तक विक्रेता ने ऑर्डर तैयार करना शुरू नहीं किया है, तब तक आप ऐप के अंदर से ही ऑर्डर मुफ़्त में रद्द कर सकते हैं (ऑर्डर ट्रैकिंग स्क्रीन से)। तैयार होना शुरू हो जाने के बाद रद्द करना संभव नहीं होगा — ऐसे में कृपया सीधे विक्रेता या हमारे सपोर्ट से संपर्क करें।',
          ),
          (
            'रिफंड और रिप्लेसमेंट',
            'हर प्रोडक्ट पेज पर उसकी रिप्लेसमेंट विंडो (जैसे सब्ज़ी-फल के लिए 48 घंटे, बाकी सामान के लिए 72 घंटे) दिखाई जाती है। पूरी जानकारी के लिए हमारी रिफंड पॉलिसी देखें।',
          ),
          (
            'विक्रेता की ज़िम्मेदारी',
            'विक्रेता अपने द्वारा बेचे गए सामान की गुणवत्ता, कीमत, और उपलब्धता के लिए खुद ज़िम्मेदार हैं। Kusbilo सिर्फ खरीदार और विक्रेता को जोड़ने का माध्यम है।',
          ),
          (
            'ज़िम्मेदारी की सीमा',
            'Kusbilo पूरी कोशिश करता है कि सेवा सही तरीके से चले, लेकिन डिलीवरी में देरी, सामान की गुणवत्ता, या तकनीकी खराबी से हुए किसी नुकसान की पूरी ज़िम्मेदारी नहीं ले सकता, कानून द्वारा अनुमत सीमा तक।',
          ),
          (
            'बदलाव',
            'यह शर्तें समय-समय पर अपडेट हो सकती हैं। बड़े बदलाव होने पर ऐप में सूचित किया जाएगा।',
          ),
          (
            'संपर्क करें',
            'सवाल या शिकायत के लिए: support@kusbilo.in',
          ),
        ]
      : [
          (
            null,
            'Please read these Terms carefully before using the Kusbilo app. By using the app, you agree to them.',
          ),
          (
            'Payment',
            'You can pay via UPI (online) or Cash on Delivery — whichever you prefer. UPI payments are processed securely through our payment partner.',
          ),
          (
            'Delivery time',
            'The estimated time (ETA) shown is based on distance and prep time — it is an estimate, not a guarantee. Actual time may vary due to traffic, weather, or other factors.',
          ),
          (
            'Cancelling an order',
            'You can cancel an order for free from within the app (on the order tracking screen) as long as the seller hasn\'t started preparing it yet. Once preparation has begun, cancellation isn\'t possible — please contact the seller or our support directly instead.',
          ),
          (
            'Refunds & replacements',
            'Every product page shows its replacement window (e.g. 48 hours for fruits & vegetables, 72 hours for other items). See our Refund Policy for full details.',
          ),
          (
            'Seller responsibility',
            'Sellers are solely responsible for the quality, pricing, and availability of the goods they sell. Kusbilo is only a medium connecting buyers and sellers.',
          ),
          (
            'Limitation of liability',
            'Kusbilo makes every effort to keep the service running smoothly, but cannot take full responsibility for losses from delivery delays, product quality, or technical faults, to the extent permitted by law.',
          ),
          (
            'Changes',
            'These terms may be updated from time to time. Significant changes will be notified within the app.',
          ),
          (
            'Contact us',
            'For questions or complaints: support@kusbilo.in',
          ),
        ];

  String get refundPolicyTitle => _isHindi ? 'रिफंड और रिप्लेसमेंट पॉलिसी' : 'Refund & Replacement Policy';

  List<(String?, String)> get refundPolicySections => _isHindi
      ? [
          (
            null,
            'हम चाहते हैं कि आप Kusbilo पर बेझिझक ऑर्डर करें। यह पॉलिसी बताती है कि आप कब ऑर्डर रद्द कर सकते हैं, रिप्लेसमेंट माँग सकते हैं, या रिफंड पा सकते हैं।',
          ),
          (
            'ऑर्डर रद्द करना',
            'जब तक विक्रेता ने तैयारी शुरू नहीं की है, तब तक ऑर्डर मुफ़्त में रद्द किया जा सकता है। ऑनलाइन भुगतान किया हो और तैयारी शुरू होने से पहले रद्द कर दिया हो, तो पूरा पैसा वापस मिलेगा।',
          ),
          (
            'रिप्लेसमेंट विंडो',
            'हर प्रोडक्ट पेज पर उसकी रिप्लेसमेंट विंडो दिखाई जाती है:\n• सब्ज़ी-फल, डेयरी जैसे जल्दी खराब होने वाले सामान: डिलीवरी के 48 घंटे तक\n• बाकी सभी सामान (पैकेज्ड, कपड़े, घरेलू सामान आदि): डिलीवरी के 72 घंटे तक',
          ),
          (
            'रिप्लेसमेंट के लिए योग्य',
            '• मिला हुआ सामान टूटा-फूटा, खराब, या ऑर्डर से अलग हो\n• ऑर्डर में से कोई सामान गायब हो\n• गलत सामान या गलत मात्रा डिलीवर हुई हो\n• सामान एक्सपायर या इस्तेमाल के लायक न हो',
          ),
          (
            'रिप्लेसमेंट के लिए अयोग्य',
            '• रिप्लेसमेंट विंडो खत्म होने के बाद की गई माँग\n• डिलीवरी के बाद सिर्फ मन बदलने पर\n• ताज़ी सब्ज़ी-फल में सामान्य अंतर (आकार, रंग)\n• डिलीवरी सही हालत में लेने के बाद हुआ नुकसान',
          ),
          (
            'कैसे माँगें',
            '"मेरे ऑर्डर" में जाकर संबंधित ऑर्डर खोलें और समस्या बताएं, या नीचे दिए संपर्क पर लिखें। संभव हो तो फ़ोटो ज़रूर भेजें — इससे जल्दी समाधान मिलता है। हम हर माँग का जवाब 24 घंटे में देने की कोशिश करते हैं।',
          ),
          (
            'रिफंड कैसे मिलेगा',
            'स्वीकृत रिफंड आपके मूल भुगतान तरीके (UPI/कार्ड) में 5-7 कार्य दिवसों में वापस आ जाता है। Cash on Delivery ऑर्डर के लिए, रिफंड बैंक ट्रांसफर के ज़रिए किया जाता है।',
          ),
          (
            'संपर्क करें',
            'ऑर्डर से जुड़ी किसी भी मदद के लिए: support@kusbilo.in (ऑर्डर नंबर ज़रूर बताएं)',
          ),
        ]
      : [
          (
            null,
            'We want you to order on Kusbilo with confidence. This policy explains when you can cancel an order, request a replacement, or get a refund.',
          ),
          (
            'Cancelling an order',
            'You can cancel for free as long as the seller hasn\'t started preparing it yet. If you paid online and cancel before preparation starts, you get a full refund.',
          ),
          (
            'Replacement window',
            'Every product page shows its replacement window:\n• Perishables (fruits, vegetables, dairy): 48 hours from delivery\n• All other items (packaged goods, clothing, household items, etc.): 72 hours from delivery',
          ),
          (
            'What\'s eligible for replacement',
            '• The item is damaged, spoiled, or different from what was ordered\n• An item is missing from your order\n• The wrong item or quantity was delivered\n• The item is expired or unsafe to use',
          ),
          (
            'What\'s not eligible',
            '• Requests made after the replacement window has closed\n• Change of mind after delivery\n• Normal variation in fresh produce (size, colour)\n• Damage caused after accepting delivery in good condition',
          ),
          (
            'How to request',
            'Open the order under "My Orders" and report the issue, or write to us at the contact below. Include a photo where possible — it helps us resolve it faster. We aim to respond within 24 hours.',
          ),
          (
            'How refunds are issued',
            'Approved refunds go back to your original payment method (UPI/card) within 5–7 business days. For Cash on Delivery orders, refunds are issued via bank transfer.',
          ),
          (
            'Contact us',
            'For help with any order: support@kusbilo.in (please include your order ID)',
          ),
        ];

  String get rateAppBody => _isHindi
      ? 'अगर आपको कुसबिलो पसंद आया, तो कृपया इसे रेट करें — इससे और लोगों तक पहुँचने में मदद मिलती है।'
      : 'If you enjoy Kusbilo, please rate it — it helps more people discover the app.';

  String get rateAppButton => _isHindi ? 'अभी रेट करें' : 'Rate now';

  String get rateAppFailedError => _isHindi
      ? 'स्टोर नहीं खुल पाया, बाद में कोशिश करें'
      : "Couldn't open the store, please try again later";

  // ---- Merchant shop location ----

  String get shopLocationSection => _isHindi ? 'दुकान की जगह' : 'Shop location';

  String get shopLocationHelper => _isHindi
      ? 'इससे नज़दीकी ग्राहकों तक ऑर्डर पहुंचाना आसान होगा'
      : 'This helps route nearby orders to you correctly';

  String get shopLocationRequiredError =>
      _isHindi ? 'कृपया दुकान की जगह बताएं' : 'Please detect your shop location';

  // ---- Seller: incoming orders ----

  String get incomingOrdersTitle => _isHindi ? 'नए ऑर्डर' : 'Incoming Orders';

  String get noIncomingOrdersTitle => _isHindi ? 'अभी कोई नया ऑर्डर नहीं' : 'No new orders right now';

  String get acceptOrderButton => _isHindi ? 'स्वीकार करें' : 'Accept';

  String get rejectOrderButton => _isHindi ? 'अस्वीकार करें' : 'Reject';

  String get orderResponseFailed =>
      _isHindi ? 'कुछ गलत हो गया, दोबारा कोशिश करें' : 'Something went wrong, please try again';

  String etaMinutesLabel(int minutes) =>
      _isHindi ? 'लगभग $minutes मिनट में पहुंचेगा' : 'Arriving in about $minutes minutes';

  String get etaArrivingSoon => _isHindi ? 'बस पहुंचने ही वाला है' : 'Arriving any moment';

  String get etaMayArriveAnytime => _isHindi ? 'कभी भी पहुंच सकता है' : 'Could arrive any time now';

  // ---- Seller: active deliveries ----

  String get activeDeliveriesTitle => _isHindi ? 'मेरी डिलीवरी' : 'My Deliveries';

  String get deliveryPreparingLabel => _isHindi ? 'तैयार हो रहा है' : 'Preparing';

  String get deliveryInProgressLabel => _isHindi ? 'रास्ते में' : 'On the way';

  String get viewMapButton => _isHindi ? 'मैप देखें' : 'View Map';

  String get startDeliveryButton => _isHindi ? 'डिलीवरी शुरू करें' : 'Start Delivery';

  String get markDeliveredButton => _isHindi ? 'डिलीवर हो गया' : 'Mark Delivered';

  String get deliveryUpdateFailed =>
      _isHindi ? 'कुछ गलत हुआ, फिर कोशिश करें' : 'Something went wrong, please try again';

  // ---- Buyer: order tracking ----

  String get trackOrderTitle => _isHindi ? 'ऑर्डर ट्रैकिंग' : 'Track Order';

  String get trackOrderButton => _isHindi ? 'ऑर्डर ट्रैक करें' : 'Track Order';

  String get orderNotFound => _isHindi ? 'ऑर्डर नहीं मिला।' : 'Order not found.';

  String get statusPlacedLabel => _isHindi ? 'ऑर्डर दिया' : 'Order Placed';

  String get statusConfirmedLabel => _isHindi ? 'स्वीकार किया' : 'Confirmed';

  String get statusOutForDeliveryLabel => _isHindi ? 'रास्ते में' : 'Out for Delivery';

  String get statusDeliveredLabel => _isHindi ? 'डिलीवर हुआ' : 'Delivered';

  String get orderCancelledMessage =>
      _isHindi ? 'यह ऑर्डर रद्द कर दिया गया है।' : 'This order has been cancelled.';

  // ---- Voice ordering conversation ----

  String get voiceAnythingElsePrompt =>
      _isHindi ? 'और कुछ चाहिए? "हाँ" बोलें या अगली चीज़ बोलें, नहीं तो चुप रहें' : 'Anything else? Say "yes" or the next item, or stay quiet if done';

  String get voiceOrderPlacedSpoken => _isHindi
      ? 'आपका ऑर्डर हो गया है'
      : 'Your order has been placed';

  String voiceOrderEtaSpoken(int minutes) => _isHindi
      ? 'लगभग $minutes मिनट में पहुंच जाएगा'
      : 'It will arrive in about $minutes minutes';

  String get voiceLocationNeededSpoken => _isHindi
      ? 'जगह नहीं मिल पाई, कृपया चेकआउट से ऑर्डर पूरा करें'
      : "Couldn't detect your location, please complete checkout manually";

  String get voiceCartEmptyError =>
      _isHindi ? 'कार्ट खाली है, कुछ बोलकर ऑर्डर करें' : 'Cart is empty, say an item to order';

  String get voicePlacingOrderLabel => _isHindi ? 'ऑर्डर किया जा रहा है...' : 'Placing your order...';

  // ---- Live call-style voice ----

  String get liveCallConnecting => _isHindi ? 'जोड़ा जा रहा है...' : 'Connecting...';

  String get liveCallInProgress => _isHindi ? 'सुन रहे हैं — बोलिए' : 'Listening — go ahead and speak';

  String get liveCallEndButton => _isHindi ? 'बातचीत बंद करें' : 'End';

  String get liveCallStartButton => _isHindi ? 'बोलकर ऑर्डर करें' : 'Order by voice';

  String get liveCallFailedError => _isHindi
      ? 'कॉल शुरू नहीं हो पाई, दोबारा कोशिश करें'
      : "Couldn't start the call, please try again";

  String get liveCallMicPermissionError =>
      _isHindi ? 'बोलने के लिए माइक्रोफ़ोन की अनुमति दें' : 'Please allow microphone access to talk';

  String liveCallItemAdded(String itemName, int qty) =>
      _isHindi ? '$itemName × $qty कार्ट में जुड़ गया' : '$itemName × $qty added to cart';

  String get liveCallAiSpeakingLabel => _isHindi ? 'बोल रहे हैं...' : 'Speaking...';

  String get liveCallMuteButton => _isHindi ? 'माइक बंद करें' : 'Mute';

  String get liveCallUnmuteButton => _isHindi ? 'माइक चालू करें' : 'Unmute';

  String get liveCallPlacingOrderLabel => _isHindi ? 'ऑर्डर दिया जा रहा है...' : 'Placing your order...';

  String get liveCallNoApiKeyError => _isHindi
      ? 'वॉइस कॉल अभी सेटअप हो रही है, थोड़ी देर बाद कोशिश करें।'
      : 'Voice call is still being set up — please try again in a bit.';

  String get liveCallEmptyCartError => _isHindi
      ? 'कार्ट में कोई सामान नहीं जुड़ा — कृपया दोबारा कोशिश करें और सामान बोलकर बताएं।'
      : "Nothing was added to your cart — please try again and tell us what you'd like.";

  String get liveCallLocationError => _isHindi
      ? 'आपकी लोकेशन नहीं मिल पाई। लोकेशन की अनुमति चालू करके दोबारा कोशिश करें।'
      : "Couldn't get your location. Please turn on location access and try again.";

  String get liveCallOrderFailedError => _isHindi
      ? 'ऑर्डर नहीं हो पाया, कृपया दोबारा कोशिश करें।'
      : "Your order couldn't be placed, please try again.";

  // ---- Turn-based voice ordering (listen -> think -> speak loop) ----

  String get voiceListeningLabel => _isHindi ? 'सुन रहे हैं... बोलिए' : 'Listening... go ahead';

  String get voiceThinkingLabel => _isHindi ? 'सोचा जा रहा है...' : 'Thinking...';

  String get voiceUnclearMessage =>
      _isHindi ? 'माफ़ कीजिए, समझ नहीं आया। फिर से बोलिए।' : "Sorry, I didn't catch that. Please try again.";

  String get voiceCartEmptyMessage => _isHindi
      ? 'आपकी कार्ट अभी खाली है। पहले कुछ सामान बोलकर जोड़िए।'
      : 'Your cart is empty right now. Please add something first by speaking.';

  String get voiceOrderFailedMessage => _isHindi
      ? 'माफ़ कीजिए, ऑर्डर नहीं हो पाया। कृपया फिर से कोशिश करें।'
      : "Sorry, the order couldn't be placed. Please try again.";

  // ---- Voice FAQ answers (used by AppFaqService) ----

  String get faqHowToOrderAnswer => _isHindi
      ? 'माइक दबाकर बोलिए कि आपको क्या चाहिए, जैसे "मुझे दो किलो टमाटर चाहिए"। मैं आपके लिए कार्ट में जोड़ दूँगा।'
      : 'Press the mic and say what you need, like "I want two kilos of tomatoes." I\'ll add it to your cart.';

  String get faqPaymentAnswer => _isHindi
      ? 'अभी सिर्फ कैश ऑन डिलीवरी उपलब्ध है — सामान आने पर नकद भुगतान करें।'
      : 'Only Cash on Delivery is available right now — pay in cash when your order arrives.';

  String get faqDeliveryTimeAnswer => _isHindi
      ? 'डिलीवरी का समय विक्रेता की दूरी पर निर्भर करता है, आमतौर पर 20 से 40 मिनट में पहुंच जाता है।'
      : 'Delivery time depends on how far the seller is — usually it arrives within 20 to 40 minutes.';

  String get faqTrackOrderAnswer => _isHindi
      ? 'अपने ऑर्डर देखने के लिए प्रोफ़ाइल में जाकर "मेरे ऑर्डर" खोलें, वहां लाइव ट्रैकिंग भी मिलेगी।'
      : 'Open "My Orders" from your profile to see your orders — live tracking is available there too.';

  String get faqBecomeSellerAnswer => _isHindi
      ? 'विक्रेता बनने के लिए प्रोफ़ाइल में जाकर "विक्रेता बनें" चुनें और अपनी दुकान की जानकारी भरें।'
      : 'To become a seller, go to your profile and choose "Become a Seller," then fill in your shop details.';

  String get faqChangeLanguageAnswer => _isHindi
      ? 'ऊपर दाईं ओर हिंदी/EN बटन दबाकर आप भाषा बदल सकते हैं।'
      : 'You can switch languages anytime using the हिंदी/EN button in the top corner.';

  String get faqCancelOrderAnswer => _isHindi
      ? 'अभी ऑर्डर रद्द करने की सुविधा ऐप में उपलब्ध नहीं है, कृपया विक्रेता से संपर्क करें।'
      : 'Cancelling an order isn\'t available in the app yet — please contact the seller directly.';

  String get faqAppNameAnswer => _isHindi
      ? 'यह गांवहाट है — अपने गांव के आसपास की दुकानों से सीधे सामान मंगाने का ऐप।'
      : 'This is Kusbilo — an app to order straight from shops around your village.';
}
