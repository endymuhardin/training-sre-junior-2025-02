# Blue-Green Deployment Example

Blue-Green deployment maintains two identical production environments. Traffic is switched instantly from old (blue) to new (green) version.

## Steps

### 1. Deploy Blue (Current Version)

```bash
kubectl apply -f 01-blue-deployment.yml
kubectl apply -f 03-service.yml

# Verify blue is running
kubectl get pods -l version=blue
```

### 2. Deploy Green (New Version)

```bash
kubectl apply -f 02-green-deployment.yml

# Wait until ready
kubectl wait --for=condition=ready pod -l version=green --timeout=300s

# Check both versions running
kubectl get pods -l app=belajar-app
```

### 3. Test Green Environment

```bash
# Port-forward to green directly
kubectl port-forward deployment/app-belajar-green 9090:8080

# Test in browser or curl
curl http://localhost:9090/api/product
```

### 4. Switch Traffic to Green

```bash
# Update service selector to point to green
kubectl patch service app-belajar -p '{"spec":{"selector":{"version":"green"}}}'

# Verify switch
kubectl get service app-belajar -o yaml | grep -A 2 selector
kubectl get endpoints app-belajar
```

### 5. Rollback to Blue (if needed)

```bash
# Switch back to blue
kubectl patch service app-belajar -p '{"spec":{"selector":{"version":"blue"}}}'
```

### 6. Cleanup Old Version

```bash
# After green is stable, delete blue
kubectl delete deployment app-belajar-blue
```

## Advantages

- **Instant traffic switch**: No gradual rollout needed
- **Easy rollback**: Just switch service selector back
- **Zero downtime**: Both versions ready
- **Full testing**: Test in production before switch

## Disadvantages

- **Double resources**: Need 2x resources during transition
- **Database complexity**: Both versions must work with same schema
- **Cost**: Higher infrastructure cost
