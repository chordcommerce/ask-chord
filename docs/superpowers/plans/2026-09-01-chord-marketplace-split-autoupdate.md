# Chord Marketplace Split + Auto-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the single-plugin `chord` marketplace into a base plugin (MCP + core skill) plus three feature plugins that depend on it, and wire git-SHA auto-update with a team `autoUpdate` settings snippet.

**Architecture:** One marketplace (`chord`) lists four plugins living in a `plugins/` monorepo. The base `chord` plugin registers the shared `ask-chord` remote MCP server via `.mcp.json` and ships the core `ask-chord` skill. Three feature plugins are skill-only and declare `chord` (and, for daily-insights, `chord-metric-verify`) in their `dependencies` array, so installing a feature plugin auto-installs the server. Marketplace entries carry no pinned `version`, so Claude Code tracks the git SHA and every merge to `main` is an available update.

**Tech Stack:** Claude Code plugin marketplace (`.claude-plugin/marketplace.json`, `plugin.json`, `.mcp.json`), bash (`install.sh`), Markdown docs. Validation via `claude plugin validate` (v2.1.252) and `jq`.

**Spec:** `docs/superpowers/specs/2026-09-01-chord-marketplace-split-autoupdate-design.md`

## Global Constraints

- Marketplace entries carry **no `version` field** (keeps git-SHA auto-update). Never add one without a bump discipline.
- Each `plugin.json` has `"version": "0.2.0"`, `"author": { "name": "Chord Commerce" }`, `"homepage": "https://github.com/chordcommerce/ask-chord"`.
- Base plugin is named **`chord`** (preserves existing `/plugin install chord@chord`).
- MCP server: name `ask-chord`, `"type": "streamable-http"`, `"url": "https://mcp.chord.co/mcp"`. Registered by the base plugin only.
- `.mcp.json` lives at the **plugin root** — never inside `.claude-plugin/`.
- Skill directory names match each skill's frontmatter `name`: `ask-chord`, `chord-activation-health`, `chord-metric-verify`, `chord-daily-insights`.
- **Do not rewrite skill bodies.** Moving them is the only change; the `mcp__chord__*` tool-name mismatch is a pre-existing, out-of-scope concern.
- Marketplace name stays `chord`; owner `{ "name": "Chord Commerce", "url": "https://chord.co" }`.
- All manifests must pass `claude plugin validate <path>` (non-`--strict`; `--strict` may warn on `$schema`/metadata and is advisory only).
- Use `git mv` for every skill/file move so history is preserved.

## File Structure

```
.claude-plugin/marketplace.json          # rewrite: 4 entries, relative sources
plugins/
  chord/
    .claude-plugin/plugin.json           # base, version 0.2.0, no deps
    .mcp.json                            # moved from plugin/.mcp.json
    skills/ask-chord/SKILL.md            # moved
  chord-activation-health/
    .claude-plugin/plugin.json           # deps: ["chord"]
    skills/chord-activation-health/SKILL.md   # moved + dir renamed
  chord-metric-verify/
    .claude-plugin/plugin.json           # deps: ["chord"]
    skills/chord-metric-verify/SKILL.md       # moved + dir renamed
  chord-daily-insights/
    .claude-plugin/plugin.json           # deps: ["chord","chord-metric-verify"]
    skills/chord-daily-insights/SKILL.md      # moved + dir renamed
install.sh                               # SKILL_REPO_PATH updated
README.md                                # paths + marketplace/auto-update/migration sections
docs/superpowers/specs/2026-09-01-...    # already committed (spec)
```

The old `plugin/` directory ceases to exist once its four skills, `.mcp.json`, and `.claude-plugin/plugin.json` are `git mv`'d out (Tasks 1–2).

---

### Task 1: Base `chord` plugin

