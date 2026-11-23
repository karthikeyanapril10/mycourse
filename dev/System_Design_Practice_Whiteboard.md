# System Design Practice: Whiteboard Edition

> **For 12+ Years Experience**: Interviewers expect you to design end-to-end systems, not just components

---

## 📐 What is System Design Interview?

**NOT a coding interview.** You'll spend 45 minutes:
- Drawing boxes and arrows (services, databases, queues)
- Explaining tradeoffs ("Why RabbitMQ instead of Kafka?")
- Estimating scale ("100k invoices/day = 1.16/sec average, 50/sec peak")
- Handling follow-ups ("What if S3 goes down?")

**You'll be judged on:**
✅ Structured thinking (not random brainstorming)  
✅ Tradeoff analysis (every choice has pros/cons)  
✅ Scale estimation (back-of-envelope math)  
✅ Communication (can you explain it clearly?)

---

## 🎯 5 System Design Problems (From Your Experience)

### **Problem 1: Invoice Delivery System**

**Interviewer:** "Design Billtrust's invoice delivery system. 100k invoices/month, customers receive PDFs via email."

---

#### **Step 1: Requirements Clarification (5 min)**

**You Ask:**
- "What's the invoice volume? 100k/month = 3,333/day = 2.3/sec average. What's peak?"
- "Do customers need invoices immediately or can we batch?"
- "What if email delivery fails? Retry logic? DLQ?"
- "Are PDFs generated on-demand or pre-generated?"
- "What's the SLA? 'Within 15 minutes' vs 'within 1 hour'?"

**Interviewer Answers:**
- Peak is 10x average (month-end billing spike) = 23 msgs/sec
- SLA: 15 minutes from invoice creation to customer email
- Retry failed emails 3 times, then DLQ
- PDFs generated on-demand (not pre-generated)

---

#### **Step 2: High-Level Design (10 min)**

**Draw This:**

```
┌──────────────┐
│  Billing API │  ← Creates invoice record in DB
└──────┬───────┘
       │ Publish event
       ▼
┌──────────────────┐
│    RabbitMQ      │  ← Invoice generation queue
│  (invoice_jobs)  │
└──────┬───────────┘
       │ Consume
       ▼
┌──────────────────┐
│  PDF Generator   │  ← Worker pods (5-20 auto-scale)
│    Workers       │  → Generate PDF from invoice data
└──────┬───────────┘
       │ Upload
       ▼
┌──────────────────┐
│   AWS S3         │  ← Store PDF (key: invoice_id.pdf)
└──────┬───────────┘
       │ Publish event
       ▼
┌──────────────────┐
│    RabbitMQ      │  ← Email sending queue
│  (email_jobs)    │
└──────┬───────────┘
       │ Consume
       ▼
┌──────────────────┐
│  Email Workers   │  ← SendGrid API
└──────────────────┘
```

**Key Components:**
1. **Billing API**: REST API, creates invoice record in MySQL
2. **RabbitMQ (invoice_jobs)**: Task queue, prefetch_count=1 for fair load balancing
3. **PDF Generator Workers**: Kubernetes pods, 5-20 auto-scale on queue depth
4. **AWS S3**: Object storage, PDF files (10 MB avg each)
5. **RabbitMQ (email_jobs)**: Second queue for email sending
6. **Email Workers**: Call SendGrid API, retry 3x on failure

---

#### **Step 3: Deep Dive (15 min)**

**Interviewer:** "How do you handle PDF generation failures?"

**You Answer:**
```
Failure Scenarios:

1. Worker Pod Crashes Mid-Generation:
   ✅ Solution: RabbitMQ message requeued (not acked)
   → Another worker picks it up
   → prefetch_count=1 ensures fair redistribution

2. Customer Data Missing (DB query returns NULL):
   ❌ Solution: Send to DLQ after 3 retries
   → Log error: "Missing customer data for invoice 12345"
   → Ops team investigates DLQ manually
   → Don't block queue with unfixable messages

3. S3 Upload Timeout:
   🔄 Solution: Retry with exponential backoff
   → 1st retry: 2 sec delay
   → 2nd retry: 4 sec delay
   → 3rd retry: 8 sec delay
   → If all fail → DLQ

4. Duplicate Messages (Network Retry):
   ✅ Solution: Idempotency key (invoice_id)
   → Check Redis: "processed:invoice_12345" before generating
   → If exists → skip (already generated)
   → TTL: 24 hours
```

