# Locking Down Kubernetes with Linkerd

Welcome to our workshop on securing clusters in Kubernetes with Linkerd!

We're going to walk you through installing and configuring Linkerd with a short lived
certificate. Then we're going to show you how to configure policy for a sample application
that will demonstrate the principles of zero trust.

We'll use both [cert-manager](https://github.com/cert-manager/cert-manager) and [trust-manager](https://github.com/cert-manager/trust)
for managing our certs.

## Requirements

You'll need the [Linkerd CLI](https://linkerd.io/2.12/getting-started/) installed for this workshop.

In addition, you'll need recent versions of the following tools:

* The [Civo CLI](https://github.com/civo/cli#set-up) if you want to use Civo clusters (recommended!)
* `helm`
* `kubectl`
* `curl`
* `openssl` and `jq` (only required to inspect certificates; you can complete the workshop without these tools!)

In addition, if you want to run a test cluster locally using k3d you'll need the following tools:

* k3d (and rootful docker)
* or kind (untested)

We recommend that workshop attendees follow these instructions for creating an on demand Civo cluster

## Creating a cluster with Civo

```bash
civo k8s create workshop -s "${size}" -r g4s.kube.medium
```

## Outline

* Why cryptographic identity?
* Why use cert-manager?
* cert-manager Issuers
  * CA / SelfSigned
  * Vault
  * Venafi
  * ACME
* mTLS
* Linkerd
* Linkerd Identity
* Linkerd Policy
  * Authn vs Authz
* Workshop
* Questions

## Steps

```bash
# Load up Booksapp, our demo application

kubectl create ns booksapp && \
  curl --proto '=https' --tlsv1.2 \
  -sSfL https://run.linkerd.io/booksapp.yml |
  kubectl -n booksapp apply -f -

## NOTE: All installs to be done with helm

# cert-manager install

helm repo add linkerd https://helm.linkerd.io/stable
helm repo add jetstack https://charts.jetstack.io
helm repo update

## Install cert-manager

helm install cert-manager jetstack/cert-manager --namespace cert-manager \
  --create-namespace --set installCRDs=true --version v1.10.0

## Install trust-manager

helm upgrade --install -n cert-manager cert-manager-trust \
  jetstack/cert-manager-trust --wait

## Create linkerd namespace, since we'll want to create certs there later!

kubectl create ns linkerd

## Create our issuers, certs and our trust bundle for Linkerd

kubectl apply -f bootstrap_ca.yaml

## Let's take a look at what's in bootstrap_ca.yaml!

cat bootstrap_ca.yaml

## Inspect root certificate

kubectl get -n cert-manager secrets linkerd-trust-anchor -ojson |
  jq '.data."tls.crt"' -r | base64 -d | openssl x509 -noout -text

## Inspect intermediate certificate

kubectl get -n linkerd secrets linkerd-identity-issuer -ojson |
  jq '.data."tls.crt"' -r | base64 -d | openssl x509 -noout -text

# Linkerd

### NOTE: The Linkerd namespace was created above

## Install CRDS

helm install linkerd-crds linkerd/linkerd-crds -n linkerd

## Install Linkerd's Control Plane
## You can see we reference the already created CA by setting "exernalCA" to true
## and setting the issuer scheme to use a Kubernetes secret

helm install linkerd-control-plane --namespace linkerd \
  --set identity.externalCA=true \
  --set identity.issuer.scheme=kubernetes.io/tls linkerd/linkerd-control-plane

linkerd check

## Install Linkerd Viz so that we can see what's happening in the cluster

helm install linkerd-viz --namespace linkerd-viz \
  --create-namespace linkerd/linkerd-viz

linkerd viz check

# Adding our applications
## Inject booksapp
### By inject we mean add the Linkerd proxies. This will
### enable mTLS for all our traffic and allow us to begin
### configuring policy

kubectl get deploy -n booksapp -o yaml | linkerd inject - |
  kubectl apply -f -

## Look around, this is a good time to check on your pods
## and see the current state of traffic in your cluster.

linkerd check --proxy -n booksapp 

## Things mostly work

### You can confirm that with this

linkerd viz stat deploy -n booksapp

### Unfortunately while we have mTLS
### There are no effective policies

linkerd viz authz deploy -n booksapp

# Harden our ns

## Default deny

### Configure a deny policy for booksapp

kubectl annotate ns booksapp \
  config.linkerd.io/default-inbound-policy=deny

kubectl get pods -n booksapp

linkerd viz stat deploy -n booksapp

## Traffic is still there
## That's because the default policy is only read by 
## the proxies at startup time. In order to properly 
## crater our traffic we need to run a rollout restart 
## command.
### Apps still restart thanks to default exemptions for health checks

kubectl rollout restart -n booksapp deploy

# Now traffic is gone
## You can watch the traffic, 
## or lack thereof with

linkerd viz authz -n booksapp deployment

linkerd viz stat deploy -n booksapp

## Allow admin traffic

### These commands will allow viz to begin talking to our
### applications. This will NOT allow any application traffic.
### We allow viz traffic first so that we can see the impact 
### of the changes we'll be making later.

kubectl apply -f manifests/booksapp/admin_server.yaml

kubectl apply -f manifests/booksapp/allow_viz.yaml

### In the server object you'll see a
### Server that we created that will
### refer to every linkerd admin port in 
### our namespace.
cat manifests/booksapp/admin_server.yaml

### In this file we'll see the AuthorizationPolicy and it's corresponding binding that explicitly authorizes 
cat manifests/booksapp/allow_viz.yaml


### Allow app traffic
kubectl apply -f manifests/booksapp/authors_server.yaml

kubectl apply -f manifests/booksapp/books_server.yaml

kubectl apply -f manifests/booksapp/webapp_server.yaml

cat manifests/booksapp/authors_server.yaml

kubectl apply -f manifests/booksapp/allow_namespace.yaml

cat manifests/booksapp/allow_namespace.yaml 

### No Traffic app? no ports!
### We only created server objects for authors, books, and
### webapp because they serve traffic. our traffic generator
### only calls out to webapp on port 7000.

## At this point we've isolated our namespace and only local 
## workloads, and linkerd-viz, can speak to anything in the 
## namespace.
```

## Conclusion

That concludes our workshop for today. If You'd like to learn more about policy with Linkerd please see our [service mesh academy](https://buoyant.io/service-mesh-academy) page and [this talk](https://buoyant.io/service-mesh-academy/a-deep-dive-into-route-based-policy) in particular.
