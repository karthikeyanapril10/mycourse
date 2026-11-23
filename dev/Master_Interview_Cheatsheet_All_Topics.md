# Master Interview Cheatsheet: All Topics

> **Quick Reference**: Review this 1 hour before your interview

---

## 🎯 60-Second Intro ("Tell Me About Yourself")

**Template:**
```
"I'm Karthik, a Staff Engineer at Billtrust with 12+ years in fintech and SaaS.

I specialize in production triage — I've led 100+ NJQRT cases, preventing over 
$500k in revenue loss. I developed an AI-assisted triage workflow (RC-5 protocol) 
that reduced investigation time from 6 hours to 2 hours, now adopted by my team.

I'm hands-on with backend: PHP/Laravel, .NET, MySQL, RabbitMQ, Kafka. Recently 
scaled invoice generation from 5 to 20 workers, handling 100k invoices/month.

I'm looking for Staff Engineer or SRE roles where I can apply my expertise in 
fintech platforms and production reliability."
```

**Time:** Under 60 seconds  
**Practice:** Record 5 times, reduce "umm"s

---

## 📚 OOP Concepts (SOLID + Design Patterns)

### **4 Pillars of OOP**
1. **Encapsulation** - Hide data, expose methods (Invoice class, private $amount)
2. **Inheritance** - Code reuse (BaseController → InvoiceController)
3. **Polymorphism** - Same interface, different implementations (PaymentProcessor)
4. **Abstraction** - Hide complexity (InvoiceRepository hides SQL)

### **SOLID Principles (2-Min Explanation)**
- **S** = Single Responsibility (one class, one reason to change)
- **O** = Open/Closed (open for extension, closed for modification)
- **L** = Liskov Substitution (subclass must be substitutable for parent)
- **I** = Interface Segregation (don't force methods you don't need)
- **D** = Dependency Inversion (depend on interfaces, not concrete classes)

**Your Experience:**
"At Billtrust:
- **S**: Repository separates persistence from business logic
- **O**: PaymentGateway interface (add Stripe/AuthNet without changing code)
- **L**: All notification classes (Email/SMS/Push) are interchangeable
- **I**: Cacheable, Auditable interfaces are small and focused
- **D**: Laravel DI injects dependencies (Mailer, Cache, DB)"

### **Design Patterns (Know These 5)**

| Pattern | Use Case | Billtrust Example |
|---------|----------|-------------------|
| **Singleton** | One instance (Logger, DB connection) | Laravel singleton binding |
| **Factory** | Create objects without exposing logic | PaymentGatewayFactory::create($type) |
| **Observer** | Event-driven (pub/sub) | Laravel events, RabbitMQ |
| **Repository** | Data access layer | InvoiceRepository hides SQL |
| **Strategy** | Interchangeable algorithms | Discount calculation (% vs fixed) |

**Quick Answer:**
"At Billtrust, we use Factory pattern for payment gateway selection — customers choose Stripe or Authorize.Net, and PaymentGatewayFactory creates the right gateway. This keeps client code clean (no if/else chains)."

---

## 🏗️ System Design (5 Systems You MUST Know)

### **1. Invoice Delivery System (100k invoices/month)**

```
Billing API → RabbitMQ (invoice_jobs) → PDF Workers (5-20 auto-scale)
   → S3 → RabbitMQ (email_jobs) → Email Workers → SendGrid
```

**Scale:** 100k/month = 2.3/sec avg, 23/sec peak  
**Key:** Auto-scaling (HPA on queue depth), idempotency (Redis), DLQ

**Interview Answer (2 min):**
"I'd use RabbitMQ for task distribution — each invoice processed exactly once. PDF workers auto-scale 5-20 pods based on queue depth via Kubernetes HPA. For idempotency, we check Redis (processed:{invoice_id}) before generating. Failed messages go to DLQ after 3 retries. At Billtrust, this handled 100k invoices/month with zero downtime."

---

### **2. Payment Processing (10k transactions/hour)**

```
Web UI → Payment API → Kafka (payment_events) → Workers → Stripe API
   → MySQL (payments table) → Multiple consumers (billing, analytics, fraud)
```

**Why Kafka?** Event replay, multiple consumers, audit log (7-year retention)

**Key Decisions:**
- Idempotency: UUID per transaction, check Redis before charging
- At-least-once delivery: Ack AFTER processing
- Fraud detection: Velocity checks (Redis counters), blacklist, geolocation

---

### **3. User Authentication (SSO + OAuth)**

```
Web App → Auth Service → Okta (SAML) → Redis (session store, 8h TTL)
   → MySQL (users table)
```

