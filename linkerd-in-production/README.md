# Linkerd in Production

This workshop centers on using Linkerd for real-world production use.
While most of it works if you use a [`k3d`] cluster or the like, it works
**much** better to use an actual cloud cluster (we're fond of [Civo],
but you do you).

[`k3d`]: https://k3d.io/
[Civo]: https://civo.io/

# Workshop Contents

## What is Linkerd?

[Linkerd] is a lightweight, high-performance, robust, secure service mesh. It
is currently the _only_ graduated CNCF service mesh. Linkerd's purpose in
life is to give developers everywhere the tools they need to create highly
secure, reliable, observable cloud-native applications, and to make those
tools freely available. As such, Linkerd has a strong focus on security,
speed, and operational simplicity.

In this workshop, we'll be focusing on open-source Linkerd. If you want
something a little less hands-on, though, [Buoyant] - the creators of
Linkerd - also provide a managed Linkerd solution called [Buoyant Cloud].

[Linkerd]: https://linkerd.io/
[Buoyant]: https://buoyant.io/
[Buoyant Cloud]: https://buoyant.io/cloud/

## What real-world concerns show up with Kubernetes in production?

Most of the time we do demos or workshops, we run them on small Kubernetes
clusters, often on our laptops, that don't worry about a lot of real-world
considerations. When we talk about actual production use, we're talking about
the need to address all those things that we deliberately ignore for demo use.

### Workload identity and certificates

Linkerd is based on the idea that you do _workload identity_ which is
separate from _network identity_: the basis of identity within Linkerd is
a Kubernetes ServiceAccount, which is tied to a TLS certificate that's
then used to authenticate both ends of a network connection with mTLS.
This permits workloads to move around in the network at will and still
retain their identities, which in turn dramatically simplifies policy
enforcement.

However, certificates are meaningless without proper verification:
checking _every_ access, _every_ time is actually a cornerstone of
[zero trust]. Linkerd uses a three-layer _trust hierarchy_ for this
verification, with the root of trust being a certificate called the
_trust anchor_.

