#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/career-navigator-23819-23867/CareerNavigatorDatabase"
DATADIR="$WORKSPACE/pgdata"
PORT=$(cat "$WORKSPACE/.pg_port" 2>/dev/null || echo 5432)
# Ensure datadir exists
mkdir -p "$DATADIR"
# Start postgres cluster using pg_ctl as postgres user, wait for start
sudo -u postgres pg_ctl -D "$DATADIR" -o "-p $PORT -c config_file=$DATADIR/postgresql.conf -c hba_file=$DATADIR/pg_hba.conf" -w start
