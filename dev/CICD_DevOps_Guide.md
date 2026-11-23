# CI/CD Pipelines & DevOps Guide

**For Senior Software Engineer Interviews**

Your competitive advantage: **Production release management** (cert process, zero-downtime deployments, automated testing, 99.9% uptime)

---

## Table of Contents

1. [CI/CD Fundamentals](#cicd-fundamentals)
2. [Pipeline Stages](#pipeline-stages)
3. [Deployment Strategies](#deployment-strategies)
4. [Production Release Process](#your-Enterprise SaaS Company-release-process)
5. [Infrastructure as Code](#infrastructure-as-code)
6. [Monitoring & Rollback](#monitoring--rollback)
7. [Interview Questions & Answers](#interview-questions--answers)

---

## CI/CD Fundamentals

### CI (Continuous Integration)

**Goal:** Merge code frequently, catch bugs early

```
Developer pushes code
  ↓
Git webhook triggers pipeline
  ↓
1. Checkout code
2. Install dependencies
3. Run linters (PHPStan, ESLint)
4. Run unit tests
5. Run integration tests
6. Security scan (Checkmarx)
7. Build artifacts
  ↓
If ALL pass → Merge to main
If ANY fail → Block merge
```

**Benefits:**
- Find bugs in minutes, not days
- No "it works on my machine"
- Always deployable main branch

### CD (Continuous Delivery vs Deployment)

**Continuous Delivery:**
- Automate UNTIL production
- Manual approval for production deploy
- ← **Production cert process**

**Continuous Deployment:**
- Fully automated to production
- No manual gates

```
Continuous Delivery:
main → auto-deploy → Dev
            ↓
       auto-deploy → Stage
            ↓
       auto-deploy → UAT
            ↓
    [MANUAL APPROVAL] ← Cert review
            ↓
       auto-deploy → Production

Continuous Deployment:
main → auto-deploy ALL environments
```

---

## Pipeline Stages

### Stage 1: Build

```yaml
# GitHub Actions
name: Build
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
      
      - name: Install dependencies
        run: composer install --no-dev --optimize-autoloader
      
      - name: Build assets
        run: npm run production
      
      - name: Create artifact
        run: tar -czf app.tar.gz *
      
      - name: Upload artifact
        uses: actions/upload-artifact@v2
        with:
          name: app-build
          path: app.tar.gz
```

### Stage 2: Test

```yaml
test:
  needs: build
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v2
    
    # Unit tests
    - name: PHPUnit
      run: vendor/bin/phpunit --testsuite=Unit
    
    # Integration tests
    - name: Integration tests
      run: vendor/bin/phpunit --testsuite=Integration
      env:
        DB_HOST: mysql
        REDIS_HOST: redis
    
    # Code coverage
    - name: Coverage
      run: vendor/bin/phpunit --coverage-clover coverage.xml
    
    - name: Upload coverage
      uses: codecov/codecov-action@v2
```

### Stage 3: Security & Quality

```yaml
security:
  needs: test
  runs-on: ubuntu-latest
  steps:
    # Static analysis
    - name: PHPStan
      run: vendor/bin/phpstan analyze
    
    # Security vulnerabilities
    - name: Composer audit
      run: composer audit
    
    # Checkmarx scan
    - name: Checkmarx
      uses: checkmarx/ast-github-action@v1
      with:
        cx_tenant: ${{ secrets.CX_TENANT }}
        cx_client_id: ${{ secrets.CX_CLIENT_ID }}
        cx_client_secret: ${{ secrets.CX_CLIENT_SECRET }}
```

### Stage 4: Deploy

```yaml
deploy-dev:
  needs: security
  if: github.ref == 'refs/heads/develop'
  runs-on: ubuntu-latest
  steps:
    - name: Download artifact
      uses: actions/download-artifact@v2
      with:
        name: app-build
    
    - name: Deploy to Dev
      run: |
        scp app.tar.gz deploy@dev-server:/var/www/
        ssh deploy@dev-server 'cd /var/www && tar -xzf app.tar.gz && php artisan migrate'

deploy-prod:
  needs: security
  if: github.ref == 'refs/heads/main' && github.event_name == 'workflow_dispatch'
  runs-on: ubuntu-latest
  environment:
    name: production
    url: https://app.Enterprise SaaS Company.com
  steps:
    - name: Deploy to Production
      run: ./deploy-prod.sh
```

---

## Deployment Strategies

### 1. Blue-Green Deployment

**Concept:** Two identical environments, switch traffic

```
Production Traffic → [Blue] (Current: v1.0)
                     [Green] (Standby: empty)

1. Deploy v2.0 to Green
2. Test Green (not live yet)
3. Switch load balancer: Blue ← Green
4. Production Traffic → [Green] (New: v2.0)
                        [Blue] (Standby: v1.0)
5. Keep Blue for instant rollback
```

**AWS Implementation:**
```bash
# Current: Blue (v1.0)
aws elasticbeanstalk describe-environments --application-name myapp

# Deploy to Green
aws elasticbeanstalk create-environment \
  --application-name myapp \
  --environment-name myapp-green \
  --version-label v2.0

# Test Green
curl https://myapp-green.elasticbeanstalk.com/health

# Swap URLs (instant traffic switch)
aws elasticbeanstalk swap-environment-cnames \
  --source-environment-name myapp-blue \
  --destination-environment-name myapp-green

# Rollback (if needed)
aws elasticbeanstalk swap-environment-cnames \
  --source-environment-name myapp-green \
  --destination-environment-name myapp-blue
```

**Pros:**
- Instant cutover (DNS switch)
- Instant rollback
- Zero downtime

**Cons:**
- 2x infrastructure cost
- Database migrations tricky (must be backward compatible)

---

### 2. Canary Deployment

**Concept:** Gradual rollout to small % of users

```
100% Traffic → v1.0

Step 1: 5% → v2.0, 95% → v1.0  (monitor errors, latency)
Step 2: 25% → v2.0, 75% → v1.0
Step 3: 50% → v2.0, 50% → v1.0
Step 4: 100% → v2.0
```

**Kubernetes Implementation:**
```yaml
# Service (routes traffic)
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp  # Matches BOTH v1 and v2 pods

---
# v1.0 Deployment (5 replicas = 95%)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-v1
spec:
  replicas: 19
  selector:
    matchLabels:
      app: myapp
      version: v1
  template:
    metadata:
      labels:
        app: myapp
        version: v1
    spec:
      containers:
      - name: myapp
        image: myapp:v1.0

---
# v2.0 Deployment (1 replica = 5%)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      version: v2
  template:
    metadata:
      labels:
        app: myapp
        version: v2
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0

# Gradually scale v2 up, v1 down
```

**Pros:**
- Low-risk (only 5% affected if broken)
- Real production traffic testing
- Gradual confidence building

**Cons:**
- Slower rollout
- Complex traffic routing
- Need good monitoring

---

### 3. Rolling Deployment

**Concept:** Replace instances one-by-one

```
Load Balancer → [Server 1: v1.0] [Server 2: v1.0] [Server 3: v1.0]

Step 1: Deploy v2.0 to Server 1
LB → [Server 1: v2.0] [Server 2: v1.0] [Server 3: v1.0]

Step 2: Deploy v2.0 to Server 2
LB → [Server 1: v2.0] [Server 2: v2.0] [Server 3: v1.0]

Step 3: Deploy v2.0 to Server 3
LB → [Server 1: v2.0] [Server 2: v2.0] [Server 3: v2.0]
```

**Kubernetes (Default):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # Max 12 pods during rollout (10 + 2)
      maxUnavailable: 1  # Min 9 pods available (10 - 1)
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0

# Rollout process:
# - Create 2 new v2.0 pods (maxSurge)
# - Terminate 1 old v1.0 pod (maxUnavailable)
# - Wait for new pods healthy
# - Repeat until all v2.0
```

**Pros:**
- Simple
- No extra infrastructure
- Kubernetes default

**Cons:**
- Slow (minutes for 100 pods)
- Mixed versions during rollout

---

### 4. Recreate (Production Non-Critical Apps)

**Concept:** Stop all, then start new

```
1. Stop all v1.0 pods
2. Deploy v2.0 pods
3. Start v2.0

Downtime: ~30 seconds
```

**When to Use:**
- Non-critical apps (background workers)
- Can tolerate 30s downtime
- Database schema changes (can't run 2 versions)

---

## Production Release Process

### Cert Workflow (EIC, CC, CSR)

**Branch Strategy:**
```
main (production)
  ↑
release/2026-11-16 (cert branch)
  ↑
feature/INV-1234 (dev work)
```

**Release Steps:**

**1. Pre-Cut Readiness**
```bash
# Check all tickets in Fix Version
jira-cli list --fixVersion "EIC-2026-11-16"

# Verify:
# - All tickets: Status = Done
# - All tickets: MR linked
# - All commits: Accounted for in tickets
# - No untracked changes in branch

# Run release-readiness skill
/release-readiness EIC-2026-11-16
```

**2. Cut Release Branch**
```bash
git checkout develop
git pull origin develop
git checkout -b release/2026-11-16
git push origin release/2026-11-16
```

**3. Deploy to Stage**
```bash
# Pipeline auto-deploys release/* to stage
# Triggered by branch push

# Verify at:
# https://stage-eic.Enterprise SaaS Company.com/cc-status/version.php
```

**4. Record Pipeline ID**
```bash
# Get from GitHub Actions / GitLab CI
PIPELINE_ID=12345

# Record in cert ticket (NJQRT-XXXX)
jira-cli comment NJQRT-XXXX "Production Pipeline ID: $PIPELINE_ID"
```

**5. Checkmarx Scan**
```bash
# Scan runs automatically on pipeline
# Check for NEW findings (not RECURRENT)

# If NEW findings:
# - Fix immediately OR
# - Document risk acceptance
```

**6. QA Testing (Stage)**
```
QA Team tests:
- Smoke tests (critical paths)
- Fix verification (tickets in Fix Version)
- Regression tests (nothing broke)

Status: QA Review → Ready for Security Approval
```

**7. UAT Deployment**
```bash
# Manual approval required
# Deploy same pipeline to UAT

# Security team tests:
# - Penetration testing
# - Compliance checks (PCI, HIPAA)

Status: Ready for Security Approval → Pending Deployment
```

**8. Production Deployment**
```bash
# Manual approval (Director+)
# Deploy same pipeline to Production

# Zero-downtime rolling deployment:
# - 10 pods in EKS
# - Rolling update: maxSurge=2, maxUnavailable=1
# - Total time: ~5 minutes

# Verify:
curl https://eic.Enterprise SaaS Company.com/health
# Expected: 200 OK, version: 2026-11-16
```

**9. Post-Deployment Verification**
```bash
# CloudWatch alarms (30 min monitoring)
# - Error rate < 1%
# - Latency P95 < 500ms
# - 5xx errors < 10/min

# Smoke tests in production
./smoke-test-prod.sh

# If ALL pass:
# - Mark cert ticket Done
# - Close all Fix Version tickets
```

**10. Rollback (If Needed)**
```bash
# Kubernetes rollback (instant)
kubectl rollout undo deployment/eic -n invoicing-prod

# Or: Re-deploy previous pipeline
# Same zero-downtime process
```

### Your Release Metrics

- **Frequency:** Weekly releases (every Friday)
- **Lead Time:** 3-5 days (dev → prod)
- **MTTR:** < 15 minutes (rollback)
- **Success Rate:** 99%+ (failed: 1 in 100)
- **Downtime:** Zero (rolling deployments)

---

## Infrastructure as Code

### Terraform (AWS Infrastructure)

```hcl
# EKS Cluster
resource "aws_eks_cluster" "invoicing" {
  name     = "invoicing-prod"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28"

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
      aws_subnet.private_c.id
    ]
  }
}

# RDS MySQL
resource "aws_db_instance" "billingclient1" {
  identifier = "billingclient1-prod"
  engine     = "mysql"
  engine_version = "8.0"
  instance_class = "db.r5.2xlarge"
  allocated_storage = 1000
  
  multi_az = true  # High availability
  backup_retention_period = 7
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.private.name
}

# ElastiCache Redis
resource "aws_elasticache_cluster" "redis" {
  cluster_id = "redis-prod"
  engine     = "redis"
  node_type  = "cache.r5.large"
  num_cache_nodes = 3
  
  parameter_group_name = "default.redis7"
  port                = 6379
}
```

### Kubernetes Manifests

```yaml
# Deployment
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
        ports:
        - containerPort: 80
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: host
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5

---
# Service (Load Balancer)
apiVersion: v1
kind: Service
metadata:
  name: eic
  namespace: invoicing-prod
spec:
  type: LoadBalancer
  selector:
    app: eic
  ports:
  - port: 80
    targetPort: 80
```

---

## Monitoring & Rollback

### CloudWatch Alarms

```python
# High error rate
alarm = cloudwatch.put_metric_alarm(
    AlarmName='EIC-HighErrorRate',
    MetricName='5XXError',
    Namespace='AWS/ELB',
    Statistic='Sum',
    Period=60,  # 1 minute
    EvaluationPeriods=2,
    Threshold=10,  # > 10 errors in 2 min
    ComparisonOperator='GreaterThanThreshold',
    AlarmActions=[sns_topic_arn]
)

# High latency
alarm = cloudwatch.put_metric_alarm(
    AlarmName='EIC-HighLatency',
    MetricName='TargetResponseTime',
    Namespace='AWS/ELB',
    Statistic='Average',
    Period=60,
    EvaluationPeriods=3,
    Threshold=0.5,  # > 500ms
    ComparisonOperator='GreaterThanThreshold'
)
```

### Automated Rollback

```yaml
# GitHub Actions
deploy-prod:
  steps:
    - name: Deploy
      run: kubectl apply -f k8s/prod/
    
    - name: Wait for rollout
      run: kubectl rollout status deployment/eic -n invoicing-prod --timeout=5m
    
    - name: Health check
      run: |
        for i in {1..30}; do
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://eic.Enterprise SaaS Company.com/health)
          if [ $STATUS -eq 200 ]; then
            echo "Health check passed"
            exit 0
          fi
          sleep 10
        done
        echo "Health check failed"
        exit 1
    
    - name: Rollback on failure
      if: failure()
      run: kubectl rollout undo deployment/eic -n invoicing-prod
```

---

## Interview Questions & Answers

### Q1: "Explain your CI/CD pipeline. What stages does it have?"

**Your Answer:**

> *"In a production environment, our CI/CD pipeline has 5 stages for every code change:*
> 
> **Stage 1: Build (2-3 min)**
> *- Checkout code from GitHub*
> *- Install PHP dependencies (Composer)*
> *- Install JavaScript dependencies (npm)*
> *- Compile assets (Laravel Mix)*
> *- Create deployable artifact (tar.gz)*
> 
> **Stage 2: Test (5-10 min)**
> *- PHPUnit unit tests (~500 tests)*
> *- Integration tests (hit test database)*
> *- Cypress E2E tests (critical user paths)*
> *- Code coverage (must be > 70%)*
> 
> **Stage 3: Quality & Security (10-15 min)**
> *- PHPStan static analysis (type safety)*
> *- PHP_CodeSniffer (coding standards)*
> *- Composer audit (dependency vulnerabilities)*
> *- Checkmarx scan (SAST - finds SQL injection, XSS)*
> *- **Block merge if ANY security findings***
> 
> **Stage 4: Auto-Deploy to Dev**
> *- On develop branch merge*
> *- Deploy to dev-eic.Enterprise SaaS Company.com*
> *- Developers test immediately*
> 
> **Stage 5: Manual Release Process**
> *- Cut release branch (release/2026-11-16)*
> *- Auto-deploy to Stage → UAT → Production*
> *- Manual approval gates at each environment*
> *- Checkmarx re-scan on release branch*
> *- QA testing in Stage*
> *- Security testing in UAT*
> *- Production deploy after Director approval*
> 
> **Key Metrics:**
> *- Total pipeline time: ~20 minutes (dev)*
> *- Dev → Prod lead time: 3-5 days*
> *- Deployment frequency: Weekly*
> *- MTTR (rollback): < 15 minutes*
> *- Zero downtime (rolling Kubernetes deployments)*"*

---

### Q2: "How do you do zero-downtime deployments?"

**Your Answer:**

> *"In a production environment, we use Kubernetes rolling deployments for zero downtime:*
> 
> **Architecture:**
> *- 10 EIC pods behind a load balancer*
> *- All pods serve traffic simultaneously*
> 
> **Deployment Strategy:**
> ```yaml
> strategy:
>   type: RollingUpdate
>   rollingUpdate:
>     maxSurge: 2        # Can temporarily have 12 pods
>     maxUnavailable: 1  # Always 9+ pods serving traffic
> ```
> 
> **Rollout Process:**
> *1. Create 2 new v2.0 pods (total: 12 pods)*
> *2. Wait for v2.0 pods to pass health checks*
> *3. Load balancer starts sending traffic to v2.0*
> *4. Terminate 1 old v1.0 pod (total: 11 pods)*
> *5. Repeat until all 10 pods are v2.0*
> 
> **Health Checks (Critical):**
> ```yaml
> readinessProbe:
>   httpGet:
>     path: /ready
>     port: 80
>   initialDelaySeconds: 5
>   periodSeconds: 5
> 
> livenessProbe:
>   httpGet:
>     path: /health
>     port: 80
>   initialDelaySeconds: 30
>   periodSeconds: 10
> ```
> *- Pod NOT ready → no traffic sent*
> *- Pod fails liveness → Kubernetes restarts it*
> 
> **Database Migrations (Tricky Part):**
> *- **Backward-compatible migrations only***
> *- Add column → Deploy code → Remove old column (2 releases)*
> *- Never: Drop column in same release as code*
> 
> **Example:**
> ```
> Release 1: ALTER TABLE invoices ADD COLUMN status_v2
> Release 1 Code: Writes to BOTH status, status_v2
> (Both versions work)
> Release 2: Code uses only status_v2
> Release 3: ALTER TABLE invoices DROP COLUMN status
> ```
> 
> **Traffic Draining:**
> *- Kubernetes waits 30s before killing pod*
> *- Existing requests complete*
> *- New requests go to new pods*
> 
> **Monitoring During Deploy:**
> *- Watch error rate (< 1%)*
> *- Watch latency (< 500ms P95)*
> *- If spike → auto-rollback*
> 
> **Result: Users see NOTHING during deploy"*

---

### Q3: "Describe a time you had to rollback a production deployment. What went wrong and how did you handle it?"

**Your Answer:**

> *"Real incident In a production environment (2025-10):**
> 
> **What We Deployed:**
> *- EIC invoice PDF generation optimization*
> *- Replaced old library with new one (3x faster in testing)*
> 
> **What Went Wrong:**
> *- 15 minutes after production deploy, PagerDuty alerts*
> *- CloudWatch: 5xx errors spiked from 0 to 200/min*
> *- Users reporting: "Invoice PDFs are blank"*
> 
> **Root Cause:**
> *- New library didn't handle special characters in invoices (German umlauts, accented chars)*
> *- Our tests only had English invoices*
> *- 10% of customers affected (international)*
> 
> **Immediate Response (5 minutes):**
> *1. Page on-call team (me + DBA + DevOps)*
> *2. Check CloudWatch logs: PDF rendering errors*
> *3. Decision: ROLLBACK (don't debug in production)*
> *4. Execute:*
> ```bash
> kubectl rollout undo deployment/eic -n invoicing-prod
> # Rolling update back to v1.0 (previous version)
> # Completed in 3 minutes
> ```
> *5. Verify: Error rate back to 0*
> 
> **Post-Rollback (30 minutes):**
> *- Replicate bug in dev: German invoice → blank PDF*
> *- Found: Missing charset configuration*
> *- Fix + test with international invoices*
> *- Re-deploy to Stage → QA verified*
> 
> **Next Day:**
> *- Added international invoice test suite*
> *- Expanded Cypress tests (20 languages)*
> *- Re-deployed fix to production (successful)*
> 
> **Lessons Learned:**
> *1. **Test diversity matters** - not just volume*
> *2. **Rollback is cheap** - 3 minutes vs hours debugging*
> *3. **Monitor first 30 min** - catch issues fast*
> *4. **Blameless postmortem** - focus on process, not person*
> 
> **Metrics:**
> *- Total incident: 8 minutes (alert → rollback complete)*
> *- MTTR: 5 minutes (decision → recovery)*
> *- User impact: 10% for 8 minutes*
> *- Zero data loss (PDFs regenerated after fix)*
> 
> **This is why we:**
> *- Keep previous version in Kubernetes (instant rollback)*
> *- Have automated rollback on health check failure*
> *- Monitor aggressively first 30 min after deploy*"*

---

## Summary: Your DevOps Expertise

**When Asked About CI/CD:**

> *"In a production environment, I manage the release process for EIC, CC, and CSR across 6 environments. Our CI/CD pipeline runs 20 minutes on every commit — build, test, security scan (Checkmarx), auto-deploy to Dev.*
> 
> *For production, we follow a cert workflow: weekly release branches, auto-deploy to Stage for QA testing, UAT for security approval, then production with Director approval. We use Kubernetes rolling deployments for zero downtime — 10 pods, rolling 2 at a time, 5-minute total rollout.*
> 
> *Database migrations are backward-compatible only (add column → deploy code → remove old column across 2 releases). Health checks ensure no traffic hits unhealthy pods.*
> 
> *We monitor CloudWatch for 30 minutes post-deploy — error rate, latency, 5xx count. If anything spikes, we rollback via kubectl in under 5 minutes. Our MTTR is 15 minutes, deployment success rate is 99%+, and we've maintained 99.9% uptime."*

---

**CI/CD & DevOps expertise complete!** 🚀

Creating final 3 guides...
