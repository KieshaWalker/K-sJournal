// Validates an invitation code for the unauthenticated registration flow.
// Read-only: the atomic uses_remaining decrement happens at membership
// activation, not here.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

const rateLimits = new Map<string, { count: number; reset: number }>()

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    // Rate limit: 5 attempts per IP per 5 minutes (prevents code enumeration).
    // In-memory per-isolate map — Deno KV is not available on the Supabase
    // edge runtime. Resets when the isolate recycles, which is acceptable
    // for slowing enumeration on a small private app.
    const ip = req.headers.get('x-forwarded-for') ?? 'unknown'
    const now = Date.now()
    const record = rateLimits.get(ip)
    if (record && record.reset > now && record.count >= 5) {
      return json({ error: 'Too many attempts. Try again in a few minutes.' }, 429)
    }
    rateLimits.set(ip, {
      count: record && record.reset > now ? record.count + 1 : 1,
      reset: record && record.reset > now ? record.reset : now + 300_000,
    })

    const { code } = await req.json()
    const normalized = String(code ?? '').toUpperCase().trim()

    const { data: invite, error } = await supabaseAdmin
      .from('invitation_codes')
      .select('id, status, expires_at, uses_remaining, default_tier')
      .eq('code', normalized)
      .single()

    if (error || !invite) return json({ error: 'Invalid invitation code.' }, 400)
    if (invite.status !== 'active') {
      return json({ error: 'This invitation code has been revoked.' }, 400)
    }
    if (invite.expires_at && new Date(invite.expires_at) < new Date()) {
      return json({ error: 'This invitation code has expired.' }, 400)
    }
    if (invite.uses_remaining <= 0) {
      return json({ error: 'This invitation code has already been used.' }, 400)
    }

    return json({ invite_code_id: invite.id, default_tier: invite.default_tier })
  } catch (err) {
    console.error(err)
    return json({ error: 'Unexpected error.' }, 500)
  }
})
