# Care and feeding for your shiny new Mesh

## Pre Reqs

## Outline

* Rotating certs
* Checking resource usage
* Collecting logs
* Oh Metrics where art thou?
* Upgarding and Rollback

## Steps

### Certificate Rotation in Linkerd

Linkerd uses a 3 tiered certificate model. A root CA provides the basis for trust in, and across, clusters. Each cluster should have a unique intermediary CA that the control plane uses to issue individual workload certificates. Each workload, and by extension each pod, gets a certificate that allows it to communicate securely and establish it's identity.

#### Checking Certificates

At the beginning of this workshop you should have created some certificates, if you didn't please go back to the section on certificate management before continuing. The first operational task we'll introduce you to is checking on the health of your certificates.

The simplest way to check on your certificates is to check on your Linkerd install.

```bash
# Use the Linkerd cli to check on your cluster

linkerd check

## This will output details about the health of your cluster. 
## Linkerd check can also output information as a json doc so
## you can consume the results programatically.
```

#### Rotating the Issuer

Linkerd's intermediary certificate is referred to as the issuer as it is used to issue individual workload certificates. It's important that you rotate the issuer before it expires in order to avoid an outage. You can find the docs for rotating and expired issuer [here](https://linkerd.io/2.12/tasks/replacing_expired_certificates/).

We'll be following [the instructions](https://linkerd.io/2.12/tasks/manually-rotating-control-plane-tls-credentials/#rotating-the-identity-issuer-certificate) for manually rotating the issuer. If you're using a tool like cert-manager to manage the issuer the rotation process is fully automatic.

```bash
# Rotate the Issuer

## Check the state of your environment

linkerd check --proxy

### This will give you details about your existing
### proxies and the issuer service.

## Generate a new issuer certificate

step certificate create identity.linkerd.cluster.local \
  issuer-new.crt issuer-new.key \
  --profile intermediate-ca --not-after 8760h --no-password --insecure \
  --ca ca.crt --ca-key ca.key

### This will output a new issuer certificate for your
### cluster.

## Rotate the issuer

### We'll be using the linkerd cli for
### the upgrade operation. Alternatively,
### feel free to use the helm cli to
### upgrade linkerd and add the new issuer.

linkerd upgrade \
    --identity-issuer-certificate-file=./issuer-new.crt \
    --identity-issuer-key-file=./issuer-new.key \
    | kubectl apply -f -

## Look for an Issuer Updated event

kubectl get events --field-selector reason=IssuerUpdated -n linkerd

### This will confirm that Linkerd has seen 
### new certificate and is ready to start
### issuing new certs.

## Roll your workload pods

### You will need to roll your workload 
### pods.

kubectl -n emojivoto rollout restart deploy

### This will force the pods to pick up new 
### workload certificates. You can validate 
### that with the following command

linkerd check --proxy

```

#### Rotating the Root CA

The root CA, or trust anchor, is an important component of your Linkerd environment. Typically you will not store your root CA inside your k8s cluster.

The basic process of rotating the trust anchor involves the following steps:

* Generate a new trust root
* Bundle the new trust root with the old root
* Deploy your new bundle to your cluster
* Roll your workloads
* Wait for all workloads to have an updated certificate
* Rotate the issuer certificate
* Remove the old trust anchor
* Roll your workloads
* Wait for all workloads to have an updated certificate

```bash
# Rotating the root CA

## Step 0: Save your old trust root

kubectl -n linkerd get cm linkerd-identity-trust-roots -o=jsonpath='{.data.ca-bundle\.crt}' > original-trust-anchors.crt

## Step 1: Generate a new root CA

step certificate create root.linkerd.cluster.local ca-new.crt ca-new.key --profile root-ca --no-password --insecure

## Step 3: Bundle your root CAs

step certificate bundle ca-new.crt original-trust.crt bundle.crt

### Ensure you're using the correct trust roots
### If you skipped step 0 it will be ca.crt

## Step 4: Deploy your new bundle to Linkerd

linkerd upgrade --identity-trust-anchors-file=./bundle.crt | kubectl apply -f -

### You can also use helm to handle the upgrade

## Step 5: Roll your workloads

kubectl -n emojivoto rollout restart deploy

linkerd check --proxy

### You my need to wait a few minutes for
### all your proxies to get updated. Please be 
### sure you've updated the proxy for all 
### your workloads.

## Step 6: Rotate the issuer

### Please follow the steps from the issuer rotation section above.
### You can read more about the steps 
### required here:
### https://linkerd.io/2.12/tasks/manually-rotating-control-plane-tls-credentials/#rotating-the-identity-issuer-certificate

## Step 7: Remove the old root CA

linkerd upgrade  --identity-trust-anchors-file=./ca-new.crt  | kubectl apply -f -

### Alternatively please feel free to use
### helm instead of the linkerd cli

## Step 8: Roll your workloads

kubectl -n emojivoto rollout restart deploy
linkerd check --proxy
```

### Collecting Proxy Logs

An important part of debugging Linkerd involves setting proxy log levels and collecting logs. We'll be loosely following the official [Linkerd docs](https://linkerd.io/2.12/tasks/modifying-proxy-log-level/) for this section.

As an aside, if you're looking to emit access logs in Linkerd please read [this article](https://linkerd.io/2.12/features/access-logging/).

```bash
# Collecting logs

## Method 1: admin endpoint

### We can update the log level on a given pod 
### by setting the log level dynamically
### via the admin api

### You must replace <pod_name> with the name
### of your pod.

kubectl port-forward <pod_name> linkerd-admin
curl -v --data 'linkerd=debug' -X PUT localhost:4191/proxy-log-level

kubectl logs <pod_name>

## Method 2: Persist log level changes
## via the manifest

### Configure the config.linkerd.io/proxy-log-level 
### value with a valid log level. Read more
### about the valid proxy annotations here:
### https://linkerd.io/2.12/reference/proxy-log-level/
```

### Externalizing Prometheus

We recommend using an external prometheus and grafana when running Linkerd in production. We will not cover this example during the workshop but you can read more about the process [here](https://linkerd.io/2.12/tasks/external-prometheus/).

### Upgrades and Rollbacks

Upgrading and, potentially rolling back, your Linkerd control plane is an important part of maintaining your platform. For production we generally recommend that you use the Linkerd helm charts.

An extremely important word of caution: You should carefully read the upgrade instructions when moving between major versions of Linkerd. For example the move from Linkerd 2.11.x to 2.12.x involves a migration as the project changed helm charts in their entirety.

For this workshop we will show you how to [upgrade minor versions](https://linkerd.io/2.12/tasks/upgrade/). Please see the relevant instructions for your major upgrade.

```bash
# Upgrades and Rollbacks

## Upgrading Linkerd

### Helm upgrade docs:
### https://linkerd.io/2.12/tasks/install-helm/#helm-upgrade-procedure

helm repo update

### We'll actually start with a rollback as 
### we're currently on the latest version of 
### Linkerd.

helm upgrade linkerd-crds linkerd/linkerd-crds --version 2.12.1

helm upgrade linkerd-control-plane linkerd/linkerd-control-plane --atomic --version 2.12.1

### This will "upgrade" your control plane to 2.11.1. 
### The --automic flag allows changes 
### to be rolled back automatically in the 
### event of a failure.

## Upgrading again, or rolling back
## depending on your perspective.

helm upgrade linkerd-crds linkerd/linkerd-crds --version 2.12.2

helm upgrade linkerd-control-plane linkerd/linkerd-control-plane --atomic --version 2.12.2

```