**Files:**
- Move: `plugin/.mcp.json` → `plugins/chord/.mcp.json`
- Move: `plugin/.claude-plugin/plugin.json` → `plugins/chord/.claude-plugin/plugin.json` (then edit)
- Move: `plugin/skills/ask-chord/` → `plugins/chord/skills/ask-chord/`
- Result: `plugins/chord/**`

**Interfaces:**
- Produces: a plugin named `chord` at `plugins/chord/` that registers MCP server `ask-chord` and ships skill `ask-chord`. Feature plugins (Task 2) name it in `dependencies`. Marketplace (Task 3) sources it at `./plugins/chord`.

- [ ] **Step 1: Create target dirs and move files with git**

```bash
mkdir -p plugins/chord/.claude-plugin plugins/chord/skills
git mv plugin/.mcp.json plugins/chord/.mcp.json
git mv plugin/.claude-plugin/plugin.json plugins/chord/.claude-plugin/plugin.json
git mv plugin/skills/ask-chord plugins/chord/skills/ask-chord
```

- [ ] **Step 2: Rewrite `plugins/chord/.claude-plugin/plugin.json`**

Replace its contents with:

```json
{
  "name": "chord",
  "version": "0.2.0",
  "description": "Ask Chord MCP server registration and the data-question workflow skill.",
  "author": { "name": "Chord Commerce" },
  "homepage": "https://github.com/chordcommerce/ask-chord"
}
```

- [ ] **Step 3: Confirm `.mcp.json` is unchanged and at plugin root**

`plugins/chord/.mcp.json` must read exactly:

```json
{
  "mcpServers": {
    "ask-chord": {
      "type": "streamable-http",
      "url": "https://mcp.chord.co/mcp"
    }
  }
}
```

- [ ] **Step 4: Validate the base plugin**

Run: `claude plugin validate plugins/chord && jq empty plugins/chord/.claude-plugin/plugin.json plugins/chord/.mcp.json`
Expected: validation passes (exit 0); no jq parse errors.

- [ ] **Step 5: Commit**

```bash
git add plugins/chord plugin
git commit -m "refactor: move chord base plugin into plugins/chord (MCP + ask-chord skill)"
```

---

### Task 2: Three feature plugins

**Files:**
- Move: `plugin/skills/activation-health/` → `plugins/chord-activation-health/skills/chord-activation-health/`
- Move: `plugin/skills/metric-verify/` → `plugins/chord-metric-verify/skills/chord-metric-verify/`
- Move: `plugin/skills/daily-insights/` → `plugins/chord-daily-insights/skills/chord-daily-insights/`
- Create: `plugins/chord-activation-health/.claude-plugin/plugin.json`
- Create: `plugins/chord-metric-verify/.claude-plugin/plugin.json`
- Create: `plugins/chord-daily-insights/.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: base plugin `chord` (Task 1) — named in `dependencies`.
- Produces: plugins `chord-activation-health`, `chord-metric-verify`, `chord-daily-insights` at `plugins/<name>/`. Marketplace (Task 3) sources each at `./plugins/<name>`.

- [ ] **Step 1: Move the three skills, renaming each skill dir to match its frontmatter name**

```bash
mkdir -p plugins/chord-activation-health/.claude-plugin plugins/chord-activation-health/skills
mkdir -p plugins/chord-metric-verify/.claude-plugin plugins/chord-metric-verify/skills
mkdir -p plugins/chord-daily-insights/.claude-plugin plugins/chord-daily-insights/skills
git mv plugin/skills/activation-health plugins/chord-activation-health/skills/chord-activation-health
git mv plugin/skills/metric-verify plugins/chord-metric-verify/skills/chord-metric-verify
git mv plugin/skills/daily-insights plugins/chord-daily-insights/skills/chord-daily-insights
```

- [ ] **Step 2: Create `plugins/chord-activation-health/.claude-plugin/plugin.json`**

```json
{
  "name": "chord-activation-health",
  "version": "0.2.0",
  "description": "Report the health of all audience syncs and destinations against your Chord warehouse.",
  "author": { "name": "Chord Commerce" },
  "homepage": "https://github.com/chordcommerce/ask-chord",
  "dependencies": ["chord"]
}
```

- [ ] **Step 3: Create `plugins/chord-metric-verify/.claude-plugin/plugin.json`**

```json
{
  "name": "chord-metric-verify",
  "version": "0.2.0",
  "description": "Verify a revenue, order-count, or LTV figure uses the correct basis before it ships.",
  "author": { "name": "Chord Commerce" },
  "homepage": "https://github.com/chordcommerce/ask-chord",
  "dependencies": ["chord"]
}
```

- [ ] **Step 4: Create `plugins/chord-daily-insights/.claude-plugin/plugin.json`**

```json
{
  "name": "chord-daily-insights",
  "version": "0.2.0",
  "description": "Nightly commerce-signals digest (revenue, ROAS, repeat/LTV, LTV/CAC, VIP slippage) posted to Slack.",
  "author": { "name": "Chord Commerce" },
  "homepage": "https://github.com/chordcommerce/ask-chord",
  "dependencies": ["chord", "chord-metric-verify"]
}
```

- [ ] **Step 5: Validate all three feature plugins**

Run:
```bash
for p in chord-activation-health chord-metric-verify chord-daily-insights; do
  claude plugin validate "plugins/$p" && jq empty "plugins/$p/.claude-plugin/plugin.json" || { echo "FAIL: $p"; break; }
