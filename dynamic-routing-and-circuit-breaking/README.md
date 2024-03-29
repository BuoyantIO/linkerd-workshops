# Linkerd 2.13 Dynamic Request Routing and Circuit Breaking

This is the documentation - and executable code! - for the Service Mesh
Academy workshop about what's coming in Linkerd 2.13. The easiest way to use
this file is to execute it with [demosh].

Things in Markdown comments are safe to ignore when reading this later. When
executing this with [demosh], things after the horizontal rule below (which
is just before a commented `@SHOW` directive) will get displayed.

[demosh]: https://github.com/BuoyantIO/demosh

For this workshop, you'll need a running Kubernetes cluster set up with
Linkerd, Emissary, and the Faces app. You can use `create-cluster.sh` to
create an appropriate `k3d` cluster, and `setup-demo.sh` to initialize it.

<!-- set -e >
<!-- @import demosh/check-requirements.sh -->
<!-- @import demosh/demo-tools.sh -->

<!-- @start_livecast -->

```bash
BAT_STYLE="grid,numbers"
```

You'll also want two web browsers running pointing to the Faces app at
(assuming you used `create-cluster.sh` to set up your cluster)
https://localhost/faces/ -- one normal one, and one using ModHeader or the
like to set `X-Faces-User: testuser` for the canarying test.

---
<!-- @SHOW -->

# Dynamic Request Routing and Circuit Breaking

Two significant new features in Linkerd 2.13 are dynamic request routing and
circuit breaking.

Dynamic request routing permits HTTP routing based on headers, HTTP method,
etc. We'll use this to demonstrate progessive delivery and A/B testing deep in
the call graph of our application.

Circuit breaking is a resilience feature that allows Linkerd to stop sending
requests to endpoints that fail too much. We'll use this to protect our
application from a failing workload.

<!-- @wait_clear -->

## Dynamic Request Routing: Progressive Delivery

As running right now, the Faces GUI should be showing all grinning faces on
green backgrounds. The green background comes from the `color` workload. If we
have a new version of that workload (`color2`) which returns blue instead of
green, we can slowly shift traffic to `color2` using a new `HTTPRoute`
resource.

Here's the resource we'll apply:

```bash
#@immed
bat k8s/02-canary/color-canary-10.yaml
```

When we apply that, we should immediately see 10% of the backgrounds shift to
blue.

```bash
kubectl apply -f k8s/02-canary/color-canary-10.yaml
```

<!-- @wait_clear -->

## Dynamic Request Routing: Progressive Delivery

We can change the amount of traffic by changing the weights. For example, now
that we see 10% blue working, we can shift to a 50/50 split:

```bash
diff -u99 --color k8s/02-canary/color-canary-{10,50}.yaml
```

Applying that, we'll immediately see the amount of blue backgrounds increase.

```bash
kubectl apply -f k8s/02-canary/color-canary-50.yaml
```

<!-- @wait_clear -->

## Dynamic Request Routing: Progressive Delivery

Finally, when we're happy with the 50/50 split, we can shift to routing all
our traffic to the blue `color2` service. We could do this by deleting one of
our `backendRefs`, but here we'll show using a `weight` of 0 instead:

```bash
diff -u99 --color k8s/02-canary/color-canary-{50,100}.yaml
```

Applying that, we should see no green backgrounds at all.

```bash
kubectl apply -f k8s/02-canary/color-canary-100.yaml
```

<!-- @wait_clear -->

## Dynamic Request Routing: A/B Testing

Another thing we can do with dynamic request routing is A/B testing deep in
the call graph, where the ingress controller can't reach. Here we'll use two
browsers to show an A/B test where all requests with the header

`X-Faces-Header: testuser`

get routed to a different `smiley` workload (named `smiley2`), which returns a
heart eyes smiley instead of the normal grinning smiley.

One browser is "normal" and will not send the `X-Faces-User` header. It will
show `User: unknown`. The other browser is set up using the ModHeader
extension to send `X-Faces-User: testuser`. It will show `User: testuser`.

<!-- @wait_clear -->

## Dynamic Request Routing: A/B Testing

Here's the HTTPRoute we'll add to do the A/B test:

```bash
#@immed
bat k8s/03-abtest/smiley-ab.yaml
```

Applying that, we will immediately start to see the browser setting the
`X-Faces-User: testuser` header start getting heart eyes smilies.

```bash
kubectl apply -f k8s/03-abtest/smiley-ab.yaml
```

<!-- @wait_clear -->

## Dynamic Request Routing: A/B Testing

Once we're happy that the B side of our A/B test results in happy users (maybe
they really like the heart eyes smiley?) we can delete the `matches` clause
entirely, and change the `backendRefs` of the route to unconditionally route
all traffic to our `smiley2` workload.

Here's the HTTPRoute:

```bash
#@immed
bat k8s/03-abtest/smiley2-unconditional.yaml
```

Applying it will result in both browsers getting heart eyes smilies:

```bash
kubectl apply -f k8s/03-abtest/smiley2-unconditional.yaml
```

<!-- @wait_clear -->

## Circuit Breaking

Circuit breaking stops routing traffic to failing endpoints. To demonstrate
this, we'll first start by spinning up extra workload Pods behind the `face`
service.

```bash
kubectl apply -f k8s/04-circuit-breakING/face2.yaml
```

<!-- @wait_clear -->

## Circuit Breaking

The new Pods are from the `face2` Deployment, but are still matched by the
label selector on the `face` service. The big new thing in the `face2`
Deployment is that its Pods will rapidly get stuck in an error state, which
will appear as a "meh" face on a pink background, and stay there until they
get no traffic for awhile.

We'll display Pods in the Faces GUI for this, so that we can see which Pods
are answering `face` requests, and with what. This will make it easier to see
when the circuit breaker is open and closed. We'll wait until our browser
shows the failures happening.

<!-- @wait_clear -->

## Circuit Breaking

Now that we see failures, we'll enable circuit breaking. At the moment, this
is configured by annotations. We'll set it to break the circuit after 30
consecutive failures (which happens quickly in this demo), and to stay failed
for at least 10 seconds.

```bash
kubectl annotate -n faces svc/face \
    balancer.linkerd.io/failure-accrual=consecutive \
    balancer.linkerd.io/failure-accrual-consecutive-max-failures=30 \
    balancer.linkerd.io/failure-accrual-consecutive-min-penalty=10s
```

<!-- @wait_clear -->

## Circuit Breaking

At this point, we should be back to seeing blue backgrounds and grinning
faces, except for every so often when a request will be allowed through to see
if the `face2` Pods have recovered. Eventually they will, after which they'll
continue getting traffic until the next time they fail and the circuit breaker
opens.

<!-- @wait_clear -->
