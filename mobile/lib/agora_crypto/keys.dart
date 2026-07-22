import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Wrapper pentru X25519 (Diffie-Hellman) folosit în X3DH + Double Ratchet.
class X25519Keys {
  static final _algo = X25519();

  /// Generează o pereche X25519 nouă (privată + publică).
  static Future<SimpleKeyPair> generate() => _algo.newKeyPair();

  /// Extrage cheia publică din keypair.
  static Future<SimplePublicKey> publicKey(SimpleKeyPair kp) =>
      kp.extractPublicKey();

  /// Calculează shared secret (32 bytes) între priv-ul nostru și pub-ul partenerului.
  static Future<List<int>> sharedSecret(
      SimpleKeyPair ours, SimplePublicKey theirs) async {
    final secretKey = await _algo.sharedSecretKey(
        keyPair: ours, remotePublicKey: theirs);
    return secretKey.extractBytes();
  }

  /// Serializare public key ca base64 (pentru wire / storage).
  static Future<String> publicKeyBase64(SimpleKeyPair kp) async {
    final pub = await publicKey(kp);
    return base64Encode(pub.bytes);
  }

  /// Deserializare public key din base64.
  static SimplePublicKey publicKeyFromBase64(String b64) {
    return SimplePublicKey(base64Decode(b64), type: KeyPairType.x25519);
  }

  /// Serializare private key ca base64 (doar pentru secure storage).
  static Future<String> privateKeyBase64(SimpleKeyPair kp) async {
    final privBytes = await kp.extractPrivateKeyBytes();
    return base64Encode(privBytes);
  }

  /// Reconstrucție keypair din private key base64.
  static Future<SimpleKeyPair> fromPrivateBase64(String b64) async {
    final privBytes = base64Decode(b64);
    return _algo.newKeyPairFromSeed(privBytes);
  }
}

/// Wrapper pentru Ed25519 (semnături) — long-term identity.
class Ed25519Keys {
  static final _algo = Ed25519();

  /// Generează o pereche Ed25519 nouă.
  static Future<SimpleKeyPair> generate() => _algo.newKeyPair();

  /// Extrage cheia publică.
  static Future<SimplePublicKey> publicKey(SimpleKeyPair kp) =>
      kp.extractPublicKey();

  /// Semnează bytes cu private key.
  static Future<List<int>> sign(SimpleKeyPair kp, List<int> message) async {
    final sig = await _algo.sign(message, keyPair: kp);
    return sig.bytes;
  }

  /// Verifică o semnătură cu public key.
  static Future<bool> verify({
    required List<int> message,
    required List<int> signatureBytes,
    required SimplePublicKey publicKey,
  }) async {
    final sig = Signature(signatureBytes, publicKey: publicKey);
    return _algo.verify(message, signature: sig);
  }

  /// Serializare public key ca base64.
  static Future<String> publicKeyBase64(SimpleKeyPair kp) async {
    final pub = await publicKey(kp);
    return base64Encode(pub.bytes);
  }

  static SimplePublicKey publicKeyFromBase64(String b64) {
    return SimplePublicKey(base64Decode(b64), type: KeyPairType.ed25519);
  }

  static Future<String> privateKeyBase64(SimpleKeyPair kp) async {
    final privBytes = await kp.extractPrivateKeyBytes();
    return base64Encode(privBytes);
  }

  static Future<SimpleKeyPair> fromPrivateBase64(String b64) async {
    final privBytes = base64Decode(b64);
    return _algo.newKeyPairFromSeed(privBytes);
  }
}
