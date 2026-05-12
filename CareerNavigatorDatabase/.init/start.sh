#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/career-navigator-23819-23867/CareerNavigatorDatabase"
DATADIR="$WORKSPACE/pgdata"
PORT=$(cat "$WORKSPACE/.pg_port" 2>/dev/null || echo 5432)
# Ensure datadir exists
mkdir -p "$DATADIR"

# Ensure app role/database exist (idempotent) if scaffolded entrypoint is present.
if [[ -f "$WORKSPACE/pg-setup-entrypoint.sh" ]]; then
  POSTGRES_USER="${POSTGRES_USER:-appuser}" \
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-apppassword}" \
  POSTGRES_DB="${POSTGRES_DB:-appdb}" \
  bash "$WORKSPACE/pg-setup-entrypoint.sh"
fi

# Start postgres cluster using pg_ctl as postgres user, wait for start.
sudo -u postgres pg_ctl -D "$DATADIR" -o "-p $PORT -c config_file=$DATADIR/postgresql.conf -c hba_file=$DATADIR/pg_hba.conf" -w start

# Apply schema + seed (idempotent). This keeps downstream containers (backend) simple.
if [[ -f "$WORKSPACE/.init/apply_schema_and_seed.sh" ]]; then
  bash "$WORKSPACE/.init/apply_schema_and_seed.sh"
fi
