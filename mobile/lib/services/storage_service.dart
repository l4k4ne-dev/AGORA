import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/identity.dart';

class StorageService {
  static const String _identityKey = 'agora_identity';
  static const String _contactsKey = 'agora_contacts';

  /// Salvează identitatea
  static Future<void> saveIdentity(Identity identity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_identityKey, jsonEncode(identity.toJson()));
  }

  /// Încarcă identitatea salvată
  static Future<Identity?> getIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_identityKey);
    if (jsonStr == null) return null;
    
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return Identity.fromJson(Map<String, String>.from(json));
  }

  /// Verifică dacă există identitate salvată
  static Future<bool> hasIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_identityKey);
  }

  /// Salvează lista de contacte
  static Future<void> saveContacts(List<Map<String, String>> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = contacts.map((c) => jsonEncode(c)).toList();
    await prefs.setStringList(_contactsKey, jsonList);
  }

  /// Încarcă lista de contacte
  static Future<List<Map<String, String>>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_contactsKey) ?? [];
    return jsonList.map((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      return Map<String, String>.from(json);
    }).toList();
  }

  /// Adaugă un contact nou
  static Future<void> addContact(String peerId, String publicKey) async {
    final contacts = await getContacts();
    contacts.add({'peerId': peerId, 'publicKey': publicKey});
    await saveContacts(contacts);
  }
}