**Interviewer:** "How do you scale during month-end spike (10x traffic)?"

**You Answer:**
```
Auto-Scaling Strategy:

Kubernetes HPA (Horizontal Pod Autoscaler):
  Metric: RabbitMQ queue depth
  Trigger: queue_depth > 100 messages
  
  Min Replicas: 5 (normal)
  Max Replicas: 20 (peak)
  
  Scale Up:
    Queue depth 500 → 10 pods
    Queue depth 1000 → 15 pods
    Queue depth 2000 → 20 pods (max)
  
  Scale Down:
    Queue depth < 50 for 5 min → scale down 1 pod
    Gradual (not instant) to avoid thrashing

Cost:
  Normal: 5 pods × $50/month = $250
  Peak (1 day): 20 pods × $50/month ÷ 30 = $33
  Total: $283/month
```

---

#### **Step 4: Tradeoffs & Alternatives (10 min)**

**Interviewer:** "Why RabbitMQ instead of Kafka?"

**You Answer:**
```
RabbitMQ is the right choice because:

✅ Task Queue Pattern:
   - Each invoice processed exactly once
   - Message deleted after generation (no retention needed)
   - Worker pulls 1 job at a time (prefetch=1)

✅ Throughput:
   - 23 msgs/sec peak (RabbitMQ handles 1000+ msgs/sec easily)
   - Kafka is overkill for this volume

✅ Operational Simplicity:
   - RabbitMQ: Single broker, 2 GB RAM
   - Kafka: 3+ brokers, ZooKeeper, 8 GB RAM

Kafka would be better IF:
  - Multiple consumers need same events (pub/sub)
  - Event replay required (reprocess last week)
  - Throughput > 1000 msgs/sec
```

**Interviewer:** "What if S3 goes down?"

**You Answer:**
```
Disaster Recovery:

Option 1: Multi-Region S3 (Best)
  - Primary: us-east-1
  - Failover: us-west-2
  - Worker tries us-east-1, falls back to us-west-2 on error
  - Cost: $0.023/GB (same as single-region)

Option 2: Retry + DLQ (Good Enough)
  - S3 downtime is rare (99.99% uptime = 4 min/month)
  - Workers retry 3x with backoff
  - If all fail → DLQ
  - After S3 recovers → replay DLQ manually

Option 3: Local Disk Cache (Complex)
  - Workers save PDF to local disk first
  - Background job uploads to S3
  - Pro: Survives S3 outage
  - Con: Pods are ephemeral (restart = data loss)
  - Not worth the complexity for 4 min/month downtime
```

---

#### **Step 5: Monitoring & Metrics (5 min)**

**You Say:**
```
Monitoring Dashboard (Datadog):

1. Queue Depth:
   - Alert: > 1000 messages (backlog building)
   - Critical: > 5000 messages (page oncall)

2. Processing Rate:
   - Target: 23 msgs/sec (peak), 2.3 msgs/sec (normal)
   - Alert: < 10 msgs/sec during peak (workers slow)

3. DLQ Depth:
   - Alert: > 10 messages (something failing)
   - Critical: > 50 messages (systemic issue)

4. PDF Generation Latency:
   - p50: 2 sec, p95: 5 sec, p99: 10 sec
   - Alert: p95 > 10 sec (bottleneck)

5. S3 Upload Success Rate:
   - Target: 99.9%
   - Alert: < 99% (S3 issues)

6. Email Delivery Rate:
   - Target: 95% (5% bounced emails is normal)
   - Alert: < 90% (SendGrid issues)
```

