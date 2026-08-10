import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/localization/locale_provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/haat_badge.dart';
import 'features/auth/presentation/providers/auth_flow_provider.dart';
import 'features/auth/presentation/screens/phone_login_screen.dart';
import 'features/cart/presentation/providers/cart_provider.dart';
import 'features/home/data/catalog_provider.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/addresses/presentation/providers/addresses_provider.dart';
import 'features/admin/presentation/providers/admin_provider.dart';
import 'features/favorites/presentation/providers/favorites_provider.dart';
import 'features/merchant/presentation/providers/merchant_provider.dart';
import 'features/merchant/presentation/providers/seller_orders_provider.dart';
import 'features/merchant/presentation/providers/seller_products_provider.dart';
import 'features/order/presentation/providers/order_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App Check is NOT activated for now — Play Integrity only passes for
  // apps installed via the Play Store, and this app is sideloaded
  // (release build installed directly, no Play Console yet). Activating
  // it here would just throw the same "App attestation failed" error on
  // every launch. App Check enforcement is already off/monitoring on the
  // Firestore side in the Firebase Console, so Firestore calls work fine
  // without this. Once there's a Play Console account: upload the app,
  // register the release SHA-256 in Firebase Console > App Check, then
  // add back:
  //   await FirebaseAppCheck.instance.activate(
  //     providerAndroid: AndroidPlayIntegrityProvider(),
  //     providerApple: AppleAppAttestProvider(),
  //   );
  await NotificationService.initForegroundHandler();
  runApp(const GaonHaatApp());
}

class GaonHaatApp extends StatelessWidget {
  const GaonHaatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthFlowProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => MerchantProvider()),
        ChangeNotifierProvider(create: (_) => SellerProductsProvider()),
        ChangeNotifierProvider(create: (_) => SellerOrdersProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => AddressesProvider()),
      ],
      child: MaterialApp(
        title: 'GaonHaat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}

/// Decides which screen to show on app start: Firebase persists sign-in
/// state on the device, so a user who verified their phone earlier should
/// land straight on Home again — not be asked to log in every time the
/// app restarts. This listens to Firebase's own auth state instead of
/// hardcoding a starting screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _StartupSplash();
        }
        if (snapshot.hasData) {
          // Cheap to call every time auth state resolves to "logged in" —
          // it just re-saves the current FCM token, which is exactly what
          // you want after a fresh login or a token rotation.
          NotificationService.registerBuyerDevice();
          return const HomeShellScreen();
        }
        return const PhoneLoginScreen();
      },
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HaatBadge(size: 72),
            SizedBox(height: 20),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.green),
            ),
          ],
        ),
      ),
    );
  }
}
