# AWS Services and Architecture Guide

## 📋 Table of Contents

1. [AWS Overview](#aws-overview)
2. [Core Compute Services](#core-compute-services)
3. [Storage Services](#storage-services)
4. [Database Services](#database-services)
5. [Networking & Content Delivery](#networking--content-delivery)
6. [Security & Identity](#security--identity)
7. [Application Integration](#application-integration)
8. [Monitoring & Operations](#monitoring--operations)
9. [Common Architecture Patterns](#common-architecture-patterns)
10. [Production AWS Experience](#your-Enterprise SaaS Company-aws-experience)
11. [Cost Optimization](#cost-optimization)
12. [Interview Questions](#interview-questions)

---

## AWS Overview

**What is AWS?**
Amazon Web Services - cloud computing platform offering 200+ services

**Key Benefits:**
- **Scalability:** Scale up/down based on demand
- **Pay-as-you-go:** Only pay for what you use
- **Global:** 30+ regions worldwide
- **Reliability:** 99.99% SLA on many services
- **Security:** Enterprise-grade security built-in

**AWS Regions & Availability Zones:**
```
Region (e.g., us-east-1)
  ├── Availability Zone 1 (us-east-1a) - Separate data center
  ├── Availability Zone 2 (us-east-1b) - Separate data center
  └── Availability Zone 3 (us-east-1c) - Separate data center
```

**Why multiple AZs?**
- High availability (if one AZ fails, others continue)
- Disaster recovery
- Low-latency failover

---

## Core Compute Services

### 1. EC2 (Elastic Compute Cloud)

**What:** Virtual servers in the cloud

**Instance Types:**
- **t3.micro/small/medium** - Burstable, general purpose (dev/test, low-traffic web)
- **t3.large/xlarge** - Burstable, more CPU credits
- **m5.large/xlarge/2xlarge** - General purpose (balanced CPU/memory)
- **c5.large/xlarge** - Compute optimized (CPU-intensive workloads)
- **r5.large/xlarge** - Memory optimized (databases, caching)
- **g4dn.xlarge** - GPU instances (ML training)

**Pricing Models:**
```
On-Demand:    $0.10/hour  (pay by the hour, no commitment)
Reserved:     $0.06/hour  (1-3 year commitment, 40% savings)
Spot:         $0.03/hour  (bid on unused capacity, 70% savings, can be terminated)
Savings Plan: $0.07/hour  (commit to $ amount per hour, flexibility)
```

**Auto Scaling:**
```
Define scaling policy:
  - Min instances: 2
  - Max instances: 10
  - Target CPU: 70%
  
When CPU > 70% → Scale out (add instances)
When CPU < 30% → Scale in (remove instances)
```

**User Data (Bootstrap Script):**
```bash
#!/bin/bash
yum update -y
yum install -y docker
systemctl start docker
docker run -d -p 80:80 myapp:latest
```

---

### 2. Lambda (Serverless Functions)

**What:** Run code without managing servers

**Characteristics:**
- **Pay per request:** First 1M requests free, then $0.20 per 1M
- **Pay per duration:** $0.0000166667 per GB-second
- **Max runtime:** 15 minutes
- **Languages:** Node.js, Python, Java, Go, Ruby, .NET

**Use cases:**
- API backends
- Data processing (S3 uploads, DynamoDB streams)
- Scheduled tasks (cron jobs)
- Event-driven workflows

**Example:**
```python
# Process uploaded images
def lambda_handler(event, context):
    # Triggered when file uploaded to S3
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
    # Download image
    s3.download_file(bucket, key, '/tmp/image.jpg')
    
    # Resize image
    resize_image('/tmp/image.jpg', '/tmp/thumbnail.jpg')
    
    # Upload thumbnail
    s3.upload_file('/tmp/thumbnail.jpg', bucket, f'thumbnails/{key}')
    
    return {'statusCode': 200}
```

**When to use Lambda vs EC2:**
- **Lambda:** Event-driven, short tasks, variable load, serverless
- **EC2:** Long-running, consistent load, custom OS, full control

---

### 3. ECS (Elastic Container Service)

**What:** Managed Docker container orchestration

**Components:**
- **Cluster:** Group of EC2 instances running containers
- **Task Definition:** Blueprint (Docker image, CPU, memory, ports)
- **Service:** Ensures N tasks always running (auto-restart on failure)

**Example Task Definition:**
```json
{
  "family": "web-app",
  "containerDefinitions": [{
    "name": "nginx",
    "image": "nginx:latest",
    "memory": 512,
    "cpu": 256,
    "portMappings": [{
      "containerPort": 80,
      "hostPort": 80
    }]
  }]
}
```

---

### 4. EKS (Elastic Kubernetes Service)

**What:** Managed Kubernetes cluster

**Your actual experience In a production environment!**

**Architecture:**
```
EKS Control Plane (managed by AWS)
  ↓
Worker Nodes (EC2 instances in your VPC)
  ├── Pod 1 (EIC container)
  ├── Pod 2 (CC container)
  └── Pod 3 (CSR container)
```

**kubectl commands you use:**
```bash
# List pods in namespace
kubectl get pods -n invoicing-prod

# Get pod details
kubectl describe pod eic-deployment-abc123 -n invoicing-prod

# View logs
kubectl logs -f eic-deployment-abc123 -n invoicing-prod

# Exec into pod (DEV only, not PROD)
kubectl exec -it eic-deployment-abc123 -n invoicing-dev -- /bin/bash

# Check deployment status
kubectl rollout status deployment/eic-deployment -n invoicing-prod
```

**Your 6 environments:**
- us-dev (full access, exec allowed)
- us-stage (read-only)
- us-uat (read-only)
- us-prod (read-only)
- eu-uat (read-only)
- eu-prod (read-only)

---

## Storage Services

### 1. S3 (Simple Storage Service)

**What:** Object storage (files, not filesystem)

**Storage Classes:**
```
Standard:           $0.023/GB/month  (frequent access, high availability)
Intelligent-Tiering: Auto-moves between tiers based on access
Standard-IA:        $0.0125/GB/month (infrequent access, retrieval fee)
Glacier:            $0.004/GB/month  (archival, minutes to hours retrieval)
Glacier Deep:       $0.00099/GB/month (archival, 12-hour retrieval)
```

**Use cases:**
- Static website hosting
- Backup and archival
- Data lake (raw data storage)
- CDN origin (with CloudFront)
- Application file storage (invoices, PDFs, images)

**Bucket policies:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::my-public-bucket/*"
  }]
}
```

**Lifecycle policies:**
```
Rule: Archive old invoices
  - After 90 days → Move to S3-IA
  - After 365 days → Move to Glacier
  - After 7 years → Delete
```

**Versioning:**
```
Enable versioning on bucket
  → Every file modification creates new version
  → Can restore previous versions
  → Protects against accidental deletion
```

---

### 2. EBS (Elastic Block Store)

**What:** Block storage for EC2 (like hard drives)

**Volume Types:**
- **gp3 (General Purpose SSD):** $0.08/GB/month, 3000 IOPS baseline
- **io2 (Provisioned IOPS SSD):** $0.125/GB/month, up to 64000 IOPS
- **st1 (Throughput Optimized HDD):** $0.045/GB/month, big data, logs
- **sc1 (Cold HDD):** $0.015/GB/month, infrequent access

**Snapshots:**
```
Take snapshot of EBS volume (incremental backup)
  → Store in S3
  → Can create new volume from snapshot
  → Can copy snapshot to another region (DR)
```

**Use case:**
```
Database on EC2
  ↓
Attached EBS volume (io2, 10000 IOPS)
  ↓
Daily snapshots to S3
  ↓
Cross-region copy for disaster recovery
```

---

### 3. EFS (Elastic File System)

**What:** Managed NFS (network file system), shared across multiple EC2

**Use cases:**
- Shared file storage for multiple servers
- Content management systems
- Home directories

**vs EBS:**
- **EBS:** One EC2 instance at a time, fixed size
- **EFS:** Multiple EC2 instances, auto-scales

---

## Database Services

### 1. RDS (Relational Database Service)

**What:** Managed MySQL, PostgreSQL, MariaDB, Oracle, SQL Server

**Benefits:**
- Automated backups (daily snapshots, 7-35 day retention)
- Automated patching
- Multi-AZ for high availability
- Read replicas for scaling reads

**Multi-AZ (High Availability):**
```
Primary DB (us-east-1a)
  ↓ Synchronous replication
Standby DB (us-east-1b)

If primary fails:
  → Automatic failover to standby (1-2 min)
  → DNS endpoint stays same (app doesn't change)
```

**Read Replicas (Scalability):**
```
Master DB (writes)
  ↓ Asynchronous replication
Read Replica 1 (reads)
Read Replica 2 (reads)
Read Replica 3 (reads)

Application:
  - Writes → Master
  - Reads → Load balanced across replicas
```

**Your MySQL setup (likely):**
```
RDS MySQL (Multi-AZ)
  - Instance: db.r5.2xlarge (8 vCPU, 64 GB RAM)
  - Storage: 1TB gp3 SSD
  - Backups: 30-day retention
  - Multi-AZ: Yes (for HA)
  
Read Replicas:
  - 3 replicas in same region (for read scaling)
  
Database names:
  - billingmaster (routing DB)
  - billingclient1 (Stack 1 customer data)
  - billingclient2 (Stack 2 customer data)
```

---

### 2. DynamoDB

**What:** Managed NoSQL database (key-value, document)

**Characteristics:**
- **Single-digit millisecond latency**
- **Auto-scaling**
- **Global tables** (multi-region replication)
- **Pay per request** or **provisioned capacity**

**Use cases:**
- Session storage
- User profiles
- Gaming leaderboards
- IoT sensor data

**Example:**
```javascript
// Put item
dynamodb.putItem({
  TableName: 'Users',
  Item: {
    'UserId': {S: '12345'},
    'Email': {S: 'user@example.com'},
    'CreatedAt': {N: '1699999999'}
  }
});

// Get item
dynamodb.getItem({
  TableName: 'Users',
  Key: {'UserId': {S: '12345'}}
});
```

---

### 3. ElastiCache

**What:** Managed Redis or Memcached

**Use cases:**
- Session storage (distributed)
- Database query caching
- Rate limiting
- Leaderboards

**Redis vs Memcached:**
- **Redis:** Data structures (lists, sets, sorted sets), persistence, replication
- **Memcached:** Simple key-value, multi-threaded, no persistence

**Example (Redis caching):**
```python
import redis

r = redis.Redis(host='my-cache.abc.0001.use1.cache.amazonaws.com', port=6379)

# Cache database query
cache_key = f"customer:{customer_id}:settings"
cached = r.get(cache_key)

if cached:
    return json.loads(cached)
else:
    data = db.query(...)
    r.setex(cache_key, 3600, json.dumps(data))  # 1 hour TTL
    return data
```

---

## Networking & Content Delivery

### 1. VPC (Virtual Private Cloud)

**What:** Isolated network in AWS (your own private data center in the cloud)

**Components:**
```
VPC (10.0.0.0/16)
  ├── Public Subnet (10.0.1.0/24) - us-east-1a
  │     └── EC2 with public IP (web servers)
  ├── Public Subnet (10.0.2.0/24) - us-east-1b
  │     └── EC2 with public IP (web servers)
  ├── Private Subnet (10.0.3.0/24) - us-east-1a
  │     └── RDS, internal services (no public IP)
  └── Private Subnet (10.0.4.0/24) - us-east-1b
        └── RDS, internal services (no public IP)
```

**Internet Gateway:**
```
Public subnet EC2
  ↓
Internet Gateway (attached to VPC)
  ↓
Internet
```

**NAT Gateway:**
```
Private subnet EC2 (no public IP)
  ↓
NAT Gateway (in public subnet)
  ↓
Internet Gateway
  ↓
Internet

Purpose: Private instances can make outbound calls (software updates)
         but can't receive inbound traffic from internet
```

**Security Groups (Stateful firewall):**
```
Web Server Security Group:
  Inbound:
    - Port 80 (HTTP) from 0.0.0.0/0 (anywhere)
    - Port 443 (HTTPS) from 0.0.0.0/0
    - Port 22 (SSH) from 10.0.0.0/16 (only from VPC)
  Outbound:
    - All traffic to 0.0.0.0/0 (anywhere)
```

---

### 2. ELB (Elastic Load Balancer)

**3 Types:**

**a) Application Load Balancer (ALB) - Layer 7**
```
Supports:
  - HTTP/HTTPS
  - Path-based routing (/api → API servers, /images → Image servers)
  - Host-based routing (api.example.com → API, www.example.com → Web)
  - WebSockets
  
Use case: Web applications, microservices
```

**b) Network Load Balancer (NLB) - Layer 4**
```
Supports:
  - TCP/UDP/TLS
  - Ultra-high performance (millions of requests/sec)
  - Static IP addresses
  
Use case: Gaming, IoT, non-HTTP protocols
```

**c) Classic Load Balancer (CLB) - Legacy**
```
Don't use for new applications (use ALB or NLB instead)
```

**Health Checks:**
```
Load balancer pings EC2 instances:
  - Every 30 seconds
  - GET /health HTTP/1.1
  - Expect 200 OK
  
If 2 consecutive failures → Mark unhealthy, stop routing traffic
```

---

### 3. CloudFront (CDN)

**What:** Content Delivery Network - cache static content at edge locations

**Architecture:**
```
User in Tokyo
  ↓
CloudFront Edge (Tokyo) - Cache hit? Return cached content
  ↓ Cache miss?
Origin (S3 bucket or ALB in us-east-1)
  ↓
Content returned and cached at Tokyo edge
```

**Benefits:**
- **Faster:** Content served from nearby edge location
- **Lower cost:** Less data transfer from origin
- **DDoS protection:** AWS Shield integrated

**Use cases:**
- Static website (HTML, CSS, JS, images)
- Video streaming
- API acceleration
- Software downloads

---

### 4. Route 53 (DNS)

**What:** Managed DNS service

**Routing Policies:**

**1. Simple:** One record → One IP
```
example.com → 54.123.45.67
```

**2. Weighted:** Distribute traffic by percentage
```
example.com:
  - 70% → 54.123.45.67 (us-east-1)
  - 30% → 13.234.56.78 (eu-west-1)
```

**3. Latency-based:** Route to lowest latency region
```
User in US → us-east-1 (10ms)
User in EU → eu-west-1 (8ms)
```

**4. Failover:** Active-passive
```
Primary: 54.123.45.67 (healthy)
Secondary: 13.234.56.78 (only if primary unhealthy)
```

**5. Geolocation:** Route based on user's location
```
Users from US → us-east-1
Users from EU → eu-west-1
Users from Asia → ap-southeast-1
```

---

## Security & Identity

### 1. IAM (Identity and Access Management)

**Components:**

**Users:**
```
Individual person
  - Username/password for console
  - Access keys for API/CLI
```

**Groups:**
```
Collection of users
  - Developers group → ReadOnly access
  - Admins group → Full access
```

**Roles:**
```
Assumed by AWS services or federated users
  - EC2 instance role → Access S3 buckets
  - Lambda role → Access DynamoDB
```

**Policies (JSON):**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:GetObject",
      "s3:PutObject"
    ],
    "Resource": "arn:aws:s3:::my-bucket/*"
  }]
}
```

**Best Practices:**
- **Root account:** Secure it, don't use for daily work
- **MFA:** Enable on all accounts
- **Least privilege:** Grant minimum permissions needed
- **Rotate keys:** Every 90 days
- **Use roles:** For EC2/Lambda, not access keys

---

### 2. Secrets Manager

**What:** Store and rotate secrets (DB passwords, API keys)

**Example:**
```python
import boto3

secrets = boto3.client('secretsmanager')

# Retrieve secret
response = secrets.get_secret_value(SecretId='prod/mysql/password')
db_password = response['SecretString']

# Connect to database
connection = mysql.connect(
    host='db.example.com',
    user='admin',
    password=db_password
)
```

**Auto-rotation:**
```
Every 30 days:
  1. Generate new password
  2. Update database
  3. Update secret in Secrets Manager
  4. Test new password
  5. Delete old password
```

---

### 3. KMS (Key Management Service)

**What:** Encryption key management

**Use cases:**
- Encrypt EBS volumes
- Encrypt S3 objects
- Encrypt database at rest
- Envelope encryption

---

## Application Integration

### 1. SQS (Simple Queue Service)

**What:** Managed message queue

**Standard vs FIFO:**
```
Standard Queue:
  - Unlimited throughput
  - At-least-once delivery (may duplicate)
  - Best-effort ordering
  
FIFO Queue:
  - 3000 messages/sec (with batching)
  - Exactly-once delivery
  - Strict ordering (within message group)
```

**Use case:**
```
Web Server → SQS Queue → Worker Instances
  
Example: Image upload
  1. User uploads image
  2. Web server sends message to SQS
  3. Worker picks up message
  4. Worker resizes image
  5. Worker deletes message from queue
```

**Visibility Timeout:**
```
Message picked up by worker
  ↓
Invisible to other workers for 30 seconds
  ↓
If worker completes → Delete message
If worker fails → Message becomes visible again (auto-retry)
```

---

### 2. SNS (Simple Notification Service)

**What:** Pub/Sub messaging, push notifications

**Architecture:**
```
Topic: "OrderPlaced"
  ├── Subscriber 1: Email (notifications@company.com)
  ├── Subscriber 2: SMS (555-1234)
  ├── Subscriber 3: Lambda (process order)
  └── Subscriber 4: SQS (queue for analytics)
```

**Use cases:**
- Send notifications (email, SMS, push)
- Fan-out pattern (one message → many subscribers)
- Application-to-application messaging

---

### 3. EventBridge

**What:** Event bus for application events

**Use case:**
```
Schedule expression: cron(0 2 * * ? *)  (Every day at 2 AM UTC)
  ↓
Trigger Lambda function
  ↓
Generate daily reports
```

---

## Monitoring & Operations

### 1. CloudWatch

**Metrics:**
```
EC2:
  - CPUUtilization
  - NetworkIn/NetworkOut
  - DiskReadOps/DiskWriteOps
  
RDS:
  - DatabaseConnections
  - ReadLatency/WriteLatency
  - FreeableMemory
  
ALB:
  - RequestCount
  - TargetResponseTime
  - HTTPCode_Target_4XX_Count
```

**Custom Metrics:**
```python
import boto3

cloudwatch = boto3.client('cloudwatch')

# Publish custom metric
cloudwatch.put_metric_data(
    Namespace='MyApp',
    MetricData=[{
        'MetricName': 'PaymentSuccess',
        'Value': 1,
        'Unit': 'Count',
        'Dimensions': [{
            'Name': 'Environment',
            'Value': 'Production'
        }]
    }]
)
```

**Alarms:**
```
Alarm: High CPU
  Metric: EC2 CPUUtilization
  Threshold: > 80% for 5 minutes
  Action: Send SNS notification → PagerDuty
```

**Logs:**
```
Application logs → CloudWatch Logs
  ↓
Create metric filter: "ERROR"
  ↓
Alarm if > 10 errors in 5 minutes
  ↓
SNS notification
```

---

### 2. X-Ray

**What:** Distributed tracing (follow request across microservices)

**Trace example:**
```
User request
  ↓ 150ms
API Gateway
  ↓ 50ms
Lambda (Auth)
  ↓ 200ms
RDS (query)
  ↓ 100ms
Lambda (Process)
  ↓ 300ms
S3 (store)
  
Total: 800ms
Bottleneck: S3 storage (300ms)
```

---

### 3. Systems Manager

**What:** Operational hub for AWS

**Parameter Store:**
```
Store configuration values (free alternative to Secrets Manager for non-sensitive data)

/myapp/prod/db_host = "db.example.com"
/myapp/prod/api_key = "encrypted-value"
```

**Session Manager:**
```
SSH into EC2 without opening port 22
  - More secure
  - Fully audited
  - No bastion host needed
```

---

## Common Architecture Patterns

### 1. Three-Tier Web Application

```
┌─────────────────────────────────────────┐
│           CloudFront (CDN)               │
│        Static Assets (S3 bucket)        │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│     Application Load Balancer (ALB)     │
└──────────────────┬──────────────────────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
   ┌────▼───┐ ┌───▼────┐ ┌───▼────┐
   │  EC2   │ │  EC2   │ │  EC2   │  Public Subnet
   │  Web   │ │  Web   │ │  Web   │  (Auto Scaling Group)
   └────┬───┘ └───┬────┘ └───┬────┘
        │         │          │
        └─────────┼──────────┘
                  │
        ┌─────────▼──────────┐
        │  RDS (Multi-AZ)    │  Private Subnet
        │  Read Replicas     │  (Database layer)
        └────────────────────┘
```

**Scalability:**
- ALB distributes traffic
- Auto Scaling adds/removes EC2 instances
- RDS Read Replicas for read scaling

**High Availability:**
- Multi-AZ deployment
- Multiple EC2 in different AZs
- RDS automatic failover

---

### 2. Serverless Architecture

```
┌─────────────────────────────────────────┐
│         API Gateway (REST API)          │
└──────────────────┬──────────────────────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
   ┌────▼───┐ ┌───▼────┐ ┌───▼────┐
   │Lambda  │ │Lambda  │ │Lambda  │
   │(Auth)  │ │(Users) │ │(Orders)│
   └────┬───┘ └───┬────┘ └───┬────┘
        │         │          │
        └─────────┼──────────┘
                  │
        ┌─────────▼──────────┐
        │    DynamoDB        │
        └────────────────────┘
```

**Benefits:**
- No server management
- Auto-scaling built-in
- Pay per request
- High availability by default

---

### 3. Event-Driven Architecture

```
S3 Bucket → S3 Event → Lambda (resize image) → S3 (thumbnails)
                    └→ DynamoDB (metadata)
                    └→ SNS → Email notification
```

---

### 4. Microservices on EKS (Your production setup!)

```
┌──────────────────────────────────────────────┐
│         Route 53 (DNS: *.Enterprise SaaS Company.com)      │
└───────────────────┬──────────────────────────┘
                    │
┌───────────────────▼──────────────────────────┐
│     Application Load Balancer (ALB)          │
│  Ingress Controller (routes by path/host)   │
└───────────────────┬──────────────────────────┘
                    │
┌───────────────────▼──────────────────────────┐
│             EKS Cluster                       │
│  ┌────────────────────────────────────────┐  │
│  │  EIC Service (Pods across 3 nodes)     │  │
│  │  CC Service (Pods across 3 nodes)      │  │
│  │  CSR Service (Pods across 3 nodes)     │  │
│  │  WCL Service (Pods across 3 nodes)     │  │
│  │  MPay Service (Pods across 3 nodes)    │  │
│  └────────────────┬───────────────────────┘  │
└───────────────────┼──────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
   ┌────▼────┐ ┌───▼────┐ ┌───▼────┐
   │  RDS    │ │ Redis  │ │   S3   │
   │billingDB│ │ Cache  │ │Invoices│
   └─────────┘ └────────┘ └────────┘
```

---

## Production AWS Experience

### Infrastructure You Work With:

**1. EKS Clusters (6 environments):**
```
us-dev    → Development (full kubectl access)
us-stage  → Staging (read-only)
us-uat    → UAT (read-only)
us-prod   → Production (read-only)
eu-uat    → EU UAT (read-only)
eu-prod   → EU Production (read-only)
```

**2. Database Stack:**
```
RDS MySQL (Multi-AZ):
  - billingmaster (tenant routing)
  - billingclient1 (Stack 1 customer data)
  - billingclient2 (Stack 2 customer data)
  
ElastiCache Redis:
  - Session storage
  - Customer settings cache
  - Rate limiting
```

**3. Storage:**
```
S3 Buckets:
  - Invoice PDFs
  - Document attachments
  - Application logs
  - Database backups
```

**4. Networking:**
```
VPC per environment
  - Public subnets (ALB, NAT Gateway)
  - Private subnets (EKS nodes, RDS)
  - Separate VPC for prod (isolated)
```

**5. Monitoring:**
```
CloudWatch:
  - Application logs from EKS pods
  - RDS metrics
  - Custom payment metrics
  
Datadog/Splunk:
  - Integrated with CloudWatch
  - Custom dashboards
```

---

## Cost Optimization

### 1. Right-Sizing EC2

**Problem:**
```
Current: m5.2xlarge (8 vCPU, 32 GB RAM)
  - Cost: $280/month
  - Average CPU: 20%
  - Average Memory: 40%
```

**Solution:**
```
Downsize to: m5.large (2 vCPU, 8 GB RAM)
  - Cost: $70/month
  - Savings: $210/month (75%)
```

---

### 2. Reserved Instances

**Scenario:**
```
On-Demand: 10 × m5.large = $700/month
Reserved (1-year): 10 × m5.large = $455/month (35% savings)
Reserved (3-year): 10 × m5.large = $420/month (40% savings)
```

**When to use:**
- Predictable, steady-state workloads
- Baseline capacity (not auto-scaled portion)

---

### 3. S3 Lifecycle Policies

**Problem:**
```
10 TB of invoices stored in S3 Standard
  - Cost: $230/month
  - 90% of invoices > 1 year old (rarely accessed)
```

**Solution:**
```
Lifecycle policy:
  - 0-90 days: S3 Standard ($0.023/GB)
  - 90-365 days: S3-IA ($0.0125/GB)
  - > 365 days: Glacier ($0.004/GB)
  
New cost: ~$60/month (74% savings)
```

---

### 4. Auto Scaling

**Problem:**
```
Fixed capacity: 10 EC2 instances 24/7
  - Peak (8am-6pm): Need all 10
  - Off-peak (6pm-8am): Only need 2
  - Cost: $700/month
```

**Solution:**
```
Auto Scaling:
  - Peak hours: 10 instances
  - Off-peak: 2 instances
  - Average: 5 instances
  - Cost: $350/month (50% savings)
```

---

### 5. Spot Instances (for fault-tolerant workloads)

**Use cases:**
- CI/CD build servers
- Batch processing
- Data analysis
- Testing environments

**Savings:** 70-90% vs On-Demand

---

## Interview Questions

### Q1: Design a highly available web application on AWS.

**Answer:**
```
Requirements:
  - 99.99% uptime (52 min downtime/year max)
  - Handle 10,000 requests/sec
  - Global users (low latency)
  - Database transactions

Architecture:

1. Multi-Region Setup:
   - Primary: us-east-1
   - Secondary: eu-west-1
   - Route 53 latency-based routing

2. Per-Region Setup:
   
   CloudFront (CDN) → static assets from S3
        ↓
   Route 53 → ALB (Multi-AZ)
        ↓
   EC2 Auto Scaling Group (3+ AZs)
     - Min: 3 instances (1 per AZ)
     - Max: 30 instances
     - Target: 70% CPU
        ↓
   RDS Multi-AZ + Read Replicas
     - Master in AZ-1
     - Standby in AZ-2
     - Read replicas in AZ-1, AZ-2, AZ-3
        ↓
   ElastiCache Redis (cluster mode)
     - 3-node cluster (1 per AZ)

3. Failure Scenarios:
   - AZ failure → ALB routes to healthy AZs
   - RDS master failure → Auto-failover to standby (1-2 min)
   - Region failure → Route 53 failover to secondary region
   - EC2 failure → Auto Scaling replaces instance (5 min)

4. Data Replication:
   - RDS cross-region read replica (async)
   - S3 cross-region replication
   - DynamoDB global tables (if using NoSQL)

RTO (Recovery Time Objective): 5 minutes
RPO (Recovery Point Objective): 5 minutes (replication lag)
```

---

### Q2: How would you migrate an on-premise database to AWS with minimal downtime?

**Answer:**
```
Strategy: Database Migration Service (DMS)

Steps:

1. Assessment (Week 1):
   - Current DB size, IOPS, connections
   - Schema compatibility check
   - Network bandwidth

2. Setup Target RDS (Week 2):
   - Provision RDS instance (same or higher spec)
   - Multi-AZ for HA
   - Security groups, VPN/Direct Connect

3. Initial Full Load (Weekend):
   - Take snapshot of source DB
   - DMS full load to RDS (historical data)
   - Application still uses on-premise

4. Change Data Capture - CDC (Ongoing):
   - DMS replicates ongoing changes
   - Lag < 1 minute
   - Run for 1-2 weeks (validate)

5. Cutover (Planned maintenance window):
   - Stop application writes (5 min)
   - Wait for replication lag = 0
   - Switch application to RDS
   - Start application (total downtime: 10-15 min)

6. Validation:
   - Row counts match
   - Key queries tested
   - Performance acceptable

7. Rollback Plan:
   - Keep on-premise DB for 1 week
   - Can revert if issues found

Alternative (Zero-downtime):
  - Use application-level dual writes
  - Write to both on-premise and RDS
  - Gradually shift reads to RDS
  - Once validated, stop on-premise writes
```

---

### Q3: How do you secure an AWS environment?

**Answer:**
```
Multi-layered security:

1. Network Layer:
   - VPC with private subnets (databases, app servers)
   - Security groups (least privilege, port-specific)
   - NACLs (subnet-level firewall)
   - No public IPs on app/database servers
   - NAT Gateway for outbound only

2. Identity Layer:
   - IAM users with MFA enabled
   - Principle of least privilege
   - No root account usage
   - IAM roles for EC2/Lambda (not access keys)
   - Rotate credentials every 90 days
   - SCPs (Service Control Policies) for org-wide rules

3. Data Layer:
   - Encryption at rest:
     * EBS volumes (KMS)
     * S3 buckets (SSE-S3 or SSE-KMS)
     * RDS (KMS)
   - Encryption in transit:
     * TLS/SSL everywhere
     * VPN or Direct Connect for on-premise

4. Application Layer:
   - WAF (Web Application Firewall) on ALB
     * SQL injection rules
     * XSS protection
     * Rate limiting
   - Secrets Manager for passwords/API keys
   - Parameter Store for config

5. Monitoring Layer:
   - CloudTrail (all API calls logged)
   - GuardDuty (threat detection)
   - Config (compliance monitoring)
   - CloudWatch alarms (suspicious activity)
   - VPC Flow Logs (network traffic)

6. Compliance:
   - PCI-DSS: Isolated VPC, encrypted storage
   - HIPAA: PHI encryption, access logging
   - SOC 2: Audit trail, access controls

Example Security Group:
Web Tier:
  - Inbound: 443 from 0.0.0.0/0 (HTTPS only)
  - Outbound: 3306 to DB security group only

App Tier:
  - Inbound: 8080 from Web SG only
  - Outbound: 3306 to DB SG only

DB Tier:
  - Inbound: 3306 from App SG only
  - Outbound: None (no outbound needed)
```

---

### Q4: Your application is experiencing high latency. How do you troubleshoot?

**Answer:**
```
Systematic approach:

1. Identify Scope (5 min):
   CloudWatch metrics:
     - Check ALB target response time
     - Check EC2 CPU/Memory
     - Check RDS read/write latency
     - Check application-specific metrics
   
   Questions:
     - All users or specific region?
     - All endpoints or specific API?
     - Started when? (correlate with deployments)

2. Database Layer (if DB latency high):
   - RDS Performance Insights (slow queries)
   - Check for missing indexes (EXPLAIN)
   - Check for connection pool exhaustion
   - Check for lock contention
   - Quick fix: Add read replica, route reads there

3. Application Layer (if app slow):
   - X-Ray traces (find slow services)
   - Check for N+1 queries
   - Check external API calls
   - Check for thread pool exhaustion
   - Quick fix: Scale out (more EC2 instances)

4. Network Layer:
   - VPC Flow Logs (packet loss?)
   - Security group rules (dropping packets?)
   - Cross-AZ traffic (unnecessary latency)
   - Quick fix: Move to same AZ

5. Caching Layer:
   - ElastiCache hit rate (should be > 80%)
   - If low, increase cache size or TTL
   - Check for cache stampede (many cache misses)
   - Quick fix: Pre-warm cache

Example findings:
  - RDS CPU: 90% (slow queries)
  - Top query: SELECT * FROM invoices (no WHERE clause!)
  - Fix: Add WHERE clause, add index
  - Result: Latency 500ms → 50ms

Long-term fixes:
  - Add caching (ElastiCache)
  - Add read replicas
  - Optimize database queries
  - Add CDN (CloudFront) for static assets
```

---

### Q5: Explain the difference between horizontal and vertical scaling on AWS.

**Answer:**
```
Vertical Scaling (Scale Up):
  - Increase instance size
  - Example: t3.medium → t3.xlarge
  - Pros: Simple, no code changes
  - Cons: Downtime during resize, hardware limits, expensive
  
  When to use:
    - Legacy apps that can't scale horizontally
    - Single-threaded workloads
    - Databases (up to a point)

Horizontal Scaling (Scale Out):
  - Add more instances
  - Example: 2 instances → 10 instances
  - Pros: No downtime, unlimited scaling, cost-effective
  - Cons: Needs stateless design, more complexity
  
  When to use:
    - Web applications
    - Stateless services
    - Variable load

AWS Tools:
  Vertical:
    - Manually resize EC2 instance
    - Or scheduled scaling (resize at night)
  
  Horizontal:
    - Auto Scaling Groups
    - ECS/EKS (container orchestration)
    - Lambda (auto-scales by default)

Best Practice:
  - Horizontal for application tier (stateless)
  - Vertical for database tier (stateful)
  - Combine: Start with m5.large × 3 instances
            If need more: Scale to 10 instances (horizontal)
            If still need more: Upgrade to m5.xlarge × 10 (vertical + horizontal)
```

---

### Q6: Explain EC2 instance types and when to use each.

**Answer:**
```
EC2 Instance Families (by use case):

1. General Purpose (T3, M5):
   - Balanced CPU, memory, network
   - Use for: Web servers, small databases, dev environments
   - Example: t3.medium (2 vCPU, 4 GB RAM)
   - Billtrust use: CC application servers

2. Compute Optimized (C5):
   - High CPU, less memory
   - Use for: Batch processing, encoding, gaming servers
   - Example: c5.xlarge (4 vCPU, 8 GB RAM)
   - Billtrust use: EIC invoice generation workers

3. Memory Optimized (R5):
   - High memory, good CPU
   - Use for: Redis/Memcache, real-time big data
   - Example: r5.large (2 vCPU, 16 GB RAM)
   - Billtrust use: ElastiCache nodes

4. Storage Optimized (I3):
   - High disk IOPS, NVMe SSD
   - Use for: NoSQL databases, data warehouses
   - Example: i3.large (2 vCPU, 15 GB RAM, 475 GB NVMe)

Sizing Strategy:
  1. Start small: t3.micro or t3.small
  2. Monitor CloudWatch metrics (CPU, memory)
  3. Scale up if CPU > 70% sustained
  4. Consider reserved instances for 24/7 workloads (60% cost savings)
```

**Your Experience:**
"At Billtrust, we use t3.medium for CC web servers (balanced), c5.large for EIC batch invoice processing (CPU-intensive), and r5.large for Redis caching (memory-intensive). We right-size based on CloudWatch metrics and use reserved instances for production to save 60% on costs."

---

### Q7: How does RDS Multi-AZ work and why use it?

**Answer:**
```
RDS Multi-AZ (Availability Zone):

Architecture:
  Primary DB (us-east-1a) ──synchronous replication──> Standby DB (us-east-1b)
      ↑
      │
  Application (single endpoint: billingdb.us-east-1.rds.amazonaws.com)

How It Works:
  1. All writes go to Primary
  2. Changes are SYNCHRONOUSLY replicated to Standby
  3. Standby is NOT accessible (no reads allowed)
  4. If Primary fails:
     - Automatic failover to Standby (1-2 minutes)
     - DNS endpoint automatically points to new Primary
     - Zero application code changes needed

Multi-AZ vs Read Replica:
  Multi-AZ (High Availability):
    - Synchronous replication
    - Same region, different AZ
    - Automatic failover
    - No read traffic (standby is idle)
    - Use for: Production uptime

  Read Replica (Scalability):
    - Asynchronous replication
    - Can be different region
    - Manual failover (promote to primary)
    - Can handle read traffic
    - Use for: Reporting queries, analytics

When to Use Multi-AZ:
  ✅ Production databases (critical data)
  ✅ RPO = 0 (no data loss acceptable)
  ✅ RTO < 2 minutes (fast recovery)
  ❌ Dev/test environments (save cost)
  ❌ Read-heavy workloads (use read replicas instead)

Cost:
  - 2x the single-AZ price (you pay for standby)
  - But worth it for 99.95% SLA
```

**Your Experience:**
"At Billtrust, our production MySQL RDS runs Multi-AZ for high availability. We've had automatic failovers during maintenance windows with zero downtime — the application just reconnected within seconds. For reporting queries, we use read replicas in the same AZ to offload heavy SELECT queries from the primary."

---

### Q8: Explain S3 storage classes and when to use each.

**Answer:**
```
S3 Storage Classes (by access frequency):

1. S3 Standard (Frequently Accessed):
   - Latency: Milliseconds
   - Durability: 99.999999999% (11 nines)
   - Availability: 99.99%
   - Cost: $0.023/GB/month
   - Use for: Active website assets, frequently accessed invoices

2. S3 Intelligent-Tiering (Unknown/Changing):
   - Automatically moves between frequent/infrequent tiers
   - Cost: $0.0025/GB monitoring fee
   - Use for: Data with unpredictable access patterns

3. S3 Standard-IA (Infrequent Access):
   - Latency: Milliseconds (same as Standard)
   - Cost: $0.0125/GB/month (50% cheaper than Standard)
   - Retrieval fee: $0.01/GB
   - Use for: Backups, disaster recovery, old invoices (accessed monthly)

4. S3 Glacier Flexible Retrieval:
   - Retrieval: 1-5 minutes (Expedited) to 3-5 hours (Standard)
   - Cost: $0.0036/GB/month (84% cheaper than Standard)
   - Use for: Long-term archives, compliance data (accessed yearly)

5. S3 Glacier Deep Archive:
   - Retrieval: 12-48 hours
   - Cost: $0.00099/GB/month (96% cheaper than Standard)
   - Use for: 7-10 year retention (compliance, legal)

Lifecycle Policies (Automate Transitions):
  Rule: "Move invoices older than 90 days to Standard-IA"
  Rule: "Move invoices older than 1 year to Glacier"
  Rule: "Delete after 7 years (compliance requirement)"

Example:
  Day 1-90:    S3 Standard ($0.023/GB) ← Active invoices
  Day 91-365:  S3 Standard-IA ($0.0125/GB) ← Occasional access
  Day 366+:    Glacier ($0.0036/GB) ← Compliance archives
```

**Your Experience:**
"At Billtrust, we store invoice PDFs in S3 Standard for the first 90 days (customers frequently download them). After 90 days, a lifecycle policy moves them to Standard-IA (accessed monthly for disputes). After 1 year, they go to Glacier for long-term compliance. This saves us thousands per month on storage costs while maintaining instant access for active invoices."

---

### Q9: Explain SQS vs SNS — when to use each?

**Answer:**
```
SQS (Simple Queue Service) vs SNS (Simple Notification Service):

┌─────────────────────────────────────────────────────────┐
│                      SQS (Queue)                         │
│  Producer → Queue → Consumer (pull model)               │
│  - Point-to-point (1 consumer per message)              │
│  - Messages persist until processed                     │
│  - Consumer pulls at their own pace                     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                     SNS (Pub/Sub)                        │
│  Publisher → Topic → [Subscriber 1, Sub 2, Sub 3, ...]  │
│  - Fan-out (all subscribers get the message)            │
│  - Push model (SNS pushes to subscribers)               │
│  - No persistence (if subscriber is down, message lost) │
└─────────────────────────────────────────────────────────┘

When to Use SQS:
  ✅ One consumer should process each message
  ✅ Processing can be delayed (async job queue)
  ✅ Consumer controls the pace (backpressure)
  ✅ Retry logic needed (DLQ for failures)
  
  Examples:
    - Invoice generation queue (1 worker processes each invoice)
    - Email sending queue (1 worker sends each email)
    - Image resizing queue

When to Use SNS:
  ✅ Multiple subscribers need the same event
  ✅ Real-time push notifications
  ✅ Loosely coupled services (don't know who's listening)
  
  Examples:
    - Payment event: notify billing + analytics + fraud detection
    - User signup: send welcome email + create CRM record + log to analytics
    - Alert notifications: email + SMS + PagerDuty

Combined Pattern (SNS → SQS Fan-out):
  Payment Event (SNS Topic)
    ├→ Billing Queue (SQS) ← Billing Service
    ├→ Analytics Queue (SQS) ← Analytics Service
    └→ Fraud Queue (SQS) ← Fraud Detection Service
  
  Why: SNS for fan-out + SQS for reliability and backpressure

SQS Types:
  - Standard Queue: At-least-once delivery, best-effort ordering
  - FIFO Queue: Exactly-once, strict ordering (but 300 TPS limit)
```

**Your Experience:**
"At Billtrust, we use SQS for invoice PDF generation — a producer adds invoice IDs to the queue, and worker pods pull and process them asynchronously. For payment events, we use SNS to fan out to multiple services: one subscriber updates the billing DB, another logs to analytics, and another triggers fraud checks. We also combine SNS → SQS for reliability — SNS pushes to SQS queues so each service can process at its own pace."

---

### Q10: How do you secure sensitive data in AWS (RDS passwords, API keys)?

**Answer:**
```
AWS Secrets Management:

1. AWS Secrets Manager (Recommended):
   - Store: RDS passwords, API keys, OAuth tokens
   - Auto-rotation: Rotate RDS password every 30 days
   - Versioning: Keep secret history
   - Fine-grained IAM access
   
   Example:
     Secret: billtrust/prod/mysql-password
     Retrieve in app:
       import boto3
       client = boto3.client('secretsmanager')
       response = client.get_secret_value(SecretId='billtrust/prod/mysql-password')
       password = response['SecretString']

2. AWS Systems Manager Parameter Store:
   - Store: Config values, non-critical secrets
   - Free tier: 10,000 params
   - SecureString type: Encrypted with KMS
   
   Example:
     Parameter: /billtrust/prod/db-host
     Retrieve: aws ssm get-parameter --name /billtrust/prod/db-host --with-decryption

3. KMS (Key Management Service):
   - Encrypt/decrypt data
   - Envelope encryption (data key encrypted by master key)
   - Audit via CloudTrail
   
   Example:
     Encrypt PII before storing in S3
     Decrypt on retrieval

4. IAM Roles (No Hardcoded Credentials):
   - EC2 Instance Role → Automatically get temp credentials
   - Lambda Execution Role → Access RDS/S3
   - EKS Pod Role (IRSA) → Fine-grained permissions per pod
   
   Example:
     EC2 instance with role "BillingServiceRole"
     → Can access S3 bucket "billtrust-invoices"
     → Can read secret "billtrust/prod/mysql-password"
     → No credentials in code!

5. Never Do This (Anti-Patterns):
   ❌ Hardcode in source code: password = "MySecret123"
   ❌ Store in .env committed to Git
   ❌ Pass as environment variables in Dockerfile
   ❌ Store unencrypted in S3
   ❌ Share IAM user access keys

Best Practices:
  1. All secrets in Secrets Manager or Parameter Store
  2. Use IAM roles (no access keys)
  3. Enable secret rotation (30-90 days)
  4. Encrypt at rest (S3, RDS, EBS)
  5. Encrypt in transit (TLS/SSL)
  6. Audit access via CloudTrail
  7. Least privilege IAM policies
```

**Your Experience:**
"At Billtrust, we store all RDS passwords and API keys in AWS Secrets Manager with auto-rotation enabled. Our EKS pods use IRSA (IAM Roles for Service Accounts) to retrieve secrets — no credentials in code or environment variables. We enable encryption at rest for RDS and S3, and all data in transit uses TLS. CloudTrail logs all secret access for audit compliance."

---

### Q11: Explain VPC, subnets, and security groups.

**Answer:**
```
AWS Networking Hierarchy:

Region (us-east-1)
  └─ VPC (10.0.0.0/16) ← Your private network
      ├─ Public Subnet (10.0.1.0/24) in AZ-1a ← Has Internet Gateway
      │   └─ NAT Gateway
      ├─ Public Subnet (10.0.2.0/24) in AZ-1b
      ├─ Private Subnet (10.0.10.0/24) in AZ-1a ← No direct internet
      │   └─ Application Servers
      └─ Private Subnet (10.0.11.0/24) in AZ-1b
          └─ RDS Database

VPC (Virtual Private Cloud):
  - Your isolated network in AWS
  - Define IP range (CIDR block): 10.0.0.0/16 = 65,536 IPs
  - Spans all AZs in a region
  - Default: 1 VPC per region (you can create more)

Subnets:
  - Subdivision of VPC
  - Tied to 1 Availability Zone
  - Public Subnet: Has route to Internet Gateway (0.0.0.0/0 → IGW)
  - Private Subnet: No direct internet (uses NAT Gateway for outbound)

Security Groups (Stateful Firewall):
  - Instance-level (attached to EC2, RDS, etc.)
  - Whitelist only (allow rules, no deny rules)
  - Stateful: If you allow inbound, response is auto-allowed
  
  Example: Web Server Security Group
    Inbound:
      - Port 443 (HTTPS) from 0.0.0.0/0 (anywhere)
      - Port 22 (SSH) from 10.0.0.0/16 (VPC only)
    Outbound:
      - All traffic to 0.0.0.0/0 (default)

Network ACLs (Stateless Firewall):
  - Subnet-level (applies to all instances in subnet)
  - Both allow and deny rules
  - Stateless: Must explicitly allow response traffic
  - Processed in order (rule #100, #200, etc.)

Best Practices:
  1. Multi-AZ subnets (high availability)
  2. Public subnet for load balancers, NAT gateways
  3. Private subnet for app servers, databases
  4. Least privilege security groups (only open ports you need)
  5. Use bastion host (jump box) for SSH access to private instances
```

**Your Experience:**
"At Billtrust, our production VPC has public subnets for ALB (Application Load Balancer) and private subnets for EKS pods and RDS. Security groups allow inbound HTTPS (443) on ALB from anywhere, but EKS pods only accept traffic from ALB security group. RDS only accepts MySQL (3306) from EKS pod security group. SSH is restricted to bastion host only. This layered approach follows defense-in-depth."

---

### Q12: How do you monitor and troubleshoot an AWS application?

**Answer:**
```
AWS Observability Stack:

1. CloudWatch Metrics (What's happening):
   - EC2: CPU, network, disk I/O
   - RDS: Connections, queries/sec, replication lag
   - ELB: Request count, latency, 5xx errors
   - Custom: Application metrics (invoice generation rate)
   
   Alarms:
     - Alert if CPU > 80% for 5 minutes
     - Alert if RDS connections > 90% of max
     - Alert if ELB 5xx errors > 10/min

2. CloudWatch Logs (Why it's happening):
   - Centralized log storage
   - Log groups per application
   - Retention: 7 days (dev), 90 days (prod)
   - Insights: SQL-like queries on logs
   
   Example:
     fields @timestamp, @message
     | filter @message like /ERROR/
     | stats count() by bin(5m)

3. X-Ray (Distributed Tracing):
   - Trace requests across microservices
   - Identify bottlenecks (which service is slow?)
   - Service map visualization
   
   Flow:
     ALB → EIC → CSR API → RDS
     Latency: 50ms + 200ms + 300ms = 550ms total
     → CSR is the bottleneck!

4. CloudTrail (Who did what):
   - Audit log of all AWS API calls
   - Track: Who deleted the S3 bucket? Who changed security group?
   - Compliance/security

Troubleshooting Workflow:
  1. Check CloudWatch dashboard (high CPU? High latency?)
  2. Drill into CloudWatch Logs (error messages?)
  3. Use X-Ray to trace slow requests (which service?)
  4. Check CloudTrail if infrastructure changed (who modified?)
  5. SSH to EC2 (if needed) or kubectl exec (EKS pods)

Example: "Application is slow"
  Step 1: CloudWatch Metrics
    → RDS CPU is 95% (bottleneck!)
  
  Step 2: RDS Performance Insights
    → Top query: SELECT * FROM fsidocument (no WHERE clause!)
  
  Step 3: CloudWatch Logs (application logs)
    → Found code calling the query
  
  Fix: Add WHERE clause + LIMIT
```

**Your Experience:**
"At Billtrust, we use CloudWatch for all metrics and logs. When we had a P1 incident (invoice emails not sending), I checked CloudWatch metrics and saw SQS queue depth spiking to 10,000 messages. Logs showed 'Redis connection pool exhausted' errors. X-Ray traces confirmed workers were timing out on Redis. Fix: increased connection pool size from 10 to 50. We now have CloudWatch alarms on queue depth and Redis connection count."

---

## Summary Cheat Sheet

**Compute:**
- **EC2:** Virtual servers, full control
- **Lambda:** Serverless functions, event-driven
- **ECS:** Docker containers (managed)
- **EKS:** Kubernetes (managed) ← You use this!

**Storage:**
- **S3:** Object storage (files)
- **EBS:** Block storage (attached to EC2)
- **EFS:** File system (shared across EC2)

**Database:**
- **RDS:** Managed relational (MySQL, PostgreSQL) ← You use this!
- **DynamoDB:** NoSQL (key-value, document)
- **ElastiCache:** In-memory cache (Redis, Memcached) ← You use this!

**Networking:**
- **VPC:** Private network
- **ELB:** Load balancers (ALB, NLB)
- **CloudFront:** CDN
- **Route 53:** DNS

**Security:**
- **IAM:** Identity and access
- **KMS:** Encryption keys
- **Secrets Manager:** Store secrets

**Integration:**
- **SQS:** Message queue
- **SNS:** Pub/sub notifications
- **EventBridge:** Event bus

**Monitoring:**
- **CloudWatch:** Metrics, logs, alarms
- **X-Ray:** Distributed tracing

---

**High Availability Formula:**
```
Multi-Region
  + Multi-AZ
  + Auto Scaling
  + RDS Multi-AZ
  + Load Balancer
  = 99.99% uptime
```

---

Good luck with your AWS interviews! 🚀
