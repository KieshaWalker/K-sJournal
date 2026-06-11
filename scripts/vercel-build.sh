#!/usr/bin/env bash
# Vercel build step: release web build with Supabase env injected.
# Requires SUPABASE_PROJECT_URL and SUPABASE_PUBLISHABLE_KEY set in the
# Vercel project's environment variables.
set -euo pipefail

: "${SUPABASE_PROJECT_URL:?Set SUPABASE_PROJECT_URL in Vercel env vars}"
: "${SUPABASE_PUBLISHABLE_KEY:?Set SUPABASE_PUBLISHABLE_KEY in Vercel env vars}"

"$HOME/flutter/bin/flutter" build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_PROJECT_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_PUBLISHABLE_KEY"
