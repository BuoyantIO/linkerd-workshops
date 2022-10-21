# Installing Linkerd

## Pre Reqs

* linkerd cli
* helm
* Your certificates generated in 02

## Outline

* cli install
* helm install
* gitops and Linkerd (Optional)

## Steps

### Install Linkerd via the CLI

```bash
# Install Linkerd via the CLI
## using pre generated certificates

## Step 1: install the Linkerd CRDs
### as of Linkerd 2.12 the Linkerd control-plane install
### has been broken into 2 components, the CRDs and the 
### core control plane.

linkerd install --crds | kubectl apply -f -

## Step 2: install the Linkerd control plane, with the 
## certificates we just generated.

linkerd install \
  --identity-trust-anchors-file ca.crt \
  --identity-issuer-certificate-file issuer.crt \
  --identity-issuer-key-file issuer.key \
  | kubectl apply -f -

### We only pass the public key for the root CA, or trust 
### anchor. The intermediary certificate, which the linkerd
### identity service will use to generate our individual 
### workload certificates, is passed to the control plane
### at install time.

## Step 3: validate the install using linkerd check
linkerd check

## Step 4: install the Linkerd dashboard

linkerd viz install | kubectl apply -f -

## Step 5: wait for viz to finish installing

linkerd viz check

### We use Linkerd viz in many of our examples later on 
### So it's worth running the install now.

```

### Install Linkerd with Helm

```bash
# Install Linkerd via Helm
## Using cert-manager to manage our certs


## Step 1: Install CRDS

helm install linkerd-crds linkerd/linkerd-crds -n linkerd

## Step 2: Install Linkerd's Control Plane
### You can see we reference the already created
### CA from the earlier section of the workshop.

# NOTE: We are not creating the linkerd namespace. It was
## created earlier when we created our certificates

helm install linkerd-control-plane --namespace linkerd \
  --set identity.externalCA=true \
  --set identity.issuer.scheme=kubernetes.io/tls linkerd/linkerd-control-plane

## Step 3: validate the install using linkerd check

linkerd check

## Step 4: Install Linkerd Viz so that we can see what's 
## happening in the cluster

helm install linkerd-viz --namespace linkerd-viz \
  --create-namespace linkerd/linkerd-viz

## Step 5: wait for the dashboard to finish intalling

linkerd viz check

```

### Linkerd in HA Mode

#### Via the Cli

You can nearly copy the instructions from the standard cli install.
The only difference here is that you'll set the `--ha` flag at install
time. With Linkerd in HA mode you need at least 3 nodes to support the
anti affinity rules for the control plane components.

```bash
## Step 1: install the Linkerd CRDs

linkerd install --crds | kubectl apply -f -

## Step 2: install the Linkerd control plane, with the 
## certificates we just generated.

linkerd install \
  --identity-trust-anchors-file ca.crt \
  --identity-issuer-certificate-file issuer.crt \
  --identity-issuer-key-file issuer.key \
  --ha \
  | kubectl apply -f -

## Step 3: validate the install using linkerd check
linkerd check

```

#### With Helm

When installing linkerd in HA mode with helm you need to
use the values-ha.yaml file that we include with the helm
template.

```bash
# Install Linkerd via Helm
## Using cert-manager to manage our certs

## Step 1: Install CRDS

helm install linkerd-crds linkerd/linkerd-crds -n linkerd

## Step 2: Pull a local copy of the linkerd-control-plane
## helm chart

helm fetch --untar linkerd/linkerd-control-plane

## Step 3: Install Linkerd's Control Plane

helm install linkerd-control-plane --namespace linkerd \
  --set identity.externalCA=true \
  --set identity.issuer.scheme=kubernetes.io/tls \
  -f linkerd-control-plane/values-ha.yaml \
  linkerd/linkerd-control-plane

## Step 4: validate the install using linkerd check

linkerd check

```
