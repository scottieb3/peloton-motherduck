# peloton-motherduck

Sync your Peloton workout history into [MotherDuck](https://motherduck.com), then
query it conversationally through the Model Context Protocol (MCP).

This monorepo has two parts:

| Folder | What it does |
| --- | --- |
| [`pipeline/`](pipeline) | Fetches Peloton workouts (with auto token refresh) and upserts them into a MotherDuck database. Runs locally or daily via GitHub Actions. |
| [`mcp/`](mcp) | Points the MotherDuck MCP server at that database so an AI assistant can query your data. *(Setup in progress.)* |

See [`docs/architecture.md`](docs/architecture.md) for how the pieces fit together.

## Quick start

```bash
cd pipeline
pip install -r requirements.txt
cp .env.example .env          # fill in your tokens and database name
python peloton_pipeline.py
```

Full pipeline docs: [`pipeline/README.md`](pipeline/README.md).

## Configuration

All secrets are supplied via environment variables / GitHub Secrets — nothing
sensitive is committed. See each subproject's `.env.example` / `.mcp.example.json`.

## Disclaimer

This project is **not affiliated with, endorsed by, or sponsored by Peloton
Interactive, Inc.** It uses Peloton's unofficial/private API and is intended for
**personal use** with your own account. Use responsibly and at your own risk;
respect Peloton's Terms of Service.

## License

[MIT](LICENSE) © scottieb3
