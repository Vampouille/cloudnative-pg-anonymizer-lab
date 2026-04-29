#!/bin/bash
kubectl cnpg install generate | kubectl apply --server-side --force-conflicts -f -

# Barman plugin
kubectl apply -f https://github.com/cloudnative-pg/plugin-barman-cloud/releases/download/v0.12.0/manifest.yaml