// Syncs ticker data from the external market-data Supabase project's
// iv_snapshots table into this project's volatility_data and
// market_snapshots. Replaces the old FMP design.
//
// Env (set via `supabase secrets set`):
//   MARKET_DATA_URL  — external project URL
//   MARKET_DATA_KEY  — external project key with read access to iv_snapshots
//
// Schedule via pg_cron (e.g. 30 6 * * 1-5) or invoke manually.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

const marketData = createClient(
  Deno.env.get('MARKET_DATA_URL')!,
  Deno.env.get('MARKET_DATA_KEY')!,
)

// Fields of iv_snapshots that map to first-class volatility_data columns;
// everything else is preserved in volatility_data.extra.
const CORE_FIELDS = new Set([
  'ticker',
  'date',
  'atm_iv',
  'iv_rank',
  'iv_percentile',
  'underlying_price',
])

Deno.serve(async (_req) => {
  try {
    const { data: watchlist, error: wlError } = await supabaseAdmin
      .from('watchlist_tickers')
      .select('ticker, source_symbol')
      .eq('is_active', true)
    if (wlError) throw wlError

    let synced = 0
    const failures: string[] = []

    for (const { ticker, source_symbol } of watchlist ?? []) {
      const symbol = source_symbol ?? ticker
      const { data: snap, error } = await marketData
        .from('iv_snapshots')
        .select('*')
        .eq('ticker', symbol)
        .order('date', { ascending: false })
        .limit(1)
        .maybeSingle()

      if (error || !snap) {
        failures.push(symbol)
        continue
      }

      const extra: Record<string, unknown> = {}
      for (const [k, v] of Object.entries(snap)) {
        if (!CORE_FIELDS.has(k) && v !== null) extra[k] = v
      }

      const { error: volError } = await supabaseAdmin
        .from('volatility_data')
        .upsert(
          {
            ticker,
            snapshot_date: snap.date,
            iv_current: snap.atm_iv,
            iv_rank: snap.iv_rank,
            iv_percentile: snap.iv_percentile,
            underlying_price: snap.underlying_price,
            extra,
          },
          { onConflict: 'ticker,snapshot_date' },
        )
      if (volError) {
        failures.push(symbol)
        continue
      }

      if (snap.underlying_price !== null) {
        const { error: msError } = await supabaseAdmin
          .from('market_snapshots')
          .upsert(
            {
              ticker,
              snapshot_date: snap.date,
              close: snap.underlying_price,
            },
            { onConflict: 'ticker,snapshot_date' },
          )
        if (msError) {
          failures.push(symbol)
          continue
        }
      }

      synced++
    }

    console.log(`sync_market_data: synced=${synced} failed=[${failures.join(',')}]`)
    return new Response(JSON.stringify({ synced, failures }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error(err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
