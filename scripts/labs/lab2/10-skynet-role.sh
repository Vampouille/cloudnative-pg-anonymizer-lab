#!/usr/bin/env bash
# Check that the "skynet" role exists and is marked as MASKED by anon.
ns="$1"
kubectl cnpg psql --tty=false prod -n "$ns" -- -t -c \
  "SELECT * FROM pg_seclabels WHERE objtype = 'role' AND provider = 'anon' AND label = 'MASKED'" \
  2>/dev/null | grep -q "MASKED"
