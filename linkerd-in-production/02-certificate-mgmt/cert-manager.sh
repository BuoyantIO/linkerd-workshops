#!/bin/bash

clear

set -e

# scriptdir is the directory this script lives in
scriptdir=$(cd $(dirname $0) ; pwd)
cd ${scriptdir}

# WORKDIR=/tmp/l5d-prod
# CA_DIR=${WORKDIR}/cert-manager

if kubectl get ns linkerd >/dev/null 2>&1; then \
    echo "Whoops! Presenter needs to cycle the cluster!" >&2 ;\
    exit 1 ;\
fi

#@SHOW

# In actual production, it's often a much better plan to automate certificate
# handling. We'll use cert-manager: it's a Kubernetes add-on whose purpose is
# automating certificate management.
#
# cert-manager can handle both bootstrapping identity and automagically
# rotating certificates, but in this workshop we'll only show the bootstrap
# step -- the automatic rotation is automatic once everything is set up.
#
# We start by using Helm to install cert-manager.
helm repo add jetstack https://charts.jetstack.io --force-update
#$ helm upgrade --install \
#     -n cert-manager --create-namespace \
#     cert-manager \
#     jetstack/cert-manager \
#     --set installCRDs=true \
#     --wait
#@noshow
helm upgrade --install \
    -n cert-manager --create-namespace \
    cert-manager \
    ${scriptdir}/cert-manager-v1.10.0.tgz \
    --set installCRDs=true \
    --wait

# Also install the JetStack 'trust' tool. More on this in a bit.
#$ helm upgrade --install \
#     -n cert-manager \
#     cert-manager-trust \
#     jetstack/cert-manager-trust \
#     --wait \
#     && echo "DONE!"
#@noshow
helm upgrade --install \
     -n cert-manager \
     cert-manager-trust \
     ${scriptdir}/cert-manager-trust-v0.2.0.tgz \
     --wait \
     && echo "DONE!"

#@wait
#@clear
# OK. Before messing with Linkerd we need to set up a few things using
# cert-manager:
#
# 1. We'll use cert-manager to create a self-signed root CA. (This is mostly
#    for workshop purposes: in many real-world scenarios, you'd already have
#    some established corporate CA and you'd use that instead.)
#@wait
#
# 2. We'll use that root CA to create and sign a trust anchor certificate,
#    signed by the root CA. This will stored in the cert-manager namespace,
#    in the linkerd-trust-anchor Secret.
#@wait
#
#   (It's important to note that Linkerd will not have access to anything in
#    the cert-manager namespace. In fact, nothing but cert-manager should be
#    able to access the cert-manager namespace -- set your RBAC accordingly!)
#@wait
#
# 3. We'll use that trust anchor to set up _another_ cert-manager CA, which
#    we'll use to sign our issuer certificate. The issuer certificate must be
#    stored in the linkerd namespace, in the linkerd-identity-issuer Secret.
#@wait
#
# 4. Finally, we'll use the cert-manager trust extension to copy the public
#    key for our trust anchor from the cert-manager namespace to the linkerd
#    namespace, so that Linkerd has access to it (in the ConfigMap named
#    linkerd-identity-trust-roots -- note ConfigMap, not Secret!).
#@wait
#
# Worth remembering: our trust anchor is _not_ self-signed any more - which
# means that cert-manager can handle rotating it! - and its private key is
# _never_ stored anywhere that Linkerd can see it.

#@wait
#@clear
# Here are the CRDs to set up the CA root.
#@wait
#@noshow
bat manifests/cert-manager-ca-root.yaml

#@clear
# Applying them tells cert-manager to create our CA root and get ready to
# issue our trust anchor.

kubectl apply -f manifests/cert-manager-ca-root.yaml
#@wait

#@echo
# Let's look at the CA root's Secret. This is deliberately set up in the
# cert-manager namespace so that other bits of the system don't have access
# to it.

kubectl describe secret -n cert-manager cert-manager-ca-root
#@wait

