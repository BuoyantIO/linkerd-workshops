#!/bin/env bash
source ./demo-magic.sh
clear

## Cluster setup
k3d cluster delete workshop > /dev/null 2>&1 || true

k3d cluster create workshop --wait > /dev/null 2>&1

# Alternative if you need registry config!
# k3d cluster create workshop --registry-config registries.yaml > /dev/null 2>&1

## Load up Booksapp
# curl -sL run.linkerd.io/emojivoto.yml | kubectl apply -f -
kubectl create ns booksapp && \
  curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/booksapp.yml \
  | kubectl -n booksapp apply -f -

clear

# All installs to be done with helm
## cert-manager install
helm repo add linkerd https://helm.linkerd.io/stable
helm repo add jetstack https://charts.jetstack.io
helm repo update

clear

## cert-manager install
# Install cert-manager

pe "helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true --version v1.10.0"
wait
clear

# Install trust-manager
pe "helm upgrade --install --namespace cert-manager cert-manager-trust jetstack/cert-manager-trust --wait"
wait
clear

# Create the linkerd namespace ahead of time since we'll create our certs there

pe "kubectl create ns linkerd"
wait
clear

# Create certs for Linkerd

pe "kubectl apply -f bootstrap_ca.yaml"
wait
clear

# Inspect the YAML which defines the certificates

pe "bat -lyaml bootstrap_ca.yaml"
wait
clear

# Inspect root certificate

pe "kubectl get -n cert-manager secrets linkerd-trust-anchor -ojson | jq '.data.\"tls.crt\"' -r | base64 -d | openssl x509 -noout -text"
wait
clear

# Inspect intermediate certificate

pe "kubectl get -n linkerd secrets linkerd-identity-issuer -ojson | jq '.data.\"tls.crt\"' -r | base64 -d | openssl x509 -noout -text"
wait
clear

## Linkerd

# Install CRDS
## Note: Namespace is created above

pe "helm install linkerd-crds linkerd/linkerd-crds -n linkerd"
wait
clear

pe "helm install linkerd-control-plane --namespace linkerd --set identity.externalCA=true --set identity.issuer.scheme=kubernetes.io/tls linkerd/linkerd-control-plane"
wait
clear

pe "linkerd check"
wait
clear

pe "helm install linkerd-viz --namespace linkerd-viz --create-namespace linkerd/linkerd-viz"
wait
clear

pe "linkerd check"
wait
clear

## Inject booksapp
pe "kubectl get deploy -n booksapp -o yaml | linkerd inject - | kubectl apply -f -"
wait
clear

## Look around
#Things mostly work
pe "linkerd viz stat deploy -n booksapp"
wait 
clear


# No effective policies
# pe "linkerd viz authz -n booksapp deployment"
# wait 
# clear

## Harden our ns
### Default deny
### Configure a deny policy for booksapp
pe 'kubectl annotate ns booksapp config.linkerd.io/default-inbound-policy=deny'
wait
clear

pe 'kubectl get pods -n booksapp'
wait
clear

# pe "linkerd viz authz -n booksapp deployment"
# wait 
# clear

pe "linkerd viz stat deploy -n booksapp"
wait 
clear

# Traffic is still there
## Apps still restart thanks to default exemptions for health checks
pe 'kubectl rollout restart -n booksapp deploy'
wait
clear

# Now traffic is gone
## Alternately watch the traffic
# pe "linkerd viz authz -n booksapp deployment"
# wait 
# clear

# pe "linkerd viz stat deploy -n booksapp"
# wait 
# clear

### Allow admin traffic
pe "kubectl apply -f manifests/booksapp/admin_server.yaml"
wait 
clear

pe "kubectl apply -f manifests/booksapp/allow_viz.yaml"
wait 
clear

pe "bat -l yaml manifests/booksapp/admin_server.yaml"
wait 
clear

pe "bat -l yaml manifests/booksapp/allow_viz.yaml"
wait 
clear

### Allow app traffic
pe "kubectl apply -f manifests/booksapp/authors_server.yaml"
wait 
clear

pe "kubectl apply -f manifests/booksapp/books_server.yaml"
wait 
clear

pe "kubectl apply -f manifests/booksapp/webapp_server.yaml"
wait 
clear

pe "kubectl apply -f manifests/booksapp/allow_namespace.yaml"
wait 
clear

pe "bat -l yaml manifests/booksapp/authors_server.yaml"
wait 
clear

pe "bat -l yaml manifests/booksapp/allow_namespace.yaml "
wait 
clear

p 'fin'
wait
clear
