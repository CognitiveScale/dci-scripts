#!/bin/bash
# Allow Volume Expansion
kubectl get sc --no-headers | awk '{print $1}' | xargs kubectl patch sc --type merge --patch '{"allowVolumeExpansion": true}'

# Delete STS with Modified Volume Claims
kubectl delete sts cortex-elasticsearch-data --namespace cortex --cascade=false
kubectl delete sts cortex-mongodb-replicaset --namespace cortex --cascade=false

# Update PVC Resource Request
kubectl get pvc -l app=elasticsearch,component=data --namespace cortex --no-headers | awk '{print $1}' | xargs kubectl patch pvc -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}' --namespace cortex
kubectl get pvc -l app=mongodb-replicaset --namespace cortex --no-headers | awk '{print $1}' | xargs kubectl patch pvc -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}' --namespace cortex

# Remove Connection Type Loader Job
kubectl delete job cortex-connection-type-loader --namespace cortex
