#!/bin/bash

set -e

WORKDIR=/tmp/l5d-prod
CA_DIR=${WORKDIR}/manual-certs

clear

#@SHOW

# We'll start by manually creating the certificates that Linkerd needs, to
# make it clear how things fit together. We'll store all the information we
# need for this in the ${CA_DIR} directory.

rm -rf ${CA_DIR}
mkdir -p ${CA_DIR}

#@clear

# STEP 1: Create a self-signed trust anchor
#
# Linkerd needs a trust anchor and an issuer, which should be different.
# The trust anchor must sign the issuer certificate.
#
# We'll start with creating the trust anchor.

#@wait
#@echo
# Step arguments for a self-signed CA:
#   root.linkerd.cluster.local: name for the Subject
#   ${CA_DIR}/anchor.crt: where to save the certificate
#   ${CA_DIR}/anchor.key: where to save its private key
#   --profile root-ca: self-signed certificate for use as a CA root
#   --no-password --insecure: don't require a password to use the cert
#   --not-after: expiration time, either a duration or an RFC3339 time string
#
# We'll do this with a 1-year expiration time (8760 hours).

#@rm -rf ${CA_DIR}/anchor.crt ${CA_DIR}/anchor.key
step certificate create root.linkerd.cluster.local \
     ${CA_DIR}/anchor.crt ${CA_DIR}/anchor.key \
     --profile root-ca \
     --no-password --insecure \
     --not-after="8760h"

#@echo
# Once the root CA certificate is created, we can examine it with
# "step certificate inspect".

step certificate inspect ${CA_DIR}/anchor.crt | less

#@clear

# STEP 2: Create an issuer cert signed by the trust anchor.
#
# Remember, the trust anchor must sign the issuer certificate; it cannot be
# self-signed. It's also a good practice for it to have a shorter expiration time
# than the trust anchor, because its private key must live in the cluster.
#
# Step arguments for an issuer certificate:
#   identity.linkerd.cluster.local: name for the Subject
#   ${CA_DIR}/issuer.crt: where to save the certificate
#   ${CA_DIR}/issuer.key: where to save its private key
#   --profile intermediate-ca: this cert is signed by another, and will be used to sign more!
#   --no-password --insecure: don't require a password to use the cert
#   --ca ${CA_DIR}/anchor.crt: cert to use to sign this one
#   --ca-key ${CA_DIR}/anchor.key: private key for --ca certificate
#   --not-after: expiration time, either a duration or an RFC3339 time string
#
# We're doing this with a two-week expiration time (336 hours).

#@rm -rf ${CA_DIR}/identity.crt ${CA_DIR}/identity.key
step certificate create identity.linkerd.cluster.local \
     ${CA_DIR}/identity.crt ${CA_DIR}/identity.key \
     --profile intermediate-ca --no-password --insecure \
     --ca ${CA_DIR}/anchor.crt --ca-key ${CA_DIR}/anchor.key \
     --not-after='336h'

#@echo
# If we inspect this, the major differences are around the Issuer and the
# path length constraint.
step certificate inspect ${CA_DIR}/identity.crt | less

#@clear
# Next, we'll install Linkerd, using these certs. First, we install Linkerd's
# CRDs.
linkerd install --crds | kubectl apply -f -

#@echo
# After installing the CRDs, we install Linkerd proper. Look carefully at the
# options here: we DO NOT provide the private half of the trust anchor. This is
# because, in this manual world, it's ONLY used to verify identity.
linkerd install \
  --identity-trust-anchors-file ${CA_DIR}/anchor.crt \
  --identity-issuer-certificate-file ${CA_DIR}/identity.crt \
  --identity-issuer-key-file ${CA_DIR}/identity.key \
  | kubectl apply -f -

#@echo
# After that, we'll use 'linkerd check' to make sure that all is well (this
# will check all the certificates as part of its work).

linkerd check
