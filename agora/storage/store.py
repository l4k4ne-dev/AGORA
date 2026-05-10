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
