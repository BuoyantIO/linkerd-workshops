#!/bin/bash

set -e

CLUSTER_NAME="$1"

if [ -z "$CLUSTER_NAME" ]; then CLUSTER_NAME="workshop"; fi

#@SHOW

# Delete any existing cluster with the same name...
civo k8s delete "$CLUSTER_NAME" --yes || true
#@echo
# ...then create the new cluster!
civo k8s create "$CLUSTER_NAME" \
    --nodes=3 \
    --remove-applications Traefik-v2-nodeport \
    --yes --save --wait
