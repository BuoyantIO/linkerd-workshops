#!/bin/bash

set -e

CLUSTER_NAME="$1"

if [ -z "${CLUSTER_NAME}" ]; then \
    echo "Usage: $0 <cluster-name>" >&2 ;\
    exit 1 ;\
fi

#@SHOW

# Delete any existing cluster with the same name...
civo k8s delete "${CLUSTER_NAME}" --yes || true
#@echo
# ...then create the new cluster!
civo k8s create "${CLUSTER_NAME}" \
    --nodes=3 \
    --remove-applications Traefik-v2-nodeport \
    --yes --save --wait

civo k8s config "${CLUSTER_NAME}" > ${KUBECONFIG}