**Why Redis?** Speed (0.1ms vs 10ms MySQL), TTL auto-expiration

---

### **4. Fraud Detection (Real-Time)**

```
Payment API → Kafka → Rules Engine (10ms, synchronous) → Block/Allow
   → ML Model (500ms, async) → Review Queue
```

**Key:** Rules run BEFORE payment completes, ML runs AFTER (async)

---

### **5. Notification System (10M users)**

```
Event Source → Kafka → Fan-Out Service → 3 queues (Email, SMS, Push)
   → SendGrid/Twilio/FCM
```

**Scale:** 10M/day = 115/sec avg, 1150/sec peak = 400 msgs/sec per queue

---

## 💬 Behavioral (STAR Stories - Know 3)

### **Story 1: Technical Problem (NJQRT-14987)**
- **S**: Invoice discount bug, 42 customers, $128k at risk
- **T**: 48-hour SLA to find root cause
- **A**: RC-5 protocol (checked prior conclusion, universality, reachability, signature, fix vs mask). Ran 12 MySQL queries, verified 3 files.
- **R**: Fixed in 24 hours, $128k saved, RC-5 adopted by team

**Time:** 90 seconds

---

### **Story 2: Scaling Under Pressure**
- **S**: Month-end billing, queue backed up 10k → 15k messages, customers expecting invoices by 9 AM
- **T**: 2 hours to clear or notify customers of delay
- **A**: Scaled pods 5 → 20 (manual override), increased S3 timeout, requeued DLQ
- **R**: Cleared by 8:50 AM (10 min before deadline), implemented multi-region S3 fallback

---

### **Story 3: Mentoring Junior Devs**
- **S**: 2 new devs, 6-8 hours per case (should be 2 hours), 40% false root causes
- **T**: Get them productive faster
- **A**: Created RC-5 checklist, global rules doc (CLAUDE.md), weekly code reviews, measured progress
- **R**: 8h → 2h in 3 months, false root causes 40% → 5%, team velocity 15 → 25 cases/month

---

## 🗄️ Database (MySQL)

### **Indexing**
- **Without index:** Full table scan (slow)
- **With index:** B-tree lookup (fast)
- **When to index:** WHERE, JOIN, ORDER BY columns
- **Cost:** Slower writes (index must update)

**Example:**
```sql
-- Slow (no index on CustomerId)
SELECT * FROM fsiinvoice WHERE CustomerId = 12345;

-- Fast (index on CustomerId)
CREATE INDEX idx_customer ON fsiinvoice(CustomerId);
```

### **Query Optimization**
- Use `EXPLAIN` to see execution plan
- Avoid `SELECT *` (specify columns)
- Use `LIMIT` for large result sets
- Parameterized queries (prevent SQL injection)

**At Billtrust:**
"We always scope queries by tenant (CustomerId) to ensure multi-tenant isolation. All queries use parameterized statements to prevent SQL injection."

---

## 🔄 RabbitMQ vs Kafka

| Feature | RabbitMQ | Kafka |
|---------|----------|-------|
| **Pattern** | Task queue (1 consumer) | Event stream (N consumers) |
| **Delivery** | At-least-once | At-least-once (or exactly-once) |
| **Retention** | Deleted after consumed | Days/weeks (configurable) |
| **Use For** | Invoice PDF, email jobs | Payment events, audit log |
| **Throughput** | 1000+ msgs/sec | 100k+ msgs/sec |

**When to Use Each:**
- **RabbitMQ**: Task queues (1 worker per job), short-lived messages
- **Kafka**: Pub/sub (multiple consumers), event replay, audit log

**At Billtrust:**
"We use RabbitMQ for invoice generation (task queue, deleted after generation) and Kafka for payment events (multiple teams read same events: billing, analytics, fraud)."

---

## ☁️ AWS Services (Know These 5)

### **1. EC2 (Compute)**
- **Instance Types:** t3 (burstable), m5 (balanced), c5 (compute), r5 (memory)
- **Auto-Scaling:** Based on CPU, queue depth, custom metric

### **2. RDS (Database)**
- **Multi-AZ:** Synchronous replication, automatic failover (<1 min)
- **Read Replicas:** Async replication, scale reads

### **3. S3 (Storage)**
- **Storage Classes:** Standard (hot), IA (infrequent access), Glacier (archive)
- **Use:** Store invoice PDFs, backups

### **4. SQS (Queue)**
- **Standard:** Unlimited throughput, best-effort ordering
- **FIFO:** 300 TPS, strict ordering, exactly-once

