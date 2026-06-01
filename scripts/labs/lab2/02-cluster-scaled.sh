#!/usr/bin/env bash
# Check that the "prod" cluster has more than 1 instance (spec.instances > 1).
ns="$1"
instances=$(kubectl get cluster prod -n "$ns" \
  -o jsonpath='{.spec.instances}' 2>/dev/null || true)
[[ -n "$instances" && "$instances" -gt 1 ]]
