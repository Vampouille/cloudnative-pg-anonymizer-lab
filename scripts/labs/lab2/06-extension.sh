#!/usr/bin/env bash
# Check that the "anon" extension is installed on the "postgres" database
# of the "prod" cluster in the user namespace.
ns="$1"
kubectl cnpg psql prod -n "$ns" -- -c \
  "SELECT extname FROM pg_extension WHERE extname = 'anon';" 2>/dev/null \
  | grep -q "anon"

