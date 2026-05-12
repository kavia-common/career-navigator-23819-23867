#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/career-navigator-23819-23867/CareerNavigatorDatabase"
DATADIR="$WORKSPACE/pgdata"
ENTRY="$WORKSPACE/pg-setup-entrypoint.sh"
SCHEMA="$WORKSPACE/schema.sql"
HEALTH="$WORKSPACE/healthcheck.sh"
PORT=$(cat "$WORKSPACE/.pg_port" 2>/dev/null || echo 5432)
# verify clients
for cmd in psql pg_dump pg_restore; do command -v "$cmd" >/dev/null || { echo "Missing $cmd in PATH" >&2; exit 2; }; done
psql --version && pg_dump --version && pg_restore --version
PGUSER=${POSTGRES_USER:-appuser}
PGPASS=${POSTGRES_PASSWORD:-apppassword}
PGDB=${POSTGRES_DB:-appdb}
# ensure scaffold artifacts exist
[ -f "$ENTRY" ] || { echo "Missing entrypoint: $ENTRY" >&2; exit 2; }
[ -f "$SCHEMA" ] || { echo "Missing schema: $SCHEMA" >&2; exit 2; }
[ -f "$HEALTH" ] || { echo "Missing healthcheck: $HEALTH" >&2; exit 2; }
# bootstrap (idempotent)
POSTGRES_USER="$PGUSER" POSTGRES_PASSWORD="$PGPASS" POSTGRES_DB="$PGDB" bash "$ENTRY"
# start cluster
sudo -u postgres pg_ctl -D "$DATADIR" -o "-p $PORT -c config_file=$DATADIR/postgresql.conf -c hba_file=$DATADIR/pg_hba.conf" -w start
# apply schema
PGPASSWORD="$PGPASS" psql -h 127.0.0.1 -p "$PORT" -U "$PGUSER" -d "$PGDB" -v ON_ERROR_STOP=1 -f "$SCHEMA"
# healthcheck
if ! bash "$HEALTH" | grep -q '^READY$'; then echo "Healthcheck failed" >&2; sudo -u postgres pg_ctl -D "$DATADIR" -m fast -w stop; exit 3; fi
# dump and restore
DUMP_CF="$WORKSPACE/test_dump.fc"
PGPASSWORD="$PGPASS" pg_dump -h 127.0.0.1 -p "$PORT" -U "$PGUSER" -d "$PGDB" -Fc -f "$DUMP_CF"
sudo -u postgres psql -h 127.0.0.1 -p "$PORT" --username=postgres -c "DROP DATABASE IF EXISTS test_restore; CREATE DATABASE test_restore;"
PGPASSWORD="$PGPASS" pg_restore -h 127.0.0.1 -p "$PORT" -U "$PGUSER" -d test_restore "$DUMP_CF"
PGPASSWORD="$PGPASS" psql -h 127.0.0.1 -p "$PORT" -U "$PGUSER" -d test_restore -c "SELECT count(*) FROM users;"
# stop cluster
sudo -u postgres pg_ctl -D "$DATADIR" -m fast -w stop
echo READY
