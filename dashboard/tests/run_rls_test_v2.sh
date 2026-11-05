#!/usr/bin/env bash
# Esegue schema v1 + test, poi schema v2 + test v2 su un PostgreSQL temporaneo. Uso: sudo tests/run_rls_test_v2.sh
set -euo pipefail
PGBIN=${PGBIN:-/usr/lib/postgresql/16/bin}; D=$(mktemp -d /tmp/pgtest.XXXX); chown postgres "$D"; HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(dirname "$HERE")
trap 'su postgres -c "$PGBIN/pg_ctl -D $D/data stop -m immediate >/dev/null 2>&1" || true; rm -rf "$D"' EXIT
su postgres -c "$PGBIN/initdb -D $D/data -A trust >/dev/null && $PGBIN/pg_ctl -D $D/data -o '-p 54331 -k $D' -l $D/log -w start >/dev/null"
P="$PGBIN/psql -h $D -p 54331 -U postgres -q -v ON_ERROR_STOP=1"
su postgres -c "$P -c 'create database t'"
for f in "$HERE/supabase_stub.sql" "$ROOT/schema.sql" "$HERE/rls_test.sql" "$ROOT/schema_v2.sql" "$HERE/rls_test_v2.sql"; do
  chmod a+r "$f"; su postgres -c "$P -d t -f $f" 2>&1
done | grep -E "ok:|FALL|ERROR|SUPERATI|error"
