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

  /// Uploads as many photos as the seller picked for one product —
  /// there's no fixed limit here; each file just gets its own indexed
  /// path (`0.jpg`, `1.jpg`, ...) under that product's folder. Returns
  /// the download URLs in the same order as [imageFiles], ready to
  /// save straight into `Product.imageUrls`.
  static Future<List<String>> uploadProductImages({
    required String sellerUid,
    required String productId,
    required List<File> imageFiles,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < imageFiles.length; i++) {
      final ref = _storage.ref('product_images/$sellerUid/$productId/$i.jpg');
      await ref.putFile(imageFiles[i], SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }
}