---

### **Problem 2: Payment Processing System**

**Interviewer:** "Design a payment gateway for processing credit card transactions. 10k transactions/hour."

---

#### **Requirements (5 min)**

**You Ask:**
- "What payment methods? Credit card only or also ACH, PayPal?"
- "What's the success rate? 70% approved, 30% declined?"
- "Do we need PCI compliance? (Storing card numbers?)"
- "What's the retry policy? Retry declined cards?"
- "What about fraud detection?"

**Interviewer Answers:**
- Credit card only (Stripe/Authorize.Net API)
- 70% approved, 30% declined (normal for SaaS)
- PCI Level 1 compliance required (tokenize cards, don't store raw)
- No retry on declined (fraud risk), but retry on network errors
- Basic fraud detection: amount > $10k = manual review

---

#### **High-Level Design (10 min)**

```
┌──────────────┐
│  Web UI      │  ← Customer enters card
└──────┬───────┘
       │ POST /charge
       ▼
┌──────────────────┐
│  Payment API     │  ← Tokenize card (Stripe.js client-side)
│  (Node.js)       │  → Validate amount, customer_id
└──────┬───────────┘
       │ Publish event
       ▼
┌──────────────────┐
│    Kafka         │  ← Payment events stream
│ (payment_events) │  → Multiple consumers (billing, analytics, fraud)
└──────┬───────────┘
       │ Consume
       ▼
┌──────────────────┐
│ Payment Processor│  ← Call Stripe API
│    Workers       │  → Charge card, handle response
└──────┬───────────┘
       │ Update status
       ▼
┌──────────────────┐
│     MySQL        │  ← Payments table (transaction_id, status, amount)
└──────────────────┘
```

**Why Kafka instead of RabbitMQ?**
```
Payment events need multiple consumers:
  - Billing Service: Update invoice status
  - Analytics Service: Log to data warehouse
  - Fraud Service: Check for suspicious patterns
  
RabbitMQ fanout exchange could work, BUT:
  ✅ Kafka: Event replay (reprocess last week if analytics job fails)
  ✅ Kafka: Audit log (compliance requires 7-year retention)
  ✅ Kafka: Partitioning by customer_id (all events for a customer in order)
```

---

#### **Deep Dive: Idempotency (10 min)**

**Interviewer:** "How do you prevent double-charging?"

**You Answer:**
```
Idempotency Key Pattern:

Client Request:
  POST /charge
  {
    "idempotency_key": "uuid-12345",  ← Generated by client
    "amount": 100.00,
    "customer_id": "cust_67890",
    "stripe_token": "tok_visa_..."
  }

Server Logic:
  1. Check Redis: GET "charge:uuid-12345"
     → If exists: Return cached response (skip charge)
     → If not exists: Proceed to charge
  
  2. Call Stripe API:
     result = stripe.Charge.create(
       amount=10000,  # cents
       currency='usd',
       source=stripe_token,
       idempotency_key='uuid-12345'  ← Stripe also checks this!
     )
  
  3. Store result in Redis:
     SET "charge:uuid-12345" = result
     EXPIRE 24 hours
  
  4. Return response to client

Stripe's Guarantee:
  - If network fails after charge succeeds
  - Client retries with same idempotency_key
  - Stripe returns the ORIGINAL charge (doesn't create a new one)
```

---

#### **Deep Dive: Fraud Detection (10 min)**

**Interviewer:** "How do you detect fraud?"

**You Answer:**
```
Fraud Detection Rules (Real-Time):

Rule 1: Velocity Check
  - Same card used 5+ times in 1 hour → Block
  - Implementation: Redis counter
      INCR "card:4242424242424242:attempts"
      EXPIRE 3600 (1 hour)

Rule 2: Amount Threshold
  - Single charge > $10,000 → Manual review queue
  - Implementation: Publish to fraud_review_queue

Rule 3: Geolocation Mismatch
  - Card issued in US, charge from Russia → Block
  - Implementation: Check IP geolocation vs card BIN

Rule 4: Blacklist
  - Known stolen cards (from industry database)
  - Implementation: Redis set
      SISMEMBER "blacklist:cards" "4242424242424242"

ML Model (Batch, Not Real-Time):
  - Train on historical fraud (1% fraud rate)
  - Features: amount, time, merchant, card age, billing_zip
  - Score: 0-100 (100 = high fraud risk)
  - If score > 80 → Manual review
  - Runs async (not blocking payment flow)
```

---

### **Problem 3: User Authentication System (SSO + OAuth)**

**Interviewer:** "Design a Single Sign-On (SSO) system for enterprise customers. 10k companies, 1M total users."

---

#### **Requirements (5 min)**

- Support SAML 2.0 (enterprise standard)
- Support OAuth 2.0 (Google, Microsoft login)
- Session timeout: 8 hours
- Password reset flow
- Multi-factor authentication (MFA)

---

#### **High-Level Design (10 min)**

```
┌──────────────┐
│  Web App     │  ← User clicks "Login with SSO"
└──────┬───────┘
       │ Redirect
       ▼
┌──────────────────┐
│  Auth Service    │  ← Redirect to IdP (Okta, Azure AD)
│  (Node.js)       │  → Validate SAML response
└──────┬───────────┘
       │ Create session
       ▼
┌──────────────────┐
│     Redis        │  ← Session store (session_id → user_id)
│  (Session Store) │  → TTL: 8 hours
└──────────────────┘
       │
       ▼
┌──────────────────┐
│     MySQL        │  ← Users table (user_id, email, company_id)
└──────────────────┘
```

**Session Flow:**
```
1. User clicks "Login with Okta"
2. Auth Service redirects to Okta login page
3. User enters credentials in Okta (not our system!)
4. Okta redirects back with SAML assertion (XML)
5. Auth Service validates SAML signature
6. Auth Service creates session:
     session_id = uuid.v4()
     Redis: SET "session:abc123" = {"user_id": 456, "company_id": 789}
     EXPIRE 28800 (8 hours)
7. Auth Service sets cookie: session_id=abc123
8. User redirects to app homepage
```

---

#### **Deep Dive: Session Storage (10 min)**

**Interviewer:** "Why Redis instead of MySQL for sessions?"

**You Answer:**
```
Redis is better for sessions because:

✅ Speed:
   - Redis: 0.1 ms (in-memory)
   - MySQL: 10 ms (disk I/O)
   - Every HTTP request checks session → speed matters

✅ TTL (Automatic Expiration):
   - Redis: EXPIRE 28800 (8 hours)
   - MySQL: Requires cron job to delete expired rows

✅ Scale:
   - 1M users × 1 KB session = 1 GB (fits in memory)
   - Redis: 1 GB = $50/month
   - MySQL: Need indexes, cleanup jobs, more complex

Tradeoff:
  ❌ Redis is in-memory → If Redis crashes, all sessions lost
  ✅ Solution: Redis cluster with replication (master + 2 replicas)
       → If master fails, replica promoted automatically
       → Downtime: 10 seconds (not 0, but acceptable)
```

---

### **Problem 4: Fraud Detection System**

**Interviewer:** "Design a system to detect fraudulent transactions in real-time. 100k transactions/hour."

---

#### **Requirements (5 min)**

- Detect fraud within 100 ms (can't block payment flow)
- Rules engine: Velocity checks, blacklist, geolocation
- ML model: Fraud score 0-100
- Manual review queue for suspicious transactions
- Analyst dashboard

---

#### **High-Level Design (10 min)**

```
┌──────────────┐
│  Payment API │  ← Transaction created
└──────┬───────┘
       │ Publish event
       ▼
┌──────────────────┐
│    Kafka         │  ← Transaction stream
│ (transactions)   │
└──────┬───────────┘
       │ Consume (real-time)
       ▼
┌──────────────────┐
│  Rules Engine    │  ← Check velocity, blacklist, geo
│  (Go, 10 ms)     │  → Block or Allow
└──────┬───────────┘
       │ Publish result
       ▼
┌──────────────────┐
│    Kafka         │  ← Fraud decisions
│ (fraud_events)   │
└──────┬───────────┘
       │ Consume (batch)
       ▼
┌──────────────────┐
│  ML Model        │  ← Predict fraud score (Python, 500 ms)
│ (Async)          │  → Score > 80 → Review queue
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  Review Queue    │  ← Analysts manually approve/reject
│  (Postgres)      │
└──────────────────┘
```

**Key Insight:**
```
Rules Engine (10 ms) runs SYNCHRONOUSLY (before payment completes)
ML Model (500 ms) runs ASYNCHRONOUSLY (after payment completes)

Why?
  - 10 ms = Acceptable payment latency
  - 500 ms = Too slow, would block payment flow
  - ML model catches fraud AFTER charge, then we refund if fraud
```

---

### **Problem 5: Real-Time Notification System**

**Interviewer:** "Design a system to send push notifications to 10M users. Email, SMS, mobile push."

---

#### **High-Level Design (10 min)**

```
┌──────────────┐
│  Event Source│  ← Invoice created, payment succeeded, etc.
└──────┬───────┘
       │ Publish event
       ▼
┌──────────────────┐
│    Kafka         │  ← Notification events
│ (notifications)  │
└──────┬───────────┘
       │ Consume
       ▼
┌──────────────────┐
│  Fan-Out Service │  ← Determine: Who gets notified? (email/SMS/push?)
│  (Node.js)       │  → Query user preferences from DB
└──────┬───────────┘
       │ Publish to 3 queues
       ▼
┌───────────┬───────────┬───────────┐
│ Email Q   │  SMS Q    │  Push Q   │
└─────┬─────┴─────┬─────┴─────┬─────┘
      │           │           │
      ▼           ▼           ▼
┌──────────┐┌──────────┐┌──────────┐
│ SendGrid ││ Twilio   ││  FCM     │
└──────────┘└──────────┘└──────────┘
```

**Scale Estimation:**
```
10M users, 1 notification/user/day = 10M notifications/day
  = 416k/hour
  = 115/sec average
  = 1150/sec peak (10x)

Each queue needs to handle ~400 msgs/sec
  → RabbitMQ can handle this (single broker)
  → Or use AWS SQS (serverless, auto-scales)
```

---

## 🎯 How to Practice

### **Week 1: Draw on Paper**
- ✅ Draw all 5 designs on paper/whiteboard
- ✅ Practice drawing boxes, arrows, labels
- ✅ Time yourself: 10 min per high-level design

### **Week 2: Explain Out Loud**
- 📹 Record yourself explaining each design (15 min)
- 🎤 Practice saying: "I chose X because Y, the tradeoff is Z"
- ⏱️ Keep it under 15 minutes total (45 min interview = 15 min design + 30 min deep dive)

### **Week 3: Back-of-Envelope Math**
- 🧮 Practice estimating:
  - 100k requests/month = ? per second
  - 1M users × 1 KB session = ? GB memory
  - 10 TB data × $0.023/GB = ? per month

### **Week 4: Mock Interview**
- 🎯 Ask a friend to grill you: "What if S3 goes down?"
- 🔥 Practice defending your choices: "Why RabbitMQ not Kafka?"

---

## 💡 Key Takeaways

✅ **Start with requirements**: Don't jump to drawing  
✅ **High-level first, then deep dive**: Don't go straight to Redis keys  
✅ **Every choice has a tradeoff**: "RabbitMQ is simpler, Kafka scales better"  
✅ **Estimate scale**: "100k/month = 2.3/sec average, 23/sec peak"  
✅ **Monitor everything**: "Alert if queue depth > 1000"

You've BUILT these systems at Billtrust. Now you just need to explain them on a whiteboard. 🚀
