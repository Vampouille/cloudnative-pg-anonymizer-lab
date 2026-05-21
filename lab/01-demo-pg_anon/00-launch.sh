#!/bin/sh

echo -n "docker run -e POSTGRES_PASSWORD=pgpass --rm --name cluster -d -p 127.0.0.1:5432:5432 ghcr.io/camptocamp/postgres:18"
read
docker run -e POSTGRES_PASSWORD=pgpass --rm --name cluster -d -p 127.0.0.1:5432:5432 ghcr.io/camptocamp/postgres:18

export PGHOST=127.0.0.1
export PGPASSWORD=pgpass
export PGUSER=postgres

for sql in $(ls *.sql); do
  bat $sql
  read
  cat $sql | psql
done
