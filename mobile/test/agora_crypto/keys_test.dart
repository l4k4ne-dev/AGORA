import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:agora_app/agora_crypto/keys.dart';

void main() {
  group('X25519Keys', () {
    test('generate produces 32-byte public key', () async {
      final kp = await X25519Keys.generate();
      final pub = await X25519Keys.publicKey(kp);
      expect(pub.bytes.length, 32);
    });

    test('shared secret is symmetric (Alice <-> Bob)', () async {
      final alice = await X25519Keys.generate();
      final bob = await X25519Keys.generate();
      final alicePub = await X25519Keys.publicKey(alice);
      final bobPub = await X25519Keys.publicKey(bob);

      final s1 = await X25519Keys.sharedSecret(alice, bobPub);
      final s2 = await X25519Keys.sharedSecret(bob, alicePub);

      expect(s1, equals(s2));
      expect(s1.length, 32);
    });

    test('base64 roundtrip preserves public key', () async {
      final kp = await X25519Keys.generate();
      final b64 = await X25519Keys.publicKeyBase64(kp);
      final restored = X25519Keys.publicKeyFromBase64(b64);
      final original = await X25519Keys.publicKey(kp);
      expect(restored.bytes, equals(original.bytes));
    });

    test('private key roundtrip reconstructs same keypair', () async {
      final kp1 = await X25519Keys.generate();
      final privB64 = await X25519Keys.privateKeyBase64(kp1);
      final kp2 = await X25519Keys.fromPrivateBase64(privB64);

      final pub1 = await X25519Keys.publicKey(kp1);
      final pub2 = await X25519Keys.publicKey(kp2);
      expect(pub1.bytes, equals(pub2.bytes));
    });
  });

  group('Ed25519Keys', () {
    test('sign + verify roundtrip', () async {
      final kp = await Ed25519Keys.generate();
      final pub = await Ed25519Keys.publicKey(kp);
      final msg = utf8.encode('AGORA test message');

      final sig = await Ed25519Keys.sign(kp, msg);
      final ok = await Ed25519Keys.verify(
        message: msg,
        signatureBytes: sig,
        publicKey: pub,
      );
      expect(ok, isTrue);
    });

    test('tampered signature fails verify', () async {
      final kp = await Ed25519Keys.generate();
      final pub = await Ed25519Keys.publicKey(kp);
      final msg = utf8.encode('AGORA test message');

      final sig = await Ed25519Keys.sign(kp, msg);
      sig[0] = sig[0] ^ 0xFF;

      final ok = await Ed25519Keys.verify(
        message: msg,
        signatureBytes: sig,
        publicKey: pub,
      );
      expect(ok, isFalse);
    });

    test('wrong public key fails verify', () async {
      final alice = await Ed25519Keys.generate();
      final bob = await Ed25519Keys.generate();
      final bobPub = await Ed25519Keys.publicKey(bob);
      final msg = utf8.encode('AGORA test message');

      final sig = await Ed25519Keys.sign(alice, msg);
      final ok = await Ed25519Keys.verify(
        message: msg,
        signatureBytes: sig,
        publicKey: bobPub,
      );
      expect(ok, isFalse);
    });

    test('base64 roundtrip preserves public key', () async {
      final kp = await Ed25519Keys.generate();
      final b64 = await Ed25519Keys.publicKeyBase64(kp);
      final restored = Ed25519Keys.publicKeyFromBase64(b64);
      final original = await Ed25519Keys.publicKey(kp);
      expect(restored.bytes, equals(original.bytes));
    });
  });
}
