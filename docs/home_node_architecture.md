# Home Node Architecture

## ASCII Component Diagram

```
+-------------------+      +-------------------+      +-------------------+
|   P2P Transport   |<---->|  Crypto Ratchet   |<---->| Storage Interface |
|  (NATS/RabbitMQ)  |      |(Double Ratchet)   |      |  (LevelDB)        |
+-------------------+      +-------------------+      +-------------------+
                  \                                  /|                |
                   \                                / |                |
                    \                              /  |                |
+-------------------+ +--------------------------+  +-----------------+
|    Web API        | |    Session Management    |              |
|  (Flask/FastAPI)  | |   (WebRTC/ICE)           |              |
+-------------------+ +--------------------------+              |
                              |                                |
                              v                                v
                     +----------------------------------+------------------+
                     |           Home Node Core          |  Identity Store  |
                     |  (Routing/P2P Discovery)          |  (SQLite)        |
                     +----------------------------------+------------------+
```

## Diferențe față de whitepaper

1. Fehlt: REST API Gateway → Adăugare ruter inversat NGINX cu OAuth2 (Sprint 2)
2. Fehlt: Metrics/Healthcheck-endpoint în Web API (adăugat în Sprint 2)
3. Fehlt: WebSockets pentru streaming real-time → Planificat pentru Sprint 3
4. Fehlt: Snapshot/compaction pe storage → Planificat pentru Sprint 3

## Sprint Planning

### Sprint 1 (Weeks 1-4): Core P2P Architecture
- ✅ P2P Transport Layer finish
- ✅ Crypto Rädchen finalizat
- ✅ Session Management implementare
- ✅ Web API skeleton

### Sprint 2 (Weeks 5-8): Security & Monitoring
- Implementare OAuth2 Gateway (NGINX)
- Adăugare endpoint /healthz cu Prometheus metrics
- Securizare transport (TLS 1.3 miminal)
- Unit tests pentru crypto protocol

### Sprint 3 (Weeks 9-12): Scaling & Stability
- Implementare WebSockets server
- Snapshot/compaction pentru storage
- Load testing + chaos engineering
- Finalizează whitepaper gaps

## Combinare cu Git

Rulare git operations...
```sh
/home/x3d/AGORA/venv/bin/python3 -c "print('✓ Executed with AGORA venv')"
"

git add -A && git commit -m 'docs: architecture plan' && git push origin main