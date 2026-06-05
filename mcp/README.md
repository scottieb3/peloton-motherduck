# Peloton MCP (via MotherDuck)

> **Placeholder** — this directory will hold the Model Context Protocol (MCP)
> setup that lets an AI assistant (e.g. Claude) query your Peloton workout data
> stored in MotherDuck. The real, sanitized config will be added here.

## Overview

The [pipeline](../pipeline) loads Peloton workouts into a MotherDuck database.
This MCP setup points the [MotherDuck MCP server](https://github.com/motherduckdb/mcp-server-motherduck)
at that same database so an assistant can run read queries against your data in
natural language.

## Setup (draft)

1. Install the MotherDuck MCP server (e.g. via `uvx mcp-server-motherduck`).
2. Copy `.mcp.example.json` to your client's MCP config and fill in:
   - `MOTHERDUCK_TOKEN` — your MotherDuck service token (never commit this).
   - `MOTHERDUCK_DATABASE` — the same database name used by the pipeline.
3. Restart your MCP client and confirm the `motherduck` server connects.

## Security notes

- Never commit real tokens or database names. Use the `${VARIABLE}` placeholders
  in `.mcp.example.json` and inject values via your client's environment.
- Prefer a read-scoped MotherDuck token for the MCP server if available.
