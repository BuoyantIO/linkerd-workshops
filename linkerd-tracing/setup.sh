#!/bin/env bash
set -e

## Create Cluster
k3d cluster delete tracing > /dev/null 2>&1 || true
k3d cluster create tracing --k3s-arg '--no-deploy=traefik@server:*;agents:*' --wait > /dev/null 2>&1
clear

## Prep Linkerd
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f - && linkerd check
linkerd jaeger install | kubectl apply -f - && linkerd check
linkerd viz install | kubectl apply -f - && linkerd check

## Install Nginx
kubectl apply -f manifests/nginx.yaml
linkerd check --proxy -n ingress-nginx

## Inject Emojivoto
linkerd inject manifests/emojivoto.yaml | kubectl apply -f -
linkerd check --proxy -n emojivoto

## Create ingress
kubectl apply -f manifests/ingress.yaml
