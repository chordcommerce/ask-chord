# Chord Commerce public marketplace: multi-plugin split + auto-update

**Date:** 2026-09-01
**Status:** Design — awaiting review
**Repo:** `chordcommerce/ask-chord`

## Goal

Turn the existing single-plugin `chord` marketplace into a **public,
multi-plugin marketplace** where:

1. Installed plugins **auto-update** for consumers who opt in, and the
   marketplace listing **self-refreshes** on its own.
2. There is **room for a few first-party Chord plugins**, delivered now
   by splitting the four bundled skills into separate, purpose-scoped
   plugins that share one MCP server.

Non-goals (YAGNI — explicitly out of scope): CI/validation workflows,
automated version bumping, publishing pipelines, and rewriting the
skills' internal content. Easy to add later; not requested.

## Platform facts this design relies on

Confirmed against the official Claude Code docs (code.claude.com/docs):

- **Marketplace refresh.** No git pull on startup; a background check
  runs ~10 min after launch and applies on next launch or
  `/reload-plugins`. `/plugin install name@marketplace` refreshes the
  marketplace first. Manual: `/plugin marketplace update <name>`.
- **Plugin version tracking.** If a marketplace entry sets `version`,
  the plugin is **pinned** to that string — consumers only update when
  we bump it. If `version` is **omitted**, Claude tracks the git commit
  SHA, so every merge to `main` becomes an available update. We keep
  entries **unpinned** to make updates automatic.
- **Auto-update is a consumer opt-in.** A marketplace only self-refreshes
  and auto-updates its plugins when the consumer has `autoUpdate` on.
  A team enables it for everyone by committing an `extraKnownMarketplaces`
  entry with `"autoUpdate": true` to `.claude/settings.json`, which also
  auto-adds the marketplace (once the repo folder is trusted). We cannot
  force this on a stranger's client — the design makes it one config away.
- **Shared MCP server across plugins.** Declaring the same server in
  multiple plugins is *safe* (each is scoped independently) but *not
  recommended*. Recommended pattern: one **base** plugin registers the
  MCP server; **feature** plugins declare it via a `dependencies` array.
- **`dependencies` array** in `plugin.json` (e.g. `["chord"]`, or
  `[{"name":"chord","version":"^0.2"}]`). Installing a feature plugin
  auto-installs its dependency; disabling a dependency is blocked while a
  dependent needs it. No `requires`/`defaultEnabled` for this purpose.
- **MCP config location.** `.mcp.json` at the **plugin root** (never
  inside `.claude-plugin/`), or inline as `mcpServers` in `plugin.json`.

## Architecture: one marketplace, four plugins

The four skills all depend on the single remote `ask-chord` MCP server
(`streamable-http`, `https://mcp.chord.co/mcp`). So exactly one plugin
owns that registration and the others depend on it.

| Plugin | Contains | `dependencies` |
|---|---|---|
| **`chord`** (base) | `ask-chord` MCP server (`.mcp.json`) + `ask-chord` core skill | — |
| **`chord-activation-health`** | activation-health skill | `["chord"]` |
| **`chord-metric-verify`** | metric-verify skill | `["chord"]` |
| **`chord-daily-insights`** | daily-insights skill (cron + Slack) | `["chord", "chord-metric-verify"]` |

Rationale:

- **Base stays named `chord`** so the existing `/plugin install chord@chord`
  keeps working and existing installs migrate on next refresh.
- **`chord` is lean** (MCP + core `ask-chord` skill only). Existing
  installs keep the core query workflow; the three specialized skills
  become opt-in plugins. Migration is documented in the README (see
  Migration below).
- **`chord-daily-insights` depends on `chord-metric-verify`** because the
  digest skill runs that verification checklist. Its Slack MCP dependency
  is **external** (consumer-provided) and documented, not bundled.

### Tool-name scoping caveat (documented, not fixed)

