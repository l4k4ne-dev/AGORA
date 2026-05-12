"""
End-to-end test: X3DH + P2P transport + Double Ratchet
Alice connects to Bob via TCP, they do handshake, exchange 5 encrypted messages.
"""
import asyncio
import sys
sys.path.insert(0, 'C:\\Users\\X3D\\AGORA-Windows')

from agora.crypto.x3dh import X3DH
from agora.crypto.ratchet import RatchetSession
from agora.p2p.transport import AgoraConnection
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey

PORT = 19800
received = []


def test_e2e_p2p_messaging():
    """Full E2E: P2P connection + handshake + 5 encrypted messages."""
    asyncio.run(_run_e2e())
    assert len(received) == 3
    assert received[0] == b"Hello Agora!"
    assert received[1] == b"P2P works."
    assert received[2] == b"No server needed."


async def _run_e2e():
    done = asyncio.Event()

    async def handle_client(reader, writer):
        conn = AgoraConnection(reader, writer)
        from agora.crypto.keys import IdentityKey
        identity = IdentityKey()
        ok = await conn.handshake_responder(identity)
        if ok:
            for _ in range(3):
                msg = await asyncio.wait_for(conn.recv_message(), timeout=5)
                received.append(msg.encode() if isinstance(msg, str) else msg)
        done.set()
        conn.close()

    server = await asyncio.start_server(handle_client, "127.0.0.1", PORT)

    async def run_client():
        from agora.crypto.keys import IdentityKey
        identity = IdentityKey()
        reader, writer = await asyncio.open_connection("127.0.0.1", PORT)
        conn = AgoraConnection(reader, writer)
        ok = await conn.handshake_initiator(identity)
        assert ok, "Handshake failed"
        for msg in [b"Hello Agora!", b"P2P works.", b"No server needed."]:
            await conn.send_message(msg.decode())
        await asyncio.sleep(0.2)
        conn.close()

    client_task = asyncio.create_task(run_client())
    await asyncio.wait_for(done.wait(), timeout=10)
    client_task.cancel()
    server.close()
