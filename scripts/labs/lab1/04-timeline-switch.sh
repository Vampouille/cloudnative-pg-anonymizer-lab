#!/usr/bin/env bash
# If the "prod" cluster uses a custom image catalog (Lab 2+), Lab 1 is done: exit 0.
# Otherwise, check that the timeline has switched (status.timelineID > 1),
# which means a failover was triggered during Lab 1.
ns="$1"
val=$(kubectl get cluster prod -n "$ns" \
  -o jsonpath='{.spec.imageCatalogRef.name}' 2>/dev/null || true)
[[ -n "$val" ]] && exit 0

timeline=$(kubectl get cluster prod -n "$ns" \
  -o jsonpath='{.status.timelineID}' 2>/dev/null || true)
[[ -n "$timeline" && "$timeline" -gt 1 ]]
