"""
Home Node — The sovereign local server for AGORA.

Responsibilities:
  - TCP server on port 7777 for mobile app connections
  - STUN discovery to learn public IP
  - Double Ratchet handshake with connected clients
  - Offline message buffering in SQLite via LocalStore
  - REST API on port 8080 for status & pending messages
"""

import asyncio
import json
import logging
import os
import time
import uuid
from typing import Dict, Optional

import stun
from aiohttp import web

from agora.crypto.ratchet import RatchetSession, RatchetState
from agora.storage.store import LocalStore

logger = logging.getLogger(__name__)

TCP_HOST = "0.0.0.0"
TCP_PORT = 7777
REST_PORT = 8080
STUN_HOST = "stun.l.google.com"
STUN_PORT = 19302
DB_PATH = os.path.expanduser("~/.agora/agora.db")


# ─────────────────────────────────────────────
# Peer session — one per connected mobile client
# ─────────────────────────────────────────────

class PeerSession:
    """Wraps an active TCP connection with its ratchet session state."""

    def __init__(self, peer_id: str, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        self.peer_id = peer_id
        self.reader = reader
        self.writer = writer
        self.ratchet: Optional[RatchetSession] = None
        self.connected_at = time.time()
        addr = writer.get_extra_info("peername")
        self.remote_addr = f"{addr[0]}:{addr[1]}" if addr else "unknown"

    async def send_json(self, obj: dict) -> None:
        data = (json.dumps(obj) + "\n").encode()
        self.writer.write(data)
        await self.writer.drain()

    async def recv_line(self) -> Optional[dict]:
        try:
            line = await asyncio.wait_for(self.reader.readline(), timeout=30)
            if not line:
                return None
            return json.loads(line.decode().strip())
        except (asyncio.TimeoutError, json.JSONDecodeError, UnicodeDecodeError):
            return None

    def close(self) -> None:
        try:
            self.writer.close()
        except Exception:
            pass


# ─────────────────────────────────────────────
# HomeNode
# ─────────────────────────────────────────────

class HomeNode:
    def __init__(self, db_path: str = DB_PATH):
        self.running = False
        self.public_ip: Optional[str] = None
        self.public_port: Optional[int] = None
        self.store = LocalStore(db_path)
        self.peers: Dict[str, PeerSession] = {}   # peer_id → PeerSession
        self._tcp_server: Optional[asyncio.Server] = None
        self._rest_app: Optional[web.Application] = None
        self._rest_runner: Optional[web.AppRunner] = None
        logger.info("HomeNode initialised")

    # ── STUN ──────────────────────────────────

    async def _discover_public_ip(self) -> None:
        """Query STUN server to learn our public IP & port."""
        loop = asyncio.get_event_loop()
        try:
            nat_type, ext_ip, ext_port = await loop.run_in_executor(
                None,
                lambda: stun.get_ip_info(
                    source_ip="0.0.0.0",
                    source_port=TCP_PORT,
                    stun_host=STUN_HOST,
                    stun_port=STUN_PORT,
                ),
            )
            self.public_ip = ext_ip
            self.public_port = ext_port
            logger.info(f"STUN: NAT={nat_type}  public={ext_ip}:{ext_port}")
        except Exception as exc:
            logger.warning(f"STUN discovery failed: {exc}")
            self.public_ip = "unknown"
            self.public_port = TCP_PORT

    # ── Double Ratchet handshake ───────────────

    async def _handshake(self, session: PeerSession) -> bool:
        """
        Minimal handshake protocol:
          → HELLO {peer_id, ratchet_pub}
          ← HELLO_ACK {node_pub}
          → READY
        Alice (mobile) sends her ratchet pub; node (Bob) responds with its pub.
        """
        msg = await session.recv_line()
        if not msg or msg.get("type") != "HELLO":
            logger.warning(f"[{session.peer_id}] Bad handshake — expected HELLO, got {msg}")
            return False

        try:
            peer_ratchet_pub = bytes.fromhex(msg["ratchet_pub"])
        except (KeyError, ValueError) as exc:
            logger.warning(f"[{session.peer_id}] Invalid ratchet_pub in HELLO: {exc}")
            return False

        # Build a shared secret (in production: full X3DH; here: ephemeral DH)
        from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
        from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

        node_ephemeral = X25519PrivateKey.generate()
        shared_secret = node_ephemeral.exchange(
            __import__(
                "cryptography.hazmat.primitives.asymmetric.x25519",
                fromlist=["X25519PublicKey"],
            ).X25519PublicKey.from_public_bytes(peer_ratchet_pub)
        )
        node_pub_hex = node_ephemeral.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw).hex()

        # Node plays Bob: init receiving side (no outbound CK until first send)
        from agora.crypto.ratchet import RatchetState, RatchetSession
        state = RatchetState()
        state.RK = shared_secret[:32]
        state.CKr = shared_secret[32:] if len(shared_secret) >= 64 else shared_secret[:32]
        from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey as _K
        state.DHs = _K.generate()
        state.DHr = peer_ratchet_pub
        session.ratchet = RatchetSession(state)

        await session.send_json({
            "type": "HELLO_ACK",
            "node_pub": node_pub_hex,
            "node_id": "home_node",
        })

        confirm = await session.recv_line()
        if not confirm or confirm.get("type") != "READY":
            logger.warning(f"[{session.peer_id}] Missing READY after handshake")
            return False

        logger.info(f"[{session.peer_id}] Handshake complete ✓")
        return True

    # ── TCP message loop ───────────────────────

    async def _handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        peer_id = str(uuid.uuid4())[:8]
        session = PeerSession(peer_id, reader, writer)
        self.peers[peer_id] = session
        logger.info(f"[{peer_id}] Connected from {session.remote_addr}")

        try:
            if not await self._handshake(session):
                return

            # Deliver buffered offline messages
            await self._flush_offline_messages(session)

            # Main receive loop
            while self.running:
                msg = await session.recv_line()
                if msg is None:
                    break
                await self._handle_message(session, msg)

        except Exception as exc:
            logger.error(f"[{peer_id}] Error: {exc}", exc_info=True)
        finally:
            session.close()
            self.peers.pop(peer_id, None)
            logger.info(f"[{peer_id}] Disconnected")

    async def _handle_message(self, session: PeerSession, msg: dict) -> None:
        """Process an inbound message from a mobile client."""
        msg_type = msg.get("type")

        if msg_type == "SEND":
            recipient = msg.get("to")
            content_hex = msg.get("content", "")
            header = msg.get("header", {})

            if not recipient or not content_hex:
                await session.send_json({"type": "ERR", "reason": "missing fields"})
                return

            # If recipient is online, forward directly
            recipient_session = self._find_peer(recipient)
            if recipient_session:
                await recipient_session.send_json({
                    "type": "MESSAGE",
                    "from": session.peer_id,
                    "header": header,
                    "content": content_hex,
                    "ts": int(time.time()),
                })
                await session.send_json({"type": "ACK", "id": msg.get("id")})
            else:
                # Store for offline delivery
                self.store.store_message(
                    msg_id=msg.get("id") or str(uuid.uuid4()),
                    sender=session.peer_id,
                    recipient=recipient,
                    content=bytes.fromhex(content_hex),
                )
                await session.send_json({"type": "QUEUED", "id": msg.get("id")})

        elif msg_type == "PING":
            await session.send_json({"type": "PONG", "ts": int(time.time())})

        else:
            logger.debug(f"[{session.peer_id}] Unknown message type: {msg_type}")

    def _find_peer(self, peer_id: str) -> Optional[PeerSession]:
        return self.peers.get(peer_id)

    async def _flush_offline_messages(self, session: PeerSession) -> None:
        """Deliver messages that were queued while this peer was offline."""
        messages = self.store.get_pending_messages(session.peer_id)
        for m in messages:
            await session.send_json({
                "type": "MESSAGE",
                "from": m["sender"],
                "content": m["content"].hex() if isinstance(m["content"], bytes) else m["content"],
                "ts": m["timestamp"],
                "offline": True,
            })
            self.store.mark_delivered(m["id"])
        if messages:
            logger.info(f"[{session.peer_id}] Flushed {len(messages)} offline messages")

    # ── REST API ───────────────────────────────

    def _build_rest_app(self) -> web.Application:
        app = web.Application()
        app.router.add_get("/status", self._rest_status)
        app.router.add_get("/messages/{peer_id}", self._rest_messages)
        app.router.add_get("/messages/pending/{peer_id}", self._rest_messages)
        app.router.add_post("/messages/send", self._rest_send_message)
        app.router.add_delete("/messages/{msg_id}", self._rest_delete_message)
        app.router.add_post("/contacts", self._rest_add_contact)
        app.router.add_get("/contacts", self._rest_get_contacts)
        return app

    async def _rest_status(self, request: web.Request) -> web.Response:
        return web.json_response({
            "status": "running" if self.running else "stopped",
            "public_ip": self.public_ip,
            "public_port": self.public_port,
            "tcp_port": TCP_PORT,
            "rest_port": REST_PORT,
            "connected_peers": len(self.peers),
            "peers": [
                {
                    "id": p.peer_id,
                    "addr": p.remote_addr,
                    "connected_at": p.connected_at,
                }
                for p in self.peers.values()
            ],
            "uptime": time.time(),
        })

    async def _rest_messages(self, request: web.Request) -> web.Response:
        peer_id = request.match_info["peer_id"]
        messages = self.store.get_pending_messages(peer_id)
        return web.json_response({
            "peer_id": peer_id,
            "count": len(messages),
            "messages": [
                {
                    "id": m["id"],
                    "sender": m["sender"],
                    "content": m["content"].hex() if isinstance(m["content"], bytes) else m["content"],
                    "timestamp": m["timestamp"],
                    "delivered": m.get("delivered", 0),
                }
                for m in messages
            ],
        })

    async def _rest_delete_message(self, request: web.Request) -> web.Response:
        msg_id = request.match_info["msg_id"]
        self.store.mark_delivered(msg_id)
        return web.json_response({"deleted": msg_id})

    async def _rest_send_message(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            peer_id = data.get("peer_id", "")
            content = data.get("encrypted_content", "")
            msg_id = str(uuid.uuid4())
            self.store.store_message(msg_id, "self", peer_id, content.encode())
            return web.json_response({"ok": True, "msg_id": msg_id})
        except Exception as e:
            return web.json_response({"ok": False, "error": str(e)}, status=400)

    async def _rest_add_contact(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            peer_id = data.get("peer_id", "")
            public_key = data.get("public_key", "")
            self.store.conn.execute(
                "INSERT OR REPLACE INTO contacts (id, public_key, name, added_at) VALUES (?, ?, ?, ?)",
                (peer_id, bytes.fromhex(public_key) if public_key else b"", data.get("name", ""), int(time.time()))
            )
            self.store.conn.commit()
            return web.json_response({"ok": True})
        except Exception as e:
            return web.json_response({"ok": False, "error": str(e)}, status=400)

    async def _rest_get_contacts(self, request: web.Request) -> web.Response:
        try:
            rows = self.store.conn.execute(
                "SELECT id, name, public_key, added_at FROM contacts"
            ).fetchall()
            contacts = [
                {"id": r[0], "name": r[1] or r[0], "public_key": r[2].hex() if r[2] else "", "added_at": r[3]}
                for r in rows
            ]
            return web.json_response(contacts)
        except Exception as e:
            return web.json_response({"error": str(e)}, status=500)

    # ── Lifecycle ──────────────────────────────

    async def start(self) -> None:
        self.running = True
        logger.info("HomeNode starting…")

        # 1. STUN discovery
        await self._discover_public_ip()

        # 2. TCP server
        self._tcp_server = await asyncio.start_server(
            self._handle_client, TCP_HOST, TCP_PORT
        )
        logger.info(f"TCP server listening on {TCP_HOST}:{TCP_PORT}")

        # 3. REST API
        self._rest_app = self._build_rest_app()
        self._rest_runner = web.AppRunner(self._rest_app)
        await self._rest_runner.setup()
        site = web.TCPSite(self._rest_runner, "0.0.0.0", REST_PORT)
        await site.start()
        logger.info(f"REST API listening on 0.0.0.0:{REST_PORT}")

        logger.info(
            f"HomeNode live — TCP:{TCP_PORT}  REST:{REST_PORT}  "
            f"Public:{self.public_ip}:{self.public_port}"
        )

        async with self._tcp_server:
            await self._tcp_server.serve_forever()

    async def stop(self) -> None:
        self.running = False
        if self._tcp_server:
            self._tcp_server.close()
        if self._rest_runner:
            await self._rest_runner.cleanup()
        for session in list(self.peers.values()):
            session.close()
        logger.info("HomeNode stopped")


# ─────────────────────────────────────────────
# Entrypoint
# ─────────────────────────────────────────────

if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    )
    node = HomeNode()
    try:
        asyncio.run(node.start())
    except KeyboardInterrupt:
        logger.info("Interrupted — shutting down")
