#!/bin/bash

clear

set -e

# scriptdir is the directory this script lives in
scriptdir=$(cd $(dirname $0) ; pwd)

WORKDIR=/tmp/l5d-prod
mkdir -p ${WORKDIR}

if [ $(kubectl get deploy -n linkerd-viz 2>/dev/null | wc -l) -lt 3 ]; then \
    echo "Whoops! Presenter needs to install everything else!" >&2 ;\
    exit 1 ;\
fi

#@SHOW

# We'll install the Emojivoto demo app into our cluster, just so
# we have something that can show that viz is working.
#$ curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/emojivoto.yml | \
#    linkerd inject - | kubectl apply -f -
#@noshow
linkerd inject ${scriptdir}/emojivoto.yaml | kubectl apply -f -
