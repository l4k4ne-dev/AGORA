import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class Identity {
  final String peerId;
  final String publicKey;  // hex
  final String privateKey; // hex

  Identity({
    required this.peerId,
    required this.publicKey,
    required this.privateKey,
  });

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  static Future<Identity> generate() async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final pubKey = await keyPair.extractPublicKey();
    final privKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubBytes = pubKey.bytes;
    final privHex = _bytesToHex(privKeyBytes);
    final pubHex = _bytesToHex(pubBytes);
    final peerId = base64UrlEncode(pubBytes).replaceAll('=', '').substring(0, 16);

    return Identity(
      peerId: peerId,
      publicKey: pubHex,
      privateKey: privHex,
    );
  }

  Uint8List get publicKeyBytes => _hexToBytes(publicKey);
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
