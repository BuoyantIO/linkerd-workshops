#!/bin/env bash

clear

# Make sure that we're in the namespace we expect.
kubectl ns default

# Tell dsh to show commands as they're run.
#@SHOW

#@clear
# Install Linkerd, per the quickstart.
#### LINKERD_INSTALL_START
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh

linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
linkerd check
#### LINKERD_INSTALL_END

# Next up, install Grafana, since we don't get that by default in 2.12.
#### GRAFANA_INSTALL_START
helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana -n grafana --create-namespace grafana/grafana \
  -f https://raw.githubusercontent.com/linkerd/linkerd2/main/grafana/values.yaml \
  --wait
linkerd viz install --set grafana.url=grafana.grafana:3000 | kubectl apply -f -
linkerd check
#### GRAFANA_INSTALL_END

#@wait
#@clear
# Next up: install Emissary-ingress 3.2.0 as the ingress. This is mostly following
# the quickstart, but we force every Deployment to one replica to reduce the load
# on k3d.

#### EMISSARY_INSTALL_START
EMISSARY_CRDS=https://app.getambassador.io/yaml/emissary/3.2.0/emissary-crds.yaml
EMISSARY_INGRESS=https://app.getambassador.io/yaml/emissary/3.2.0/emissary-emissaryns.yaml

kubectl create namespace emissary && \
curl --proto '=https' --tlsv1.2 -sSfL $EMISSARY_CRDS | \
    sed -e 's/replicas: 3/replicas: 1/' | \
    kubectl apply -f -
kubectl wait --timeout=90s --for=condition=available deployment emissary-apiext -n emissary-system

curl --proto '=https' --tlsv1.2 -sSfL $EMISSARY_INGRESS | \
    sed -e 's/replicas: 3/replicas: 1/' | \
    linkerd inject - | \
    kubectl apply -f -

kubectl -n emissary wait --for condition=available --timeout=90s deploy -lproduct=aes
#### EMISSARY_INSTALL_END

#@wait
#@clear
# Finally, configure Emissary for HTTP - not HTTPS! - routing to our cluster.
#### EMISSARY_CONFIGURE_START
kubectl apply -f emissary-yaml
#### EMISSARY_CONFIGURE_END

#@wait
#@clear
# Once that's done, install Faces, being sure to inject it into the mesh.
# Install its ServiceProfiles and Mappings too: all of these things are in
# the k8s directory.

#### FACES_INSTALL_START
kubectl create ns faces

linkerd inject k8s | kubectl apply -f -
#### FACES_INSTALL_END
