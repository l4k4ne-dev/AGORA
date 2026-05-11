import 'dart:convert';

class Identity {
  final String peerId;
  final String publicKey;
  final String privateKey;

  Identity({
    required this.peerId,
    required this.publicKey,
    required this.privateKey,
  });

  /// Generează o identitate nouă cu chei Ed25519
  /// Simplificat pentru MVP - în producție folosește pointycastle sau crypto
  static Future<Identity> generate() async {
    // Pentru MVP, generăm chei pseudo-aleatorii
    // În producție, folosește: import 'package:cryptography/cryptography.dart';
    final random = List<int>.generate(32, (i) => (i * 7 + 13) % 256);
    final publicKeyBytes = List<int>.generate(32, (i) => (i * 11 + 7) % 256);
    
    final peerId = base64Encode(publicKeyBytes).substring(0, 16);
    
    return Identity(
      peerId: peerId,
      publicKey: base64Encode(publicKeyBytes),
      privateKey: base64Encode(random),
    );
  }

  /// Convertește la JSON pentru stocare
  Map<String, String> toJson() {
    return {
      'peerId': peerId,
      'publicKey': publicKey,
      'privateKey': privateKey,
    };
  }

  /// Creează din JSON
  factory Identity.fromJson(Map<String, String> json) {
    return Identity(
      peerId: json['peerId']!,
      publicKey: json['publicKey']!,
      privateKey: json['privateKey']!,
    );
  }
}
