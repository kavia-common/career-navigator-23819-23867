#!/usr/bin/env bash
set -euo pipefail

# Apply schema and seed data to the workspace PostgreSQL instance.
# This script is intended to be non-interactive and safe to re-run.

WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATADIR="${WORKSPACE}/pgdata"

PORT="$(cat "${WORKSPACE}/.pg_port" 2>/dev/null || echo 5432)"
PGUSER="${POSTGRES_USER:-appuser}"
PGPASS="${POSTGRES_PASSWORD:-apppassword}"
PGDB="${POSTGRES_DB:-appdb}"

SCHEMA="${WORKSPACE}/schema.sql"
SEED="${WORKSPACE}/seed.sql"

if [[ ! -f "${SCHEMA}" ]]; then
  echo "Missing schema.sql at ${SCHEMA}" >&2
  exit 2
fi
if [[ ! -f "${SEED}" ]]; then
  echo "Missing seed.sql at ${SEED}" >&2
  exit 2
fi

# Ensure role+db exist (idempotent) using the scaffolded entrypoint if present
if [[ -f "${WORKSPACE}/pg-setup-entrypoint.sh" ]]; then
  POSTGRES_USER="${PGUSER}" POSTGRES_PASSWORD="${PGPASS}" POSTGRES_DB="${PGDB}" bash "${WORKSPACE}/pg-setup-entrypoint.sh"
fi

# Start server (no-op if already running; pg_ctl will error -> ignore and continue)
mkdir -p "${DATADIR}"
sudo -u postgres pg_ctl -D "${DATADIR}" -o "-p ${PORT} -c config_file=${DATADIR}/postgresql.conf -c hba_file=${DATADIR}/pg_hba.conf" -w start || true

# Apply schema + seed
PGPASSWORD="${PGPASS}" psql -h 127.0.0.1 -p "${PORT}" -U "${PGUSER}" -d "${PGDB}" -v ON_ERROR_STOP=1 -f "${SCHEMA}"
PGPASSWORD="${PGPASS}" psql -h 127.0.0.1 -p "${PORT}" -U "${PGUSER}" -d "${PGDB}" -v ON_ERROR_STOP=1 -f "${SEED}"

echo "APPLIED"
