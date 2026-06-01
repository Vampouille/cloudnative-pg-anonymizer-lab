#!/usr/bin/env bash
# Check that the "people" table exists in the "postgres" database of the "prod" cluster.
ns="$1"
kubectl cnpg psql prod -n "$ns" -- -c \
  "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'people';" \
  2>/dev/null | grep -q "1"
