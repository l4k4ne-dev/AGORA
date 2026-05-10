"""
Home Node — The sovereign local server.
Stores all data locally, syncs with devices, relays encrypted traffic.
"""
import asyncio
import logging

logger = logging.getLogger(__name__)

class HomeNode:
    def __init__(self):
        self.running = False
        logger.info("HomeNode initialized")

    async def start(self):
        self.running = True
        logger.info("HomeNode started — sovereign local node is live")
        while self.running:
            await asyncio.sleep(1)

    async def stop(self):
        self.running = False
        logger.info("HomeNode stopped")
