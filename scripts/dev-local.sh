#!/usr/bin/env bash
# Start the Node API on PORT=5001 and run Flutter against local env.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER_DIR="$ROOT/server"
FLUTTER_DIR="$ROOT/flutter_app"

"$ROOT/scripts/use-api-env.sh" local

if [[ ! -f "$SERVER_DIR/.env" ]]; then
  echo "Missing $SERVER_DIR/.env — copy from server/.env.example and configure DATABASE_URL." >&2
  exit 1
fi

if [[ ! -d "$SERVER_DIR/node_modules" ]]; then
  echo "Installing server dependencies…"
  (cd "$SERVER_DIR" && npm install)
fi

# Permissive CORS for Flutter web during local dev.
if grep -q '^NODE_ENV=production' "$SERVER_DIR/.env" 2>/dev/null; then
  echo "Tip: set NODE_ENV=development in server/.env for local CORS (Flutter web)."
fi

echo "Starting API server on http://127.0.0.1:5010 …"
(cd "$SERVER_DIR" && PORT=5010 npm run dev) &
SERVER_PID=$!

cleanup() {
  kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

for _ in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:5010/api/health" >/dev/null 2>&1; then
    echo "API healthy at http://127.0.0.1:5010/api/health"
    break
  fi
  sleep 1
done

cd "$FLUTTER_DIR"
echo "Running Flutter (pass extra args, e.g. -d chrome)…"
flutter run "$@"
