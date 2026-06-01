#!/usr/bin/env bash
# Check that the "prod" cluster references the camptocamp ClusterImageCatalog.
ns="$1"
apiGroup=$(kubectl get cluster prod -n "$ns" \
  -o jsonpath='{.spec.imageCatalogRef.apiGroup}' 2>/dev/null || true)
kind=$(kubectl get cluster prod -n "$ns" \
  -o jsonpath='{.spec.imageCatalogRef.kind}' 2>/dev/null || true)
name=$(kubectl get cluster prod -n "$ns" \
  -o jsonpath='{.spec.imageCatalogRef.name}' 2>/dev/null || true)
[[ "$apiGroup" == "postgresql.cnpg.io" && "$kind" == "ClusterImageCatalog" && "$name" == "camptocamp" ]]
