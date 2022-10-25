#!/bin/bash

clear

set -e

# scriptdir is the directory this script lives in
scriptdir=$(cd $(dirname $0) ; pwd)

WORKDIR=/tmp/l5d-prod
mkdir -p ${WORKDIR}

if ! kubectl get ns linkerd >/dev/null 2>&1; then \
    echo "Whoops! Presenter needs to set up cert-manager!" >&2 ;\
    exit 1 ;\
fi

if ! kubectl get clusterissuer >/dev/null 2>&1; then \
    echo "Whoops! Presenter needs to set up cert-manager!" >&2 ;\
    exit 1 ;\
fi

if [ $(kubectl get deploy -n linkerd 2>/dev/null | wc -l) -gt 0 ]; then \
    echo "Whoops! Presenter needs to cycle the cluster!" >&2 ;\
    exit 1 ;\
fi

#@SHOW

# Linkerd's high-availability mode ("HA mode") removes the potential for
# Linkerd itself to be a single point of failure, by switching it to run
# with three replicas rather than one. Note that HA Mode REQUIRES at
# least three Nodes: the Pod anti-affinity rules will not allow all the
# replicas to run on a single Node.
#@wait
#@echo
# We're going to use Helm to install Linkerd in high-availability mode,
# but first here's how you can do this from the command line, by literally
# sticking "--ha" on the linkerd install command line:#
#
# First, install the Linkerd CRDs:
#$ linkerd install --crds | kubectl apply -f -
#@echo
# Once that's done, install the rest of Linkerd:
#$ linkerd install \
#    --identity-external-issuer \
#    --set identity.externalCA=true \
#    | kubectl apply -f -
#@wait
#@clear
# Using Helm, but keeping our cert-manager cert setup, can be a bit more
# helpful when the time comes for upgrades, etc.
# 
# We start by using Helm to pull a local copy of the linkerd-control-plane
# chart, untarring it so that we have access to its values-ha.yaml file.
# We'll use this file to override the various things that need to be changed
# for HA mode.
#
# We'll do this in ${WORKDIR}.
helm repo add linkerd https://helm.linkerd.io/stable

cd ${WORKDIR}
#@noshow
rm -rf linkerd-control-plane
#$ helm fetch --untar linkerd/linkerd-control-plane && echo "Fetched!"
#@noshow
tar xzf ${scriptdir}/linkerd-control-plane-1.9.4.tgz && echo "Fetched!"

#@wait
#@echo
# This is what the values-ha.yaml file looks like:
less linkerd-control-plane/values-ha.yaml

#@clear
# Given that, we next use Helm to install the Linkerd CRDs. This is a manual
# step because of changes in how Helm 3 handles CRDs.

#$ helm install linkerd-crds linkerd/linkerd-crds -n linkerd
#@noshow
helm install linkerd-crds -n linkerd ${scriptdir}/linkerd-crds-1.4.0.tgz

#@wait
#@echo
# Once that's done, we can go ahead and install Linkerd in HA mode, using that
# values-ha.yaml. 
# 
# Note that we do _not_ create the linkerd namespace here: it was created
# earlier when we set up cert-manager.

#$ helm install linkerd-control-plane --namespace linkerd \
#    --set identity.externalCA=true \
#    --set identity.issuer.scheme=kubernetes.io/tls \
#    -f linkerd-control-plane/values-ha.yaml \
#    linkerd/linkerd-control-plane
#@noshow
helm install linkerd-control-plane --namespace linkerd \
  --set identity.externalCA=true \
  --set identity.issuer.scheme=kubernetes.io/tls \
  -f linkerd-control-plane/values-ha.yaml \
  ${scriptdir}/linkerd-control-plane-1.9.4.tgz

#@wait
#@clear
# Finally, once that's done, check to make sure all's well.
linkerd check
#@wait
#@echo
# We can also check to make sure that we have all the replicas of the
# various pods that we should.
kubectl get pods -n linkerd

