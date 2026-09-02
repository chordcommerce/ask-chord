# Ask Chord

Ask Chord (formerly Chord Copilot) is a hosted MCP server that lets
Claude answer data questions against **your** Chord warehouse — schema
lookup, saved views, canonical SQL pairs, and `execute_sql`, all behind
OAuth.

This repo is the **Chord plugin marketplace** for connecting Claude
(Code or Desktop) to Ask Chord. The server itself runs on Chord-managed
infrastructure.

> **Migrating from `chord-copilot`?** This repo was renamed from
> `chordcommerce/chord-copilot` — GitHub redirects the old git and raw
> URLs, so existing installs keep working. To move to the new name,
> reinstall from the marketplace (`/plugin install ask-chord@chord`,
> steps below). In Claude Code, if you registered the server manually
> under the old name, also re-register it as `ask-chord`
> (`claude mcp remove chord-copilot`, then the `claude mcp add` command
> below).

> **Upgrading from the bundled `chord` plugin?** The base plugin was
> renamed from `chord` to `ask-chord` (reinstall with
> `/plugin install ask-chord@chord`) and is now lean — it registers the
> MCP server and the core `ask-chord` skill only. The activation-health,
> metric-verify, and daily-insights skills are now separate plugins.
> Install any you use:
> `/plugin install chord-activation-health@chord`,
> `/plugin install chord-metric-verify@chord`,
> `/plugin install chord-daily-insights@chord`. If you rely on the
> nightly digest, install `chord-daily-insights` (it pulls `ask-chord`
> and `chord-metric-verify` automatically) and keep your Slack MCP
> connected.

## Before you start

Ask Chord is reachable at a single global endpoint:

```
https://mcp.chord.co/mcp
```

There's no per-customer URL — the same endpoint serves every tenant, and
the server routes each request to the right warehouse based on your
authenticated Chord account. The examples below all use this URL as-is.

On first connection, you'll be redirected to a browser to complete OAuth
sign-in with your Chord account. The token is cached for subsequent
sessions.

---

## Claude Code

The recommended path is the **Chord marketplace**: add it once, then
install the plugins you want. Each plugin registers the Ask Chord MCP
server and installs the matching skill together — no per-customer URL to
fill in.

### What is a marketplace?

A plugin marketplace is just a Git repo (this one) with a manifest that
lists installable plugins. Adding a marketplace tells Claude Code where
to find Chord's plugins; installing a plugin from it registers the MCP
server and skill in one step. Marketplaces are a **Claude Code** feature
— Claude Desktop can't add them (see the Claude Desktop section for its
setup).

### Install via the Chord marketplace

```bash
# Add the marketplace (one time)
/plugin marketplace add chordcommerce/ask-chord

# Base plugin: registers the Ask Chord MCP server + the data-question skill
/plugin install ask-chord@chord
```

`/plugin marketplace add` takes a GitHub `owner/repo` (as above), a full
Git URL, or a local path. Manage marketplaces with
`/plugin marketplace list`, `/plugin marketplace update chord`, and
`/plugin marketplace remove chord`.

Optional add-on plugins (each pulls in `ask-chord` automatically):

| Plugin | What it adds |
|---|---|
| `chord-activation-health@chord` | Audience-sync / destination health reporting |
| `chord-metric-verify@chord` | Revenue/order/LTV figure verification |
| `chord-daily-insights@chord` | Nightly commerce-signals digest to Slack (also pulls `chord-metric-verify`) |

```bash
/plugin install chord-daily-insights@chord   # installs ask-chord + chord-metric-verify too
```

`chord-daily-insights` also needs a Slack MCP server connected in your
own environment to post the digest.

### Keeping plugins up to date

Chord's marketplace entries are **version-unpinned**, so Claude Code
tracks the latest commit — every change we ship to `main` becomes an
available update. To pick updates up automatically, enable auto-update.

**For a team (recommended):** commit this to your repo's
`.claude/settings.json`. It auto-adds the marketplace and turns on
background refresh + plugin auto-update for everyone who trusts the repo:

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

**For an individual:** after installing, enable auto-update from the
`/plugin` menu, or refresh on demand with
`/plugin marketplace update chord` followed by `/reload-plugins`.

### Manual setup (without the marketplace)

If you'd rather not use plugins, set the two pieces up by hand.

1. **Register the MCP server** so Claude Code can talk to Ask Chord:

   ```bash
   claude mcp add ask-chord \
     --transport http \
     --scope user \
     https://mcp.chord.co/mcp
   ```

2. **Install the skill** so Claude knows the retrieval-grounded workflow
   for using it: copy
   [`plugins/ask-chord/skills/ask-chord/SKILL.md`](plugins/ask-chord/skills/ask-chord/SKILL.md)
   into `~/.claude/skills/ask-chord/SKILL.md` (create the directory if
   needed).

