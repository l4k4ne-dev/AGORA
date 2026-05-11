"""
Key Management — Ed25519 identity keys + X25519 for key exchange.
Identity = a keypair generated locally. No phone number, no email, no real name required.
"""
import os
import logging
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import (
    Encoding, PublicFormat, PrivateFormat, NoEncryption, load_pem_private_key
)

logger = logging.getLogger(__name__)

DEFAULT_IDENTITY_PATH = os.path.expanduser("~/.agora/identity.pem")


class IdentityKey:
    """Ed25519 signing key — your permanent identity on Agora."""

    def __init__(self, private_key: Ed25519PrivateKey = None):
        self._private = private_key or Ed25519PrivateKey.generate()
        self._public = self._private.public_key()

    @property
    def public_bytes(self) -> bytes:
        return self._public.public_bytes(Encoding.Raw, PublicFormat.Raw)

    @property
    def public_hex(self) -> str:
        return self.public_bytes.hex()

    def sign(self, data: bytes) -> bytes:
        return self._private.sign(data)

    def save(self, path: str = DEFAULT_IDENTITY_PATH) -> None:
        """Serialize private key to PEM and save to disk."""
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        pem = self._private.private_bytes(Encoding.PEM, PrivateFormat.PKCS8, NoEncryption())
        with open(path, "wb") as f:
            f.write(pem)
        os.chmod(path, 0o600)
        logger.info(f"Identity saved to {path}")

    @classmethod
    def load(cls, path: str = DEFAULT_IDENTITY_PATH) -> "IdentityKey":
        """Load identity key from PEM file."""
        with open(path, "rb") as f:
            private_key = load_pem_private_key(f.read(), password=None)
        logger.info(f"Identity loaded from {path}")
        return cls(private_key)

    @classmethod
    def load_or_create(cls, path: str = DEFAULT_IDENTITY_PATH) -> "IdentityKey":
        """Load existing identity or create + save a new one."""
        if os.path.exists(path) and os.path.getsize(path) > 0:
            return cls.load(path)
        key = cls()
        key.save(path)
        logger.info(f"New identity created: {key.public_hex}")
        return key


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
