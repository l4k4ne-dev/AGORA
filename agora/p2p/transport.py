"""
P2P Transport Layer — Direct device-to-device communication.
No intermediary stores or reads the content.
"""
import asyncio
import logging

logger = logging.getLogger(__name__)

class P2PTransport:
    """Basic P2P transport over TCP. Will be upgraded to libp2p."""
    
    def __init__(self, host: str = "0.0.0.0", port: int = 7777):
        self.host = host
        self.port = port
        self.peers = {}

    async def start(self):
        server = await asyncio.start_server(
            self._handle_connection, self.host, self.port
        )
        logger.info(f"P2P transport listening on {self.host}:{self.port}")
        async with server:
            await server.serve_forever()

    async def _handle_connection(self, reader, writer):
        addr = writer.get_extra_info('peername')
        logger.info(f"New peer connected: {addr}")
        # TODO: handshake + Double Ratchet setup

    async def send(self, peer_id: str, data: bytes):
        # TODO: encrypted send via Double Ratchet
        pass
