# System Design Interview Guide

## 📋 Table of Contents

1. [Interview Framework](#interview-framework)
2. [Key Concepts & Patterns](#key-concepts--patterns)
3. [Scalability Deep Dive](#scalability-deep-dive)
4. [Database Design](#database-design)
5. [Common System Design Problems](#common-system-design-problems)
6. [Real-World Examples from Your Experience](#real-world-examples-from-your-experience)
7. [Evaluation Criteria](#evaluation-criteria)
8. [Practice Problems](#practice-problems)

---

## Interview Framework

### The 7-Step Approach (45-60 min interview)

**Step 1: Clarify Requirements (5-7 min)**
- Ask questions to understand scope
- Define functional requirements (what the system does)
- Define non-functional requirements (scale, performance, consistency)
- Identify constraints and assumptions

**Step 2: Estimate Scale (3-5 min)**
- Daily Active Users (DAU)
- Requests per second (read/write ratio)
- Data volume and growth rate
- Bandwidth requirements

**Step 3: Define APIs (3-5 min)**
- Key endpoints or interfaces
- Request/response formats
- Keep it high-level

**Step 4: High-Level Design (10-15 min)**
- Draw the main components
- Show data flow
- Identify major services

**Step 5: Deep Dive (15-20 min)**
- Interviewer will probe specific areas
- Database schema
- Caching strategy
- Scalability bottlenecks
- Failure scenarios

**Step 6: Identify Bottlenecks & Tradeoffs (5-10 min)**
- Discuss limitations
- Propose improvements
- Talk about tradeoffs

**Step 7: Wrap Up (2-3 min)**
- Summarize the design
- Mention monitoring and operations

---

## Key Concepts & Patterns

### 1. Load Balancing

**What:** Distributes incoming requests across multiple servers

**Types:**
- **Layer 4 (Transport):** Routes based on IP/port, fast but less flexible
- **Layer 7 (Application):** Routes based on content (URL, headers), slower but smarter

**Algorithms:**
- Round Robin: Simple rotation
- Least Connections: Send to server with fewest active connections
- IP Hash: Same client always goes to same server (session affinity)

**Your experience:**
```
                  Load Balancer (AWS ELB)
                         |
        +----------------+----------------+
        |                |                |
   EIC Pod 1        EIC Pod 2        EIC Pod 3
   (Active)         (Active)         (Active)
```

**When to discuss:** Any system serving many users

---

### 2. Caching

**Why:** Reduce database load, improve response time

**Cache Levels:**
- **Client-side:** Browser cache
- **CDN:** Static assets (images, CSS, JS)
- **Application:** Redis/Memcached for hot data
- **Database:** Query cache, buffer pool

**Cache Strategies:**

**a) Cache-Aside (Lazy Loading)**
```
1. App checks cache
2. If miss → read from DB
3. Write to cache
4. Return to user
```
**Pros:** Only cache what's needed  
**Cons:** Cache miss penalty, potential stale data

**b) Write-Through**
```
1. Write to cache AND database synchronously
2. Cache always consistent with DB
```
**Pros:** Consistency  
**Cons:** Write latency

**c) Write-Behind (Write-Back)**
```
1. Write to cache immediately
2. Asynchronously write to DB later
```
**Pros:** Fast writes  
**Cons:** Risk of data loss, eventual consistency

**Cache Invalidation Strategies:**
- **TTL (Time To Live):** Auto-expire after X seconds
- **Event-driven:** Invalidate on data change
- **LRU (Least Recently Used):** Evict oldest unused items

**Your experience In a production environment:**
```php
// Customer settings cached for 1 hour
$cacheKey = "customer_settings_{$customerId}_{$settingPath}";
$settings = Cache::remember($cacheKey, 3600, function() use ($customerId, $settingPath) {
    return DB::selectOne('CALL FindCustSettings(?, ?)', [$customerId, $settingPath]);
});
```

**When to discuss:** Almost every system design question

---

### 3. Database Scaling

#### Vertical Scaling (Scale Up)
- Add more CPU, RAM, disk to single server
- **Pros:** Simple, no code changes
- **Cons:** Hardware limits, single point of failure, expensive

#### Horizontal Scaling (Scale Out)

**a) Replication (Master-Slave)**
```
         Master (Writes)
              |
    +---------+---------+
    |         |         |
  Slave 1   Slave 2   Slave 3
  (Reads)   (Reads)   (Reads)
```
**Pros:** Read scalability, failover  
**Cons:** Replication lag, write bottleneck on master

**b) Sharding (Partitioning)**

Distribute data across multiple databases

**Sharding Strategies:**

1. **Hash-based:** `shard_id = hash(user_id) % num_shards`
   - Pro: Even distribution
   - Con: Hard to add shards, no range queries

2. **Range-based:** User 1-1M → Shard 1, 1M-2M → Shard 2
   - Pro: Easy range queries
   - Con: Uneven distribution, hotspots

3. **Geographic:** Users by region
   - Pro: Low latency, compliance
   - Con: Uneven distribution

4. **Entity-based:** All data for customer in one shard
   - Pro: No cross-shard joins, tenant isolation
   - Con: Large tenants can overwhelm shard

**Your production experience (Entity-based sharding):**
```
billingmaster (routing DB)
  CustomerId | StackNum | DBName
  12345      | 1        | billingclient1
  67890      | 2        | billingclient2

Stack 1 (billingclient1) → Customers 1-5000
Stack 2 (billingclient2) → Customers 5001-10000
```

**Sharding Challenges:**
- Cross-shard joins become expensive
- Transactions across shards are complex
- Rebalancing data when adding shards

---

### 4. Microservices vs Monolith

**Monolith:**
```
+---------------------------+
|  Single Application       |
|  - User Management        |
|  - Invoice Generation     |
|  - Payment Processing     |
|  - Notifications          |
|  All in one codebase/DB   |
+---------------------------+
```
**Pros:** Simple deployment, easy transactions, less network overhead  
**Cons:** Hard to scale parts independently, tight coupling, large codebase

**Microservices:**
```
User Service <---> Invoice Service <---> Payment Service
    |                    |                      |
  User DB            Invoice DB             Payment DB
```
**Pros:** Independent scaling, technology flexibility, team autonomy  
**Cons:** Distributed system complexity, network latency, data consistency

**Production platform (Microservices):**
- **EIC** (eInvoice Connect): Customer portal
- **CC** (Client Connect): Account management
- **CSR** (Customer Settings Repository): Configuration service
- **WCL** (Web Communication Layer): Notification service
- **MPay** (Managed Pay): Payment processing

**Communication Patterns:**
- **Synchronous:** REST APIs for request/response
- **Asynchronous:** Message queues for events

---

### 5. Message Queues & Async Processing

**Why:** Decouple services, handle traffic spikes, retry failed operations

**Popular Tools:** RabbitMQ, Apache Kafka, AWS SQS, Redis Pub/Sub

**Patterns:**

**a) Work Queue**
```
Producer → Queue → Consumer 1
                 → Consumer 2
                 → Consumer 3
```
**Use case:** Distribute work (email sending, report generation)

**b) Pub/Sub**
```
Publisher → Topic → Subscriber 1 (logs to DB)
                  → Subscriber 2 (sends notification)
                  → Subscriber 3 (updates cache)
```
**Use case:** Event broadcasting (invoice created, payment received)

**Guaranteed Delivery Patterns:**
- **At-most-once:** Fire and forget, may lose messages
- **At-least-once:** Retry until ack, may duplicate
- **Exactly-once:** Idempotent processing, no duplicates (hardest)

**Your use case:**
```
Invoice Generation Queue
  → Worker 1: Generate PDF
  → Worker 2: Generate PDF
  → Worker 3: Generate PDF

Each worker:
1. Pull job from queue
2. Generate invoice
3. Store in S3/DB
4. Send to email queue
5. Ack completion
```

---

### 6. CAP Theorem

**You can only have 2 of 3:**

- **C (Consistency):** All nodes see the same data at the same time
- **A (Availability):** Every request gets a response (success/failure)
- **P (Partition Tolerance):** System works despite network failures

**Trade-offs:**

**CP (Consistency + Partition Tolerance):**
- Example: Traditional RDBMS (MySQL, PostgreSQL)
- Sacrifice: May refuse requests if nodes can't sync
- Use when: Financial transactions, inventory

**AP (Availability + Partition Tolerance):**
- Example: Cassandra, DynamoDB
- Sacrifice: Different nodes may have different data (eventual consistency)
- Use when: Social media feeds, analytics

**CA (Consistency + Availability):**
- Not realistic in distributed systems (network failures happen)

**Production context:**
- **Payment processing:** CP (must be consistent)
- **Invoice delivery logs:** AP (eventual consistency okay)

---

### 7. Consistent Hashing

**Problem:** Adding/removing servers in traditional hashing breaks many cache keys

**Traditional hash:**
```
server = hash(key) % num_servers
Add/remove server → most keys rehash to different server → cache miss storm
```

**Consistent hashing:**
```
         Server 1
            |
    Key A --+-- Key B
    |              |
Server 3 ----●---- Server 2
              |
          Key C
```
- Keys and servers placed on a ring
- Each key goes to next server clockwise
- Adding/removing server only affects adjacent keys (~1/N)

**Use cases:**
- Load balancer routing
- Distributed cache (Memcached)
- Distributed databases (Cassandra)

---

### 8. Rate Limiting

**Why:** Prevent abuse, ensure fair usage, protect against DDoS

**Algorithms:**

**a) Token Bucket**
```
Bucket holds N tokens
Refill at rate R per second
Request consumes 1 token
If bucket empty → reject
```
**Pros:** Allows bursts  
**Cons:** More complex

