# Certificate Management in Linkerd

## Pre Reqs

## Outline

* Overview
* Step cli
* Manual certificate rotation
* Cert-Manager and Linkerd

## Steps

```bash
# Using the step cli to generate certificates

## Please see the linkerd docs for more details:
## https://linkerd.io/2.12/tasks/generate-certificates/

## Step 1: Create your root CA, this is the foundation for 
## trust both in and between your clusters.

### Strongly consider making yourself a temp directory for this

step certificate create root.linkerd.cluster.local ca.crt ca.key \
  --profile root-ca --no-password --insecure

## Step 2: Create the intermediary CA 
### The control plane will use to this certificate to issue
### individual workload certificates.

step certificate create identity.linkerd.cluster.local issuer.crt issuer.key \
  --profile intermediate-ca \
  --not-after 8760h \
  --no-password \
  --insecure \
  --ca ca.crt \
  --ca-key ca.key

## Store all these certificates securely as you'll need them later

```

```bash
# Using cert-manager with Linkerd

## An alternate method for generating, and even rotating, our 
## certificates is to use a tool like cert manager. We 
## recommend that production users of Linkerd seriously 
## consider using cert-manager.

## Step 1: add the jetstack helm repo 

helm repo add jetstack https://charts.jetstack.io
helm repo update

## Step 2: Install cert-manager
### We use cert-manager to generate our certificates

helm install cert-manager jetstack/cert-manager --namespace cert-manager \
  --create-namespace --set installCRDs=true --version v1.10.0

## Step 3: Optional, install trust-manager
### trust-manager will add your trust bundle to other 
### workloads in your cluster

helm upgrade --install -n cert-manager cert-manager-trust \
  jetstack/cert-manager-trust --wait

## Step 4: Create certs for Linkerd

kubectl create ns linkerd

kubectl apply -f manifests/bootstrap_ca.yaml

### Take a look at our custom objects

cat bootstrap_ca.yaml

### Inspect the root certificate

kubectl get -n cert-manager secrets linkerd-trust-anchor -ojson |
  jq '.data."tls.crt"' -r | base64 -d | openssl x509 -noout -text

### Inspect the intermediate certificate

kubectl get -n linkerd secrets linkerd-identity-issuer -ojson |
  jq '.data."tls.crt"' -r | base64 -d | openssl x509 -noout -text

```
