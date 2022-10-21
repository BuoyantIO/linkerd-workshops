#!/bin/bash

set -x

CLUSTER_NAME="$1"

if [ -z "$CLUSTER_NAME" ]; then CLUSTER_NAME="workshop"; fi

#@SHOW

# Delete any existing cluster with the same name...
k3d cluster delete "$CLUSTER_NAME" || true

#@echo
# ...then create the new cluster!
k3d cluster create "$CLUSTER_NAME" \
    --servers=3 \
    --k3s-arg "--disable=traefik@server:0" >&2