**b) Leaky Bucket**
```
Requests enter bucket
Process at fixed rate
If bucket full → reject
```
**Pros:** Smooth traffic  
**Cons:** No bursts

**c) Fixed Window**
```
Count requests per minute
If count > limit → reject
Reset count at minute boundary
```
**Pros:** Simple  
**Cons:** Burst at window edge

**d) Sliding Window**
```
Track timestamps of recent requests
Count requests in last N seconds
More accurate than fixed window
```

**Implementation:**
```php
// Redis-based rate limiter
$key = "rate_limit:{$userId}:{$endpoint}";
$count = Redis::incr($key);
if ($count === 1) {
    Redis::expire($key, 60); // 1 minute window
}
if ($count > 100) {
    throw new RateLimitException("Too many requests");
}
```

---

### 9. Content Delivery Network (CDN)

**What:** Geographically distributed servers serving cached static content

**How it works:**
```
User in Tokyo → Tokyo CDN Edge Server (cached content)
User in NYC → NYC CDN Edge Server (cached content)
            ↓ Cache miss only
        Origin Server (your infrastructure)
```

**Benefits:**
- Reduced latency (content closer to user)
- Reduced load on origin
- Better availability
- DDoS protection

**What to cache:**
- Images, videos
- JavaScript, CSS
- PDFs, documents
- API responses (with short TTL)

