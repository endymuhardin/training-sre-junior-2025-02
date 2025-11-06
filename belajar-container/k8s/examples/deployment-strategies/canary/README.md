# Canary Deployment Example (Native Kubernetes)

Canary deployment gradually rolls out new version to subset of users. This example uses replica count to control traffic distribution.

## Traffic Distribution Formula

```
Canary Traffic % = (Canary Replicas / Total Replicas) * 100
```

## Steps

### 1. Deploy Stable Version (v1)

```bash
kubectl apply -f 01-stable-deployment.yml
kubectl apply -f 03-service.yml

# Verify
kubectl get pods -l app=belajar-app
```

### 2. Deploy Canary (v2) with 10% Traffic

```bash
kubectl apply -f 02-canary-deployment.yml

# Wait for canary ready
kubectl wait --for=condition=ready pod -l version=v2 --timeout=300s

# Verify: Should have 9 v1 pods and 1 v2 pod
kubectl get pods -l app=belajar-app
```

### 3. Monitor Canary

```bash
# Watch logs from canary
kubectl logs -f -l version=v2

# Check resource usage
kubectl top pods -l version=v2

# Monitor error rates (jika ada metrics/monitoring)
```

### 4. Gradually Increase Canary Traffic

```bash
# Increase to 25% (3 canary, 9 stable)
kubectl scale deployment app-belajar-v2 --replicas=3
kubectl scale deployment app-belajar-v1 --replicas=9

# Increase to 50% (5 canary, 5 stable)
kubectl scale deployment app-belajar-v2 --replicas=5
kubectl scale deployment app-belajar-v1 --replicas=5

# Increase to 75% (9 canary, 3 stable)
kubectl scale deployment app-belajar-v2 --replicas=9
kubectl scale deployment app-belajar-v1 --replicas=3

# Verify distribution
kubectl get pods -l app=belajar-app -o wide
```

### 5. Complete Rollout (100% to v2)

```bash
# Scale v2 to full capacity
kubectl scale deployment app-belajar-v2 --replicas=10

# Scale down v1
kubectl scale deployment app-belajar-v1 --replicas=0

# Verify
kubectl get deployment app-belajar-v1
kubectl get deployment app-belajar-v2
```

### 6. Cleanup Old Version

```bash
# After v2 proven stable
kubectl delete deployment app-belajar-v1
```

## Rollback

If issues detected during canary:

```bash
# Scale down canary immediately
kubectl scale deployment app-belajar-v2 --replicas=0

# Or delete canary
kubectl delete deployment app-belajar-v2
```

## Traffic Distribution Examples

| v1 Replicas | v2 Replicas | v2 Traffic % |
|-------------|-------------|--------------|
| 9 | 1 | 10% |
| 3 | 1 | 25% |
| 1 | 1 | 50% |
| 1 | 3 | 75% |
| 0 | 10 | 100% |

## Testing Canary

```bash
# Generate load and observe distribution
for i in {1..100}; do
  curl http://localhost:30001/api/product
  sleep 0.1
done

# Watch which pods handle requests
kubectl logs -f -l app=belajar-app --prefix=true

# Check endpoint distribution
kubectl get endpoints app-belajar -o yaml
```

## Advantages

- **Gradual rollout**: Minimize risk
- **Real production testing**: With actual users
- **Easy rollback**: Just scale down canary
- **Flexible control**: Adjust percentage anytime

## Disadvantages

- **Manual scaling**: Need to calculate replicas
- **Coarse-grained**: Can't do exact percentages (e.g., 15%)
- **No header/cookie routing**: All users get random version
- **Need monitoring**: To detect issues early

## Considerations

- **Pod startup time**: Factor in when calculating rollout speed
- **Resource limits**: Ensure cluster can handle both versions
- **Session affinity**: Users might switch between versions
- **Database compatibility**: Both versions must work with same schema
