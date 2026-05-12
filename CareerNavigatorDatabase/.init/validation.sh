#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/career-navigator-23819-23867/CareerNavigatorDatabase"
DATADIR="$WORKSPACE/pgdata"
PORT=$(cat "$WORKSPACE/.pg_port" 2>/dev/null || echo 5432)
HEALTH="$WORKSPACE/healthcheck.sh"
# start
sudo -u postgres pg_ctl -D "$DATADIR" -o "-p $PORT -c config_file=$DATADIR/postgresql.conf -c hba_file=$DATADIR/pg_hba.conf" -w start
OUT=$(bash "$HEALTH" || true)
if [ "${OUT}" != "READY" ]; then echo "Validation healthcheck failed: $OUT" >&2; sudo -u postgres pg_ctl -D "$DATADIR" -m fast -w stop; exit 4; fi
sudo -u postgres pg_ctl -D "$DATADIR" -m fast -w stop
ls -la "$WORKSPACE" | sed -n '1,200p'
echo READY
