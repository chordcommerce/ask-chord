---
name: ask-chord
description: "Answer data questions against the Chord warehouse using the chord MCP retrieval and execution tools. Use when the user asks about warehouse data, schema, metrics, revenue, customers, orders, products, subscriptions, sessions, attribution, Shopify, Klaviyo, Iterable, or any saved/canonical query — i.e. anything that would be answered by SQL against the Chord data model. Triggers include 'how many', 'show me', 'top N', 'last month', 'last quarter', 'trend', 'breakdown', 'compare', 'revenue', 'orders', 'customers'. Walks the agent through the default retrieval-grounded SQL workflow: search_instructions → search_sql_pairs → search_schema + describe_schema → (consult Looker business logic for tenant-defined metric definitions/classifications when retrieval is ambiguous) → draft SQL → validate_query → submit_query → get_query_result. Requires the Ask Chord MCP server (registered as ask-chord) to be connected; if the retrieval/execution tools (search_schema, submit_query, etc.) are not available, fall back to the user's normal workflow and tell them to connect the server."
---

# Ask Chord — data-question workflow

You have access to a set of tools exposed by the Ask Chord MCP server (registered
as `ask-chord`) — `search_schema`, `submit_query`, and the others named below. Your
host prefixes their names according to how it registered the server (e.g.
`mcp__ask-chord__…` or, when installed via this plugin, `mcp__plugin_ask-chord_ask-chord__…`),
so match on the tool's base name rather than an exact prefix. Reach for them
automatically — without being asked — whenever the
user's request involves the project's warehouse data, schema, saved queries,
or product documentation. Do not fall back to hand-written SQL or guess at
table names when these tools are available.

## When to use which tool

- **`search_instructions`** — first stop: pull any always-apply SQL guidance
  the user has stored (filters, joins, casing rules, revenue/COGS conventions,
  test-order exclusion). Lead with it — it shapes how you read everything else.
- **`search_sql_pairs`** — find past question/SQL pairs that resemble the
  user's question. Useful as few-shot grounding before drafting new SQL.
- **`search_schema`** — semantic search for the tables most relevant to the
  question. Returns each table with its columns (DDL), so you usually have enough
  to write SQL. Start here.
- **`describe_schema`** — keyword discovery by table name. Pull the key nouns
  from the question and call `describe_schema(keyword=<noun>)` for each to surface
  tables by name that the semantic search may not rank or cover — including
  purpose-built staging/intermediate tables. Run alongside `search_schema`, even
  when it already returned something plausible: a dedicated table named for the
  metric asked about usually beats deriving from a general table.
- **`search_documentation`** — for "how do I…" questions about the Ask Chord
  product itself (global, not project-scoped).
- **`preview_table`** — peek at a handful of rows from a known table.
  Capped at 100 rows; use for shape/sanity checks, not analysis.
- **`validate_query`** — parse-check a read-only query (EXPLAIN dry-run) without
  running it. Returns `{valid: true}` or `{error}`. Run it before `submit_query`.
- **`submit_query`** — start a read-only query (SELECT/UNION/INTERSECT/EXCEPT only;
  capped at 500 rows) running **asynchronously** on the warehouse. Returns
  `{status:'pending', handle}` — or completed rows straight away on a cache hit —
  so no request stays open for a long query.
- **`get_query_result`** — fetch a submitted query's result by its `handle`.
  Returns `{status:'running'}` (call again in a couple seconds),
  `{status:'complete', columns, rows, row_count, dtypes}`, or `{error}`.
- **`explain_query`** — inspect a query's execution plan; use it to recover from a
  timeout (see the workflow below), not on queries that haven't timed out.
- **`list_tenants`** — list the tenants (Chord organizations) you have access
  to. Returns `[{name, slug, current}]` where `current` marks the tenant your
  requests route to right now. Every other tool automatically targets the
  current tenant's warehouse — you never pass a tenant per call.
- **`switch_tenant`** — change which tenant subsequent tool calls route to.
  Pass `slug` (from `list_tenants`) for an organization you're a member of;
  every later call (`submit_query`, `search_*`, `preview_table`) then
  targets that tenant's warehouse for the rest of the session — no reconnect
  or re-auth needed. Rejected if you're not a member of the requested tenant.

### Looker business-logic tools

Reach for these when the question hinges on a tenant-defined business concept —
a metric's exact formula (e.g. what counts toward net revenue), a categorical
classification (e.g. which channels are paid vs organic), or an attribution
model — and the retrieval tools above come back empty or ambiguous. Looker
holds the tenant's authoritative definitions; prefer them over guessing from
raw column names.

- **`list_looker_explores`** — entry point for business-logic discovery.
  Enumerate the tenant's Looker models and their explores, then pick the right
  model + explore before drilling in.
- **`list_looker_explore_fields`** — compact index (name/label/type) of a
  chosen explore's fields. Use to locate the field(s) that carry the concept
  you need.
- **`get_looker_field_detail`** — the payoff: the authoritative definition of
  named fields — the business description/formula, the SQL, and the source
  file. This is the tenant's real definition of a metric or classification.
