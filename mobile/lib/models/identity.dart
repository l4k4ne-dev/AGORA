import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class Identity {
  final String peerId;
  final String publicKey;
  final String privateKey;

  Identity({
    required this.peerId,
    required this.publicKey,
    required this.privateKey,
  });

  static Future<Identity> generate() async {
    final rng = Random.secure();
    final privBytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final pubBytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final privHex = privBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final pubHex = pubBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final peerId = base64UrlEncode(pubBytes).replaceAll('=', '').substring(0, 16);
    return Identity(peerId: peerId, publicKey: pubHex, privateKey: privHex);
  }

  Uint8List get publicKeyBytes {
    final result = Uint8List(publicKey.length ~/ 2);
    for (var i = 0; i < publicKey.length; i += 2) {
      result[i ~/ 2] = int.parse(publicKey.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  Uint8List get privateKeyBytes {
    final result = Uint8List(privateKey.length ~/ 2);
    for (var i = 0; i < privateKey.length; i += 2) {
      result[i ~/ 2] = int.parse(privateKey.substring(i, i + 2), radix: 16);
    }
    return result;
  }

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
