import 'package:flutter_test/flutter_test.dart';
import 'package:agora_app/agora_crypto/identity.dart';
import 'package:agora_app/agora_crypto/keys.dart';

void main() {
  group('AgoraIdentity', () {
    test('generate produces valid identity', () async {
      final id = await AgoraIdentity.generate(oneTimePreKeyCount: 10);
      expect(id.deviceId, isNotEmpty);
      expect(id.oneTimePreKeys.length, 10);
      expect(id.signedPreKey.id, 1);
    });

    test('signed prekey signature verifies with identity key', () async {
      final id = await AgoraIdentity.generate(oneTimePreKeyCount: 5);
      final identityPub = await Ed25519Keys.publicKey(id.identityKeyPair);
      final spkPub = await X25519Keys.publicKey(id.signedPreKey.keyPair);

      final ok = await Ed25519Keys.verify(
        message: spkPub.bytes,
        signatureBytes: id.signedPreKey.signature,
        publicKey: identityPub,
      );
      expect(ok, isTrue);
    });

    test('one-time prekeys have unique ids', () async {
      final id = await AgoraIdentity.generate(oneTimePreKeyCount: 50);
      final ids = id.oneTimePreKeys.map((k) => k.id).toSet();
      expect(ids.length, 50);
    });

    test('toJson / fromJson roundtrip preserves keys', () async {
      final original = await AgoraIdentity.generate(oneTimePreKeyCount: 5);
      final json = await original.toJson();
      final restored = await AgoraIdentity.fromJson(json);

      expect(restored.deviceId, original.deviceId);
      expect(restored.oneTimePreKeys.length, original.oneTimePreKeys.length);

      final origPub = await Ed25519Keys.publicKey(original.identityKeyPair);
      final restPub = await Ed25519Keys.publicKey(restored.identityKeyPair);
      expect(restPub.bytes, equals(origPub.bytes));

      final origX = await X25519Keys.publicKey(original.x25519KeyPair);
      final restX = await X25519Keys.publicKey(restored.x25519KeyPair);
      expect(restX.bytes, equals(origX.bytes));

      final identityPub = await Ed25519Keys.publicKey(restored.identityKeyPair);
      final spkPub = await X25519Keys.publicKey(restored.signedPreKey.keyPair);
      final ok = await Ed25519Keys.verify(
        message: spkPub.bytes,
        signatureBytes: restored.signedPreKey.signature,
        publicKey: identityPub,
      );
      expect(ok, isTrue);
    });

    test('consumeOneTimePreKey removes and returns', () async {
      final id = await AgoraIdentity.generate(oneTimePreKeyCount: 5);
      final consumed = id.consumeOneTimePreKey(3);
      expect(consumed, isNotNull);
      expect(consumed!.id, 3);
      expect(id.oneTimePreKeys.length, 4);
      expect(id.consumeOneTimePreKey(3), isNull);
    });

    test('needsPreKeyReplenish + replenish', () async {
      final id = await AgoraIdentity.generate(oneTimePreKeyCount: 3);
      expect(id.needsPreKeyReplenish(threshold: 10), isTrue);
      await id.replenishOneTimePreKeys(20);
      expect(id.oneTimePreKeys.length, 23);
      expect(id.needsPreKeyReplenish(threshold: 10), isFalse);
    });
  });
}
