# Kubernetes Deep Dive Guide

**For Senior Software Engineer Interviews**

Your competitive advantage: **Production EKS experience** (6 environments, daily kubectl usage, multi-tenant workloads at scale)

---

## Quick Reference

### Production EKS Clusters

```bash
# 6 Active Environments
us-dev (full kubectl access)
us-stage (read-only)
us-uat (read-only)
us-prod (read-only)
eu-uat (read-only)
eu-prod (read-only)

# Daily Commands
kubectl get pods -n invoicing-prod
kubectl logs -f <pod> -n invoicing-prod
kubectl describe pod <pod> -n invoicing-prod
kubectl exec -it <pod> -n invoicing-dev -- /bin/bash
```

---

## Core Concepts

### Pod (Smallest Unit)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: eic-pod
  labels:
    app: eic
    env: prod
spec:
  containers:
  - name: eic
    image: Enterprise SaaS Company/eic:latest
    ports:
    - containerPort: 80
    env:
    - name: DB_HOST
      value: "billingclient1.rds.amazonaws.com"
```

**Pod = 1+ containers sharing:**
- Network namespace (localhost between containers)
- Storage volumes
- Same node

---

### Deployment (Manages Pods)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: eic
  namespace: invoicing-prod
spec:
  replicas: 10
  selector:
    matchLabels:
      app: eic
  template:
    metadata:
      labels:
        app: eic
    spec:
      containers:
      - name: eic
        image: Enterprise SaaS Company/eic:2026-11-16
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
```

**Deployment ensures:**
- 10 replicas always running
- Rolling updates (zero downtime)
- Self-healing (restarts failed pods)

---

### Service (Load Balancer)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: eic
  namespace: invoicing-prod
spec:
  type: LoadBalancer  # AWS ELB
  selector:
    app: eic
  ports:
  - port: 80
    targetPort: 80
```

**Service → Pods:**
- Discovers all pods with label `app: eic`
- Load balances across them
- Stable endpoint (DNS: `eic.invoicing-prod.svc.cluster.local`)

---

### ConfigMap & Secrets

```yaml
# ConfigMap (non-sensitive)
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: production
  LOG_LEVEL: info
  CACHE_TTL: "3600"

---
# Secret (sensitive)
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  username: YWRtaW4=  # base64 encoded
  password: cGFzc3dvcmQ=
```

**Use in Pod:**
```yaml
spec:
  containers:
  - name: eic
    env:
    - name: APP_ENV
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_ENV
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
```

---

## Your Daily kubectl Commands

### Get Resources

```bash
# List pods
kubectl get pods -n invoicing-prod
kubectl get pods -n invoicing-prod -l app=eic  # Filter by label

# Wide output (node, IP)
kubectl get pods -n invoicing-prod -o wide

# Watch (live updates)
kubectl get pods -n invoicing-prod --watch

# All resources
kubectl get all -n invoicing-prod
```

### Logs

```bash
# Tail logs
kubectl logs -f <pod-name> -n invoicing-prod

# Last 100 lines
kubectl logs <pod-name> -n invoicing-prod --tail=100

# Specific container (multi-container pod)
kubectl logs <pod-name> -c <container-name> -n invoicing-prod

# Previous crashed pod
kubectl logs <pod-name> -n invoicing-prod --previous
```

### Describe (Debug Info)

```bash
# Pod details
kubectl describe pod <pod-name> -n invoicing-prod

# Shows:
# - Events (why pod crashed)
# - Resource usage
# - Restart count
# - Node placement
```

### Exec (SSH into pod)

```bash
# Bash shell (dev only)
kubectl exec -it <pod-name> -n invoicing-dev -- /bin/bash

# Run single command
kubectl exec <pod-name> -n invoicing-dev -- php artisan migrate:status
```

### Edit Resources

```bash
# Edit deployment (live)
kubectl edit deployment eic -n invoicing-prod

# Scale replicas
kubectl scale deployment eic -n invoicing-prod --replicas=15
```

### Rollout Management

```bash
# Check rollout status
kubectl rollout status deployment/eic -n invoicing-prod

# Rollout history
kubectl rollout history deployment/eic -n invoicing-prod

# Rollback to previous version
kubectl rollout undo deployment/eic -n invoicing-prod

