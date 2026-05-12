import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _nodeUrlKey = 'node_url';
  static const String _defaultUrl = 'http://10.0.2.2:8080';

  /// Get the configured node URL
  static Future<String> getNodeUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nodeUrlKey) ?? _defaultUrl;
  }

  /// Set the node URL
  static Future<void> setNodeUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nodeUrlKey, url);
  }

  /// Verifica statusul node-ului
  static Future<Map<String, dynamic>> getStatus() async {
    final baseUrl = await getNodeUrl();
    try {
      final response = await http.get(Uri.parse('$baseUrl/status'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  /// Trimite un mesaj
  static Future<bool> sendMessage(String peerId, String encryptedContent) async {
    final baseUrl = await getNodeUrl();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'peer_id': peerId,
          'encrypted_content': encryptedContent,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Primeste mesaje pending
  static Future<List<Map<String, dynamic>>> getPendingMessages(String peerId) async {
    final baseUrl = await getNodeUrl();
    try {
      final response = await http.get(Uri.parse('$baseUrl/messages/pending/$peerId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((m) => m as Map<String, dynamic>).toList();
        }
        return [];
      } else {
        throw Exception('Failed to get messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  /// Adauga un contact
  static Future<bool> addContact(String peerId, String publicKey) async {
    final baseUrl = await getNodeUrl();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/contacts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'peer_id': peerId,
          'public_key': publicKey,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Failed to add contact: $e');
    }
  }

  /// Listeaza contactele
  static Future<List<Map<String, dynamic>>> getContacts() async {
    final baseUrl = await getNodeUrl();
    try {
      final response = await http.get(Uri.parse('$baseUrl/contacts'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((c) => c as Map<String, dynamic>).toList();
        }
        return [];
      } else {
        throw Exception('Failed to get contacts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
}
