# Locking Down Clusters

## Pre Reqs

* linkerd cli
* helm
* A functional Linkerd install from 03

## Outline

* Introducing our shiny new CRDs
  * Server
  * Authorizations
  * MeshTLS
  * NetworkID
  * HTTPRoute
* Isolate a Namespace
* It's gone do what to who?
  * Let's find out and see

## Steps

```bash
# Looking at CRDs

## New Linkerd object types
## To learn more about all of these object types please 
## visit the Linkerd docs here: 
## https://linkerd.io/2.12/reference/authorization-policy/

### Server

#### A server defines a port on a workload. It is also used
#### as an attachment point for policy objects

cat manifests/booksapp/admin_server.yaml

### HTTPRoute

#### An HTTPRoute specifies a particular path in an workload.
#### It can match on a path, or a verb and must be tied to a 
#### Server object.

cat manifests/booksapp/authors_probe.yaml

### MeshTLSAuthentication

#### This object specifies a set of linkerd identities that
#### can be bound to a Server or HTTPRoute

cat manifests/booksapp/allow_viz.yaml

### NetworkAuthentication

#### This object specifies an IPRange that should be allowed
#### to access an HTTPRoute or Server

cat manifests/booksapp/authors_probe.yaml

### AuthorizationPolicy

#### An Authorization policy binds a Mesh or Network authn
#### object to an HTTPRoute or Server

cat manifests/booksapp/allow_viz.yaml

```

```bash
# Namespace Jail

## In this example we'll show you how to isolate a given 
## namespace with Linkerd.

## Step 1: Install and Inject booksapp
### By inject we mean add the Linkerd proxies. This will
### enable mTLS for all our traffic and allow us to begin
### configuring policy

kubectl create ns booksapp && \
  curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/booksapp.yml \
  | linkerd inject - \
  | kubectl -n booksapp apply -f -

## Look around, this is a good time to check on your pods
## and see the current state of traffic in your cluster.

linkerd check --proxy -n booksapp 

## Things mostly work

### You can confirm that with this

linkerd viz stat deploy -n booksapp

### Unfortunately while we have mTLS
### There are no effective policies

linkerd viz authz deploy -n booksapp

## Step 2: Harden our ns

### About default deny: We use a default deny as the basis 
### for a zero trust security model. Default deny means that
### only traffic that has been explicitly authorized will 
### be allowed in our namespace.

### Configure a deny policy for booksapp

kubectl annotate ns booksapp \
  config.linkerd.io/default-inbound-policy=deny

kubectl get pods -n booksapp

linkerd viz stat deploy -n booksapp

### Traffic is still there
### That's because the default policy is only read by 
### the proxies at startup time. In order to properly 
### crater our traffic we need to run a rollout restart 
### command.

## Step 3: Cause our default policy to take effect

### default inbound policy is only read when a proxy 
### starts. The effect of that is that we need to 
### restart our apps for our default deny to work.

kubectl rollout restart -n booksapp deploy

### Apps still restart thanks to default exemptions for 
### health checks. 

# NOTE: Linkerd creates default exceptions for health 
# and readiness checks. Those exceptions ONLY exist
# until you define an HTTPRoute. Once you create any
# HTTPRoute for a server linkerd removes it's own
# default routes.


## Now traffic is gone
## You can watch the traffic, 
## or lack thereof with

linkerd viz authz -n booksapp deployment

linkerd viz stat deploy -n booksapp

## Step 4: Allow admin traffic

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

### In this file we'll see the AuthorizationPolicy and it's 
### corresponding binding that explicitly authorizes

cat manifests/booksapp/allow_viz.yaml


## Step 5: Allow app traffic

### The next 3 objects that get created are all nearly 
### identical. We are creating 1 server per workload
### which will allow us to bind a meshTLSauth to our 
### workloads.

kubectl apply -f manifests/booksapp/authors_server.yaml

kubectl apply -f manifests/booksapp/books_server.yaml

kubectl apply -f manifests/booksapp/webapp_server.yaml

cat manifests/booksapp/authors_server.yaml

### With our servers created we can now bind a wildcard
### meshTLSAuth object to our servers.

kubectl apply -f manifests/booksapp/allow_namespace.yaml

cat manifests/booksapp/allow_namespace.yaml 

# NOTE: No Traffic app? no ports!
# We only created server objects for authors, books, and
# webapp because they serve traffic. our traffic generator
# only calls out to webapp on port 7000.

## At this point we've isolated our namespace and only local 
## workloads, and linkerd-viz, can speak to anything in the 
## namespace.

```

```bash
# Fine grained policy

## Now that we've locked down booksapp we want to further 
## isolate our applications. We'll do that using HTTPRoutes. 
## With HTTPRoutes we can specify who can do what with our 
## app.

## Step 1: Create our first route

kubectl apply -f manifests/booksapp/authors_get_route.yaml

## Wait a minute for the authors pod to become unready.
## You can safely ignore any restarts to the traffic pod.

### Why did this happen? Linkerd creates default routes 
### for you health and readiness checks when your pods 
### get created. This ensures you can safely and easily 
### enforce mTLS everywhere without needing to carve out 
### exceptions for the kubelet. When we begin creating 
### routes Linkerd assumes we no longer want the routes 
### it created for us.

## Step 2: Lets fix our busted health checks

kubectl apply -f manifests/booksapp/authors_probe.yaml

### You can see here we explicitly re-authorize unauthenticated
### connections to the health and readiness endpoint of our
### application. This is required because the kubelet, which
### performs those checks, is not, and cannot, be part of our
### mesh.

cat manifests/booksapp/authors_probe.yaml

### wait a minute for authors to become ready
### Check readiness

## Step 3: Now that authors is ready we can enable traffic once again.

kubectl apply -f manifests/booksapp/authors_get_policy.yaml

### When you look at the route and policy objects you'll see
### we are explicitly authorizing webapp and books to perform
### GET requests on the authors service.

cat manifests/booksapp/authors_get_route.yaml

cat manifests/booksapp/authors_get_policy.yaml

### Check app

linkerd viz authz -n booksapp deployment

linkerd viz stat deploy -n booksapp

kubectl port-forward svc/webapp 7000:7000

### Browse over and explore your app, also if you put a watch
### on linkerd viz stat deploy -n booksapp you'll see very
### little traffic going to anything other than webapp.

### The UI looks good but we can't update books

## Step 4: Allow Webapp to create and delete authors

kubectl apply -f manifests/booksapp/authors_modify_route.yaml

manifests/booksapp/authors_modify_route.yaml

kubectl apply -f manifests/booksapp/authors_modify_policy.yaml

manifests/booksapp/authors_modify_policy.yaml

### With this we've wrapped up our demo. You can see when we 
### get to route based policy we've significantly increased the
### complexity of our custom resource definitions. Feel free to
### explore more on your own, a good exercise is to add routes 
### to books or allow an ingress to talk to webapp.

```