#@echo
# Just to prove that there's really a certificate in there, let's look
# at it with 'step certificate inspect'. The 'tls.crt' key that appeared
# in the output above has a value which is a base64-encoded certificate --
# which, yes, means that it's base64-encoded base64-encoded data. If we
# unwrap one layer of base64 encoding, we can feed that into 'step
# certificate inspect'.
#
# NOTE: there's also a 'ca.crt' key in there, but don't be fooled! This is
# NOT the thing to look at.

kubectl get secret -n cert-manager cert-manager-ca-root \
                   -o jsonpath='{ .data.tls\.crt }' \
  | base64 -d \
  | step certificate inspect -

#@wait
#@clear
# Next up, here are the CRDs to use that CA root to create our trust anchor.
#@wait
#@noshow
bat manifests/cert-manager-trust-anchor.yaml

#@clear
# Applying them tells cert-manager to create our CA root and get ready to
# issue our trust anchor.

kubectl apply -f manifests/cert-manager-trust-anchor.yaml
#@wait

#@echo
# Let's look at the trust anchor's Secret. Again, this lives in the
# cert-manager namespace _so that_ it's not visible from outside.

kubectl describe secret -n cert-manager linkerd-trust-anchor
#@wait

#@echo
# We can repeat the same trick with unwrapping tls.crt to inspect it,
# too. Note the 30-day duration.

kubectl get secret -n cert-manager linkerd-trust-anchor \
                   -o jsonpath='{ .data.tls\.crt }' \
  | base64 -d \
  | step certificate inspect -

#@wait

#@clear
# Onward. Set up the identity issuer as well and look at what we get with it.

# Again, here are the raw CRDs.
#@wait
#@noshow
bat manifests/cert-manager-identity-issuer.yaml

#@clear
# We'll apply those and then look at the resulting Secret.
kubectl apply -f manifests/cert-manager-identity-issuer.yaml

kubectl describe secret -n linkerd linkerd-identity-issuer

#@wait
#@echo
# One last look into the Secret itself. Note the duration, again.
kubectl get secret -n linkerd linkerd-identity-issuer \
                   -o jsonpath='{ .data.tls\.crt }' \
  | base64 -d \
  | step certificate inspect -

#@wait

#@clear

# Almost done. Finally, we'll use the Trust extension to copy the trust
# anchor's public key into the trust anchor bundle ConfigMap that Linkerd
# uses.
#
# Last time for the CRDs.

#@wait
#@noshow
bat manifests/ca-bundle.yaml

#@echo
# Apply them and then look at the resulting ConfigMap.
kubectl apply -f manifests/ca-bundle.yaml

kubectl get cm -n linkerd
#@wait

#@echo
# Note that this time we need to look at the 'ca-bundle.crt' key, not the
# 'tls.crt' key, and that there's no extra layer of base64'ing going on.
kubectl get cm -n linkerd linkerd-identity-trust-roots \
        -o jsonpath='{ .data.ca-bundle\.crt }' | \
        step certificate inspect -

#@clear
# When all is said and done, here's what you'll end up with.

kubectl get secrets -n cert-manager
#@wait
#@HIDE
# NAME                                       TYPE                                  DATA   AGE
# cert-manager-ca-root                       kubernetes.io/tls    3      4m27s
# linkerd-trust-anchor                       kubernetes.io/tls    3      3m59s
#@SHOW
#@echo
kubectl get secrets -n linkerd
#@wait
#@HIDE
# NAME                                 TYPE                                  DATA   AGE
# linkerd-identity-issuer            kubernetes.io/tls   3      4m19s

#@SHOW
#@echo
kubectl get cm -n linkerd
#@wait
#@HIDE
# NAME                           DATA   AGE
# linkerd-identity-trust-roots   1      4m37s
# linkerd-config                 2      4m6s

#@SHOW
#@clear
# And there you have it -- automated certificate bootstrapping. You can do
# a lot more things now, such as setting your expiry periods programatically,
# or pulling in certificates from your corporate PKI (maybe it's not
# cloud-native). This approach gives you more flexibility, although at the
# cost of at slightly lessening your security by keeping your trust anchor
# private key in-cluster.
#@wait
