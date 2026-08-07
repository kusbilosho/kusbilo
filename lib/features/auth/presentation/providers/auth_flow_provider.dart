import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum AuthStatus { idle, sendingOtp, otpSent, verifying, verified, error }

/// Wires the login flow to real Firebase Phone Authentication.
/// - [sendOtp] triggers an actual SMS via Firebase.
/// - [resendOtp] re-triggers it using Firebase's forceResendingToken.
/// - [verifyOtp] checks the code the user typed against Firebase.
/// No auto sign-in / auto-fill — user always types the OTP manually.
class AuthFlowProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _phoneNumber = '';
  String? _verificationId;
  int? _resendToken;
  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;

  String get phoneNumber => _phoneNumber;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isPhoneValid => _phoneNumber.length == 10;
  bool get isLoading =>
      _status == AuthStatus.sendingOtp || _status == AuthStatus.verifying;

  void setPhoneNumber(String value) {
    _phoneNumber = value;
    notifyListeners();
  }

  /// Sends a real OTP SMS to +91<phoneNumber> via Firebase.
  /// Returns true only once Firebase actually confirms the code was sent
  /// (via the codeSent callback) — not as soon as verifyPhoneNumber()
  /// itself returns, since that future resolves before codeSent fires.
  Future<bool> sendOtp() async {
    if (!isPhoneValid) return false;
    return _requestOtp();
  }

  /// Re-sends the OTP to the same number, using Firebase's
  /// forceResendingToken so it's treated as a genuine resend rather than
  /// a brand-new verification attempt.
  Future<bool> resendOtp() async {
    if (!isPhoneValid) return false;
    return _requestOtp(isResend: true);
  }

  Future<bool> _requestOtp({bool isResend = false}) async {
    _status = AuthStatus.sendingOtp;
    _errorMessage = null;
    notifyListeners();

    final completer = Completer<bool>();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$_phoneNumber',
        timeout: const Duration(seconds: 60),
        forceResendingToken: isResend ? _resendToken : null,

        // Intentionally left as a no-op: auto sign-in / auto-fill is
        // disabled on purpose. The user always types the OTP manually
        // on the verification screen, even if Android detects the SMS.
        verificationCompleted: (PhoneAuthCredential credential) {},

        verificationFailed: (FirebaseAuthException e) {
          _status = AuthStatus.error;
          _errorMessage = _mapError(e);
          notifyListeners();
          if (!completer.isCompleted) completer.complete(false);
        },

        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _status = AuthStatus.otpSent;
          notifyListeners();
          if (!completer.isCompleted) completer.complete(true);
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Kuch galat ho gaya. Dobara try karein.';
      notifyListeners();
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  /// Verifies the 6-digit code the user entered against Firebase.
  /// Returns true on success (screen should navigate to the welcome screen).
  Future<bool> verifyOtp(String smsCode) async {
    if (_verificationId == null) {
      _errorMessage = 'Session expire ho gaya, dobara number bhejein.';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.verifying;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);
      _status = AuthStatus.verified;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _mapError(e);
      notifyListeners();
      return false;
    }
  }

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Yeh mobile number sahi nahi hai.';
      case 'invalid-verification-code':
        return 'OTP galat hai, dobara check karein.';
      case 'session-expired':
        return 'OTP expire ho gaya, dobara bhejein.';
      case 'too-many-requests':
        return 'Bahut zyada koshishein ho gayi hain, thodi der baad try karein.';
      default:
        return e.message ?? 'Kuch galat ho gaya.';
    }
  }

  void reset() {
    _phoneNumber = '';
    _verificationId = null;
    _resendToken = null;
    _status = AuthStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
