#!/bin/bash

clear

set -e

# scriptdir is the directory this script lives in
scriptdir=$(cd $(dirname $0) ; pwd)

WORKDIR=/tmp/l5d-prod
mkdir -p ${WORKDIR}

if [ $(kubectl get deploy -n linkerd 2>/dev/null | wc -l) -lt 3 ]; then \
    echo "Whoops! Presenter needs to install everything else!" >&2 ;\
    exit 1 ;\
fi

#@SHOW

# linkerd viz provides visualization and debugging tools for a 
# cluster. It ships with the standard distribution of the Linkerd
# CLI, but it is not installed by default. We'll install it now.
#
# Much like with Linkerd itself, you can install viz either from
# the CLI or with Helm. Here's how you would do it from the CLI:

#$ linkerd viz install | kubectl apply -f -
#@wait
#@echo
# We'll actually do the installation with Helm, though, since we've
# done everything else with Helm so far.
#$ helm install linkerd-viz \
#    --namespace linkerd-viz --create-namespace \
#    linkerd/linkerd-viz
#@noshow
helm install linkerd-viz \
  --namespace linkerd-viz --create-namespace \
  ${scriptdir}/linkerd-viz-30.3.4.tgz

#@echo
# Once that's done, we'll use linkerd viz check to make sure that
# everything is OK with viz.

linkerd viz check