- **`get_looker_query_sql`** — the compiled SQL Looker would run for an explore
  query (dimensions/measures/filters). Use when the derivation lives in Looker
  itself rather than in a field description.
- **`get_looker_project_file`** — raw LookML file content (requires the
  `see_lookml` permission). Use for source-level guidance — comments, caveats,
  which measure to trust — that isn't in the compiled explore.

## Working across tenants

The server routes every request to the **current tenant's** warehouse — it
picks this for you from your authenticated account, so don't try to route by
hand. If you're unsure which organization you're operating in, call
`list_tenants` first (it marks the `current` one). When the user asks to work
against a different organization they belong to, call `switch_tenant` with its
`slug`; the new routing sticks for the rest of the session.

## Default workflow

<!-- Keep in sync with Hub::ChordAI::CopilotWorkflow.workflow(async: true) in the
     hub-backend repo — that constant is the single source of truth for the MCP
     prompts. This skill drives the hub /mcp server, which runs SQL asynchronously
     (validate_query / submit_query / get_query_result), so mirror the ASYNC tail;
     this repo is a separate distribution and can't import the constant. -->

Run these retrieval steps in parallel first:

1. `search_instructions` — pull always-apply guidance (filters, joins,
   revenue/COGS conventions, test-order exclusion, etc.). Lead with it: it shapes
   how you read everything else.
2. `search_sql_pairs` — pull similar past Q/SQL pairs as few-shot grounding.
3. `search_schema` and `describe_schema` — discover which tables are relevant.
   `search_schema` is a semantic search that returns the most relevant tables along
   with their columns (DDL) — start here; it usually gives you enough to write SQL.
   Alongside it, pull the key nouns from the question and call
   `describe_schema(keyword=<noun>)` for each to surface tables by name that the
   semantic search may not rank or cover — including purpose-built
   staging/intermediate tables. Run this keyword search even when `search_schema`
   already returned something plausible: a dedicated table (e.g. one literally named
   for the metric asked about) usually beats deriving the answer from a general table.

Then:

4. When the question hinges on a tenant-defined business concept — a metric's exact
   formula (e.g. what goes into net revenue), a categorical classification (e.g.
   which channels count as paid vs organic), or an attribution model — and the
   retrieval above is empty or ambiguous, consult the tenant's Looker business
   logic: `list_looker_explores` to find the right model + explore, then
   `list_looker_explore_fields` to locate the field, then `get_looker_field_detail`
   for the authoritative definition. Prefer the Looker definition over guessing
   from raw column names.

When you write SQL, remember it runs on Snowflake (not Postgres):
- No `FILTER (WHERE …)` on aggregates — use `SUM(IFF(cond, x, 0))`, `COUNT_IF(cond)`, or `SUM(CASE WHEN cond THEN x END)`.
- Booleans are `= TRUE` / `= FALSE` (or `NOT COALESCE(flag, FALSE)`), never `IS [NOT] TRUE`.
- Don't alias with reserved words (`AS rows`, `AS order`, `AS values`) — pick another name or double-quote it (`AS "rows"`).

5. Draft SQL grounded in the above. Validate it first with `validate_query(sql)`
   for anything non-trivial.
6. Run it asynchronously — there is no `execute_sql` on this server. `submit_query(sql)`
   returns `{status:'pending', handle}` (or `{status:'complete', ...rows}` straight away on
   a cache hit); then call `get_query_result(handle)` every couple seconds until it
   returns `{status:'complete', ...rows}`.

If a query times out: when `get_query_result` returns a timeout error, call
`explain_query` on the SQL to inspect its execution plan, rewrite the query to avoid
the expensive operation it reveals (keeping the same result set), validate the rewrite
with `validate_query`, then `submit_query` again before giving up. This is a reactive
recovery step only — don't do it for queries that haven't timed out.

<!-- Keep in sync with Hub::ChordAI::CopilotWorkflow::FINALIZING_CHECK in the
     hub-backend repo. -->

Before finalizing: if your answer relies on a derived or proxy interpretation
of a term in the question (e.g. reading 'no matching channel mapping rule' as
SESSION_ATTRIBUTION_CHANNEL = 'Unknown'), you must have first run
describe_schema(keyword=<the term's key noun>) and confirmed no dedicated
physical table answers it directly. Prefer a purpose-built table over a proxy
derivation.

## Presenting results

<!-- Keep in sync with Hub::ChordAI::CopilotWorkflow::PRESENTING_RESULTS in the
     hub-backend repo. -->

A single number gets a sentence, not a table. A breakdown gets a table. Cite which
instructions you applied and which you intentionally skipped (one line of reasoning
is enough). Close every response with one sentence confirming the answer addressed
what they asked, then one or two concrete follow-up questions rooted in the data
you just returned — a breakdown, a trend, a related metric. Make them specific:
"want to see that broken down by channel?" beats "let me know if you have
questions."

If a tool returns an error, surface the error text verbatim before attempting a
fix — the user often recognizes it.

On uncertainty: if you're not confident in the answer, say so plainly. Don't dress
up a guess as a finding. The data is only useful if it's trustworthy.
