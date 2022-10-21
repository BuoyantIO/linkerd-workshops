# Linkerd Extensions: broadening Linkerd's world

## Prerequisites

- A running Kubernetes cluster
- The `kubectl` CLI
- The `linkerd` CLI

## Overview

Linkerd extensions are a simple way for anyone to add functionality to Linkerd. The standard Linkerd distribution uses extensions to include several features that will only be installed into your cluster if you explicitly request it. Third parties can also provide extensions.

Creating an extension is as simple as providing an executable named `linkerd-$command` on your `$PATH`: once that's done, then `linkerd $command` will run that executable, and its `check` subcommand (which is mandatory) will be run as part of `linkerd check`. For simple extensions, this may be all that's necessary: more complex extensions, though, will typically need to install code into the Kubernetes cluster.

## Standard Extensions

These extensions ship with the standard Linkerd distribution, but must be explicitly installed to be used.

### `viz`

`linkerd viz` provides visualization and debugging tools for a cluster. It shows workloads and their communication topology, provides metrics on a per-workload and per-namespace basis, and includes the ability to tap traffic and show detailed information about requests and responses.

Another important function of `linkerd viz` is that it is responsible for gathering metrics based on `ServiceProfile`s, even when no one is using the GUI.

```bash
# Install linkerd viz
$ linkerd viz install | kubectl apply -f -
# Open the linkerd viz dashboard
$ linkerd viz dashboard
# Uninstall linkerd viz
$ linkerd viz uninstall | kubectl delete -f -
```

Though `linkerd viz` is optional, it is encouraged: even if you don't use the GUI dashboard, the metrics it collects can be invaluable for debugging.

### `cni`

When Linkerd starts, it typically uses an init container to set up the network routing rules that allow Linkerd's proxy to mediate traffic. However, the init container requires the `CAP_NET_ADMIN` capability for this, which might not be available on all clusters.

`linkerd cni` allows using a CNI plugin for this configuration instead of an init container, to avoid the need for `CAP_NET_ADMIN`. Note that it is designed to work in conjuction with an existing CNI plugin: it won't replace the need for the plugin in the first place.

**Note that `linkerd cni` is special: it _must_ be installed before the rest of Linkerd.**

```bash
# First, install the CNI plugin
$ linkerd install-cni | kubectl apply -f -
# Make sure all is well
$ linkerd check --pre --linkerd-cni-enabled

# Next, install Linkerd CRDs
$ linkerd install --crds | kubectl apply -f -
# Finally, install the rest of Linkerd, using the CNI plugin
$ linkerd install --linkerd-cni-enabled | kubectl apply -f -

# It's not possible to uninstall linkerd-cni without uninstalling all of Linkerd.
```

### `jaeger`

`linkerd-jaeger` allows Linkerd to interact with [Jaeger] distributed tracing. It consists of:

- a Jaeger backend, which stores trace spans and provides a dashboard to view them;
- a collector, which accepts spans sent from Linkerd or your applications and sends them to the back end; and
- an injector, which configures the Linkerd proxies to emit spans to the collector.

**Note that distributed tracing requires application changes: just enabling it in Linkerd isn't going to give you what you need.** See our [myths blog post] for more.

[Jaeger]: https://jaegertracing.io/
[myths blog post]: https://linkerd.io/2019/08/09/service-mesh-distributed-tracing-myths/

```bash
$ linkerd jaeger install | kubectl apply -f -
$ linkerd jaeger uninstall | kubectl delete -f -
```

## Buoyant Extensions

In addition to extensions that ship with Linkerd, Buoyant provides other extensions which are fully supported, but must be installed from the network before use.
### `smi`

`linkerd smi` allows Linkerd to use [SMI] (Service Mesh Interface) `TrafficSplit` resources to manage traffic within the cluster. Once installed, Linkerd will honor any `TrafficSplit` it finds that matches the name of a service to which Linkerd is routing traffic, shifting routing to match the weights specified in the `TrafficSplit`.

Although the name of the extension is `smi`, Linkerd only supports the `TrafficSplit` CRD from the SMI.

[SMI]: https://smi-spec.io/

```bash
# Install the linkerd-smi CLI extension
$ curl -sL https://linkerd.github.io/linkerd-smi/install | sh
# Use the CLI extension to install SMI support into the cluster.
$ linkerd smi install | kubectl apply -f -
```

### `multicluster`

`linkerd multicluster` allows multiple Linkerd clusters to work together for failover: if a service in one cluster becomes unavailable, Linkerd can route traffic to the other cluster.

This extension is covered in detail in [section 8] of this workshop.

[section 8]: ../08-multicluster/README.md