### **5. SNS (Pub/Sub)**
- **Use:** Fan-out (1 message → N subscribers)
- **Combo:** SNS → SQS (broadcast to multiple queues)

---

## 🐳 Docker + Kubernetes

### **Docker**
```dockerfile
FROM php:8.2-fpm
COPY . /var/www
RUN composer install
CMD php-fpm
```

**Benefits:** Consistent environment (dev = prod), easy scaling

### **Kubernetes**
- **Pod:** Smallest unit (1+ containers)
- **Deployment:** Manages replicas (5 → 20 pods)
- **Service:** Load balancer (distributes traffic)
- **HPA:** Auto-scaling based on CPU, queue depth

**At Billtrust:**
"Our invoice workers auto-scale 5-20 pods based on RabbitMQ queue depth. HPA monitors the queue every 15 seconds and scales up when depth > 100 messages."

---

## 🧪 Testing (Cypress Automation)

### **Page Object Model**
```typescript
// pages/AdminPage.ts
export class AdminPage {
  elements = {
    passwordTextBox: () => cy.get("[name='NewPassword']"),
    updateButton: () => cy.get("input.btncc[value='Update']")
  };
  
  enterPassword(password: string) {
    this.elements.passwordTextBox().clear().type(password);
  }
}

// tests/admin.spec.ts
it('updates password', () => {
  adminPage.enterPassword('newPass123');
  adminPage.clickUpdate();
  cy.contains('Password updated').should('be.visible');
});
```

**Benefits:** Reusable, maintainable, separates test logic from selectors

---

## 🔐 Security (Common Vulnerabilities)

### **1. SQL Injection**
```php
// ❌ Bad (vulnerable)
$sql = "SELECT * FROM users WHERE id = " . $_GET['id'];

// ✅ Good (parameterized)
$sql = "SELECT * FROM users WHERE id = ?";
$stmt = $db->prepare($sql);
$stmt->execute([$_GET['id']]);
```

### **2. XSS (Cross-Site Scripting)**
```php
// ❌ Bad (vulnerable)
echo "<div>" . $_GET['name'] . "</div>";

// ✅ Good (escaped)
echo "<div>" . htmlspecialchars($_GET['name'], ENT_QUOTES) . "</div>";
```

### **3. Authentication**
- **Never store plaintext passwords** (use bcrypt/Argon2)
- **Session timeout** (8 hours, Redis TTL)
- **Rate limiting** (5 failed logins → lock account)

**At Billtrust:**
"All database queries use parameterized statements. We escape user input before rendering. Session tokens stored in Redis with 8-hour TTL."

---

## 🛠️ CI/CD Pipeline

```
Push Code → GitHub → Run Tests (Jest/Cypress) → Lint (ESLint/PHPCS)
   → Security Scan (Checkmarx) → Build Docker Image → Deploy to Staging
   → Run E2E Tests → Manual Approval → Deploy to Prod
```

**Key Steps:**
- Unit tests (fast, 1-2 min)
- Integration tests (DB, API, 5-10 min)
- E2E tests (Cypress, full flow, 10-20 min)
- Code coverage (80%+ required)
- Security scan (Checkmarx, no NEW findings)

**At Billtrust:**
"We use GitHub Actions with 6-job workflow. Checkmarx runs pre-commit locally (CLI) and in CI. Code coverage merged across all test types (unit + integration + E2E) via Codecov."

---

## 💰 Salary Negotiation (3 Scripts)

### **1. Deflect Current Salary Question**
```
Recruiter: "What's your current salary?"

You: "I'm looking for a role that values my 12+ years of experience and 
     technical depth in fintech. Rather than focus on current compensation, 
     I'd love to understand what budget you have for this role. What's the range?"
```

### **2. Counter-Offer**
```
Hiring Manager: "We'd like to offer ₹36 LPA"

You (via email): "Thank you for the offer! After reviewing market rates for 
Staff Engineers in Bangalore (₹35-50 LPA per Glassdoor), I was hoping we 
could meet at ₹40 LPA. Given my 12 years, NJQRT expertise, and AI workflows, 
I'm confident I can deliver strong value in the first 90 days. 

Would it be possible to adjust the base to ₹34 LPA?"
```

### **3. Accept After Negotiation**
```
"Thank you for working with me. I'm happy to accept ₹39 LPA total comp 
(base ₹33L + variable ₹4L + RSUs ₹2L). 

Logistics:
- Start date: [2 weeks from today]
- Notice period: 45 days at Billtrust
- Offer letter: Please send final version

Excited to join!"
```

---

