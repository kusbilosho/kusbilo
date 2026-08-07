import '../localization/app_strings.dart';

/// The known "how does this app work" questions the voice coach can
/// answer. Kept as an enum (rather than free text) so matching stays
/// deterministic and every answer is reviewed/localized up front in
/// [AppStrings] instead of generated on the fly.
enum AppFaqTopic {
  howToOrder,
  payment,
  deliveryTime,
  trackOrder,
  becomeSeller,
  changeLanguage,
  cancelOrder,
  aboutApp,
}

/// Offline, rule-based "app coach": scores the buyer's words against a
/// small set of keyword groups per topic, the same weighted-overlap
/// approach [VoiceOrderService.match] uses for products. This is what
/// lets the voice assistant answer general app questions ("delivery
/// mein kitna time lagega?", "seller kaise banu?") instead of only
/// parsing product orders — no external AI call, so it keeps working
/// offline and with zero per-request cost.
class AppFaqService {
  static const Map<AppFaqTopic, List<String>> _keywords = {
    AppFaqTopic.howToOrder: [
      'order kaise', 'kaise order', 'order karu', 'order karna',
      'ऑर्डर कैसे', 'कैसे ऑर्डर', 'ऑर्डर करना',
      'how to order', 'how do i order', 'place order',
    ],
    AppFaqTopic.payment: [
      'payment', 'paisa', 'paise', 'bhugtan', 'cash', 'cod',
      'भुगतान', 'पैसा', 'पैसे', 'नकद',
      'pay', 'how to pay',
    ],
    AppFaqTopic.deliveryTime: [
      'delivery time', 'kitna time', 'kab tak', 'kab aayega', 'kab milega', 'eta',
      'डिलीवरी', 'कितना समय', 'कब तक', 'कब आएगा', 'कब मिलेगा',
      'how long', 'when will it arrive',
    ],
    AppFaqTopic.trackOrder: [
      'track', 'order status', 'mera order', 'order kaha',
      'ऑर्डर स्टेटस', 'मेरा ऑर्डर', 'ऑर्डर कहाँ', 'ऑर्डर कहां',
      'where is my order', 'order history',
    ],
    AppFaqTopic.becomeSeller: [
      'seller kaise', 'vikreta', 'becoming seller', 'seller banu', 'kyc',
      'विक्रेता', 'बेचना', 'बेचने',
      'become a seller', 'how to sell', 'sell on this app',
    ],
    AppFaqTopic.changeLanguage: [
      'language kaise', 'bhasha', 'change language',
      'भाषा', 'भाषा कैसे',
      'switch language',
    ],
    AppFaqTopic.cancelOrder: [
      'cancel', 'radd', 'रद्द', 'रद', 'cancel order',
      'how to cancel',
    ],
    AppFaqTopic.aboutApp: [
      'yeh app', 'ye app kya', 'app kya hai',
      'यह ऐप', 'ये ऐप', 'ऐप क्या',
      'what is this app', 'about this app',
    ],
  };

  /// Returns the best-matching topic for [text], or null if nothing
  /// scores highly enough to be confident this was an app question
  /// rather than noise / an unmatched product name.
  static AppFaqTopic? match(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty) return null;

    AppFaqTopic? best;
    int bestScore = 0;

    for (final entry in _keywords.entries) {
      int score = 0;
      for (final phrase in entry.value) {
        if (normalized.contains(phrase)) {
          // Longer phrases are more specific, so weight them higher —
          // stops a short generic word from outscoring a precise match.
          score += phrase.length >= 8 ? 3 : 2;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }

    if (bestScore < 2) return null;
    return best;
  }

  /// Looks up the localized spoken answer for [topic].
  static String answerFor(AppFaqTopic topic, AppStrings strings) {
    switch (topic) {
      case AppFaqTopic.howToOrder:
        return strings.faqHowToOrderAnswer;
      case AppFaqTopic.payment:
        return strings.faqPaymentAnswer;
      case AppFaqTopic.deliveryTime:
        return strings.faqDeliveryTimeAnswer;
      case AppFaqTopic.trackOrder:
        return strings.faqTrackOrderAnswer;
      case AppFaqTopic.becomeSeller:
        return strings.faqBecomeSellerAnswer;
      case AppFaqTopic.changeLanguage:
        return strings.faqChangeLanguageAnswer;
      case AppFaqTopic.cancelOrder:
        return strings.faqCancelOrderAnswer;
      case AppFaqTopic.aboutApp:
        return strings.faqAppNameAnswer;
    }
  }
}
