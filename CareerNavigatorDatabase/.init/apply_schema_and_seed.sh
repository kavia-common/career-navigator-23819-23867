#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/home/kavia/workspace/code-generation/career-navigator-23819-23867/CareerNavigatorDatabase"
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

# Apply schema then seed.
PGPASSWORD="${PGPASS}" psql -h 127.0.0.1 -p "${PORT}" -U "${PGUSER}" -d "${PGDB}" -v ON_ERROR_STOP=1 -f "${SCHEMA}"
PGPASSWORD="${PGPASS}" psql -h 127.0.0.1 -p "${PORT}" -U "${PGUSER}" -d "${PGDB}" -v ON_ERROR_STOP=1 -f "${SEED}"

echo "APPLIED"