## 🎤 Common Interview Questions (Quick Answers)

### **1. "Why are you leaving Billtrust?"**
"I've had 12 great years — grew from Junior to Staff level. At this point, I'm looking for new challenges in a different domain or scale. I want to work on problems outside fintech and stretch my skills in distributed systems."

### **2. "What's your biggest weakness?"**
"Early in my career, I had a tendency to present interim conclusions as final. For example, checking one audit table and concluding 'this rules out the audit mechanism' when there were 33 tables. I've since developed RC-5 (Root Cause Sanity Check) — a 5-question checklist before concluding. This discipline made me much more thorough."

### **3. "Where do you see yourself in 5 years?"**
"Principal Engineer or Engineering Manager, leading technical decisions for a product. I want to mentor engineers — I've trained 2 at Billtrust and find that rewarding. Ideally, I'll be the 'go-to person' for solving hard production issues."

### **4. "Why do you want to work here?"**
"I'm excited about [Company] for 3 reasons:
1. **Technical Challenge:** I read your blog post about [specific problem] — that's exactly the scale problem I want to solve
2. **Domain:** [E-commerce/healthcare/etc.] is new to me, and I want to learn outside fintech
3. **Team:** [Engineering Leader] worked at [Previous Company] — I admire their work on [project]"

### **5. "Do you have any questions for me?"**
1. "What's the team structure? How many engineers? Senior/junior split?"
2. "What's the biggest technical challenge the team faces right now?"
3. "How does the team handle production incidents? On-call rotation?"

---

## 📊 Cheat Sheet: Interview Day Checklist

### **1 Hour Before:**
- [ ] Review this cheatsheet (10 min)
- [ ] Review job description (5 min)
- [ ] Review your 60-sec intro (practice 2x)
- [ ] Review 3 STAR stories (practice 1x each)
- [ ] Close all tabs except interview link
- [ ] Bathroom break, water ready

### **During Interview:**
- [ ] Smile when you answer (even on video)
- [ ] Pause 2 seconds before answering (shows thoughtfulness)
- [ ] Use interviewer's name ("That's a great question, [Name]...")
- [ ] Take notes (shows you're listening)
- [ ] Ask clarifying questions ("Can I confirm: you're asking about X?")

### **After Interview:**
- [ ] Send thank-you email within 24 hours
- [ ] Write down questions you struggled with
- [ ] Practice those questions before next interview

---

## 🔥 Top 10 Things Interviewers Want to Hear

1. **"At Billtrust, we..."** (always tie to your real work)
2. **"I prevented $500k revenue loss"** (quantified impact)
3. **"I developed RC-5 protocol"** (you built something, not just used it)
4. **"My team adopted it"** (influence beyond your work)
5. **"I scaled from 5 to 20 pods"** (scaling experience)
6. **"100+ production cases"** (production reliability)
7. **"At-least-once delivery + idempotency"** (you understand tradeoffs)
8. **"RabbitMQ for tasks, Kafka for events"** (right tool for the job)
9. **"Laravel DI container"** (you understand frameworks, not just syntax)
10. **"Let me walk you through the system design..."** (clear communicator)

---

## 🎯 Final 5-Minute Review (Read Before Interview)

### **Your 3 Strengths:**
1. **Production Reliability** (100+ NJQRT cases, RC-5 protocol)
2. **System Scaling** (invoice workers 5 → 20 pods, 100k/month)
3. **Fintech Domain** (payments, fraud detection, compliance)

### **Your 3 Stories:**
1. NJQRT-14987 (invoice discount bug, $128k saved, 24 hours)
2. Scaling under pressure (month-end billing, 15k queue, cleared in 2 hours)
3. Mentoring (2 devs, 8h → 2h, false root causes 40% → 5%)

### **Your 3 Questions to Ask:**
1. "What's the team structure?"
2. "What's the biggest technical challenge?"
3. "How do you handle production incidents?"

### **Remember:**
- ✅ Pause before answering (shows you're thinking)
- ✅ Use STAR format (Situation → Task → Action → Result)
- ✅ Quantify everything ($500k saved, 100+ cases, 5 → 20 pods)
- ✅ Tie to your work ("At Billtrust, we...")
- ✅ Keep answers under 2 minutes

---

## 🚀 You're Ready

**You have:**
- ✅ 12+ years experience
- ✅ 100+ production cases
- ✅ RC-5 protocol (your differentiator)
- ✅ Scaling expertise (5 → 20 pods)
- ✅ Fintech domain knowledge
- ✅ This cheatsheet

**Now go nail that interview.** 🎯
