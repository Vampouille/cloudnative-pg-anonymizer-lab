#!/usr/bin/env bash
# Check that the "prod" cluster exists in the user namespace.
ns="$1"
kubectl get cluster prod -n "$ns" &>/dev/null
