# Agora — Status

## Phase 1: COMPLETED (2026-07-23)

**Real cryptographic identity + secure storage on Flutter.**

- ✅ Real X25519 (DH) + Ed25519 (identity signing) keypairs in Flutter
  - Package: `cryptography` (pure Dart, no native deps — avoids the iOS build issue that caused `b255c3f`)
- ✅ Signed prekey + pool of 100 one-time prekeys (X25519)
- ✅ Signed prekey signature verified via Ed25519 identity key
- ✅ Private keys stored in Keychain (iOS `first_unlock_this_device`) / Android Keystore (`EncryptedSharedPreferences`)
- ✅ Legacy SharedPreferences identity migration — auto-destroys invalid two-random-strings identity and regenerates
- ✅ Stale contacts cleared on migration (were tied to invalid legacy keys)
- ✅ Real X25519 public key sent to Home Node `/contacts` and in QR code
- ✅ 19 unit tests across X25519 / Ed25519 / AgoraIdentity / IdentityStorage (all green)
- ✅ iOS build (device): OK

## ⚠️ Still NOT E2E

Phase 1 built the cryptographic **identity**, not the encryption pipeline.

- Messages still travel plaintext through Home Node
- No client-side X3DH handshake (Phase 2)
- No client-side encryption/decryption (Phase 3)
- Home Node still sees and stores plaintext

**Do not use this build for any private communication.**

## Next: Phase 2 — X3DH client-side handshake

- Publish public prekey bundle (identity pub + signed prekey + one-time prekeys) to Home Node
- Alice fetches Bob's bundle from Home Node
- Alice computes shared secret client-side (DH1 + DH2 + DH3 [+DH4])
- Bob computes matching shared secret when receiving first message
- End of Phase 2: Alice and Bob share a symmetric secret; Home Node cannot compute it

## Then: Phase 3 — Double Ratchet + Home Node dumb relay

- Ratchet symmetric secret into per-message keys
- Encrypt/decrypt on device with AES-256-GCM
- Home Node sees only ciphertext + routing metadata
- Add TLS on REST endpoints

Only after Phase 3 do we claim E2E.
