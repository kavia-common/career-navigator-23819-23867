#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/career-navigator-23819-23867/CareerNavigatorDatabase"
DATADIR="$WORKSPACE/pgdata"; ENTRY="$WORKSPACE/pg-setup-entrypoint.sh"; SCHEMA="$WORKSPACE/schema.sql"; HEALTH="$WORKSPACE/healthcheck.sh"; README="$WORKSPACE/README.md"
# check postgres tools
for b in initdb pg_ctl psql pg_dump pg_restore; do command -v "$b" >/dev/null 2>&1 || { echo "ERROR: $b not found" >&2; exit 2; }; done
# ensure postgres system user exists
if ! id -u postgres >/dev/null 2>&1; then echo "ERROR: postgres system user missing" >&2; exit 2; fi
sudo mkdir -p "$DATADIR" && sudo chown -R postgres:postgres "$DATADIR" && sudo chmod 0700 "$DATADIR"
# initdb if needed
if ! sudo -u postgres test -f "$DATADIR/PG_VERSION"; then sudo -u postgres initdb -D "$DATADIR" >/dev/null; fi
# pick port
PORT=5432
python3 - <<'PY' || true
import socket,sys
s=socket.socket();
try:
 s.bind(('127.0.0.1',5432)); s.close(); sys.exit(0)
except Exception:
 sys.exit(1)
PY
if [ $? -ne 0 ]; then PORT=5433; fi
# write minimal configs
sudo -u postgres bash -c "cat > '$DATADIR/postgresql.conf' <<EOF
# Dev config - do not use in production
port = $PORT
listen_addresses = '127.0.0.1'
unix_socket_directories = '$DATADIR'
max_connections = 50
shared_buffers = '16MB'
logging_collector = off
EOF"
sudo -u postgres bash -c "cat > '$DATADIR/pg_hba.conf' <<EOF
# Dev HBA: local sockets = trust (dev-only), TCP connections = md5
local   all             all                                     trust
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
EOF"
sudo chown postgres:postgres "$DATADIR/postgresql.conf" "$DATADIR/pg_hba.conf" && sudo chmod 0640 "$DATADIR/postgresql.conf" "$DATADIR/pg_hba.conf"
# create idempotent bootstrap entrypoint
sudo -u postgres bash -c "cat > '$ENTRY' <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
PGDATA='__EMBED_PGDATA__'
PORT='__EMBED_PORT__'
PGUSER="${POSTGRES_USER:-appuser}"
PGPASS="${POSTGRES_PASSWORD:-apppassword}"
PGDB="${POSTGRES_DB:-appdb}"
export PGDATA
sudo -u postgres pg_ctl -D \"$PGDATA\" -o \"-p $PORT -c config_file=$PGDATA/postgresql.conf -c hba_file=$PGDATA/pg_hba.conf\" -w start
sudo -u postgres psql -v ON_ERROR_STOP=1 --username=postgres <<SQL
DO $$ BEGIN
IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '"' || $PGUSER || '"') THEN
  EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', $PGUSER, $PGPASS);
END IF;
IF NOT EXISTS (SELECT FROM pg_database WHERE datname = $PGDB) THEN
  EXECUTE format('CREATE DATABASE %I OWNER %I', $PGDB, $PGUSER);
END IF;
END$$;
SQL
sudo -u postgres pg_ctl -D \"$PGDATA\" -m fast -w stop
BASH
"
sudo sed -i "s|__EMBED_PGDATA__|$DATADIR|g; s|__EMBED_PORT__|$PORT|g" "$ENTRY"
sudo chmod +x "$ENTRY" && sudo chown postgres:postgres "$ENTRY"
# schema
cat >"$SCHEMA" <<'SQL'
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT now()
);
SQL
sudo chown postgres:postgres "$SCHEMA" || true
# healthcheck
cat >"$HEALTH" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="$WORKSPACE"
PORT=$(cat "$WORKSPACE/.pg_port" 2>/dev/null || echo 5432)
PGUSER=${POSTGRES_USER:-appuser}
PGPASS=${POSTGRES_PASSWORD:-apppassword}
PGDB=${POSTGRES_DB:-appdb}
PGPASSWORD="$PGPASS" psql -h 127.0.0.1 -p "$PORT" -U "$PGUSER" -d "$PGDB" -t -A -c 'SELECT 1' >/dev/null && echo READY || (echo FAIL && exit 1)
SH
sudo chmod +x "$HEALTH" && sudo chown postgres:postgres "$HEALTH"
# README and persist port
cat >"$README" <<'MD'
Dev PostgreSQL workspace (dev-only):
- PGDATA: workspace/pgdata
- Bootstrap: ./pg-setup-entrypoint.sh (use POSTGRES_USER/POSTGRES_PASSWORD/POSTGRES_DB env)
- Healthcheck: ./healthcheck.sh (prints READY)
Defaults (insecure): POSTGRES_USER=appuser, POSTGRES_PASSWORD=apppassword, POSTGRES_DB=appdb
MD
echo "$PORT" > "$WORKSPACE/.pg_port" && sudo chown postgres:postgres "$WORKSPACE/.pg_port"
