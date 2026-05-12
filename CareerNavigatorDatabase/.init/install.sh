#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/career-navigator-23819-23867/CareerNavigatorDatabase"
export DEBIAN_FRONTEND=noninteractive
MISSING=0
for cmd in psql pg_dump pg_restore; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "MISSING: $cmd"
    MISSING=1
  fi
done
if [ "$MISSING" -eq 1 ]; then
  echo "Installing postgresql-client packages (prints apt output)..."
  sudo apt-get update -q && sudo apt-get install -y postgresql-client postgresql-contrib
fi
psql --version
pg_dump --version
pg_restore --version
