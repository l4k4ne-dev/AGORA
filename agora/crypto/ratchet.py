"""
Double Ratchet Implementation for Agora Protocol.
Combines DH ratchet + symmetric KDF chain for forward secrecy.

Based on Signal's Double Ratchet specification:
https://signal.org/docs/specifications/doubleratchet/
"""
import os
import hmac
import hashlib
from typing import Optional, Tuple
from cryptography.hazmat.primitives.asymmetric.x25519 import (
    X25519PrivateKey, X25519PublicKey
)
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.serialization import (
    Encoding, PublicFormat
)


# ── KDF Functions ──────────────────────────────────────────────────────────────

def _hkdf(input_key: bytes, salt: bytes, info: bytes, length: int = 32) -> bytes:
    """HKDF-SHA256 key derivation."""
    # Extract
    if not salt:
        salt = bytes(32)
    prk = hmac.new(salt, input_key, hashlib.sha256).digest()
    # Expand
    t = b""
    okm = b""
    for i in range(1, (length // 32) + 2):
        t = hmac.new(prk, t + info + bytes([i]), hashlib.sha256).digest()
        okm += t
    return okm[:length]

def _kdf_rk(root_key: bytes, dh_output: bytes) -> Tuple[bytes, bytes]:
    """Root KDF: derives new root key and chain key from DH output."""
    output = _hkdf(dh_output, root_key, b"AGORA_ROOT_KDF", 64)
    return output[:32], output[32:]  # new_root_key, new_chain_key

def _kdf_ck(chain_key: bytes) -> Tuple[bytes, bytes]:
    """Chain KDF: derives message key and next chain key."""
    msg_key  = hmac.new(chain_key, b"\x01", hashlib.sha256).digest()
    next_ck  = hmac.new(chain_key, b"\x02", hashlib.sha256).digest()
    return next_ck, msg_key

def _encrypt(message_key: bytes, plaintext: bytes, aad: bytes = b"") -> bytes:
    """AES-256-GCM encryption."""
    key = message_key[:32]
    nonce = os.urandom(12)
    ct = AESGCM(key).encrypt(nonce, plaintext, aad)
    return nonce + ct

def _decrypt(message_key: bytes, ciphertext: bytes, aad: bytes = b"") -> bytes:
    """AES-256-GCM decryption."""
    key = message_key[:32]
    nonce, ct = ciphertext[:12], ciphertext[12:]
    return AESGCM(key).decrypt(nonce, ct, aad)


# ── Double Ratchet State ───────────────────────────────────────────────────────

class RatchetState:
    """
    Full Double Ratchet state for one session.
    Alice initializes as sender, Bob as receiver.
    """

    def __init__(self):
        self.DHs: Optional[X25519PrivateKey] = None   # our DH keypair
        self.DHr: Optional[bytes] = None               # their DH public key (bytes)
        self.RK: bytes = b""                           # root key
        self.CKs: Optional[bytes] = None              # sending chain key
        self.CKr: Optional[bytes] = None              # receiving chain key
        self.Ns: int = 0                               # messages sent
        self.Nr: int = 0                               # messages received
        self.PN: int = 0                               # prev sending chain length
        self.MKSKIPPED: dict = {}                      # skipped message keys

    @staticmethod
    def _dh_public_bytes(private_key: X25519PrivateKey) -> bytes:
        return private_key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)

    @staticmethod
    def _dh(our_private: X25519PrivateKey, their_public_bytes: bytes) -> bytes:
        peer = X25519PublicKey.from_public_bytes(their_public_bytes)
        return our_private.exchange(peer)


class RatchetSession:
    """
    High-level API for a Double Ratchet session between two parties.
    """

    def __init__(self, state: RatchetState):
        self.state = state

    @classmethod
    def init_alice(cls, shared_secret: bytes, bob_dh_public: bytes) -> "RatchetSession":
        """
        Alice initializes the session (she knows Bob's DH public key).
        shared_secret: result of X3DH key agreement
        bob_dh_public: Bob's ratchet public key
        """
        s = RatchetState()
        s.DHs = X25519PrivateKey.generate()
        s.DHr = bob_dh_public
        dh_out = RatchetState._dh(s.DHs, s.DHr)
        s.RK, s.CKs = _kdf_rk(shared_secret, dh_out)
        s.Ns = s.Nr = s.PN = 0
        return cls(s)

    @classmethod
    def init_bob(cls, shared_secret: bytes, bob_dh_keypair: X25519PrivateKey) -> "RatchetSession":
        """
        Bob initializes the session (passive side).
        """
        s = RatchetState()
        s.DHs = bob_dh_keypair
        s.DHr = None
        s.RK = shared_secret
        s.CKs = s.CKr = None
        s.Ns = s.Nr = s.PN = 0
        return cls(s)

    def encrypt(self, plaintext: bytes) -> Tuple[dict, bytes]:
        """Encrypt a message. Returns (header, ciphertext)."""
        s = self.state
        s.CKs, mk = _kdf_ck(s.CKs)
        header = {
            "dh": RatchetState._dh_public_bytes(s.DHs).hex(),
            "pn": s.PN,
            "n":  s.Ns,
        }
        s.Ns += 1
        ct = _encrypt(mk, plaintext)
        return header, ct

    def decrypt(self, header: dict, ciphertext: bytes) -> bytes:
        """Decrypt a message."""
        s = self.state
        their_dh = bytes.fromhex(header["dh"])

        # DH ratchet step if new DH public key
        if s.DHr is None or their_dh != s.DHr:
            s.PN = s.Ns
            s.Ns = 0
            s.Nr = 0
            s.DHr = their_dh
            dh_out = RatchetState._dh(s.DHs, s.DHr)
            s.RK, s.CKr = _kdf_rk(s.RK, dh_out)
            # Ratchet our sending key too
            s.DHs = X25519PrivateKey.generate()
            dh_out2 = RatchetState._dh(s.DHs, s.DHr)
            s.RK, s.CKs = _kdf_rk(s.RK, dh_out2)

        s.CKr, mk = _kdf_ck(s.CKr)
        s.Nr += 1
        return _decrypt(mk, ciphertext)
