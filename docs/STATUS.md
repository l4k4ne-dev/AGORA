# Agora — Current Status (2026-07-22)

## ⚠️ E2E STATUS: NOT IMPLEMENTED

Current build (post-commit b255c3f) has NO end-to-end encryption.
- Flutter sends plaintext to Home Node via HTTP.
- Home Node stores plaintext in SQLite.
- Field `encrypted_content` is misleadingly named — contains plaintext.

## What works
- Python X3DH module (isolated, not connected to mobile flow)
- Python Double Ratchet module (isolated, not connected to mobile flow)
- Basic REST API + SQLite storage
- Flutter UI (identity, contacts, chat, QR)

## What does NOT work per whitepaper
- Client-side crypto (Flutter has no encrypt/decrypt)
- Real X25519/Ed25519 key pairs (currently 2 random independent 32-byte strings)
- Secure key storage (private key in SharedPreferences, not Keychain/Keystore)
- TLS on REST endpoints
- Home node as dumb relay (currently sees and stores plaintext)
- Mesh P2P / onion routing / DHT
- Circles
- Feed
- Pager
- Migration wrapper (WhatsApp/Insta bridge)
- Shamir Secret Sharing backup
- AES-256 at-rest encryption
- Duress mode

## Do NOT
- Do NOT market or demo current build as E2E encrypted
- Do NOT invite users to test as "secure messenger"
- Do NOT deploy publicly as "Agora" per whitepaper — it's not Agora yet, it's a prototype
