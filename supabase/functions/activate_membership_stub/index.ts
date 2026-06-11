// PHASE 1 PAYMENT STUB. Activates a membership directly with no charge:
// re-validates the user's invitation code, atomically decrements its uses,
// creates the membership row, and sets users.membership_tier.
// Replaced by the real payment rail (Plaid Transfer / Stripe ACH) in Phase 3.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

const TIER_PRICES: Record<string, number> = {
  observer: 29.0,
  analyst: 79.0,
  inner_circle: 149.0,
}

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const {
      data: { user },
      error: authError,
    } = await supabaseAdmin.auth.getUser(authHeader.replace('Bearer ', ''))
    if (authError || !user) return json({ error: 'Not authenticated.' }, 401)

    const { tier } = await req.json()
    if (!(tier in TIER_PRICES)) return json({ error: 'Invalid tier.' }, 400)

    // One membership per user
    const { data: existing } = await supabaseAdmin
      .from('memberships')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle()
    if (existing) return json({ error: 'Membership already exists.' }, 409)

    // Re-validate + atomically consume the invitation code
    const { data: profile } = await supabaseAdmin
      .from('users')
      .select('invitation_code_id')
      .eq('id', user.id)
      .single()
    if (!profile?.invitation_code_id) {
      return json({ error: 'No invitation on record for this account.' }, 403)
    }
    const { data: decremented, error: decError } = await supabaseAdmin.rpc(
      'decrement_invite_use',
      { p_code_id: profile.invitation_code_id },
    )
    if (decError || !decremented) {
      return json({ error: 'Invitation code is no longer valid.' }, 409)
    }

    const today = new Date()
    const nextBilling = new Date(today)
    nextBilling.setMonth(nextBilling.getMonth() + 1)
    const dateStr = (d: Date) => d.toISOString().split('T')[0]

    const { error: insertError } = await supabaseAdmin.from('memberships').insert({
      user_id: user.id,
      tier,
      payment_status: 'active', // stub: no payment rail yet
      billing_cycle_start: dateStr(today),
      next_billing_date: dateStr(nextBilling),
      monthly_amount: TIER_PRICES[tier],
    })
    if (insertError) throw insertError

    const { error: tierError } = await supabaseAdmin
      .from('users')
      .update({ membership_tier: tier })
      .eq('id', user.id)
    if (tierError) throw tierError

    return json({ status: 'active', tier })
  } catch (err) {
    console.error(err)
    return json({ error: 'Unexpected error.' }, 500)
  }
})
