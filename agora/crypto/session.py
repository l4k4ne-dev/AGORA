"""
Agora Encrypted Session — simple symmetric key messaging.
Uses X25519 DH for key agreement + AES-256-GCM for encryption.
Will be upgraded to full Double Ratchet (forward secrecy) later.
"""
import os, hmac, hashlib
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes


def derive_keys(shared_dh: bytes) -> tuple:
    """Derive send/recv keys from shared DH output."""
    hkdf = HKDF(algorithm=hashes.SHA256(), length=64, salt=None, info=b"AGORA_SESSION_KEYS")
    out = hkdf.derive(shared_dh)
    key_ab = out[:32]   # Alice->Bob direction
    key_ba = out[32:]   # Bob->Alice direction
    return key_ab, key_ba


def encrypt(key: bytes, plaintext: bytes) -> bytes:
    nonce = os.urandom(12)
    return nonce + AESGCM(key).encrypt(nonce, plaintext, b"")


def decrypt(key: bytes, ciphertext: bytes) -> bytes:
    return AESGCM(key).decrypt(ciphertext[:12], ciphertext[12:], b"")


class AgoraSession:
    """
    Simple bidirectional encrypted session.
    Alice uses send_key=key_ab, recv_key=key_ba.
    Bob  uses send_key=key_ba, recv_key=key_ab.
    """
    def __init__(self, send_key: bytes, recv_key: bytes):
        self.send_key = send_key
        self.recv_key = recv_key

    def encrypt(self, plaintext: bytes) -> bytes:
        return encrypt(self.send_key, plaintext)

    def decrypt(self, ciphertext: bytes) -> bytes:
        return decrypt(self.recv_key, ciphertext)

    @staticmethod
    def for_alice(shared_dh: bytes) -> "AgoraSession":
        key_ab, key_ba = derive_keys(shared_dh)
        return AgoraSession(send_key=key_ab, recv_key=key_ba)

    @staticmethod
    def for_bob(shared_dh: bytes) -> "AgoraSession":
        key_ab, key_ba = derive_keys(shared_dh)
        return AgoraSession(send_key=key_ba, recv_key=key_ab)
