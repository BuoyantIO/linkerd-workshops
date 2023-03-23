#!/bin/env bash

k3d cluster delete flagger &>/dev/null
k3d cluster create flagger -s 1 -p "8080:80@loadbalancer" -p "8443:443@loadbalancer"  --k3s-arg '--no-deploy=traefik@server:*;agents:*' > /dev/null 2>&1
kubectl ns default

linkerd install --crds | kubectl apply -f -

linkerd install | kubectl apply -f - && linkerd check

linkerd smi install | k apply -f -

linkerd viz install | kubectl apply -f - && linkerd check

helm repo add flagger https://flagger.app

kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml

helm upgrade -i flagger flagger/flagger \
--namespace=linkerd-viz \
--set crd.create=false \
--set meshProvider=linkerd \
--set metricsServer=http://prometheus.linkerd-viz:9090

# kubectl apply -k https://github.com/fluxcd/flagger//kustomize/tester?ref=main

