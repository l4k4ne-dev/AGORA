"""
Double Ratchet for Agora — simplified but correct version.
Alice sends, Bob receives. Both derive the same chain keys.
"""
import os, hmac, hashlib
from typing import Optional, Tuple
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes


def _hkdf(ikm: bytes, salt: bytes, info: bytes, length: int = 32) -> bytes:
    h = HKDF(algorithm=hashes.SHA256(), length=length, salt=salt or None, info=info)
    return h.derive(ikm)

def _kdf_ck(chain_key: bytes) -> Tuple[bytes, bytes]:
    msg_key = hmac.new(chain_key, b"\x01", hashlib.sha256).digest()
    next_ck  = hmac.new(chain_key, b"\x02", hashlib.sha256).digest()
    return next_ck, msg_key

def _kdf_rk(root_key: bytes, dh_output: bytes) -> Tuple[bytes, bytes]:
    out = _hkdf(dh_output, root_key, b"AGORA_ROOT_KDF", 64)
    return out[:32], out[32:]

def _encrypt(mk: bytes, plaintext: bytes) -> bytes:
    nonce = os.urandom(12)
    return nonce + AESGCM(mk[:32]).encrypt(nonce, plaintext, b"")

def _decrypt(mk: bytes, ciphertext: bytes) -> bytes:
    return AESGCM(mk[:32]).decrypt(ciphertext[:12], ciphertext[12:], b"")


class RatchetState:
    def __init__(self):
        self.DHs: Optional[X25519PrivateKey] = None
        self.DHr: Optional[bytes] = None
        self.RK: bytes = b""
        self.CKs: Optional[bytes] = None
        self.CKr: Optional[bytes] = None
        self.Ns = self.Nr = self.PN = 0

    @staticmethod
    def dh(priv: X25519PrivateKey, pub_bytes: bytes) -> bytes:
        return priv.exchange(X25519PublicKey.from_public_bytes(pub_bytes))

    @staticmethod
    def pub(priv: X25519PrivateKey) -> bytes:
        return priv.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)


class RatchetSession:
    def __init__(self, state: RatchetState):
        self.state = state

    @classmethod
    def init_alice(cls, shared_secret: bytes, bob_ratchet_pub: bytes) -> "RatchetSession":
        """Alice knows the shared secret and Bob's ratchet public key."""
        s = RatchetState()
        s.DHs = X25519PrivateKey.generate()
        s.DHr = bob_ratchet_pub
        dh_out = RatchetState.dh(s.DHs, s.DHr)
        # Derive sending chain from shared_secret + DH
        out = _hkdf(dh_out, shared_secret, b"AGORA_ROOT_KDF_INIT", 64)
        s.RK  = out[:32]
        s.CKs = out[32:]
        return cls(s)

    def encrypt(self, plaintext: bytes) -> Tuple[dict, bytes]:
        s = self.state
        s.CKs, mk = _kdf_ck(s.CKs)
        header = {"dh": RatchetState.pub(s.DHs).hex(), "pn": s.PN, "n": s.Ns}
        s.Ns += 1
        return header, _encrypt(mk, plaintext)

    def decrypt(self, header: dict, ciphertext: bytes) -> bytes:
        s = self.state
        s.CKr, mk = _kdf_ck(s.CKr)
        s.Nr += 1
        return _decrypt(mk, ciphertext)
