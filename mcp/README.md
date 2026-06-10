# Peloton Workout History MCP

Chat with your entire Peloton workout history in Claude Desktop. Ask questions like *"which instructors do I keep coming back to?"*, *"which bookmarked classes haven't I done in a year?"*, or *"what was my best output month last year?"* — and get real answers.

**Your credentials never leave your machine.**

---

## How it works

```
Peloton (private API) -> pipeline/ (sync + views) -> MotherDuck (your cloud DuckDB)
                                                            |
                              Claude Desktop  <--  MotherDuck MCP Server
```

1. The [`pipeline/`](../pipeline) sync loads your workout history into a MotherDuck database and creates flattened views (`peloton.workouts_v`, `peloton.bookmarked_options`).
2. MotherDuck's official MCP server connects Claude Desktop to that database.
3. Claude translates your natural-language questions into SQL and runs them against your data.

**No custom MCP server needed.** MotherDuck's `query` tool is sufficient — the natural language to SQL translation happens entirely inside Claude.

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| The data pipeline | — | Run [`../pipeline`](../pipeline) first so your MotherDuck database is populated. |
| `uv` | any | For running the MCP server (`uvx`). |
| Claude Desktop | latest | [Download here](https://claude.ai/download) |
| MotherDuck account | free tier | [Sign up](https://app.motherduck.com) |

**Install `uv`** (if you don't have it):
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh   # macOS / Linux
# or
winget install astral-sh.uv                         # Windows
```

---

## Setup

### Step 1 — Populate your database

Follow [`../pipeline/README.md`](../pipeline/README.md) to sync your Peloton history into MotherDuck. When it finishes you'll have, in your database:

- `peloton.workouts_raw` — raw JSON payloads
- `peloton.workouts_v` — one flattened row per workout
- `peloton.bookmarked_options` — repeatedly-taken classes still bookmarked

Note the database name you used (the pipeline's `MOTHERDUCK_DATABASE`, default `peloton_data`).

### Step 2 — Configure Claude Desktop

Open your Claude Desktop config:

- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
- **Shortcut:** Claude Desktop -> **Settings** -> **Developer** -> **Edit Config**

Add the MotherDuck server (see [`claude_desktop_config.example.json`](./claude_desktop_config.example.json)):

```json
{
  "mcpServers": {
    "motherduck": {
      "command": "uvx",
      "args": [
        "mcp-server-motherduck",
        "--db-path", "md:peloton_data",
        "--motherduck-token", "YOUR_MOTHERDUCK_TOKEN_HERE"
      ]
    }
  }
}
```

- Replace `YOUR_MOTHERDUCK_TOKEN_HERE` with your MotherDuck token (Settings -> Access Tokens at [app.motherduck.com](https://app.motherduck.com)).
- Change `md:peloton_data` if you used a different `MOTHERDUCK_DATABASE` in the pipeline.
- If you already have other MCP servers, add the `"motherduck"` block inside the existing `"mcpServers"` object — don't replace it.

> **Alternative — Remote MCP (no `uvx`):** Claude Desktop also supports MotherDuck's hosted MCP endpoint via **Settings** -> **Connectors** (OAuth). Simpler, but gives less control over which database is targeted.

### Step 3 — Give Claude the schema context

This is what makes Claude's answers accurate. In Claude Desktop, create (or open) a **Project**, click **Project Instructions**, and paste the contents of [`peloton_context.md`](./peloton_context.md). It describes the views and how to interpret fields like `joules` and `duration_seconds`.

### Step 4 — Restart and verify

Fully quit and relaunch Claude Desktop. Look for the tools icon in a new chat. Test it:

```
How many total workouts do I have?
```

Claude should call the `query` tool and return a count from `peloton.workouts_v`.

---

## Example questions

**Instructors & favorites:**
- "Which instructors do I work out with most?"
- "Which bookmarked classes do I take most often?"

**Gaps & rediscovery:**
- "Which bookmarked classes haven't I done in over a year?"
- "What disciplines have I neglected in the last 6 months?"

**Performance trends:**
- "How has my average cycling output (kJ) changed over the past year?"
- "What was my best output month?"

**Habits:**
- "Which day of the week do I work out most?"
- "How many workouts did I do each month this year?"

---

## Schema reference

See [`peloton_context.md`](./peloton_context.md) for the full schema. In short:

- **`peloton.workouts_v`** — flattened, one row per workout (instructor, discipline, title, output in joules, etc.).
- **`peloton.bookmarked_options`** — distinct classes you've repeated and kept bookmarked, with take counts and kJ stats.
- **`peloton.workouts_raw`** — raw JSON payloads; query directly only for fields not yet in the views.

---

## Troubleshooting

**Claude can't connect to MotherDuck**
- Fully quit Claude Desktop (Cmd+Q), then relaunch. Reloading the window isn't enough.
- Verify `uvx` is on your PATH: `uvx --version`.
- Confirm your MotherDuck token is valid at [app.motherduck.com](https://app.motherduck.com).

**`uvx` command not found**
- Re-install `uv`: `curl -LsSf https://astral.sh/uv/install.sh | sh`, then open a new terminal.

**Queries return no results**
- Ask Claude: *"What tables and views are available in my peloton schema?"*
- If it sees nothing, the `--db-path` database name probably doesn't match the one the pipeline wrote to.

**Tools icon doesn't appear**
- Open **Settings** -> **Developer** to check for config parse errors.
- Validate the JSON — a stray comma will silently break the config.

---

## Privacy and security

- **Token stays local.** Your MotherDuck token lives only in your Claude Desktop config on your machine. Never commit it — `.mcp.json` is gitignored; only the `*.example.json` is tracked.
- **Data lives in your MotherDuck account.** See MotherDuck's [privacy policy](https://motherduck.com/privacy-policy/).
- **Claude sees query results.** When you ask questions, Claude calls `query` and sees the returned rows, subject to Anthropic's [privacy policy](https://www.anthropic.com/privacy).
- **No third-party infrastructure.** The path is: your machine -> Peloton -> MotherDuck -> Claude. Nothing routes through a server controlled by this project.
