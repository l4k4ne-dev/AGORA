import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pointycastle/export.dart';
import 'dart:typed_data';
import 'dart:math';

class IdentityService {
  static const String _identityKey = 'agora_identity';

  Future<Map<String, String>> getIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    String? identityJson = prefs.getString(_identityKey);

    if (identityJson != null) {
      return Map<String, String>.from(jsonDecode(identityJson));
    }

    // Generate new identity
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = ECKeyGenerator()
      ..init(ParametersWithRandom(
          ECKeyGeneratorParameters(ECCurve_secp256k1()), secureRandom));

    final keyPair = keyGen.generateKeyPair();
    final publicKey = keyPair.publicKey as ECPublicKey;
    
    // Convert to simple format for MVP (in real app, use proper Ed25519)
    final identity = {
      'public_key': base64Encode(publicKey.Q!.getEncoded(true)),
      'private_key': base64Encode((keyPair.privateKey as ECPrivateKey).d!.toByteArray()),
      'peer_id': base64Encode(publicKey.Q!.getEncoded(true)).substring(0, 12)
    };

    await prefs.setString(_identityKey, jsonEncode(identity));
    return identity;
  }
}

class HomeNodeService {
  final String baseUrl = 'http://10.0.2.2:8080'; // Android emulator localhost
  // For iOS simulator use: http://127.0.0.1:8080
  // For physical device use host IP

  Future<List<dynamic>> getContacts(String peerId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/contacts/$peerId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print("Error fetching contacts: $e");
      return [];
    }
  }

  Future<bool> addContact(String myPeerId, String friendPublicKey, String alias) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/contacts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'owner_id': myPeerId,
          'friend_public_key': friendPublicKey,
          'alias': alias
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      print("Error adding contact: $e");
      return false;
    }
  }

  Future<List<dynamic>> getMessages(String peerId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/messages/pending/$peerId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print("Error fetching messages: $e");
      return [];
    }
  }

  Future<bool> sendMessage(String fromId, String toId, String content) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'from_id': fromId,
          'to_id': toId,
          'content': content
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      print("Error sending message: $e");
      return false;
    }
  }
}
