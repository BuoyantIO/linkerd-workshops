#!/bin/bash
k3d cluster delete rollouts &>/dev/null
k3d cluster create rollouts -s 1 -p "8080:80@loadbalancer" -p "8443:443@loadbalancer"  --k3s-arg '--disable=traefik@server:*' > /dev/null 2>&1
kubectl ns default

linkerd install --crds | kubectl apply -f -

linkerd install | kubectl apply -f - && linkerd check

linkerd viz install | kubectl apply -f - && linkerd check

kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl apply -k https://github.com/argoproj/argo-rollouts/manifests/crds\?ref\=stable

kubectl apply -k manifests/
kubectl rollout restart deploy -n argo-rollouts