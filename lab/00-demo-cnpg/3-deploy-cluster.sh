#!/bin/sh

kubectl create namespace demo
kubectl apply -n demo -f 2-app1-cluster.yaml

# alias cnpg_status="watch --color kubectl  cnpg status --color always"
