#!/usr/bin/env bash
# Check that the "phone" column in the "people" table is masked for the "skynet" role
# (value must contain at least 4 asterisks).
ns="$1"
phone=$(kubectl cnpg psql prod -n "$ns" -- -h localhost --username skynet postgres -t -c \
  "SELECT phone FROM people LIMIT 1;" \
  2>/dev/null | tr -d ' ')
echo "$phone" | grep -qP '\*{4,}'
