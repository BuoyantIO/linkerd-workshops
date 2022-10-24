#!/bin/bash

set -e

# scriptdir is the directory this script lives in
scriptdir=$(cd $(dirname $0) ; pwd)

CLUSTER_NAME="$1"

if [ -z "$CLUSTER_NAME" ]; then CLUSTER_NAME="workshop"; fi

#@SHOW

# Delete any existing cluster with the same name...
kind delete cluster --name "$CLUSTER_NAME" || true

#@echo
# ...then create the new cluster!
kind create cluster --name "$CLUSTER_NAME" \
     --config ${scriptdir}/kind-config.yaml