**Popular CDNs:** Cloudflare, AWS CloudFront, Akamai, Fastly

---

### 10. Database Indexing

**What:** Data structure that improves query speed at cost of write speed and storage

**Types:**

**a) B-tree Index** (default in MySQL)
- Good for: Equality, range queries
- Example: `CREATE INDEX idx_email ON users(email);`

**b) Hash Index**
- Good for: Exact match only
- Example: Looking up by unique ID

**c) Composite Index**
- Multiple columns
- Example: `CREATE INDEX idx_customer_date ON invoices(customer_id, created_at);`
- Order matters! Can use for `WHERE customer_id = ? AND created_at > ?`
- Cannot use just `created_at` alone efficiently

**d) Covering Index**
- Includes all columns needed by query
- Query served from index alone, no table lookup
- Example:
```sql
CREATE INDEX idx_cover ON users(email, name, status);
SELECT name, status FROM users WHERE email = ?; -- Covered!
```

**Your optimization example:**
```sql
-- SLOW: Full table scan on 100M rows
SELECT * FROM fsidocument WHERE AccountNumber = '12345';

-- FAST: Index on AccountNumber
CREATE INDEX idx_account ON fsidocument(AccountNumber);

-- FASTER: Composite covering index
CREATE INDEX idx_account_billing ON fsidocument(AccountNumber, BillingDate, Amount);
SELECT BillingDate, Amount FROM fsidocument WHERE AccountNumber = '12345';
```

