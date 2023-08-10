#!/bin/env bash

k3d cluster delete flagger &>/dev/null
k3d cluster create flagger -s 1 -p "8080:80@loadbalancer" -p "8443:443@loadbalancer"  --k3s-arg '--disable=traefik@server:*' > /dev/null 2>&1
kubectl ns default

linkerd install --crds | kubectl apply -f -

linkerd install | kubectl apply -f - && linkerd check

helm repo add l5d-smi https://linkerd.github.io/linkerd-smi

helm repo up

helm install linkerd-smi l5d-smi/linkerd-smi -n linkerd-smi --create-namespace

linkerd viz install | kubectl apply -f - && linkerd check

helm repo add flagger https://flagger.app

kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml

helm upgrade -i flagger flagger/flagger \
--namespace=linkerd-viz \
--set crd.create=false \
--set meshProvider=linkerd \
--set metricsServer=http://prometheus.linkerd-viz:9090 \
--set linkerdAuthPolicy.create=true