done
```
Expected: each validates (exit 0), no jq errors, no `FAIL:` line.

- [ ] **Step 6: Confirm the old `plugin/` dir is gone**

Run: `test ! -e plugin && echo "plugin/ removed" || { echo "leftover:"; find plugin; }`
Expected: `plugin/ removed`. (If anything remains, `git mv` it into the right place or `git rm` it and note why.)

- [ ] **Step 7: Commit**

```bash
git add plugins plugin
git commit -m "refactor: split activation-health, metric-verify, daily-insights into dependent plugins"
```

---

### Task 3: Rewrite the marketplace manifest

**Files:**
- Modify (rewrite): `.claude-plugin/marketplace.json`

**Interfaces:**
- Consumes: plugin dirs `plugins/chord`, `plugins/chord-activation-health`, `plugins/chord-metric-verify`, `plugins/chord-daily-insights` (Tasks 1–2).
- Produces: marketplace `chord` listing all four plugins by relative source with no pinned versions.

- [ ] **Step 1: Replace `.claude-plugin/marketplace.json` contents**

```json
{
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

Note: the spec mentioned an optional `$schema` line; it is omitted here to avoid guessing a URL. Add it later only if a canonical schema URL is confirmed.

- [ ] **Step 2: Validate the marketplace manifest**

Run: `claude plugin validate .claude-plugin/marketplace.json && jq empty .claude-plugin/marketplace.json`
Expected: validation passes; no jq errors.

- [ ] **Step 3: Load the marketplace locally and confirm all four plugins list**

```bash
claude plugin marketplace add "$(pwd)" 2>&1 | tail -3
claude plugin marketplace list 2>&1 | grep -iE 'chord' | head -10
```
Expected: the marketplace adds without error and lists `chord`, `chord-activation-health`, `chord-metric-verify`, `chord-daily-insights`. (Clean up after: `claude plugin marketplace remove chord`.)

- [ ] **Step 4: Verify dependency resolution is understood by the CLI**

Run: `claude plugin validate plugins/chord-daily-insights --strict 2>&1 | tail -20`
Expected: no error about the `dependencies` field. Warnings about metadata/`$schema` are acceptable. If it errors that `chord`/`chord-metric-verify` are unresolvable, confirm the dependency names exactly match the base/feature plugin `name` fields.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat: list four chord plugins in the marketplace with relative sources"
```

---

### Task 4: Update `install.sh` skill path

**Files:**
- Modify: `install.sh:34` (`SKILL_REPO_PATH`)

**Interfaces:**
- Consumes: the moved skill at `plugins/chord/skills/ask-chord/SKILL.md` (Task 1).
- Produces: an installer that resolves the new skill location for both the local-clone and curl-piped paths.

- [ ] **Step 1: Update the skill path constant**

In `install.sh`, change line 34 from:
```bash
SKILL_REPO_PATH="plugin/skills/ask-chord/SKILL.md"
```
to:
```bash
SKILL_REPO_PATH="plugins/chord/skills/ask-chord/SKILL.md"
```

- [ ] **Step 2: Confirm no other `plugin/` path references remain in the script**

Run: `grep -n 'plugin/skills\|"plugin/\|/plugin/' install.sh || echo "no stale plugin/ refs"`
Expected: `no stale plugin/ refs` (the only path was line 34).

- [ ] **Step 3: Test the local-clone install path resolves the new file**

Run:
```bash
tmp="$(mktemp -d)"; ./install.sh --scope user 2>&1 | tee /dev/stderr | grep -q 'source: local' \
  && echo "OK: resolved local skill" || echo "CHECK: did not report local source"
# undo the user-scope install so we don't leave the skill behind
rm -f "$HOME/.claude/skills/ask-chord/SKILL.md"; rmdir "$HOME/.claude/skills/ask-chord" 2>/dev/null; rm -rf "$tmp"
```
Expected: `OK: resolved local skill` and the script prints `installed ask-chord (user scope)`. (The script reads `$SCRIPT_DIR/$SKILL_REPO_PATH`; a failure here means the path constant is wrong.)

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "fix: point install.sh at plugins/chord/skills/ask-chord/SKILL.md"
```

---

### Task 5: Update the README

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: the final layout, plugin names, and marketplace source repo (`chordcommerce/ask-chord`).
- Produces: user-facing docs covering the marketplace install, auto-update, migration, and corrected skill paths.

- [ ] **Step 1: Update every `plugin/skills/ask-chord/SKILL.md` reference to the new path**

Run to find them: `grep -n 'plugin/skills/ask-chord/SKILL.md' README.md`
Replace each `plugin/skills/ask-chord/SKILL.md` with `plugins/chord/skills/ask-chord/SKILL.md` (this affects the Option B copy step and the Claude Desktop download link — currently around lines 75 and 183). Verify none remain: `grep -c 'plugin/skills' README.md` → expect `0`.

- [ ] **Step 2: Add a "Marketplace (Claude Code)" section after the intro's Claude Code tip**

Insert this section near the top of the Claude Code area (before "Option A — One-liner"):

```markdown
## Install via the Chord marketplace (recommended)

Chord's plugins live in a public Claude Code marketplace. Add it once,
then install the plugins you want:

​```bash
# Add the marketplace (one time)
/plugin marketplace add chordcommerce/ask-chord

# Base plugin: registers the Ask Chord MCP server + the data-question skill
/plugin install chord@chord
​```

Optional add-on plugins (each pulls in `chord` automatically):

| Plugin | What it adds |
|---|---|
| `chord-activation-health@chord` | Audience-sync / destination health reporting |
| `chord-metric-verify@chord` | Revenue/order/LTV figure verification |
| `chord-daily-insights@chord` | Nightly commerce-signals digest to Slack (also pulls `chord-metric-verify`) |

​```bash
/plugin install chord-daily-insights@chord   # installs chord + chord-metric-verify too
​```

`chord-daily-insights` also needs a Slack MCP server connected in your
own environment to post the digest.
```

(Replace the `​` zero-width characters around the code fences with plain triple backticks when writing the file — they are only here to keep this plan's fences intact.)

- [ ] **Step 3: Add an "Auto-updating install" subsection**

Immediately after the marketplace section, add:

```markdown
### Keeping plugins up to date

Chord's marketplace entries are **version-unpinned**, so Claude Code
tracks the latest commit — every change we ship to `main` becomes an
available update. To pick updates up automatically, enable auto-update.

**For a team (recommended):** commit this to your repo's
`.claude/settings.json`. It auto-adds the marketplace and turns on
background refresh + plugin auto-update for everyone who trusts the repo:

​```json
{
  "extraKnownMarketplaces": {
    "chord": {
      "source": { "source": "github", "repo": "chordcommerce/ask-chord" },
      "autoUpdate": true
    }
  }
}
​```

**For an individual:** after installing, enable auto-update from the
`/plugin` menu, or refresh on demand with
`/plugin marketplace update chord` followed by `/reload-plugins`.
```

(Same zero-width-character caveat as Step 2.)

- [ ] **Step 4: Add a migration note for pre-split installs**

Add near the existing "Migrating from `chord-copilot`?" callout:

```markdown
> **Upgrading from the bundled `chord` plugin?** `chord` is now lean —
> it registers the MCP server and the core `ask-chord` skill only. The
> activation-health, metric-verify, and daily-insights skills are now
> separate plugins. Install any you use:
> `/plugin install chord-activation-health@chord`,
> `/plugin install chord-metric-verify@chord`,
> `/plugin install chord-daily-insights@chord`. If you rely on the
> nightly digest, install `chord-daily-insights` (it pulls `chord` and
> `chord-metric-verify` automatically) and keep your Slack MCP connected.
```

- [ ] **Step 5: Verify the README is internally consistent**

Run:
```bash
grep -c 'plugin/skills' README.md            # expect 0
grep -c 'chordcommerce/ask-chord' README.md  # expect >= 3 (raw URLs + marketplace add)
grep -n 'plugin install chord' README.md | head
```
Expected: no stale skill paths; the marketplace `add`/`install` commands and the four plugin names are present.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: marketplace install, auto-update, and split-migration guidance"
```

---

## Final verification (after all tasks)

- [ ] **All manifests validate:**
  ```bash
  claude plugin validate .claude-plugin/marketplace.json
  for p in chord chord-activation-health chord-metric-verify chord-daily-insights; do
    claude plugin validate "plugins/$p" || echo "FAIL $p"
  done
  ```
  Expected: all pass, no `FAIL` lines.

- [ ] **Marketplace lists four plugins:**
  ```bash
  claude plugin marketplace add "$(pwd)" && claude plugin marketplace list | grep -i chord
  claude plugin marketplace remove chord   # cleanup
  ```
  Expected: `chord`, `chord-activation-health`, `chord-metric-verify`, `chord-daily-insights` listed.

- [ ] **No leftover `plugin/` dir and history preserved:**
  ```bash
  test ! -e plugin && echo "clean" || find plugin
  git log --follow --oneline -1 -- plugins/chord/skills/ask-chord/SKILL.md
  ```
  Expected: `clean`, and the follow log shows pre-move history.

- [ ] **Push and update PR #5:**
  ```bash
  git push
  ```
  The implementation lands on the existing `marketplace-split-autoupdate` branch / PR #5.

## Self-Review notes

- **Spec coverage:** base+3-feature split (Tasks 1–2), shared MCP via base + `dependencies` (Tasks 1–2), marketplace rewrite with unpinned relative sources (Task 3), `install.sh` path (Task 4), README marketplace/auto-update/migration + path fixes (Task 5). `$schema` deliberately omitted (Task 3 Step 1 note). CI intentionally excluded per spec non-goals.
- **Placeholder scan:** every step carries concrete file contents or a runnable command; no TBD/TODO.
- **Type/name consistency:** plugin names (`chord`, `chord-activation-health`, `chord-metric-verify`, `chord-daily-insights`), the `dependencies` values, marketplace `source` paths, and skill dir names are identical across Tasks 1–5 and match the spec's table.