Restart Claude Code. On first use, a browser tab opens for OAuth
sign-in.

### Scope: user vs. project

The `claude mcp add` example above uses `--scope user`, which makes the
server available in every Claude Code session. To scope it to a single
repo instead, run the command from inside that repo with
`--scope project` — it writes to `.claude/settings.json` in the project
root, which you can commit so teammates pick it up automatically.

### Verifying

```bash
claude mcp list   # ask-chord should show as connected
```

Then ask Claude *"How many orders did we have last month?"* — the
`ask-chord:ask-chord` skill should auto-trigger and walk through
`search_schema` → `search_saved_views` / `search_sql_pairs` →
`search_instructions` → draft SQL → `execute_sql`.

---

## Claude Desktop

Claude Desktop doesn't support plugin marketplaces, so there's no
one-step install — you connect the MCP server and upload the skill
separately.

There are two ways to add the server. The connector UI is faster but
only available on paid plans; the config-file path works on any plan but
needs a stdio bridge.

### Option A — Custom connector (Pro / Team / Enterprise)

Available on paid Claude plans only. The UI talks the
`streamable-http` protocol natively, so there's no shim or config file
to manage.

1. Open **Settings → Connectors → Add custom connector**.
2. Fill in:
   - **Name:** `Ask Chord`
   - **Remote MCP server URL:** `https://mcp.chord.co/mcp`
3. Save. Claude Desktop opens a browser tab for OAuth sign-in on first use.

### Option B — Edit config file (any plan)

Claude Desktop's config file only speaks stdio, so the remote endpoint
has to be bridged through the [`mcp-remote`](https://www.npmjs.com/package/mcp-remote)
npm package. (Adding a bare `url` field to the JSON config triggers a
known bug where Claude Desktop silently drops the entire `mcpServers`
block on next launch — don't.)

Open **Settings → Developer → Edit Config** (or directly:
`~/Library/Application Support/Claude/claude_desktop_config.json` on
macOS, `%APPDATA%\Claude\claude_desktop_config.json` on Windows) and
add:

```json
{
  "mcpServers": {
    "ask-chord": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://mcp.chord.co/mcp"
      ]
    }
  }
}
```

If you already have other servers under `mcpServers`, merge the
`ask-chord` entry into the existing block — don't replace it.

On first launch, `mcp-remote` opens a browser tab for OAuth sign-in and
caches the token under `~/.mcp-auth/` for future sessions.

### Restart

Full quit and reopen — closing the window is not enough. Use `Cmd+Q`
on macOS, or exit from the system tray on Windows.

If the server doesn't appear, check the MCP log:

- **macOS:** `~/Library/Logs/Claude/mcp.log`
- **Windows:** `%APPDATA%\Claude\logs\mcp.log`

### Skill in Claude Desktop

Claude Desktop doesn't auto-load `~/.claude/skills/` the way Claude
Code does, but it has its own skill upload UI:

1. Download [`plugins/ask-chord/skills/ask-chord/SKILL.md`](plugins/ask-chord/skills/ask-chord/SKILL.md)
   from this repo.
2. In Claude Desktop, open **Customize → Skill**, click the **+** icon,
   and choose **Upload**.
3. Select the `SKILL.md` you just downloaded.

The skill will then auto-trigger on data questions, the same way it
does in Claude Code.

---

## Other MCP clients

Any client that supports remote `streamable-http` MCP servers can
connect directly to `https://mcp.chord.co/mcp`.
Clients that only speak stdio (like Claude Desktop's config file) need
the `mcp-remote` shim shown above.

## Troubleshooting

- **`claude mcp list` shows the server but tools don't appear** — the
  OAuth token may have expired. In Claude Code, run
  `claude mcp remove ask-chord && claude mcp add ...` again. In
  Claude Desktop, delete `~/.mcp-auth/` and restart.
- **Can't reach the server** — confirm `https://mcp.chord.co/mcp` is
  reachable from a browser; you should land on a Chord-branded sign-in
  page. If sign-in succeeds but you see no data, you may not have a
  warehouse provisioned yet — check with your Chord contact.
- **Skill doesn't auto-trigger in Claude Code** — confirm `SKILL.md`
  lives at `~/.claude/skills/ask-chord/SKILL.md` and restart the
  Claude Code session.

## Developing this repo

The marketplace manifest (`.claude-plugin/marketplace.json`) and each
plugin manifest (`plugins/*/.claude-plugin/plugin.json`) are validated in
CI on every pull request. To check them locally before pushing:

```bash
./scripts/validate.sh
```

It runs `claude plugin validate --strict` against the marketplace and
every plugin (discovered from `plugins/*/`), and exits non-zero if any
manifest is invalid. Requires the Claude Code CLI
(`npm install -g @anthropic-ai/claude-code`).

## License

MIT. See [LICENSE](LICENSE).
