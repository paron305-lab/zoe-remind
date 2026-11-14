import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// Secure Design: bago gamitin ang model file, siguraduhing buo at hindi
/// pinalitan — dapat tugma ang SHA-256 nito sa nasa Supabase (model_config).
class ModelVerifier {
  ModelVerifier._();

  /// SHA-256 ng buong file (lowercase hex). Tumatakbo sa hiwalay na isolate
  /// para hindi mag-lag ang UI habang binabasa ang ~500 MB.
  static Future<String> sha256OfFile(String path) {
    return Isolate.run(() async {
      final digest = await sha256.bind(File(path).openRead()).first;
      return digest.toString();
    });
  }

  /// true kapag tugma ang laki at hash ng file sa inaasahan.
  static Future<bool> matches({
    required String path,
    required int expectedBytes,
    required String expectedSha256,
  }) async {
    final file = File(path);
    if (!await file.exists()) return false;
    if (await file.length() != expectedBytes) return false;
    final hash = await sha256OfFile(path);
    return hash == expectedSha256.toLowerCase();
  }
}