import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

/// Uploads a product photo to Cloud Storage and returns its public
/// download URL. Storage (not Firestore) is the right place for the
/// actual image bytes — Firestore documents stay small and fast to
/// query, and the URL is all CatalogProvider/Product ever need.
class ProductImageService {
  static final _storage = FirebaseStorage.instance;

  /// Path is keyed by sellerUid + productId so storage.rules can check
  /// "does this file live under this seller's own folder?" without
  /// needing to read Firestore at all — see storage.rules.
  static Future<String> uploadProductImage({
    required String sellerUid,
    required String productId,
    required File imageFile,
  }) async {
    final ref = _storage.ref('product_images/$sellerUid/$productId.jpg');
    await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
