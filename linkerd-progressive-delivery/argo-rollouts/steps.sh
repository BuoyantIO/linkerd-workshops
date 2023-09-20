
# watch Route
kubectl -n argo-demo get httproute.gateway.networking.k8s.io/argo-rollouts-http-route -o custom-columns=NAME:.metadata.name,PRIMARY_SERVICE:.spec.rules[0].backendRefs[0].name,PRIMARY_WEIGHT:.spec.rules[0].backendRefs[0].weight,CANARY_SERVICE:.spec.rules[0].backendRefs[1].name,CANARY_WEIGHT:.spec.rules[0].backendRefs[1].weight

# View traffic
linkerd viz -n argo-demo stat rs --from deploy/slow-cooker

# View Rollout
kubectl argo rollouts -n argo-demo get rollout rollouts-demo

watch k argo rollouts -n argo-demo get rollout rollouts-demo

# Update image
kubectl argo rollouts -n argo-demo set image rollouts-demo   rollouts-demo=argoproj/rollouts-demo:yellow #red
