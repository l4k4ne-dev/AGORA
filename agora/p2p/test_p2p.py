import sys, asyncio
sys.path.insert(0, '/home/x3d/AGORA')

from agora.p2p.transport import AgoraConnection
from agora.crypto.keys import IdentityKey

received = []

async def test():
    done = asyncio.Event()

    async def server_cb(reader, writer):
        conn = AgoraConnection(reader, writer)
        await conn.handshake_responder(IdentityKey())
        for _ in range(3):
            msg = await conn.recv_message()
            received.append(msg)
            print(f"  Bob  ← '{msg}'")
        done.set()

    srv = await asyncio.start_server(server_cb, "127.0.0.1", 17781)

    reader, writer = await asyncio.open_connection("127.0.0.1", 17781)
    conn = AgoraConnection(reader, writer)
    await conn.handshake_initiator(IdentityKey())

    msgs = ["Salut din Agora!", "P2P encryption works.", "No server needed."]
    for m in msgs:
        await conn.send_message(m)
        print(f"  Alice → '{m}'")

    await asyncio.wait_for(done.wait(), timeout=5)
    assert received == msgs
    print(f"\n✅ All {len(msgs)} messages delivered and decrypted correctly!")
    print("P2P Transport: WORKING 🔐")
    srv.close()

asyncio.run(test())
