import '../agora_crypto/identity.dart';
import '../agora_crypto/keys.dart';

/// Public-facing identity view (backward-compatible interface for UI/services).
/// Wraps the real cryptographic AgoraIdentity from agora_crypto.
class Identity {
  final AgoraIdentity _internal;

  Identity(this._internal);

  AgoraIdentity get raw => _internal;

  String get peerId => _internal.deviceId;

  /// Async — X25519 public key base64 (used for wire / QR / contacts).
  Future<String> get publicKey async =>
      X25519Keys.publicKeyBase64(_internal.x25519KeyPair);

  /// Async — Ed25519 identity public key base64.
  Future<String> get identityPublicKey async =>
      Ed25519Keys.publicKeyBase64(_internal.identityKeyPair);
}
