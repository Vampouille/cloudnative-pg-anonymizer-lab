#!/usr/bin/env bash
# Check that the "prod" cluster has postgresUID and postgresGID set to 999.
ns="$1"
uid=$(kubectl get cluster prod -n "$ns" \
  -o jsonpath='{.spec.postgresUID}' 2>/dev/null || true)
gid=$(kubectl get cluster prod -n "$ns" \
  -o jsonpath='{.spec.postgresGID}' 2>/dev/null || true)
[[ "$uid" == "999" && "$gid" == "999" ]]

