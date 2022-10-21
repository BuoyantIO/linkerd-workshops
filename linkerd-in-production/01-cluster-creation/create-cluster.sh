#!/bin/bash

set -e

CLUSTER_TYPE="$1"
test -n "$CLUSTER_TYPE"

CLUSTER_NAME="${CLUSTER_NAME:-workshop}"

KUBECONFIG=$(pwd)/.kubeconfig

if [ -z "$CLUSTER_TYPE" ]; then \
    echo "Usage: $0 <cluster-type>" >&2 ;\
    exit 1 ;\
fi

if [ ! -x "create-${CLUSTER_TYPE}.sh" ]; then \
    echo "Error: cluster type $CLUSTER_TYPE not supported" >&2 ;\
    exit 1 ;\
fi

clear

$SHELL check.sh

$SHELL create-"$CLUSTER_TYPE".sh "$CLUSTER_NAME"

$SHELL setup-cluster.sh
