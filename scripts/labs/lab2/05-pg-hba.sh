#!/usr/bin/env bash
# Check that the "prod" cluster has the expected pg_hba rules.
ns="$1"
hba=$(kubectl get cluster prod -n "$ns" \
  -o jsonpath='{.spec.postgresql.pg_hba}' 2>/dev/null || true)
echo "$hba" | grep -q "host all all all trust" && \
echo "$hba" | grep -q "host replication all all trust"

