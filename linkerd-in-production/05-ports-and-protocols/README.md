# Ports and Protocols: detection and avoidance

## Prerequisities

- A running Kubernetes cluster
- The `kubectl` CLI
- The `linkerd` CLI

## Overview

Part of the value of a service mesh is in its ability to really understand what a given request means and whether it succeeds: this is critical both for metrics and for debugging. Doing this properly means understanding what protocol a request is, so that the mesh can correctly interpret status codes and errors.

Linkerd can detect the protocol in use when the client speaks first, but not when the server speaks first: for example, HTTP begins with the client sending a request, but SMTP begins with the server sending its identification. Linkerd can correctly detect HTTP, but not SMTP.

For protocols that Linkerd cannot detect, there are three mechanisms available to tell Linkerd which protocol is in use:

- `Skip` ports
- `Opaque` ports
- `Server` resource protocol hints

### `Skip` ports

Traffic over a port marked `skip` completely bypasses the Linkerd proxy: it does not participate in the mesh at all.

### `Opaque` ports

Traffic over a port marked `opaque` is encapsulated in mTLS and subjected to Linkerd's authorization mechanisms, but is not otherwise processed. As of Linkerd 2.12, the following ports are all considered `opaque` by default:

- 25 (SMTP)
- 587 (SMTP)
- 3306 (MySQL)
- 4444 (Galera)
- 5432 (Postgres)
- 6379 (Redis)
- 9300 (ElasticSearch)
- 11211 (Memcache)

**NOTE**: traffic destined outside the cluster **cannot** use an `opaque` port, because the destination will not be another Linkerd proxy. Use a `skip` port instead.

### `Server` resource protocol hints

* Servers and protocol detection
* Setting opaque ports
* Skipping ports

## Steps

```bash
# Examine Server objects

```

```bash
# Set Opaque ports
## Stretch goal of watch a timeout

```

```bash
# Skip a port

```