---

## Scalability Deep Dive

### Scaling Dimensions

**1. Compute Scaling**
- Horizontal: Add more app servers
- Auto-scaling based on CPU/memory/request rate
- Containerization (Docker) + orchestration (Kubernetes)

**2. Database Scaling**
- Read replicas for read-heavy workloads
- Sharding for write-heavy workloads
- Connection pooling to limit DB connections

**3. Storage Scaling**
- Object storage (S3) for files
- Separate hot (recent) vs cold (archived) data
- Compression and deduplication

**4. Network Scaling**
- CDN for static content
- Load balancers at multiple layers
- Keep services in same region/AZ when possible

### Handling 1M Daily Active Users

**Traffic estimation:**
```
1M DAU
Avg 10 requests per user per day = 10M requests/day
10M / 86400 seconds ≈ 116 requests/second (average)
Peak (3x average) = 350 RPS

Read:Write ratio = 80:20 (typical)
280 read RPS, 70 write RPS
```

**Architecture:**
```
              CDN (static assets)
                   |
              Load Balancer
                   |
       +-----------+-----------+
       |           |           |
   App Server  App Server  App Server
   (autoscale 3-10 instances)
       |           |           |
       +-----Redis Cache-------+
                   |
       +-----------+-----------+
       |                       |
   Master DB              Read Replicas (3)
   (writes)               (reads)
       |
   Backup + Archive
```

**Database:**
- Master DB: 16 cores, 64GB RAM, SSD
- 3 read replicas for read traffic
- Connection pool: max 200 connections
- Cache hit rate: 80% (reduce DB load)

**Storage:**
- User data: ~1KB per user = 1GB
- Invoices: ~100KB each, 10 per user/year = 1TB/year
- Archive old data to S3 (> 2 years)

---

### Handling 100M Daily Active Users

**Traffic estimation:**
```
100M DAU
Avg 20 requests per user per day = 2B requests/day
2B / 86400 ≈ 23,000 RPS (average)
Peak (3x) = 70,000 RPS
```

**Changes from 1M design:**

1. **Multi-region deployment**
   - US, EU, Asia regions
   - Route users to nearest region (latency)
   - Data sovereignty compliance

