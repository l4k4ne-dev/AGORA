import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../agora_crypto/storage.dart';
import '../models/identity.dart';

class StorageService {
  static const String _contactsKey = 'agora_contacts';
  static final IdentityStorage _identityStorage = IdentityStorage();

  /// Încarcă identitatea existentă sau generează una nouă.
  /// Șterge orice legacy corrupt din SharedPreferences.
  static Future<(Identity, bool wasNewlyGenerated)>
      loadOrCreateIdentity() async {
    final wasLegacyMigrated =
        await _identityStorage.migrateLegacyIfPresent();
    final (agora, wasNew) = await _identityStorage.loadOrGenerate();
    return (Identity(agora), wasNew || wasLegacyMigrated);
  }

  /// Verifică dacă există identitate salvată (secure storage).
  static Future<bool> hasIdentity() async {
    final existing = await _identityStorage.load();
    return existing != null;
  }

  /// Încarcă identitatea salvată sau null dacă nu există.
  static Future<Identity?> getIdentity() async {
    final agora = await _identityStorage.load();
    if (agora == null) return null;
    return Identity(agora);
  }

  /// Salvare explicită (rar necesară — loadOrCreateIdentity salvează automat).
  static Future<void> saveIdentity(Identity identity) async {
    await _identityStorage.save(identity.raw);
  }

  /// Șterge identitatea (folosită la reset/migrare).
  static Future<void> clearIdentity() async {
    await _identityStorage.clear();
  }

  // ============================================================
  // Contacts (rămân pe SharedPreferences în Faza 1 — nu sunt secrete)
  // ============================================================

  static Future<void> saveContacts(List<Map<String, String>> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = contacts.map((c) => jsonEncode(c)).toList();
    await prefs.setStringList(_contactsKey, jsonList);
  }

  static Future<List<Map<String, String>>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_contactsKey) ?? [];
    return jsonList.map((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      return Map<String, String>.from(json);
    }).toList();
  }

  static Future<void> addContact(String peerId, String publicKey) async {
    final contacts = await getContacts();
    contacts.add({'peerId': peerId, 'publicKey': publicKey});
    await saveContacts(contacts);
  }

  static Future<void> clearContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_contactsKey);
  }
}
