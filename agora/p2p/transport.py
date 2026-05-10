"""
P2P Transport Layer for Agora Protocol.
Direct TCP connections with X25519 handshake + AES-256-GCM encryption.
"""
import asyncio, json, logging
from typing import Optional, Dict
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes

from agora.crypto.session import AgoraSession
from agora.crypto.keys import IdentityKey

logger = logging.getLogger(__name__)
DEFAULT_PORT = 7777


class AgoraConnection:
    def __init__(self, reader, writer):
        self.reader = reader
        self.writer = writer
        self.session: Optional[AgoraSession] = None
        self.peer_addr = writer.get_extra_info('peername')

    async def _send(self, data: dict):
        self.writer.write(json.dumps(data).encode() + b'\n')
        await self.writer.drain()

    async def _recv(self) -> dict:
        return json.loads((await self.reader.readline()).decode())

    async def handshake_initiator(self, identity: IdentityKey) -> bool:
        try:
            our = X25519PrivateKey.generate()
            our_pub = our.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
            await self._send({"type": "hello", "pub": our_pub.hex()})
            msg = await asyncio.wait_for(self._recv(), timeout=10)
            their_pub = bytes.fromhex(msg["pub"])
            dh = our.exchange(X25519PublicKey.from_public_bytes(their_pub))
            shared = HKDF(hashes.SHA256(), 64, None, b"AGORA_DH").derive(dh)
            self.session = AgoraSession.for_alice(shared)
            return True
        except Exception as e:
            logger.error(f"Handshake failed: {e}")
            return False

    async def handshake_responder(self, identity: IdentityKey) -> bool:
        try:
            msg = await asyncio.wait_for(self._recv(), timeout=10)
            their_pub = bytes.fromhex(msg["pub"])
            our = X25519PrivateKey.generate()
            our_pub = our.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
            await self._send({"type": "hello", "pub": our_pub.hex()})
            dh = our.exchange(X25519PublicKey.from_public_bytes(their_pub))
            shared = HKDF(hashes.SHA256(), 64, None, b"AGORA_DH").derive(dh)
            self.session = AgoraSession.for_bob(shared)
            return True
        except Exception as e:
            logger.error(f"Handshake failed: {e}")
            return False

    async def send_message(self, text: str):
        ct = self.session.encrypt(text.encode())
        await self._send({"type": "msg", "ct": ct.hex()})

    async def recv_message(self) -> str:
        pkt = await self._recv()
        return self.session.decrypt(bytes.fromhex(pkt["ct"])).decode()

    def close(self):
        self.writer.close()
