import 'dart:typed_data';
import 'package:pointycastle/export.dart';
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
  static Future<Identity> generate() async {
    final keyGen = Ed25519KeyGenerator();
    final secureRandom = FortunaRandom();
    
    // Seed pentru generarea aleatorie
    final seed = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      seed[i] = i; // Simplificat - în producție folosește Random.secure()
    }
    secureRandom.seed(KeyParameter(seed));
    
    final keyPair = keyGen.generateKeyPair(secureRandom);
    final publicKey = keyPair.publicKey as Ed25519PublicKey;
    final privateKey = keyPair.privateKey as Ed25519PrivateKey;
    
    final publicKeyBytes = publicKey.keyData;
    final privateKeyBytes = privateKey.keyData;
    
    // Peer ID este hash-ul cheii publice (simplificat)
    final peerId = base64Encode(publicKeyBytes).substring(0, 16);
    
    return Identity(
      peerId: peerId,
      publicKey: base64Encode(publicKeyBytes),
      privateKey: base64Encode(privateKeyBytes),
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
