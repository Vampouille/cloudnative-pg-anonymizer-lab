#!/usr/bin/env bash
# Check that masking rules are defined on people.lastname and people.phone.
ns="$1"
count=$(kubectl cnpg psql prod -n "$ns" -- -t -c \
  "SELECT COUNT(*) FROM pg_seclabel s
   JOIN pg_attribute a ON s.objoid = a.attrelid AND s.objsubid = a.attnum
   JOIN pg_class c ON c.oid = a.attrelid
   WHERE c.relname = 'people' AND s.provider = 'anon'
     AND a.attname IN ('lastname', 'phone');" \
  2>/dev/null | tr -d ' ')
[[ "$count" == "2" ]]
