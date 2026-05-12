# CareerNavigatorDatabase (PostgreSQL)

This container provides the PostgreSQL schema + seed data for the Career Navigator MVP.

## What’s included

- `schema.sql`: MVP schema (users, persona/documents, skills/evidence, assessments, career paths, roadmaps, dashboard phase state, marketplace) + dashboard aggregate views.
- `seed.sql`: Minimal seed dataset for questionnaire + marketplace + canonical skills/career paths.
- `apply.sh`: Starts Postgres (if needed) and applies `schema.sql` + `seed.sql` (idempotent).

## Local usage (dev)

The workspace scaffolding scripts (under `.init/`) set up a local Postgres cluster under `pgdata/` and persist the port in `.pg_port`.

1) Start Postgres:
```bash
bash .init/start.sh
```

2) Bootstrap role/db (if needed) + apply schema and seed:
```bash
bash ./apply.sh
```

3) Healthcheck:
```bash
bash ./healthcheck.sh
```

4) Stop Postgres:
```bash
bash .init/stop.sh
```

## Connection details (for backend)

Backend should connect using:

- Host: `127.0.0.1`
- Port: value in `.pg_port` (defaults to `5432` in scaffold; repo `.env` exposes `PORT=5001` only for preview routing)
- Database: `${POSTGRES_DB:-appdb}`
- User: `${POSTGRES_USER:-appuser}`
- Password: `${POSTGRES_PASSWORD:-apppassword}`

### Dashboard aggregate helpers (views)

- `v_user_task_stats`
- `v_user_evidence_stats`
- `v_user_skill_stats`
