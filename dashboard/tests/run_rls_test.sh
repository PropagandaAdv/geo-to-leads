#!/usr/bin/env bash
# Esegue schema + test RLS su un PostgreSQL temporaneo. Uso: sudo tests/run_rls_test.sh  (richiede binari PostgreSQL 15+)
set -euo pipefail
PGBIN=${PGBIN:-/usr/lib/postgresql/16/bin}; D=$(mktemp -d /tmp/pgtest.XXXX); chown postgres "$D"; HERE=$(cd "$(dirname "$0")" && pwd)
trap 'su postgres -c "$PGBIN/pg_ctl -D $D/data stop -m immediate >/dev/null 2>&1" || true; rm -rf "$D"' EXIT
su postgres -c "$PGBIN/initdb -D $D/data -A trust >/dev/null && $PGBIN/pg_ctl -D $D/data -o '-p 54330 -k $D' -l $D/log -w start >/dev/null"
P="$PGBIN/psql -h $D -p 54330 -U postgres -q -v ON_ERROR_STOP=1"
su postgres -c "$P -c 'create database t'"
for f in tests/supabase_stub.sql schema.sql tests/rls_test.sql; do su postgres -c "$P -d t -f $HERE/../${f#tests/}" 2>/dev/null || su postgres -c "$P -d t -f $HERE/$(basename $f)"; done 2>&1 | grep -E "ok:|FALL|ERROR|SUPERATI"
