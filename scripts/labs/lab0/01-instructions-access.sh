#!/usr/bin/env bash
# Check for access to userX.campto.camp 401 or 200
ns="$1"

kubectl logs -n traefik deploy/traefik 2> /dev/null \
  | grep -E '(200|401)' \
  | grep websecure-users-users-${ns}-instructions-${ns}-campto-camp@kubernetes