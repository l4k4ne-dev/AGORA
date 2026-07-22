import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'identity.dart';

class IdentityStorage {
  static const _storageKey = 'agora_identity_v1';
  static const _legacyKey = 'agora_identity'; // vechiul loc SharedPreferences

  final FlutterSecureStorage _storage;

  IdentityStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  Future<AgoraIdentity?> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return await AgoraIdentity.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AgoraIdentity identity) async {
    final json = await identity.toJson();
    await _storage.write(key: _storageKey, value: jsonEncode(json));
  }

  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
  }

  /// Șterge identitatea legacy din SharedPreferences (era invalidă oricum).
  /// Returnează true dacă a găsit și șters ceva.
  Future<bool> migrateLegacyIfPresent() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLegacy = prefs.containsKey(_legacyKey);
    if (hasLegacy) {
      await prefs.remove(_legacyKey);
    }
    return hasLegacy;
  }

  /// Convenience: încarcă existentă sau generează una nouă și o salvează.
  /// Returnează (identity, wasNewlyGenerated).
  Future<(AgoraIdentity, bool)> loadOrGenerate(
      {int oneTimePreKeyCount = 100}) async {
    final existing = await load();
    if (existing != null) return (existing, false);
    final fresh =
        await AgoraIdentity.generate(oneTimePreKeyCount: oneTimePreKeyCount);
    await save(fresh);
    return (fresh, true);
  }
}
