#!/usr/bin/env bash
# Check that the user has downloaded their kubeconfig
# by looking for a 200 response on kubeconfig.yaml in the users deployment logs.
ns="$1"
kubectl logs -n users deploy/users 2>/dev/null \
  | grep kubeconfig.yaml \
  | grep 200 \
  | grep -q "$ns"