2. **Database sharding** (can't scale single master)
   - 100 shards, 1M users per shard
   - Shard by user_id hash or geographic region

3. **Microservices** (monolith can't scale)
   - User Service
   - Invoice Service
   - Payment Service
   - Notification Service
   Each scales independently

4. **Distributed cache**
   - Redis cluster (sharded)
   - Cache miss → expensive at this scale

5. **Message queues**
   - Async processing for non-critical paths
   - Email, notifications, analytics

6. **Object storage**
   - S3 for all files (invoices, documents)
   - ~10TB new data per year

---

## Database Design

### Normalization vs Denormalization

**Normalization (3NF):**
- Eliminate redundancy
- Each fact in one place
- Good for: Write-heavy, changing data

**Example:**
```sql
-- Normalized
users: id, email, name
orders: id, user_id, total
order_items: id, order_id, product_id, quantity

-- Join required for order details
SELECT u.name, o.total, oi.quantity 
FROM users u
JOIN orders o ON u.id = o.user_id
JOIN order_items oi ON o.id = oi.order_id;
```

**Denormalization:**
- Duplicate data for read performance
- Good for: Read-heavy, analytics

**Example:**
```sql
-- Denormalized
orders: id, user_id, user_name, user_email, total, items_count

-- No joins needed
SELECT user_name, total, items_count FROM orders;
```

**Your multi-tenant pattern:**
```sql
-- Normalized approach
fsiuser: UserId, Email, CustomerId
fsiaccount: AccountId, UserId, AccountNumber
fsionlineaccount: UserId, AccountNumber (for UC model)

-- Denormalized for performance
-- Cache customer settings to avoid CALL FindCustSettings on every request
```

**Trade-off:** Writes slower (update multiple places), reads faster (no joins)

---

### SQL vs NoSQL

**When to use SQL (MySQL, PostgreSQL):**
- ✅ Structured data with relationships
- ✅ ACID transactions required
- ✅ Complex queries with JOINs
- ✅ Data integrity constraints
- **Your use case:** Financial transactions, user accounts, billing

**When to use NoSQL:**

**Document DB (MongoDB, Couchbase):**
- ✅ Flexible schema
- ✅ Hierarchical data (JSON)
- ✅ Rapid iteration
- **Use case:** Product catalogs, content management

**Key-Value (Redis, DynamoDB):**
- ✅ Simple lookups by key
- ✅ High throughput
- ✅ Caching
- **Use case:** Session storage, cache

**Column-Family (Cassandra, HBase):**
- ✅ Time-series data
- ✅ Write-heavy workloads
- ✅ Massive scale
- **Use case:** Logs, analytics, IoT

**Graph DB (Neo4j):**
- ✅ Relationship-heavy data
- ✅ Social networks, recommendations

**Polyglot Persistence:**
Use multiple databases for different needs:
- MySQL: User accounts, transactions (ACID)
- Redis: Cache, session storage
- S3: File storage
- Elasticsearch: Full-text search

---

## Common System Design Problems

### 1. Design a URL Shortener (like bit.ly)

**Functional Requirements:**
- Shorten long URL to short URL
- Redirect short URL to original URL
- Optional: Custom aliases, expiration, analytics

**Non-functional:**
- High availability
- Low latency redirects
- 1M new URLs per day
- 100:1 read:write ratio

**API:**
```
POST /shorten
  Body: { "url": "https://example.com/very/long/url" }
  Response: { "short_url": "https://short.ly/abc123" }

GET /<short_code>
  Redirect to original URL
```

**Scale estimation:**
```
1M new URLs/day = 12 URLs/second
100:1 ratio = 1200 redirects/second
7 characters (base62) = 62^7 = 3.5 trillion combinations
Storage: 1M * 365 * 5 years * 500 bytes = 900 GB
```

**High-level design:**
```
        Load Balancer
             |
    +--------+--------+
    |                 |
App Servers      Cache (Redis)
    |                 |
    +--------+--------+
             |
        Database
     (short → long URL mapping)
```

**Encoding algorithm:**
```python
# Base62 encoding (0-9, a-z, A-Z)
def encode(id):
    chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    result = ""
    while id > 0:
        result = chars[id % 62] + result
        id = id // 62
    return result

# Auto-incrementing ID → short code
id = 123456789
short_code = encode(id)  # "8M0kX"
```

**Database schema:**
```sql
CREATE TABLE urls (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    short_code VARCHAR(10) UNIQUE NOT NULL,
    original_url VARCHAR(2048) NOT NULL,
    created_at TIMESTAMP,
    expires_at TIMESTAMP,
    INDEX idx_short (short_code)
);
```

**Optimization:**
- Cache hot URLs in Redis (80% hit rate)
- CDN for static redirect pages
- Bloom filter to check existence before DB hit

**Deep dive questions:**
- How to handle custom aliases? (Check uniqueness, reserve keywords)
- Analytics? (Async write to analytics DB via message queue)
- Expiration? (Cron job or lazy deletion on read)
- Security? (Validate URLs, prevent malicious sites, rate limit)

---

### 2. Design a Rate Limiter

**Requirements:**
- Limit requests per user per time window
- Multiple limits (per API endpoint, global)
- Distributed system (multiple servers)

**API:**
```
boolean allowRequest(userId, endpoint)
```

**Algorithm choice: Sliding Window Log**

**Implementation:**
```
Redis key: "rate_limit:{userId}:{endpoint}"
Value: Sorted set of timestamps

On each request:
1. Remove timestamps older than window (60 seconds ago)
2. Count remaining timestamps
3. If count < limit: add current timestamp, allow
4. If count >= limit: reject
```

**Code:**
```python
def allow_request(user_id, endpoint, limit, window_seconds):
    key = f"rate_limit:{user_id}:{endpoint}"
    now = time.time()
    
    # Remove old timestamps
    redis.zremrangebyscore(key, 0, now - window_seconds)
    
    # Count requests in window
    count = redis.zcard(key)
    
    if count < limit:
        # Add current request
        redis.zadd(key, {now: now})
        redis.expire(key, window_seconds)
        return True
    
    return False
```

**Distributed considerations:**
- Race condition: Use Redis MULTI/EXEC transaction
- Multiple datacenters: Eventual consistency, or sync writes
- Precision: Sliding window vs fixed window trade-off

---

### 3. Design a Notification System

**Requirements:**
- Send email, SMS, push notifications
- Millions of notifications per day
- Prioritization (urgent vs normal)
- Retry failed deliveries
- Track delivery status

**High-level design:**
```
       API Gateway
            |
     Notification Service
            |
    +--------------+--------------+
    |              |              |
Email Queue    SMS Queue    Push Queue
    |              |              |
Email Workers  SMS Workers  Push Workers
    |              |              |
SendGrid       Twilio         FCM/APNS
```

**Database:**
```sql
CREATE TABLE notifications (
    id BIGINT PRIMARY KEY,
    user_id BIGINT,
    type ENUM('email', 'sms', 'push'),
    priority ENUM('urgent', 'normal', 'low'),
    template_id INT,
    data JSON,
    status ENUM('pending', 'sent', 'failed', 'bounced'),
    scheduled_at TIMESTAMP,
    sent_at TIMESTAMP,
    retry_count INT DEFAULT 0
);

CREATE TABLE notification_logs (
    id BIGINT PRIMARY KEY,
    notification_id BIGINT,
    provider VARCHAR(50),
    response JSON,
    created_at TIMESTAMP
);
```

**Workflow:**
```
1. API receives notification request
2. Validate user preferences (opt-in/opt-out)
3. Enqueue to appropriate queue
4. Worker picks up job
5. Send via provider (SendGrid, Twilio)
6. Update status
7. On failure: retry with exponential backoff
```

**Optimizations:**
- Batch emails (1000 at a time to SendGrid)
- Template caching (don't regenerate each time)
- User preference caching (don't check DB each time)
- Dead letter queue for permanent failures

**Deep dive:**
- How to prevent duplicate sends? (Idempotency key)
- How to handle unsubscribes? (Check user preferences table)
- How to prioritize? (Separate queues, more workers for urgent)
- How to track opens/clicks? (Tracking pixel, redirect links)

---

### 4. Design a News Feed (like Facebook/Twitter)

**Requirements:**
- User follows other users
- Feed shows posts from followed users
- Recent posts first
- 100M DAU, each user follows 200, views feed 10 times/day

**Two approaches:**

**A) Pull Model (Fan-out on Read)**
```
User requests feed →
  Query: SELECT * FROM posts 
         WHERE user_id IN (followed_users) 
         ORDER BY created_at DESC 
         LIMIT 20
```
**Pros:** Fast writes, no storage duplication  
**Cons:** Slow reads (must join at read time)

**B) Push Model (Fan-out on Write)**
```
User creates post →
  For each follower:
    Write post_id to their feed table
    
User requests feed →
  Read from pre-generated feed table
```
**Pros:** Fast reads  
**Cons:** Slow writes (especially for celebrities), storage duplication

**Hybrid approach (Best):**
```
Regular users (< 10k followers): Push model
Celebrities (> 10k followers): Pull model

Feed = Pre-generated feed + Recent celebrity posts merged
```

**Database:**
```sql
CREATE TABLE posts (
    id BIGINT PRIMARY KEY,
    user_id BIGINT,
    content TEXT,
    created_at TIMESTAMP,
    INDEX idx_user_time (user_id, created_at)
);

CREATE TABLE follows (
    follower_id BIGINT,
    followee_id BIGINT,
    PRIMARY KEY (follower_id, followee_id),
    INDEX idx_followee (followee_id)  -- For fan-out
);

CREATE TABLE feeds (
    user_id BIGINT,
    post_id BIGINT,
    created_at TIMESTAMP,  -- Denormalized for sorting
    PRIMARY KEY (user_id, created_at, post_id)
);
```

**Optimizations:**
- Cache user's feed (Redis, 1000 most recent posts)
- Paginate (cursor-based, not offset)
- Async fan-out via message queue
- Pre-compute at off-peak hours

---

### 5. Design a Distributed Cache

**Requirements:**
- Get/Put/Delete operations
- High availability
- Scalability (add/remove nodes)
- Data partitioning

**High-level design:**
```
    Client
       |
Cache Cluster (Consistent Hashing)
  Node 1  Node 2  Node 3  Node 4
  
Each node: In-memory key-value store
```

**Consistent hashing:**
- Keys distributed evenly
- Adding/removing node affects minimal keys

**Replication:**
```
Primary Node 1 → Replica Node 1a
Primary Node 2 → Replica Node 2a
Primary Node 3 → Replica Node 3a
```

**Eviction policies:**
- LRU (Least Recently Used)
- LFU (Least Frequently Used)
- TTL (Time To Live)

**Cache invalidation:**
- Write-through: Update cache + DB
- Write-around: Update DB, invalidate cache
- Write-back: Update cache, async update DB

**Redis Cluster example:**
- 16,384 hash slots
- Each node responsible for subset of slots
- Automatic resharding when nodes added/removed
- Master-slave replication for availability

---

## Real-World Examples from Your Experience

### 1. Multi-Tenant SaaS Billing Platform

**Scale:**
- 10,000+ tenants
- Millions of invoices per month
- 99.9% uptime SLA
- PCI-DSS and HIPAA compliant

**Architecture:**
```
            CDN (static assets)
                 |
            AWS ELB
                 |
      +----------+----------+
      |          |          |
   EIC (Zend) CC (Laravel) CSR (Laravel)
   Kubernetes Kubernetes   Kubernetes
      |          |          |
      +-----Redis Cache-----+
                 |
           billingmaster
          (routing database)
                 |
      +----------+----------+
      |                     |
billingclient1        billingclient2
(Stack 1 tenants)     (Stack 2 tenants)
```

**Key design decisions:**

**1. Sharding strategy: Entity-based**
- All data for one customer in one database
- Pros: No cross-shard joins, tenant isolation, easier compliance
- Cons: Large tenants can be hot spots

**2. Routing layer:**
```sql
-- billingmaster lookup
SELECT StackNum, DBName FROM customer WHERE CustomerId = ?;

-- Then connect to billingclientN
```

**3. Configuration service (CSR):**
- Centralized settings across all apps
- Redis cache (1 hour TTL)
- Atom-based hierarchical settings

**4. Async processing:**
- Invoice generation queue
- Email sending queue
- Payment retry queue

**5. Multi-region:** US-East, US-West, EU

---

### 2. Payment Processing System

**Requirements:**
- Process credit card payments
- Handle retries for failed payments
- Idempotent (don't charge twice)
- Audit trail for compliance

**Design:**
```
          Payment API
               |
        Idempotency Check (Redis)
               |
        +------+------+
        |             |
   Validate      Payment DB
   (CVV, etc)    (transactions)
        |
   Payment Gateway (Stripe/Authorize.net)
        |
   +----+----+
   |         |
Success   Failure
   |         |
   |    Retry Queue
   |         |
 Update    Worker
 Status    (exponential backoff)
```

**Idempotency:**
```python
def process_payment(payment_id, idempotency_key):
    # Check if already processed
    cached = redis.get(f"payment:{idempotency_key}")
    if cached:
        return json.loads(cached)
    
    # Process payment
    result = stripe.charge(...)
    
    # Cache result (24 hours)
    redis.setex(f"payment:{idempotency_key}", 86400, json.dumps(result))
    
    return result
```

**Retry logic:**
```
Attempt 1: Immediate
Attempt 2: +1 minute
Attempt 3: +5 minutes
Attempt 4: +15 minutes
Attempt 5: +1 hour
After 5 attempts: Dead letter queue, manual review
```

**Audit trail:**
```sql
CREATE TABLE payment_audit (
    id BIGINT PRIMARY KEY,
    payment_id BIGINT,
    action VARCHAR(50),  -- 'attempted', 'success', 'failed', 'refunded'
    details JSON,
    created_at TIMESTAMP
);
```

---

### 3. Report Generation System

**Problem:** Large reports (100M+ rows) timing out

**Original design (blocking):**
```
User clicks "Generate Report"
  → Query 100M rows (5 minutes)
  → Generate PDF (3 minutes)
  → Display to user
  
User's browser times out after 30 seconds
```

**Improved design (async):**
```
User clicks "Generate Report"
  ↓
API creates job record, returns job_id immediately
  ↓
Background worker picks up job
  ↓
Streams query results (pagination)
  ↓
Generates PDF in chunks
  ↓
Uploads to S3
  ↓
Sends email with download link
  ↓
User downloads from S3 (or views in browser)
```

**Implementation:**
```sql
-- Don't pull all rows at once
-- Stream with cursor pagination
SELECT * FROM fsidocument 
WHERE CustomerId = ? 
  AND created_at > ?
ORDER BY created_at
LIMIT 10000 OFFSET 0;

-- Process in chunks of 10k
-- Append to PDF
-- Continue with next chunk
```

**Optimization:**
- Indexed query (CustomerId, created_at)
- Partition table by month
- Archive old data to S3
- Generate summary reports (aggregated) instead of detail

---

## Evaluation Criteria

Interviewers look for:

### 1. Clarifying Questions (10%)
- Did you ask about scale, performance requirements, constraints?
- Did you define functional vs non-functional requirements?

### 2. High-Level Design (20%)
- Clear component diagram
- Logical data flow
- Appropriate technology choices

### 3. Deep Dive (30%)
- Database schema
- API design
- Scalability considerations
- Caching strategy

### 4. Trade-offs (20%)
- Acknowledged pros/cons of decisions
- Discussed alternatives
- Cost vs performance vs complexity

### 5. Bottlenecks & Improvements (15%)
- Identified single points of failure
- Proposed scaling improvements
- Discussed monitoring and operations

### 6. Communication (5%)
- Clear explanations
- Drew diagrams
- Engaged with interviewer

---

## Practice Problems

**Beginner:**
1. Design a file storage service (like Dropbox)
2. Design a web crawler
3. Design a chat application (like WhatsApp)

**Intermediate:**
4. Design YouTube
5. Design Uber
6. Design Instagram
7. Design Twitter
8. Design a recommendation system

**Advanced:**
9. Design a distributed database
10. Design a search engine (like Google)
11. Design a distributed message queue
12. Design a stock exchange

---

## Resources for Further Study

**Books:**
- "Designing Data-Intensive Applications" by Martin Kleppmann
- "System Design Interview" by Alex Xu
- "Database Internals" by Alex Petrov

**Online:**
- System Design Primer (GitHub)
- High Scalability blog
- AWS Architecture Center
- Papers We Love (distributed systems papers)

**Practice:**
- Mock interviews with friends
- Draw out systems you use daily
- Read engineering blogs (Netflix, Uber, Airbnb tech blogs)

---

**Remember:**
- There's no single "right" answer
- Focus on trade-offs, not perfect solutions
- Communicate your thought process
- Ask clarifying questions
- Start simple, then scale
- Drive the conversation (don't wait for prompting)

Good luck! 🚀
