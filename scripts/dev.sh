#!/usr/bin/env bash
# Run the app locally against the hosted Supabase project, with env from .env
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a

exec flutter run -d web-server --web-port 3000 \
  --dart-define=SUPABASE_URL="$SUPABASE_PROJECT_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_PUBLISHABLE_KEY"