# Rollback to specific revision
kubectl rollout undo deployment/eic -n invoicing-prod --to-revision=3
```

---

## Interview Questions & Answers

### Q1: "Explain the difference between a Pod, Deployment, and Service in Kubernetes."

**Your Answer:**

> *"In a production environment, we use all three for our EIC application:*
> 
> **Pod (Atomic Unit):**
> *- Smallest deployable unit*
> *- 1+ containers sharing network + storage*
> *- Ephemeral (can die anytime)*
> *- Example: eic-pod-abc123 running our PHP app*
> 
> **Deployment (Controller):**
> *- Manages a set of identical pods (replica set)*
> *- Ensures desired state (10 replicas always running)*
> *- Handles updates (rolling deployment)*
> *- Self-healing (restarts failed pods)*
> 
> ```yaml
> Deployment: eic (replicas: 10)
>   ↓
> Creates 10 Pods: eic-abc, eic-def, eic-ghi, ...
> ```
> 
> **Service (Load Balancer):**
> *- Stable network endpoint for pods*
> *- Load balances across all healthy pods*
> *- DNS name: `eic.invoicing-prod.svc.cluster.local`*
> *- Type LoadBalancer → creates AWS ELB*
> 
> ```
> User → AWS ELB (Service) → Round-robin to 10 Pods
> ```
> 
> **Real-world flow:**
> *1. Deploy: `kubectl apply -f deployment.yaml` creates 10 pods*
> *2. Service discovers them via label selector `app: eic`*
> *3. AWS ELB routes traffic across all 10*
> *4. If pod dies, Deployment creates replacement*
> *5. Service auto-updates to route to new pod*
> 
> **Why Deployment vs Pod directly?**
> *- Pod dies → manually recreate*
> *- Deployment → auto-recreates*
> *- Deployment enables rolling updates, scaling, rollback*"*

---

### Q2: "How do you troubleshoot a pod that's in CrashLoopBackOff?"

**Your Answer:**

> *"CrashLoopBackOff means the pod keeps crashing and Kubernetes is backing off retries. In a production environment, here's my debugging workflow:*
> 
> **Step 1: Check Pod Status**
> ```bash
> kubectl get pods -n invoicing-prod
> # NAME                   READY   STATUS             RESTARTS
> # eic-abc123             0/1     CrashLoopBackOff   5
> ```
> 
> **Step 2: Describe Pod (See Events)**
> ```bash
> kubectl describe pod eic-abc123 -n invoicing-prod
> 
> # Look for:
> # Events:
> #   Type     Reason     Message
> #   Warning  BackOff    Back-off restarting failed container
> #   Warning  Failed     Error: ImagePullBackOff
> ```
> 
> **Step 3: Check Logs**
> ```bash
> # Current attempt
> kubectl logs eic-abc123 -n invoicing-prod
> 
> # Previous crash
> kubectl logs eic-abc123 -n invoicing-prod --previous
> ```
> 
> **Common Causes I've Seen:**
> 
> **1. Missing Environment Variable**
> ```
> # Log shows:
> Error: DB_HOST not set
> 
> # Fix: Add to deployment
> env:
> - name: DB_HOST
>   value: "billingclient1.rds.amazonaws.com"
> ```
> 
> **2. Database Connection Failed**
> ```
> # Log shows:
> SQLSTATE[HY000] [2002] Connection refused
> 
> # Debug:
> kubectl exec -it eic-abc123 -n invoicing-dev -- /bin/bash
> mysql -h billingclient1.rds.amazonaws.com -u admin -p
> 
> # Usually: Security group blocking pod → RDS
> ```
> 
> **3. Out of Memory (OOMKilled)**
> ```bash
> kubectl describe pod eic-abc123 -n invoicing-prod
> # Last State: Terminated
> # Reason: OOMKilled
> 
> # Fix: Increase memory limit
> resources:
>   limits:
>     memory: "2Gi"  # Was 1Gi
> ```
> 
> **4. Health Check Failing**
> ```yaml
> livenessProbe:
>   httpGet:
>     path: /health
>     port: 80
>   initialDelaySeconds: 30  # PHP-FPM takes time to start
> ```
> 
> **5. Image Pull Error**
> ```
> # Events show:
> Failed to pull image "Enterprise SaaS Company/eic:wrong-tag"
> 
> # Fix: Correct image tag
> image: Enterprise SaaS Company/eic:2026-11-16
> ```
> 
> **Real Enterprise SaaS Company Incident:**
> *- EIC pods CrashLoopBackOff after deploy*
> *- Logs: "Class 'Redis' not found"*
> *- Root cause: Forgot to install php-redis extension in Docker image*
> *- Fix: Updated Dockerfile, rebuilt image*
> *- Deployed new image, pods started successfully*"*

---

### Q3: "Explain how Kubernetes rolling updates work and how to ensure zero downtime."

**Your Answer:**

> *"In a production environment, we use rolling updates for all production deployments:*
> 
> **Rolling Update Strategy:**
> ```yaml
> spec:
>   replicas: 10
>   strategy:
>     type: RollingUpdate
>     rollingUpdate:
>       maxSurge: 2        # Can have 12 pods during update
>       maxUnavailable: 1  # Always 9+ pods serving traffic
> ```
> 
> **Update Process:**
> 1. Create 2 new v2.0 pods (total: 12)
> 2. Wait for v2.0 pods to pass readiness probe
> 3. Terminate 1 old v1.0 pod (total: 11)
> 4. Create 1 new v2.0 pod (total: 12)
> 5. Repeat until all 10 pods are v2.0
> 
> **Zero-Downtime Checklist:**
> 
> **1. Readiness Probe (CRITICAL)**
> ```yaml
> readinessProbe:
>   httpGet:
>     path: /ready
>     port: 80
>   initialDelaySeconds: 5
>   periodSeconds: 5
>   failureThreshold: 3
> ```
> *- Pod NOT ready → no traffic sent*
> *- Ensures new pods fully booted before traffic*
> 
> **2. Liveness Probe**
> ```yaml
> livenessProbe:
>   httpGet:
>     path: /health
>     port: 80
>   initialDelaySeconds: 30
>   periodSeconds: 10
> ```
> *- Pod unhealthy → Kubernetes restarts it*
> 
> **3. Graceful Shutdown**
> ```yaml
> lifecycle:
>   preStop:
>     exec:
>       command: ["/bin/sh", "-c", "sleep 15"]
> ```
> *- Kubernetes sends SIGTERM*
> *- App finishes in-flight requests (15s)*
> *- Then force kill (SIGKILL)*
> 
> **4. Resource Limits (Prevent OOM)**
> ```yaml
> resources:
>   requests:
>     memory: "512Mi"
>     cpu: "500m"
>   limits:
>     memory: "1Gi"
>     cpu: "1000m"
> ```
> 
> **5. PodDisruptionBudget (High Availability)**
> ```yaml
> apiVersion: policy/v1
> kind: PodDisruptionBudget
> metadata:
>   name: eic-pdb
> spec:
>   minAvailable: 8  # Always 8+ pods during updates/node drain
>   selector:
>     matchLabels:
>       app: eic
> ```
> 
> **Monitoring During Rollout:**
> ```bash
> # Watch rollout
> kubectl rollout status deployment/eic -n invoicing-prod
> 
> # CloudWatch alarms
> # - Error rate < 1%
> # - Latency P95 < 500ms
> # - If spike → auto-rollback
> ```
> 
> **Database Migrations (Backward Compatibility):**
> ```
> Release 1: Add new column (old code still works)
> Release 2: Code uses new column (both columns exist)
> Release 3: Remove old column (only new code deployed)
> ```
> 
> **Result: Users see nothing. Traffic seamlessly shifts from v1 to v2."*

---

## Summary: Your Kubernetes Expertise

**When Asked About Kubernetes:**

> *"In a production environment, I manage production EKS workloads across 6 environments. I use kubectl daily — get pods, logs, describe for debugging, exec for troubleshooting in dev.*
> 
> *Our EIC application runs 10 replicas in production with rolling updates (maxSurge=2, maxUnavailable=1) for zero downtime. We use readiness probes to ensure pods are healthy before traffic, liveness probes for auto-restart, and PodDisruptionBudgets to maintain availability during node maintenance.*
> 
> *For troubleshooting CrashLoopBackOff, I start with describe for events, then logs (current and previous), then exec to test connectivity. Common issues: missing env vars, database connection failures, OOMKilled, health check timeouts.*
> 
> *Our deployments are fully GitOps — infrastructure as code in Git, deployed via kubectl apply, with automated rollback on health check failures."*

---

**Kubernetes expertise complete!** ☸️

Creating final 2 guides...