Plugin-provided MCP tools are exposed under scoped names
(`mcp__plugin_chord_ask-chord__<tool>`), whereas the skills' bodies
reference `mcp__chord__*` and tool names like `ask` / `execute_sql` /
`search_saved_views`. This mismatch **pre-exists** and is unchanged by
the split (the base plugin registers the server exactly as the current
plugin does). Rewriting skill internals is out of scope for this work;
noted here so it is not mistaken for a regression introduced by the split.

## Repo layout

Move from the single `plugin/` dir to a `plugins/` monorepo. Sources in
`marketplace.json` use **relative paths** (simpler than `git-subdir`,
same git-SHA auto-update behavior, resolved inside the cloned repo).

```
.claude-plugin/
  marketplace.json
plugins/
  chord/
    .claude-plugin/plugin.json
    .mcp.json
    skills/ask-chord/SKILL.md
  chord-activation-health/
    .claude-plugin/plugin.json
    skills/chord-activation-health/SKILL.md
  chord-metric-verify/
    .claude-plugin/plugin.json
    skills/chord-metric-verify/SKILL.md
  chord-daily-insights/
    .claude-plugin/plugin.json
    skills/chord-daily-insights/SKILL.md
```

The skill directory names inside each plugin match each skill's `name:`
frontmatter (`ask-chord`, `chord-activation-health`, `chord-metric-verify`,
`chord-daily-insights`) so they load correctly.

## File contents

### `.claude-plugin/marketplace.json`

```json
{
  "$schema": "https://json.schemastore.org/claude-code-marketplace.json",
  "name": "chord",
  "owner": { "name": "Chord Commerce", "url": "https://chord.co" },
  "description": "Chord Commerce's Claude Code plugin marketplace — connect Claude to your Chord warehouse and run analytics workflows.",
  "plugins": [
    {
      "name": "chord",
      "source": "./plugins/chord",
      "displayName": "Chord",
      "description": "Registers the Ask Chord MCP server and the data-question workflow skill.",
      "category": "data",
      "keywords": ["chord", "warehouse", "analytics", "sql", "mcp"]
    },
    {
      "name": "chord-activation-health",
      "source": "./plugins/chord-activation-health",
      "displayName": "Chord Activation Health",
      "description": "Report the health of all audience syncs and destinations.",
      "category": "data",
      "keywords": ["chord", "activation", "sync", "klaviyo", "meta"]
    },
    {
      "name": "chord-metric-verify",
      "source": "./plugins/chord-metric-verify",
      "displayName": "Chord Metric Verify",
      "description": "Verify a revenue/order/LTV figure uses the correct basis before it ships.",
      "category": "data",
      "keywords": ["chord", "verify", "revenue", "metrics"]
    },
    {
      "name": "chord-daily-insights",
      "source": "./plugins/chord-daily-insights",
      "displayName": "Chord Daily Insights",
      "description": "Nightly commerce-signals digest posted to Slack.",
      "category": "data",
      "keywords": ["chord", "insights", "digest", "slack", "cron"]
    }
  ]
}
```

Notes: **no `version`** on any entry (keeps git-SHA auto-update). The
`$schema` line is best-effort; if Claude rejects an unknown field it is
dropped. Cross-plugin `dependencies` are declared in each `plugin.json`
(below), which is where the docs place them.

### `plugins/chord/.claude-plugin/plugin.json`

```json
{
  "name": "chord",
  "version": "0.2.0",
  "description": "Ask Chord MCP server registration and the data-question workflow skill.",
  "author": { "name": "Chord Commerce" },
  "homepage": "https://github.com/chordcommerce/ask-chord"
}
```

### `plugins/chord/.mcp.json`

Unchanged from the current `plugin/.mcp.json`:

```json
{
  "mcpServers": {
    "ask-chord": { "type": "streamable-http", "url": "https://mcp.chord.co/mcp" }
  }
}
```

### Feature plugin manifests

