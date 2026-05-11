"""
Local Storage — All data lives on your hardware. No cloud. No servers.
SQLite for structured data, filesystem for blobs.
"""
import sqlite3
import os
import logging

logger = logging.getLogger(__name__)

DEFAULT_DB_PATH = os.path.expanduser("~/.agora/agora.db")

class LocalStore:
    def __init__(self, db_path: str = DEFAULT_DB_PATH):
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        self.conn = sqlite3.connect(db_path)
        self._init_schema()
        logger.info(f"LocalStore initialized at {db_path}")

    def _init_schema(self):
        self.conn.executescript("""
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                sender TEXT NOT NULL,
                recipient TEXT NOT NULL,
                content BLOB NOT NULL,
                timestamp INTEGER NOT NULL,
                delivered INTEGER DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS contacts (
                id TEXT PRIMARY KEY,
                public_key BLOB NOT NULL,
                name TEXT,
                added_at INTEGER NOT NULL
            );
        """)
        self.conn.commit()

    # ── Message store ──────────────────────────

    def store_message(self, msg_id: str, sender: str, recipient: str, content: bytes) -> None:
        """Store an offline message for later delivery."""
        self.conn.execute(
            "INSERT OR REPLACE INTO messages (id, sender, recipient, content, timestamp, delivered) "
            "VALUES (?, ?, ?, ?, ?, 0)",
            (msg_id, sender, recipient, content, int(__import__("time").time())),
        )
        self.conn.commit()
        logger.debug(f"Stored offline message {msg_id} for {recipient}")

    def get_pending_messages(self, recipient: str) -> list:
        """Return all undelivered messages for a recipient."""
        cur = self.conn.execute(
            "SELECT id, sender, recipient, content, timestamp, delivered "
            "FROM messages WHERE recipient=? AND delivered=0 ORDER BY timestamp ASC",
            (recipient,),
        )
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]

    def mark_delivered(self, msg_id: str) -> None:
        """Mark a message as delivered (soft-delete pattern)."""
        self.conn.execute(
            "UPDATE messages SET delivered=1 WHERE id=?", (msg_id,)
        )
        self.conn.commit()

    def get_all_messages(self, limit: int = 100) -> list:
        """Return recent messages (for debugging/admin)."""
        cur = self.conn.execute(
            "SELECT id, sender, recipient, timestamp, delivered FROM messages "
            "ORDER BY timestamp DESC LIMIT ?",
            (limit,),
        )
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]