Demo clusters often don't actually worry about the security of the trust
anchor, and they rarely last long enough for certificate rotation to be a
factor. In production use, though, the trust anchor requires careful handling
to avoid security lapses or downtime. (We'll discuss this in detail later.)

[zero trust]: https://securityboulevard.com/2022/10/zero-trust-the-service-mesh-and-linkerd/

### Single points of failure

A typical demo setup is a single-Node [`k3d`] cluster, running a single
instance of any applications (for example, Linkerd will often be installed
with only one replica of its pods). There are three separate single points
of failure here:

- There's only one cluster.
- The cluster has only one Node.
- Each workload runs only one Pod.

This means that a crash in anything causes downtime. Obviously, that isn't
acceptable in production -- we need to be thinking in terms of multiple
clusters, each with multiple Nodes, running workloads with multiple replicas.
We need to make sure that the replicas of a given workload don't all end up
on the same Node, and we need to make sure that we can fail over smoothly in
the event of failures, even if the failure is an entire cluster crashing.

(In many cases, we'll also need to take into account things like geographic
availability zones, but for our purposes here we'll just consider that a
refinement of multiple clusters.)

### Persistent state

Many cloud-native workloads are deliberately designed to be stateless, which
is to say that nothing needs to persist across a restart. However, some
workloads are all about state: for example, a database server that forgets
everything when it restarts is often not terribly useful.

In the context of Linkerd, the most important place this comes up is with
metrics. Demo installations of Linkerd run a [Prometheus] instance that uses
ephemeral storage within the cluster, meaning that if the Prometheus instance
or the cluster crashes, all the historical metrics for the cluster are gone.
In production, it's almost always necessary to [bring your own Prometheus] so
that its state can persist.

[Prometheus]: https://prometheus.io/
[bring your own Prometheus]: https://linkerd.io/2.12/tasks/external-prometheus/

### Requests and limits

Finally, it's important in production to be explicit about how much CPU and
memory it would like, and how much it must have in order to succeed. In a
demo setup, we typically just use the defaults, which are largely based on
demo setups that Linkerd developers have used. In production, it'll be
necessary to monitor real-world usage and adjust these as necessary.

--------
## Course outline

- Certificates in Linkerd
    - Quick look at general architecture of CA/certificates
        - CA root vs intermediate CA vs leaf
        - signing vs encrypting
        - identity, authz, authn
    - More detailed look at Linkerd trust architecture
        - trust anchor → issuer → workload
        - Talk lifespans
            - trust anchor longest
            - issuers should be shorter
            - don’t worry about workloads, Linkerd handles them for you
        - Talk rotation
            - you really, really want to automate this
            - Configuring alerting
        - Automatic rotation and cert manager
        - Worst case scenarios
            - rolling expired intermediaries
            - rolling the root
            - Checking why workloads aren’t getting certs
    - Setting up Linkerd to use an external CA for production
        - Cert manager
    - Multicluster concerns
        - All clusters require a shared root
    - Webhook certs
        - Ensuring trust with the Kube API
- Installing Linkerd
    - CLI vs Helm
        - We recommend Helm for prod; if you want to use `linkerd install` you’ll need to be more careful
    - HA Mode
        - what does HA mode actually do? what does it require?
        - Why do you need it?
        - How does it change your operating environment?
    - Tour the Helm-chart values
        - Certificates
        - CPU & memory requests/limits
        - Affinity
        - Global settings
            - Policy
            - Ports
            - Behavior
    - Prometheus
        - When to bring your own?
        - Do you need viz?
        - What other tools are there to collect metrics?
- Linkerd Control Plane
    - Understand the components
    - Destination
        - Destination Controller
            - this container does the actual destination svc work. It talks to the k8s api, gives information to the proxies, and helps all the linkerd meshy bits talk to each other in a smart and safe manner.
        - Policy
            - this container checks the service profiles are actually valid and works as a validating webhook to make sure no bad service profiles get created.
        - SP-Validator
            - this container does the same validation work as sp-validator but for policy objects
    - Identity
        - creates and distributes mTLS certificates based on ServiceAccount
    - Injector
        - mutating webhook that actually stuffs proxy sidecars into workload Pods
- Linkerd Data Plane – the linkerd2 proxy
    - What is it?
        - this is the bit that actually slings traffic around
        - intercepts connections, manages mTLS, enforces policy, etc.
    - What’s special about it?
        - purpose-built for service mesh
        - simple, lightweight, hella fast
        - written in Rust
        - no config to dump (contrast with Envoy config, ew)
    - Proxy injection
        - the injector modifies Deployments, DaemonSets, and StatefulSets to place a proxy container inside each Pod
    - How do you debug it?
        - see Charles’ talk
        - turn on debug logging, file an issue
- Ports and protocols
    - Skip vs Opaque
        - skip: Linkerd does NOTHING for traffic on this port
        - opaque: Linkerd wraps it in mTLS but otherwise treats it as a bytestream
    - Protocol detection
        - requires client-speaks-first: HTTP(S), gRPC, things like that work great
        - some common things that don’t work great: SMTP, MySQL, Postgres
    - in cluster vs off cluster traffic
        - opaque doesn’t work for off-cluster traffic
            - it requires a persistent connection from proxy to proxy
            - for off-cluster stuff, there’s no proxy on the far end, so you must use skip
- Linkerd Extensions
    - Viz
        - See into your cluster
    - mc
        - Let meshed services live in multiple clusters
    - failover
        - Allow shifting traffic for a dead service to a different service
    - jaeger
        - Manage distributed tracing
    - smi
        - Work with Service Mesh Interface CRDs
            - primarily TrafficSplit
    - cni
        - Manage container networking
        - What is it and why does it exist
- What to do when things go wrong?
    - Injector failure behavior
    - Skipping ports
        - or how to take Linkerd out of the loop
    - Removing Linkerd
    - Gathering debug logs
    - What makes a good bug report
- Multicluster
    - trust anchor setup
    - configuring failover
    - mirror service
    - demo a failover and failback
- Care and Feeding
    - Routine maintenance around Linkerd
        - Cert rotation
        - Check limits and resource usage
        - Collecting logs
        - Where and how are you storing metrics?
        - Upgrading