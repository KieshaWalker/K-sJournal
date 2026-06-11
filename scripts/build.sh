#!/usr/bin/env bash
# Release web build with env from .env (CI/Vercel passes env vars directly)
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a

exec flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_PROJECT_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_PUBLISHABLE_KEY"
