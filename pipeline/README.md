# Peloton Data Pipeline

A robust data pipeline that fetches your Peloton workout history and syncs it to a MotherDuck database.

## Features

- **Auto-Authentication**: Automatically manages the OAuth token lifecycle (refreshing when expired).
- **Incremental Sync**: Queries the destination database to only fetch new workouts.
- **Data Enrichment**: Fetches detailed metrics and ride metadata for each workout.
- **GitHub Actions Support**: Includes a workflow for daily automated runs.

## Configuration

All configuration is via environment variables (a local `.env` file is supported):

| Variable | Required | Description |
| --- | --- | --- |
| `MOTHERDUCK_TOKEN` | yes | MotherDuck service token. |
| `MOTHERDUCK_DATABASE` | no | Destination database name (default: `peloton_data`). |
| `PELOTON_CLIENT_ID` | yes | Peloton OAuth client ID used for the refresh-token exchange. |
| `PELOTON_TOKENS_FILE` | no | Path to the tokens file (default: `peloton_tokens.json`). |

## Setup

### Local Development

1. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Configuration**:
   - Copy `.env.example` to `.env` and fill in your values.
   - Provide a `peloton_tokens.json` in this directory (generated via initial login).
     See `peloton_tokens.example.json` for the expected shape.

   > **Note**: Running locally rotates the Peloton refresh token, which invalidates the token stored in GitHub Secrets. After a local run, update the GitHub secret with your refreshed token:
   > ```bash
   > gh secret set PELOTON_TOKENS_JSON --repo <owner>/<repo> < peloton_tokens.json
   > ```

3. **Run**:
   ```bash
   python peloton_pipeline.py
   ```

### GitHub Actions Deployment

1. **Repository secrets** (Settings -> Secrets and variables -> Actions):
   - `MOTHERDUCK_TOKEN`: Your MotherDuck service token.
   - `MOTHERDUCK_DATABASE`: Destination database name.
   - `PELOTON_CLIENT_ID`: Peloton OAuth client ID.
   - `PELOTON_TOKENS_JSON`: The **content** of your local `peloton_tokens.json` file.
   - `GH_PAT`: A GitHub Personal Access Token (classic) with `repo` scope, so the workflow can update `PELOTON_TOKENS_JSON` after each run to persist rotated refresh tokens.

2. **Workflow**:
   Runs daily at 6:00 AM UTC via `.github/workflows/peloton_pipeline.yml`. After each run, it updates the `PELOTON_TOKENS_JSON` secret with the refreshed tokens so the next run has a valid refresh token.

## Data model

Workouts are upserted into `peloton.workouts_raw`:

| Column | Type | Notes |
| --- | --- | --- |
| `workout_id` | VARCHAR | Primary key. |
| `start_time` | TIMESTAMP | Workout start. |
| `payload` | JSON | Full enriched workout payload. |
| `fetched_at` | TIMESTAMP | When the row was last synced. |

### Transform views

After each sync, the pipeline applies `sql/transform.sql` (idempotent
`CREATE OR REPLACE VIEW`) to expose query-friendly views over the raw JSON:

| View | Description |
| --- | --- |
| `peloton.workouts_v` | One flattened row per workout (instructor, discipline, title, output in joules, etc.). |
| `peloton.bookmarked_options` | Distinct classes you've repeated and kept bookmarked, with take counts and kJ stats. |

These are plain views, so they always reflect the latest data — no refresh step
needed. They're what the [MCP setup](../mcp) queries.
