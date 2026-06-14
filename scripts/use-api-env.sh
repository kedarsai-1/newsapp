#!/usr/bin/env bash
# Switch Flutter assets/.env between local dev and production VPS profiles.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_ASSETS="$ROOT/flutter_app/assets"
PROFILE="${1:-}"

usage() {
  cat <<'EOF'
Usage: ./scripts/use-api-env.sh <local|production>

  local       → 127.0.0.1:5010 (Android emulator uses 10.0.2.2 automatically)
  production  → HTTPS Railway/custom domain (see env.production.template)

Copies the matching template to flutter_app/assets/.env.
EOF
}

if [[ "$PROFILE" != "local" && "$PROFILE" != "production" ]]; then
  usage
  exit 1
fi

SRC="$FLUTTER_ASSETS/env.${PROFILE}.template"
DEST="$FLUTTER_ASSETS/.env"

if [[ ! -f "$SRC" ]]; then
  echo "Missing template: $SRC" >&2
  exit 1
fi

cp "$SRC" "$DEST"
echo "Wrote $DEST from env.${PROFILE}.template"
