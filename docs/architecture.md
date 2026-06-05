# Architecture

How the two halves of this repo fit together.

```
                +---------------------+
                |   Peloton API       |
                | (unofficial/private)|
                +----------+----------+
                           |
            OAuth refresh + paginated fetch
                           |
                           v
                +----------------------+
                |  pipeline/           |
                |  peloton_pipeline.py |
                |  + token_exchange    |
                +----------+-----------+
                           |
                  upsert workouts_raw
                           |
                           v
                +----------------------+
                |   MotherDuck         |
                |   <MOTHERDUCK_DB>    |
                |   peloton.workouts_raw
                +----------+-----------+
                           |
                  read queries (SQL)
                           |
                           v
                +----------------------+
                |  mcp/                |
                |  MotherDuck MCP svr  |
                +----------+-----------+
                           |
                           v
                +----------------------+
                |  AI assistant (MCP)  |
                |  e.g. Claude         |
                +----------------------+
```

## Flow

1. **Ingest** — `pipeline/` authenticates to Peloton (auto-refreshing the OAuth
   token), pulls new workouts since the latest stored `start_time`, enriches them
   with workout/ride details, and upserts into `peloton.workouts_raw` in MotherDuck.
2. **Schedule** — GitHub Actions runs the pipeline daily and persists the rotated
   refresh token back to repository secrets.
3. **Query** — the MotherDuck MCP server (in `mcp/`) connects to the same database,
   letting an AI assistant answer questions over your workout data in natural language.

## Configuration boundary

Nothing personal is hardcoded. The database name, tokens, and client ID are all
injected via environment variables (`.env` locally, GitHub Secrets in CI) or via
the MCP client's environment.
