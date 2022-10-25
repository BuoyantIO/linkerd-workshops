#!/bin/bash

clear

set -e

# scriptdir is the directory this script lives in
scriptdir=$(cd $(dirname $0) ; pwd)

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

# It's common to use the "linkerd" CLI to install Linkerd. This works
# great, as long as you're careful about how you do it. Here's a typical
# command line that you might use to install Linkerd from the command line,
# keeping our cert-manager setup:
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
# Instead, we'll use Helm, but keeping our cert-manager cert setup. This is
# fairly straightforward, but is helpful when the time comes for upgrades,
# etc.
# 
# We start by using Helm to install the Linkerd CRDs. This is a manual step
# because of changes in how Helm 3 handles CRDs.

#$ helm install linkerd-crds linkerd/linkerd-crds -n linkerd
#@noshow
helm install linkerd-crds -n linkerd ${scriptdir}/linkerd-crds-1.4.0.tgz

# Once that's done, we can install Linkerd itself, referencing cert-manager's
# "external" CA.
# 
# Note that we do _not_ create the linkerd namespace here: it was created
# earlier when we set up cert-manager.

#$ helm install linkerd-control-plane --namespace linkerd \
#    --set identity.externalCA=true \
#    --set identity.issuer.scheme=kubernetes.io/tls \
#    linkerd/linkerd-control-plane
#@noshow
helm install linkerd-control-plane --namespace linkerd \
  --set identity.externalCA=true \
  --set identity.issuer.scheme=kubernetes.io/tls \
  ${scriptdir}/linkerd-control-plane-1.9.4.tgz

#@wait
#@clear
# Once that's done, check to make sure all's well.
linkerd check
