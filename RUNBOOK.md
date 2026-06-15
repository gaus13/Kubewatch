# CareerLens KubeWatch Runbook

## What is this?
This runbook documents how to respond to alerts
and incidents for CareerLens running on AWS EKS.

## Architecture
- Frontend: React (Vite) — 2 replicas
- Backend:  FastAPI — 2 replicas  
- Database: PostgreSQL — StatefulSet + EBS
- Cluster:  AWS EKS ap-south-1
- Monitor:  Prometheus + Grafana

---

## Alert: Pod Crash Looping
**Severity:** High  
**Condition:** Pod restarts > 3 in 5 minutes

### Immediate Steps
1. `kubectl get pods -n dev`
2. `kubectl logs <pod-name> -n dev --previous`
3. `kubectl describe pod <pod-name> -n dev`

### Common Causes
| Cause | Fix |
|-------|-----|
| OOM killed | `kubectl set resources deployment/backend -n dev --limits=memory=512Mi` |
| Bad image | `kubectl rollout undo deployment/backend -n dev` |
| DB connection | Check DATABASE_URL secret |
| Probe too strict | Increase initialDelaySeconds |

---

## Alert: High CPU Usage
**Severity:** Medium  
**Condition:** CPU > 80% for 5 minutes

### Steps
1. `kubectl top pods -n dev`
2. `kubectl get hpa -n dev`
3. If HPA maxed: `kubectl scale deployment/backend --replicas=5 -n dev`

---

## Alert: Deployment Rollout Stuck
**Severity:** High

### Steps
1. `kubectl rollout status deployment/backend -n dev`
2. `kubectl describe deployment backend -n dev`
3. `kubectl rollout undo deployment/backend -n dev`

---

## Useful Commands
```bash
# Check all pods
kubectl get pods -n dev

# Check pod logs
kubectl logs <pod> -n dev

# Check resource usage
kubectl top pods -n dev

# Manual rollback
kubectl rollout undo deployment/backend -n dev

# Scale manually
kubectl scale deployment/backend --replicas=3 -n dev
```

## Self-Healing Results
| Experiment | Recovery Time | Impact |
|------------|--------------|--------|
| Kill 1 pod | ~18 seconds | Zero |
| Kill all pods | ~25 seconds | Full recovery |
| OOM kill | ~10 seconds | Auto restart |
| Bad probe | CrashLoopBackOff | Auto backoff |
| Load test | Scale 2→5 pods | ~60 seconds |
