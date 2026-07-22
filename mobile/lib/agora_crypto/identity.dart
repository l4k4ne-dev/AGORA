import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import 'keys.dart';

class OneTimePreKey {
  final int id;
  final SimpleKeyPair keyPair;
  final DateTime createdAt;

  OneTimePreKey({
    required this.id,
    required this.keyPair,
    required this.createdAt,
  });

  Future<Map<String, dynamic>> toJson() async => {
        'id': id,
        'algorithm': 'X25519',
        'private': await X25519Keys.privateKeyBase64(keyPair),
        'public': await X25519Keys.publicKeyBase64(keyPair),
        'created_at': createdAt.toIso8601String(),
      };

  static Future<OneTimePreKey> fromJson(Map<String, dynamic> j) async {
    final kp = await X25519Keys.fromPrivateBase64(j['private'] as String);
    return OneTimePreKey(
      id: j['id'] as int,
      keyPair: kp,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

class SignedPreKey {
  final int id;
  final SimpleKeyPair keyPair;
  final List<int> signature; // Ed25519 sig over the X25519 public key bytes
  final DateTime createdAt;

  SignedPreKey({
    required this.id,
    required this.keyPair,
    required this.signature,
    required this.createdAt,
  });

  Future<Map<String, dynamic>> toJson() async => {
        'id': id,
        'algorithm': 'X25519',
        'private': await X25519Keys.privateKeyBase64(keyPair),
        'public': await X25519Keys.publicKeyBase64(keyPair),
        'signature': base64Encode(signature),
        'created_at': createdAt.toIso8601String(),
      };

  static Future<SignedPreKey> fromJson(Map<String, dynamic> j) async {
    final kp = await X25519Keys.fromPrivateBase64(j['private'] as String);
    return SignedPreKey(
      id: j['id'] as int,
      keyPair: kp,
      signature: base64Decode(j['signature'] as String),
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

class AgoraIdentity {
  final String deviceId;
  final DateTime createdAt;
  final SimpleKeyPair identityKeyPair; // Ed25519 — long-term ID + signing
  final SimpleKeyPair x25519KeyPair;   // X25519 — DH long-term
  final SignedPreKey signedPreKey;
  final List<OneTimePreKey> oneTimePreKeys;

  AgoraIdentity({
    required this.deviceId,
    required this.createdAt,
    required this.identityKeyPair,
    required this.x25519KeyPair,
    required this.signedPreKey,
    required this.oneTimePreKeys,
  });

  /// Generează o identitate nouă de la zero.
  static Future<AgoraIdentity> generate({int oneTimePreKeyCount = 100}) async {
    final now = DateTime.now().toUtc();
    final deviceId = const Uuid().v4();

    final identityKp = await Ed25519Keys.generate();
    final x25519Kp = await X25519Keys.generate();

    // Signed prekey: X25519 pub semnat cu Ed25519 identity key
    final spkKp = await X25519Keys.generate();
    final spkPubBytes = (await X25519Keys.publicKey(spkKp)).bytes;
    final spkSig = await Ed25519Keys.sign(identityKp, spkPubBytes);
    final signedPreKey = SignedPreKey(
      id: 1,
      keyPair: spkKp,
      signature: spkSig,
      createdAt: now,
    );

    // Pool one-time prekeys
    final oneTime = <OneTimePreKey>[];
    for (int i = 1; i <= oneTimePreKeyCount; i++) {
      final kp = await X25519Keys.generate();
      oneTime.add(OneTimePreKey(id: i, keyPair: kp, createdAt: now));
    }

    return AgoraIdentity(
      deviceId: deviceId,
      createdAt: now,
      identityKeyPair: identityKp,
      x25519KeyPair: x25519Kp,
      signedPreKey: signedPreKey,
      oneTimePreKeys: oneTime,
    );
  }

  Future<Map<String, dynamic>> toJson() async {
    final oneTimeJson = <Map<String, dynamic>>[];
    for (final k in oneTimePreKeys) {
      oneTimeJson.add(await k.toJson());
    }
    return {
      'version': 1,
      'device_id': deviceId,
      'created_at': createdAt.toIso8601String(),
      'identity_key': {
        'algorithm': 'Ed25519',
        'private': await Ed25519Keys.privateKeyBase64(identityKeyPair),
        'public': await Ed25519Keys.publicKeyBase64(identityKeyPair),
      },
      'x25519_key': {
        'algorithm': 'X25519',
        'private': await X25519Keys.privateKeyBase64(x25519KeyPair),
        'public': await X25519Keys.publicKeyBase64(x25519KeyPair),
      },
      'signed_prekey': await signedPreKey.toJson(),
      'one_time_prekeys': oneTimeJson,
    };
  }

  static Future<AgoraIdentity> fromJson(Map<String, dynamic> j) async {
    final version = j['version'] as int;
    if (version != 1) {
      throw StateError('Unsupported identity version: $version');
    }

    final identityKp = await Ed25519Keys.fromPrivateBase64(
      (j['identity_key'] as Map)['private'] as String,
    );
    final x25519Kp = await X25519Keys.fromPrivateBase64(
      (j['x25519_key'] as Map)['private'] as String,
    );
    final spk = await SignedPreKey.fromJson(
      Map<String, dynamic>.from(j['signed_prekey'] as Map),
    );
    final otpList = (j['one_time_prekeys'] as List)
        .cast<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final oneTime = <OneTimePreKey>[];
    for (final m in otpList) {
      oneTime.add(await OneTimePreKey.fromJson(m));
    }

    return AgoraIdentity(
      deviceId: j['device_id'] as String,
      createdAt: DateTime.parse(j['created_at'] as String),
      identityKeyPair: identityKp,
      x25519KeyPair: x25519Kp,
      signedPreKey: spk,
      oneTimePreKeys: oneTime,
    );
  }

  /// Consumă o one-time prekey după id (o scoate din listă).
  OneTimePreKey? consumeOneTimePreKey(int id) {
    final idx = oneTimePreKeys.indexWhere((k) => k.id == id);
    if (idx == -1) return null;
    return oneTimePreKeys.removeAt(idx);
  }

  bool needsPreKeyReplenish({int threshold = 10}) =>
      oneTimePreKeys.length < threshold;

  Future<void> replenishOneTimePreKeys(int count) async {
    final now = DateTime.now().toUtc();
    final nextId = oneTimePreKeys.isEmpty
        ? 1
        : oneTimePreKeys.map((k) => k.id).reduce((a, b) => a > b ? a : b) + 1;
    for (int i = 0; i < count; i++) {
      final kp = await X25519Keys.generate();
      oneTimePreKeys.add(
        OneTimePreKey(id: nextId + i, keyPair: kp, createdAt: now),
      );
    }
  }
}
