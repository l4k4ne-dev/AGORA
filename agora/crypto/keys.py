"""
Key Management — Ed25519 identity keys + X25519 for key exchange.
Identity = a keypair generated locally. No phone number, no email, no real name required.
"""
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import (
    Encoding, PublicFormat, PrivateFormat, NoEncryption
)
import os

class IdentityKey:
    """Ed25519 signing key — your permanent identity on Agora."""
    
    def __init__(self):
        self._private = Ed25519PrivateKey.generate()
        self._public = self._private.public_key()

    @property
    def public_bytes(self) -> bytes:
        return self._public.public_bytes(Encoding.Raw, PublicFormat.Raw)

    def sign(self, data: bytes) -> bytes:
        return self._private.sign(data)

class EphemeralKey:
    """X25519 key for Diffie-Hellman key exchange."""
    
    def __init__(self):
        self._private = X25519PrivateKey.generate()
        self._public = self._private.public_key()

    @property
    def public_bytes(self) -> bytes:
        return self._public.public_bytes(Encoding.Raw, PublicFormat.Raw)

    def exchange(self, peer_public_bytes: bytes) -> bytes:
        from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PublicKey
        peer_public = X25519PublicKey.from_public_bytes(peer_public_bytes)
        return self._private.exchange(peer_public)