Each feature plugin's `plugin.json` adds a `dependencies` array. Example
`plugins/chord-daily-insights/.claude-plugin/plugin.json`:

```json
{
  "name": "chord-daily-insights",
  "version": "0.2.0",
  "description": "Nightly commerce-signals digest posted to Slack.",
  "author": { "name": "Chord Commerce" },
  "homepage": "https://github.com/chordcommerce/ask-chord",
  "dependencies": ["chord", "chord-metric-verify"]
}
```

`chord-activation-health` and `chord-metric-verify` are identical in
shape with `"dependencies": ["chord"]` and their own name/description.

## Auto-update strategy (the parts we control)

1. **Never pin `version` on marketplace entries** → git-SHA tracking, so
   any merge to `main` is an available update. A README note warns that
   adding `version` freezes updates.
2. **README "Auto-updating install" section** with the team snippet:

   ```json
   {
     "extraKnownMarketplaces": {
       "chord": {
         "source": { "source": "github", "repo": "chordcommerce/ask-chord" },
         "autoUpdate": true
       }
     }
   }
   ```

   Committed to a team's `.claude/settings.json`, this auto-adds the
   marketplace and turns on background refresh + plugin auto-update.
3. **Individual-user path** documented:
   `/plugin marketplace add chordcommerce/ask-chord`, then
   `/plugin install chord@chord` (and any feature plugins), and enable
   auto-update in `/plugin` — or refresh manually with
   `/plugin marketplace update chord` + `/reload-plugins`.

## Migration (existing `chord` installs)

Because `chord` becomes lean, existing installs keep the core `ask-chord`
skill but lose the three specialized skills on next update. README
migration note instructs:

- The three skills are now separate plugins; install any you want:
  `/plugin install chord-activation-health@chord`, etc.
- `chord-daily-insights` runs on a cron and posts to Slack — anyone
  relying on the nightly digest must install `chord-daily-insights`
  (which pulls `chord` + `chord-metric-verify` automatically) and keep
  their Slack MCP connected.

## Files touched

| File | Change |
|---|---|
| `.claude-plugin/marketplace.json` | Rewrite: 4 entries, relative sources, metadata, unpinned. |
| `plugins/chord/**` | New: plugin.json, .mcp.json, moved `ask-chord` skill. |
| `plugins/chord-activation-health/**` | New: plugin.json + moved skill. |
| `plugins/chord-metric-verify/**` | New: plugin.json + moved skill. |
| `plugins/chord-daily-insights/**` | New: plugin.json + moved skill. |
| `plugin/` (old dir) | Removed after move. |
| `install.sh` | `SKILL_REPO_PATH`: `plugin/skills/ask-chord/SKILL.md` → `plugins/chord/skills/ask-chord/SKILL.md`; audit other `plugin/` refs. |
| `README.md` | Update skill paths (`plugin/…` → `plugins/chord/…`), add marketplace + auto-update + migration sections, list the 4 plugins. |

## Testing

- **JSON validity:** every `marketplace.json` and `plugin.json` parses
  (e.g. `jq empty` over each).
- **Marketplace loads locally:** `/plugin marketplace add ./` (or the
  absolute repo path) lists all four plugins with correct metadata.
- **Dependency resolution:** installing `chord-daily-insights` locally
  auto-installs `chord` and `chord-metric-verify`; the `ask-chord`
  server appears connected.
- **install.sh:** run with the local clone and confirm it resolves the
  new skill path (`SOURCE_DESC` = local) and installs `SKILL.md`; run the
  curl-piped form's path logic mentally against the new raw URL.
- **README links:** the two `plugin/skills/ask-chord/SKILL.md` links and
  the raw one-liner URL resolve to the new location.

## Open questions

None blocking. `$schema` URL is best-effort; `pluginRoot` was
deliberately avoided (version-gated, v2.1.239+) in favor of explicit
relative paths for broader compatibility.
