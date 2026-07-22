import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agora_app/agora_crypto/identity.dart';
import 'package:agora_app/agora_crypto/storage.dart';
import 'package:agora_app/agora_crypto/keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> memory = {};

  setUp(() {
    memory.clear();
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map?;
      switch (call.method) {
        case 'read':
          return memory[args?['key'] as String];
        case 'write':
          memory[args!['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          memory.remove(args?['key'] as String);
          return null;
        case 'containsKey':
          return memory.containsKey(args?['key'] as String);
        case 'readAll':
          return Map<String, String>.from(memory);
        case 'deleteAll':
          memory.clear();
          return null;
        default:
          return null;
      }
    });
  });

  group('IdentityStorage', () {
    test('load returns null when nothing saved', () async {
      final storage = IdentityStorage();
      expect(await storage.load(), isNull);
    });

    test('save + load roundtrip preserves identity', () async {
      final storage = IdentityStorage();
      final id = await AgoraIdentity.generate(oneTimePreKeyCount: 5);
      await storage.save(id);

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect(loaded!.deviceId, id.deviceId);
      expect(loaded.oneTimePreKeys.length, 5);

      final origPub = await Ed25519Keys.publicKey(id.identityKeyPair);
      final loadedPub = await Ed25519Keys.publicKey(loaded.identityKeyPair);
      expect(loadedPub.bytes, equals(origPub.bytes));
    });

    test('clear removes identity', () async {
      final storage = IdentityStorage();
      final id = await AgoraIdentity.generate(oneTimePreKeyCount: 3);
      await storage.save(id);
      expect(await storage.load(), isNotNull);

      await storage.clear();
      expect(await storage.load(), isNull);
    });

    test('loadOrGenerate creates new when empty', () async {
      final storage = IdentityStorage();
      final (id, wasNew) = await storage.loadOrGenerate(oneTimePreKeyCount: 3);
      expect(wasNew, isTrue);
      expect(id.oneTimePreKeys.length, 3);

      final (id2, wasNew2) =
          await storage.loadOrGenerate(oneTimePreKeyCount: 3);
      expect(wasNew2, isFalse);
      expect(id2.deviceId, id.deviceId);
    });

    test('migrateLegacyIfPresent removes legacy SharedPreferences entry',
        () async {
      SharedPreferences.setMockInitialValues({
        'agora_identity': '{"legacy": "junk"}',
      });
      final storage = IdentityStorage();

      final migrated = await storage.migrateLegacyIfPresent();
      expect(migrated, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('agora_identity'), isFalse);

      final migrated2 = await storage.migrateLegacyIfPresent();
      expect(migrated2, isFalse);
    });
  });
}
