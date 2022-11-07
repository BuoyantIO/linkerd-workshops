# Linkerd Failover Operator

This workshop focuses on using the Linkerd failover operator to provide high availability
to the emojivoto service. The failover operator works by watching two services, one
primary and one backup. As long as the primary service is healthy the operator will wait
and do nothing. If it detects that the primary service is unhealthy it will automatically
shift all traffic to the backup service. It will leave the traffic there until it once
again detects healthy replicas in the primary service.

## Requirements

You'll need access to 2 kubernetes clusters in order to complete a multi cluster failover
operation. You'll also likely need the following cli tools:

* k3d
* kubectl
* helm
