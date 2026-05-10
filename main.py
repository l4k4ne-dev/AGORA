#!/usr/bin/env python3
"""
AGORA — A Protocol for Human Connection
Home Node Entry Point
"""
import asyncio
from agora.node.home_node import HomeNode

async def main():
    node = HomeNode()
    await node.start()

if __name__ == "__main__":
    asyncio.run(main())
