"""
AGORA REST API — aiohttp routes for the mobile client.

Endpoints:
  GET  /status
  POST /contacts
  GET  /contacts
  POST /messages/send
  GET  /messages/pending/{peer_id}
"""

import json
import logging
import time
import uuid

from aiohttp import web

logger = logging.getLogger(__name__)


def build_api(node, identity, store) -> web.Application:
    """
    Factory — wire up all REST routes.

    Args:
        node:     HomeNode instance (for peer forwarding)
        identity: IdentityKey instance (for node_id in /status)
        store:    LocalStore instance (for contacts + messages)
    """
    app = web.Application()

    # ── /status ──────────────────────────────────────────────────────────

    async def status(request: web.Request) -> web.Response:
        return web.json_response({
            "status": "ok",
            "version": "0.1.0",
            "node_id": identity.public_hex,
            "connected_peers": len(node.peers),
            "public_ip": node.public_ip,
            "public_port": node.public_port,
            "ts": int(time.time()),
        })

    # ── /contacts ─────────────────────────────────────────────────────────

    async def add_contact(request: web.Request) -> web.Response:
        try:
            body = await request.json()
            contact_id  = body["id"]
            public_key  = body["public_key"]   # hex string
            name        = body.get("name", "")
        except (json.JSONDecodeError, KeyError) as exc:
            raise web.HTTPBadRequest(reason=f"Missing field: {exc}")

        try:
            pk_bytes = bytes.fromhex(public_key)
        except ValueError:
            raise web.HTTPBadRequest(reason="public_key must be a hex string")

        store.conn.execute(
            "INSERT OR REPLACE INTO contacts (id, public_key, name, added_at) "
            "VALUES (?, ?, ?, ?)",
            (contact_id, pk_bytes, name, int(time.time())),
        )
        store.conn.commit()
        logger.info(f"Contact added: {name} ({contact_id})")
        return web.json_response({"ok": True, "id": contact_id})

    async def list_contacts(request: web.Request) -> web.Response:
        cur = store.conn.execute(
            "SELECT id, public_key, name, added_at FROM contacts ORDER BY added_at DESC"
        )
        cols = [d[0] for d in cur.description]
        contacts = []
        for row in cur.fetchall():
            c = dict(zip(cols, row))
            c["public_key"] = c["public_key"].hex() if isinstance(c["public_key"], bytes) else c["public_key"]
            contacts.append(c)
        return web.json_response({"contacts": contacts, "count": len(contacts)})

    # ── /messages ─────────────────────────────────────────────────────────

    async def send_message(request: web.Request) -> web.Response:
        try:
            body = await request.json()
            recipient = body["to"]
            text      = body["text"]
        except (json.JSONDecodeError, KeyError) as exc:
            raise web.HTTPBadRequest(reason=f"Missing field: {exc}")

        msg_id = str(uuid.uuid4())

        # Encrypt with AgoraSession if we have a ratchet session for this peer
        peer_session = node._find_peer(recipient)

        if peer_session and peer_session.ratchet:
            # Peer is online — forward directly via TCP
            header, ciphertext = peer_session.ratchet.encrypt(text.encode())
            await peer_session.send_json({
                "type": "MESSAGE",
                "id": msg_id,
                "from": identity.public_hex,
                "header": header,
                "content": ciphertext.hex(),
                "ts": int(time.time()),
            })
            delivered = True
        else:
            # Peer offline — store for later delivery (plaintext stored encrypted with store key)
            # For now: store raw bytes; full E2E store encryption is Sprint 3
            store.store_message(
                msg_id=msg_id,
                sender=identity.public_hex,
                recipient=recipient,
                content=text.encode(),
            )
            delivered = False

        return web.json_response({
            "ok": True,
            "msg_id": msg_id,
            "delivered": delivered,
            "queued": not delivered,
        })

    async def pending_messages(request: web.Request) -> web.Response:
        peer_id = request.match_info["peer_id"]
        messages = store.get_pending_messages(peer_id)
        result = []
        for m in messages:
            content = m["content"]
            if isinstance(content, bytes):
                try:
                    content = content.decode("utf-8")
                except UnicodeDecodeError:
                    content = content.hex()
            result.append({
                "id": m["id"],
                "sender": m["sender"],
                "content": content,
                "timestamp": m["timestamp"],
            })
        return web.json_response({"peer_id": peer_id, "messages": result, "count": len(result)})

    # ── Register routes ───────────────────────────────────────────────────

    app.router.add_get("/status", status)
    app.router.add_post("/contacts", add_contact)
    app.router.add_get("/contacts", list_contacts)
    app.router.add_post("/messages/send", send_message)
    app.router.add_get("/messages/pending/{peer_id}", pending_messages)

    return app
