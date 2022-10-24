# Linkerd Multicluster

## Pre Reqs

* linkerd cli
* helm
* The ability to spin up 2 clusters on the same network
  * civo
  * k3d
  * BYOClusters

## Outline

* Certs
* Setup
* exporting a svc

## Steps

NOTE: We are not including steps for deploying your clusters as
part of this section of the workshop.

```bash
# Certificate setup

## We're going to create certificates using the step cli.
## The steps here are similar to what we did in section 02

## Step 1: Generate a root CA

### Strongly consider making yourself a temp directory for this

step certificate create root.linkerd.cluster.local ca.crt ca.key \
  --profile root-ca --no-password --insecure

## Step 2: Create the intermediary CA for your first cluster 
### The control plane will use to this certificate to issue
### individual workload certificates. For the purposes of our
### workshop we'll call this the east cluster.

step certificate create identity.linkerd.cluster.local issuer.east.crt issuer.east.key \
--profile intermediate-ca --not-after 8760h --no-password --insecure \
--ca ca.crt --ca-key ca.key

## Step 3: Create the intermediary CA for your second cluster 
### For the purposes of our workshop we'll call this the west 
### cluster.

step certificate create identity.linkerd.cluster.local issuer.west.crt issuer.west.key \
--profile intermediate-ca --not-after 8760h --no-password --insecure \
--ca ca.crt --ca-key ca.key

## Store all these certificates securely as you'll need them later

```

```bash
# Installing and configuring mc

## This example loosely follows the Linkerd multicluster
## guide: https://linkerd.io/2.12/tasks/multicluster/

## Step 1: install the Linkerd CRDs
### We will be installing
### one instance of linkerd in each cluster

# NOTE: You'll need to modify the install command to correctly
# reference the kubeconfig for your east cluster. You will 
# find it easier to follow along if you save your kubeconfigs
# as distinct files that can be independently referenced.

linkerd install --crds | kubectl apply --kubeconfig east -f -

linkerd install --crds | kubectl apply --kubeconfig west -f -

## Step 2: install the Linkerd control plane, with the 
## certificates we just generated. 

linkerd install \
  --identity-trust-anchors-file ca.crt \
  --identity-issuer-certificate-file issuer.east.crt \
  --identity-issuer-key-file issuer.east.key \
  | kubectl apply --kubeconfig east -f -

linkerd install \
  --identity-trust-anchors-file ca.crt \
  --identity-issuer-certificate-file issuer.west.crt \
  --identity-issuer-key-file issuer.west.key \
  | kubectl apply --kubeconfig west -f -

linkerd check --kubeconfig east

linkerd check --kubeconfig west

## Step 3: install the Linkerd dashboard

linkerd viz install | kubectl apply --kubeconfig east -f -

linkerd viz install | kubectl apply --kubeconfig west -f -

linkerd viz check --kubeconfig east

linkerd viz check --kubeconfig west

## Step 4: Install the multicluster extension

linkerd multicluster install | kubectl --kubeconfig east apply -f -

linkerd multicluster install | kubectl --kubeconfig west apply -f -

linkerd multicluster check --kubeconfig east

linkerd multicluster check --kubeconfig west

## Step 5: Link east to west

# NOTE: Linkerd's link command is directional. That means
# you can set up links as either one way or bi-directional.
# in our example we will link our clusters  
# bi-directionally.

### the linkerd multicluster link command generates a number of 
### kubernetes objects that allows one cluster to access the 
### other. We will run the link command against the east cluster
### and apply the resultant objects on the west cluster.

linkerd --kubeconfig east multicluster link --cluster-name east |
  kubectl --kubeconfig west apply -f -

### The above command gives the west cluster permission to access
### select services on the east cluster. The particular services
### are designated with a specific annotation. The annotation can
### be modified by modifying the link object.

linkerd multicluster check --kubeconfig west

linkerd multicluster gateways --kubeconfig west

## Step 6: Link west to east

linkerd --kubeconfig east multicluster link --cluster-name west |
  kubectl --kubeconfig east apply -f -

### The above command gives the east cluster permission to access
### select services on the west cluster. 

linkerd multicluster check --kubeconfig east

linkerd multicluster gateways --kubeconfig east

```

```bash
# Exporting and using a svc

## Step 1: Install an app

for ctx in west east; do
  echo "Adding test services on cluster: ${ctx} ........."
  kubectl --kubeconfig ${ctx} apply \
    -n test -k "github.com/linkerd/website/multicluster/${ctx}/"
  kubectl --kubeconfig ${ctx} -n test \
    rollout status deploy/podinfo || break
  echo "-------------"
done

## Step 2: Export a service

### We'll be exporting a cluster from the west cluster to the
### east cluster.

kubectl --kubeconfig east label svc -n test podinfo mirror.linkerd.io/exported=true

### You should now be able to see the exported service in the 
### west cluster

kubectl --kubeconfig west -n test get svc podinfo-east

## Step 3: Test out your new link

### We can run a curl command from our frontend

#### In order to see traffic from the east cluster:

kubectl --kubeconfig west -n test exec -c nginx -it \
  $(kubectl --kubeconfig west -n test get po -l app=frontend \
    --no-headers -o custom-columns=:.metadata.name) \
  -- /bin/sh -c "apk add curl && curl http://podinfo-east:9898"

#### run the same curl against the local instance:

kubectl --kubeconfig west -n test exec -c nginx -it \
  $(kubectl --kubeconfig west -n test get po -l app=frontend \
    --no-headers -o custom-columns=:.metadata.name) \
  -- /bin/sh -c "apk add curl && curl http://podinfo:9898"

```
