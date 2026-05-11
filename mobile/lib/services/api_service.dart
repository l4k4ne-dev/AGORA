import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Pentru Android emulator: 10.0.2.2
  // Pentru iOS simulator: 127.0.0.1
  // Pentru device fizic în același LAN: IP-ul mașinii host
  static const String baseUrl = 'http://10.0.2.2:8080';

  /// Verifică statusul node-ului
  static Future<Map<String, dynamic>> getStatus() async {
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

  /// Primește mesaje pending
  static Future<List<Map<String, dynamic>>> getPendingMessages(String peerId) async {
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

  /// Adaugă un contact
  static Future<bool> addContact(String peerId, String publicKey) async {
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

  /// Listează contactele
  static Future<List<Map<String, dynamic>>> getContacts() async {
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
