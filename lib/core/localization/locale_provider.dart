import 'package:flutter/foundation.dart';
import 'app_strings.dart';

/// Holds the currently selected app language and notifies listeners
/// so every screen rebuilds with the correct strings when toggled.
class LocaleProvider extends ChangeNotifier {
  AppLanguage _language = AppLanguage.hindi;

  AppLanguage get language => _language;

  AppStrings get strings => AppStrings(_language);

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
  }

  void toggle() {
    setLanguage(
      _language == AppLanguage.hindi ? AppLanguage.english : AppLanguage.hindi,
    );
  }
}
