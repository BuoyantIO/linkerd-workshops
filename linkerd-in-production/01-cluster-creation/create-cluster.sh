#!/bin/bash

set -e

# scriptdir is the directory this script lives in
scriptdir=$(cd $(dirname $0) ; pwd)

# rootdir is our parent directory
rootdir=$(cd ${scriptdir}/.. ; pwd)

WORKDIR=/tmp/l5d-prod
rm -rf ${WORKDIR}
mkdir -p ${WORKDIR}

KUBECONFIG=${WORKDIR}/kubeconfig.yaml

CLUSTER_TYPE="$1"
test -n "$CLUSTER_TYPE"

CLUSTER_NAME="${CLUSTER_NAME:-workshop}"

if [ -z "$CLUSTER_TYPE" ]; then \
    echo "Usage: $0 <cluster-type>" >&2 ;\
    exit 1 ;\
fi

if [ ! -f "${scriptdir}/${CLUSTER_TYPE}/create.sh" ]; then \
    echo "Error: cluster type $CLUSTER_TYPE not supported" >&2 ;\
    exit 1 ;\
fi

clear

$SHELL ${scriptdir}/check.sh

#@print
#@print "# We've set WORKDIR=${WORKDIR}; all our various files will be written there."
#@print "# To start with, we're putting our KUBECONFIG in ${KUBECONFIG}."
#@print ""
#@SHOW
#@wait
#@HIDE

$SHELL ${scriptdir}/${CLUSTER_TYPE}/create.sh "$CLUSTER_NAME"
