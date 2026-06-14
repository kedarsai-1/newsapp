# News App — frontend worktree (`main`)

Canonical development worktree for the News App. Git branch: **`main`** (latest merge: `14537d5` — premium glass UI + server sync).

## Repository layout

| Path (this worktree) | Git index path | Description |
|----------------------|----------------|-------------|
| `flutter_app/` | `flutter_app/` | Flutter client |
| `server/` | `server/` | Node.js Express API |

From the **root** worktree (`root-stub` branch), the same directories appear as `frontend/flutter_app/` and `frontend/server/`. Commands in this README assume you are **inside `frontend/`**.

The root worktree holds docs and `railway.toml` only; root `flutter_app/` and `server/` were deleted as duplicates.

## Prerequisites

- Node.js 20+
- PostgreSQL (local or remote `DATABASE_URL` in `server/.env`)
- Flutter SDK
- For AI features: Ollama on `http://127.0.0.1:11434` (optional locally)

## Server setup (local)

```bash
cd server
cp .env.example .env   # if .env is missing
# Edit DATABASE_URL, JWT_SECRET, etc.
npm install
```

**Local dev port:** `5010` (used by `./scripts/dev-local.sh` and the checked-in `flutter_app/assets/.env`). macOS reserves **5000** for AirPlay; `5001` is the code default when `API_PORT` / `PORT` are unset.

Set in `server/.env`:

```env
PORT=5010
NODE_ENV=development
```

For local development, `NODE_ENV=development` allows CORS for Flutter web. Mobile apps are unaffected by CORS.

```bash
npm run dev    # nodemon — uses PORT from .env
# or
npm start
```

Health check: `curl http://127.0.0.1:5010/api/health`

## Flutter API configuration

Env is loaded from `flutter_app/assets/.env` via `flutter_dotenv`.

| Profile | API | Socket |
|---------|-----|--------|
| **Local** | `http://127.0.0.1:5010/api` (simulator/desktop) | `http://127.0.0.1:5010` |
| **Android emulator** | `http://10.0.2.2:5010/api` (automatic when `API_BASE_URL` unset) | `http://10.0.2.2:5010` |
| **Physical device** | Set `API_HOST` to your Mac's LAN IP in `.env` | same host, port `5010` |
| **Railway / production** | `https://<service>.up.railway.app/api` | `https://<service>.up.railway.app` |

`AppConstants` in `flutter_app/lib/constants.dart` falls back to port **5001** only when `API_PORT` is unset. Keep `API_PORT=5010` in local `.env` to match the server.

Switch profiles:

```bash
./scripts/use-api-env.sh local        # local dev (:5010)
./scripts/use-api-env.sh production   # HTTPS production template (Railway/custom domain)
```

Templates: `flutter_app/assets/env.local.template`, `flutter_app/assets/env.production.template`. Reference: `flutter_app/assets/.env.example` (Railway HTTPS example).

## One-command local dev

Starts the API on **PORT=5010**, waits for `/api/health`, applies local env, runs Flutter:

```bash
./scripts/dev-local.sh
# e.g. target a device:
./scripts/dev-local.sh -d chrome
./scripts/dev-local.sh -d <device-id>
```

## Physical Android device on Wi‑Fi

1. Find your Mac IP: `ipconfig getifaddr en0`
2. Set in `flutter_app/assets/.env`: `API_HOST=192.168.x.x` and `API_PORT=5010`
3. Add that IP to `android/app/src/main/res/xml/network_security_config.xml` if cleartext is blocked
4. Ensure the phone and Mac are on the same network; server binds `0.0.0.0` by default

## Production deployment

### Railway (recommended)

1. Connect the GitHub repo to Railway.
2. Set **Root Directory** to **`frontend/server`** (documented in root `railway.toml` and `frontend/railway.toml`).
3. Configure env vars from `server/.env.example` (`DATABASE_URL`, `JWT_SECRET`, `ALLOWED_ORIGINS`, etc.).
4. Build uses Nixpacks (`npm ci`, `prisma generate`, `prisma migrate deploy`); start command: `npm start`.
5. Health check: `/api/health` (liveness). Use `/api/ready` for readiness when DB must be connected.
6. Point Flutter `API_BASE_URL` / `SOCKET_URL` at the public **HTTPS** Railway URL (required for JWT release builds).

### Custom domain / TLS

- Terminate TLS at Railway or nginx and set `API_BASE_URL=https://api.yourdomain.com/api`.
- Do **not** ship production Flutter builds with `http://` API URLs — bearer tokens require HTTPS/WSS.

## Verify connectivity

```bash
# Local (port 5010)
curl -s http://127.0.0.1:5010/api/health | head -c 200

# Production (HTTPS only — set in env.production.template)
# curl -s https://your-service.up.railway.app/api/health | head -c 200

# Feed endpoint (used by Flutter home)
curl -s "http://127.0.0.1:5010/api/news/feed?page=1&limit=5" | head -c 300
```

## Related docs

- [`../docs/ARCHITECTURE_AND_PRODUCTION_PLAN.md`](../docs/ARCHITECTURE_AND_PRODUCTION_PLAN.md)
- [`../docs/QA_ARCHITECTURE_REVIEW.md`](../docs/QA_ARCHITECTURE_REVIEW.md)
- [`server/docs/OLLAMA_SETUP.md`](server/docs/OLLAMA_SETUP.md)
- [`flutter_app/docs/FIREBASE_SETUP.md`](flutter_app/docs/FIREBASE_SETUP.md)
