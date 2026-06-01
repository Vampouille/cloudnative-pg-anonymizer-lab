#!/usr/bin/env bash
# If the "prod" cluster uses a custom image catalog (Lab 2+), Lab 1 is done: exit 0.
# Otherwise, check that the "prod" cluster is in healthy state.
ns="$1"
val=$(kubectl get cluster prod -n "$ns" \
  -o jsonpath='{.spec.imageCatalogRef.name}' 2>/dev/null || true)
[[ -n "$val" ]] && exit 0

phase=$(kubectl get cluster prod -n "$ns" \
  -o jsonpath='{.status.phase}' 2>/dev/null || true)
[[ "$phase" == "Cluster in healthy state" ]]
