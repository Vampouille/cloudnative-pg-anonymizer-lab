#!/usr/bin/env bash
# Check that the "prod" cluster references a ClusterImageCatalog (Lab 2 requirement).
ns="$1"
val=$(kubectl get cluster prod -n "$ns" \
  -o jsonpath='{.spec.imageCatalogRef.name}' 2>/dev/null || true)
[[ -n "$val" ]]