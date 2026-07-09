---
name: chord-copilot
description: "Answer data questions against the Chord warehouse using the chord MCP retrieval and execution tools. Use when the user asks about warehouse data, schema, metrics, revenue, customers, orders, products, subscriptions, sessions, attribution, Shopify, Klaviyo, Iterable, or any saved/canonical query — i.e. anything that would be answered by SQL against the Chord data model. Triggers include 'how many', 'show me', 'top N', 'last month', 'last quarter', 'trend', 'breakdown', 'compare', 'revenue', 'orders', 'customers'. Also exposes two purpose-built insight tools — get_channel_performance (paid-channel ROAS/CAC with Chord multi-touch attribution) and get_audience_insights (repeat rate, LTV, RFM, activatable audiences) — prefer these for marketing-performance and audience questions (ROAS, CAC, 'which channel', 'shift budget', 'who should I target', 'winback', 'lookalike', 'repeat rate', 'churn'). Walks the agent through the default retrieval-grounded SQL workflow: search_schema → search_saved_views / search_sql_pairs → search_instructions → draft SQL → execute_sql. Requires the chord-copilot MCP server to be connected; if the mcp__chord__* tools are not available, fall back to the user's normal workflow and tell them to connect the server."
---

# Chord Copilot — data-question workflow

You have access to a set of `mcp__chord__*` tools exposed by the chord-copilot
MCP server. Reach for them automatically — without being asked — whenever the
user's request involves the project's warehouse data, schema, saved queries,
or product documentation. Do not fall back to hand-written SQL or guess at
table names when these tools are available.

## When to use which tool

- **`search_schema`** — first stop for any data question. Discover which
  tables exist and what they contain before writing SQL.
- **`search_sql_pairs`** — find past question/SQL pairs that resemble the
  user's question. Useful as few-shot grounding before drafting new SQL.
- **`search_saved_views`** — check whether a user-blessed canonical query
  already answers the question. Prefer an existing view over inventing SQL.
- **`search_instructions`** — pull any always-apply SQL guidance the user
  has stored (filters, joins, casing rules, revenue/COGS conventions,
  test-order exclusion). Run this before finalizing SQL.
- **`search_documentation`** — for "how do I…" questions about the Chord
  Copilot product itself (global, not project-scoped).
- **`preview_table`** — peek at a handful of rows from a known table.
  Capped at 100 rows; use for shape/sanity checks, not analysis.
- **`execute_sql`** — run a read-only query (SELECT/UNION/INTERSECT/EXCEPT
  only; capped at 10000 rows). Pass `validate_only=True` to parse-check
  without executing.
- **`get_channel_performance`** — paid-channel ROAS/CAC with Chord's
  multi-touch attribution (see the marketing-insights section below). Prefer
  it over hand-written SQL for channel/spend/ROAS/CAC questions.
- **`get_audience_insights`** — customer-base health + activatable audiences
  (repeat rate, LTV, RFM, winback, lookalike seed). Prefer it over hand-written
  SQL for audience/segment/retention questions.
- **`list_tenants`** — list the tenants (Chord organizations) you have access
  to. Returns `[{name, slug, current}]` where `current` marks the tenant your
  requests route to right now. Every other tool automatically targets the
  current tenant's warehouse — you never pass a tenant per call.
- **`switch_tenant`** — change which tenant subsequent tool calls route to.
  Pass `slug` (from `list_tenants`) for an organization you're a member of;
  every later call (`ask`, `execute_sql`, `search_*`, `preview_table`) then
  targets that tenant's warehouse for the rest of the session — no reconnect
  or re-auth needed. Rejected if you're not a member of the requested tenant.

## Working across tenants

The server routes every request to the **current tenant's** warehouse — it
picks this for you from your authenticated account, so don't try to route by
hand. If you're unsure which organization you're operating in, call
`list_tenants` first (it marks the `current` one). When the user asks to work
against a different organization they belong to, call `switch_tenant` with its
`slug`; the new routing sticks for the rest of the session.

## Default workflow

For a data question:

1. `search_schema` — discover relevant tables.
2. `search_saved_views` and `search_sql_pairs` — in parallel, look for a
   canonical query or close prior example.
3. `search_instructions` — pull always-apply SQL guidance.
4. Draft SQL grounded in the above.
5. `execute_sql` (optionally with `validate_only=True` first for non-trivial
   queries) to return rows.

Run independent retrieval steps in parallel.

## Actionable marketing insights (prefer these over hand-written SQL)

For paid-media performance or audience questions, reach for these purpose-built
tools instead of the search_* → execute_sql workflow — they already encode the
attribution joins, coverage caveats, and RFM/predictive enrichment.

- **`get_channel_performance`** — per channel: Chord-attributed ROAS *and* the
  platform's self-reported ROAS, CAC, period-over-period deltas, best/worst
  summary. Params: `window_days` (default 30; use a shorter window for tenants
  whose attribution was instrumented recently) and `attribution_model`
  (linear | last_touch | first_touch | forty_twenty_forty). **Trust `chord_roas`
  only when a channel's `coverage` is `full`** — `low_attribution_sample`,
  `spend_without_attribution`, or `attributed_without_mapped_spend` mean judge
  that channel on `platform_roas` instead. Lead with the platform-vs-Chord ROAS
  gap — the insight no ad platform can show. Use for "what's my real ROAS/CAC
  by channel", "which channel should I shift budget to/from".
- **`get_audience_insights`** — customer-base health (repeat rate, one-time
  share, realized LTV, subscribers) + ranked activatable audiences (recent
  one-time buyers, high-value lookalike seed, discount-acquired win-back, and —
  when the tenant has the DataScience RFM/CLR model — Champions and At-Risk
  Valuable, with total predicted book value), plus the brand's existing Klaviyo
  segments. Check `feature_coverage` for which predictive/RFM signals were
  available; prefer activating an existing segment over recreating one. Use for
  "who should I target/suppress", "what's my repeat rate", "find a
  winback/lookalike audience".

Cite the `coverage` / `feature_coverage` caveats so the numbers are read right.

## How to present the answer

- Cite which instructions you applied — and which you intentionally
  skipped, with reasoning. (Example: "Used plain `NET_REVENUE` because
  the user asked for 'revenue', not 'net revenue' — instruction #37
  reserves the COGS+shipping formula for explicit 'net revenue' asks.")
- If a saved view answered the question, name the `view_id` so the user
  can find it in Copilot.
- If the engine returns an error, surface the error text verbatim before
  attempting a fix — the user often recognizes it.
