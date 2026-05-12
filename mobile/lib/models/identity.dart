import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class Identity {
  final String peerId;
  final String publicKey;  // hex
  final String privateKey; // hex

  Identity({
    required this.peerId,
    required this.publicKey,
    required this.privateKey,
  });

  /// Generate a real X25519 identity
  static Future<Identity> generate() async {
    // Generate 32 cryptographically random bytes for private key
    final rng = Random.secure();
    final privBytes = Uint8List.fromList(
      List<int>.generate(32, (_) => rng.nextInt(256)),
    );

    // Clamp private key per X25519 spec
    privBytes[0] &= 248;
    privBytes[31] &= 127;
    privBytes[31] |= 64;

    // Derive public key using X25519
    final x25519 = X25519();
    final pubBytes = x25519.scalarMultBase(privBytes);

    final privHex = _bytesToHex(privBytes);
    final pubHex = _bytesToHex(pubBytes);
    final peerId = base64UrlEncode(pubBytes).replaceAll('=', '').substring(0, 16);

    return Identity(
      peerId: peerId,
      publicKey: pubHex,
      privateKey: privHex,
    );
  }

  static String _bytesToHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Public key as bytes
  Uint8List get publicKeyBytes => _hexToBytes(publicKey);

  /// Private key as bytes
  Uint8List get privateKeyBytes => _hexToBytes(privateKey);

  Map<String, String> toJson() => {
    'peerId': peerId,
    'publicKey': publicKey,
    'privateKey': privateKey,
  };

  factory Identity.fromJson(Map<String, String> json) => Identity(
    peerId: json['peerId']!,
    publicKey: json['publicKey']!,
    privateKey: json['privateKey']!,
  );
}
