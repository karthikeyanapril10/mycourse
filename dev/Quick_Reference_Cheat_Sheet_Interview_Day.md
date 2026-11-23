# 📄 Quick Reference Cheat Sheet - Interview Day

**Print this. Keep on desk. Review 1 hour before interview.**

---

## 🎯 Your Elevator Pitch (30 seconds)

> "I'm a Senior Full-Stack Engineer with 12+ years at Billtrust, working across 8 production systems serving thousands of customers. I specialize in **high-scale distributed systems** (database sharding, 3-layer caching, idempotent APIs), **production incident resolution** (12-min MTTR, PagerDuty on-call), and **AI-powered automation** (built 3 agentic workflows that eliminated 40+ hours/month of manual work). I'm looking for roles where I can architect scalable systems and mentor teams."

---

## 💼 Your 8 Projects (One-Liner Each)

| Project | One-Liner Pitch |
|---------|----------------|
| **EIC** (eInvoice Connect) | Horizontal database sharding (Stack 1/2) serving 100M+ invoice rows with <50ms p99 latency |
| **CSR** (Customer Settings Repo) | 3-layer caching (APCu → Redis → MySQL) serving 200+ microservices with 95%+ hit rate |
| **CC** (Client Connect) | Supplier portal with Laravel 9 upgrade (PHP 7.4→8.0), eliminating 20+ latent bugs |
| **WCL** (Web Communication Layer) | Connection pooling and query optimization, reducing DB load by 40% |
| **MPay** (Managed Pay) | Idempotency pattern preventing duplicate payment charges (UUID + DB constraints) |
| **AMAPI** | Multi-tenant API serving 50K+ requests/hour with rate limiting and JWT auth |
| **Biscuit** (AI Agent) | 3 agentic workflows (DML review, QRT triage, fraud investigation) using Claude 3.5 |
| **Payment Repo** | Webhook signature validation, detecting 100+ malicious requests in 2 months |

---

## 📊 Key Metrics (Memorize These)

| Metric | Value | Context |
|--------|-------|---------|
| **MTTR** | 12 minutes | Average P1 incident resolution time (target: <15 min) |
| **Latency (p99)** | <50ms | CSR API after caching optimizations (was 150ms) |
| **Database Size** | 100M+ rows | EIC `fsidocument` table, sharded across 2 stacks |
| **Throughput** | 50K+ req/hour | AMAPI peak traffic during billing cycles |
| **On-Call** | 2 days/week | PagerDuty rotation, 7-hour shifts |
| **Code Review** | 500+ PRs/year | Reviewed/approved across 8 repos |
| **Incidents Handled** | 150+ P1/P2 | Last 2.5 years (NJQRT tickets) |
| **Cache Hit Rate** | 95%+ | CSR 3-layer cache (APCu → Redis → MySQL) |
| **Monitoring** | Datadog + Splunk | Post-deployment checks, alert rules |
| **AI Automation** | 40+ hrs/month saved | 3 agentic workflows eliminated manual work |

---

## 🧠 Top 10 DSA Patterns (Must Know)

| Pattern | When to Use | Example Problem | Time Complexity |
|---------|-------------|----------------|-----------------|
| **1. Two Pointers** | Sorted array, pairs | 3Sum, Container With Most Water | O(n) or O(n²) |
| **2. Sliding Window** | Substring/subarray | Longest Substring Without Repeating | O(n) |
| **3. Hash Map** | Frequency, lookup | Two Sum, Group Anagrams | O(n) |
| **4. Binary Search** | Sorted, find target | Search Rotated Array, Find Min | O(log n) |
| **5. DFS (Trees)** | Tree traversal | Invert Tree, Validate BST | O(n) |
| **6. BFS (Graphs)** | Shortest path, levels | Number of Islands, Level Order | O(V + E) |
| **7. Dynamic Programming** | Optimal substructure | Coin Change, House Robber | O(n) to O(n²) |
| **8. Backtracking** | All combinations | Combination Sum, Word Search | O(2^n) |
| **9. Stack** | Matching pairs, monotonic | Valid Parentheses, Min Stack | O(n) |
| **10. Linked List** | Fast/slow pointers | Reverse List, Detect Cycle | O(n) |

**Tip:** For each pattern, know ONE easy problem cold. Can code it in 5 minutes.

---

## 📐 Big O Complexities (Quick Reference)

```
O(1)        Constant      Hash lookup, array access
O(log n)    Logarithmic   Binary search, balanced tree
O(n)        Linear        Single loop, hash map build
O(n log n)  Linearithmic  Merge sort, quick sort
O(n²)       Quadratic     Nested loops, bubble sort
O(2^n)      Exponential   Recursive fibonacci (naive)
O(n!)       Factorial     Generate all permutations
```

**Golden Rule:** Drop constants (O(2n) → O(n)), Drop lower terms (O(n² + n) → O(n²))

---

## 🗺️ System Design Essentials

### **CAP Theorem**
- **C**onsistency: All nodes see same data
- **A**vailability: System always responds
- **P**artition Tolerance: Works despite network splits

**Pick 2.** Most distributed systems choose **AP** (eventual consistency).

### **SOLID Principles**
- **S**ingle Responsibility
- **O**pen/Closed (open for extension, closed for modification)
- **L**iskov Substitution
- **I**nterface Segregation
- **D**ependency Inversion

### **Database Sharding** (Your EIC Project)
- Horizontal partitioning by key (e.g., `CustomerId % 2` → Stack 1 or 2)
- Pros: Distributes load, scales horizontally
- Cons: Cross-shard queries expensive, rebalancing hard

### **Caching Strategies** (Your CSR Project)
1. **Cache-Aside:** App checks cache → miss → load from DB → store in cache
2. **Write-Through:** Write to cache + DB simultaneously
3. **Write-Behind:** Write to cache → async write to DB

### **Idempotency** (Your MPay Project)
- Multiple identical requests = same result
- Implementation: UUID + DB unique constraint
- Critical for: Payments, order processing, webhooks

### **Rate Limiting**
- **Token Bucket:** N tokens/sec, bucket max M
- **Leaky Bucket:** Process at fixed rate
- **Fixed Window:** N requests per minute (simple but bursty)

### **Load Balancing**
- **Round Robin:** Distribute evenly
- **Least Connections:** Send to server with fewest active
- **IP Hash:** Same client → same server (sticky sessions)

---

## 🔐 Security Essentials (OWASP Top 3)

| Vulnerability | What It Is | How You Prevent |
|---------------|------------|-----------------|
| **SQL Injection** | Malicious SQL in user input | **Parameterized queries** (always!) |
| **XSS** (Cross-Site Scripting) | Malicious JS injected | **Escape user input**, CSP headers |
| **Broken Authentication** | Weak login/session | **JWT tokens**, secure sessions, MFA |

**Your Experience:** Payment webhook signature validation (detected 100+ malicious requests), fraud investigation timeline reconstruction (NJQRT).

---

## 💡 Interview Tips (Last-Minute Reminders)

### **For Coding Problems:**
1. ✅ **Clarify first** - "Can the array be empty? Duplicates allowed?"
2. ✅ **Think aloud** - "I'm considering a hash map here because..."
3. ✅ **Brute force first** - "Naive solution is O(n²), then I'll optimize"
4. ✅ **Test edge cases** - Empty input, single element, duplicates
5. ✅ **State complexity** - "Time: O(n), Space: O(n)"

### **For System Design:**
1. ✅ **Ask about scale** - "How many users? Requests per second?"
2. ✅ **Start high-level** - Draw boxes (Client → LB → App → DB)
3. ✅ **Identify bottlenecks** - "Database will be the bottleneck at 10K RPS"
4. ✅ **Propose solutions** - Caching, sharding, replication
5. ✅ **Mention trade-offs** - "Eventual consistency vs strong consistency"

### **For Behavioral:**
1. ✅ **Use STAR format** - Situation, Task, Action, Result
2. ✅ **Pick recent examples** - Last 2 years (NJQRT work)
3. ✅ **Quantify results** - "Reduced MTTR from 20 min to 12 min"
4. ✅ **Show leadership** - Mentored, reviewed PRs, drove decisions

---

## 🎤 Sample Answers (Copy-Paste Ready)

### **"Tell me about yourself"**
> "I'm a Senior Full-Stack Engineer with 12 years at Billtrust. I work on 8 production systems serving thousands of customers across invoicing, payments, and customer management. Recently, I've focused on three areas: **high-scale architecture** like database sharding for 100M+ invoice rows, **production reliability** with a 12-minute MTTR for P1 incidents, and **AI automation** where I built 3 agentic workflows that save 40+ hours per month. I'm looking for a role where I can architect scalable systems and mentor engineering teams."

### **"What's your biggest achievement?"**
> "Building a 3-layer caching system (APCu → Redis → MySQL) for our Customer Settings Repository that serves 200+ microservices. Before this, we had cache stampedes during deployments causing 5-10 minute outages. I designed a hierarchical cache with TTL staggering and cache warming. Result: 95%+ hit rate, p99 latency dropped from 150ms to under 50ms, and zero cache-related outages in the last year. The system now handles 50K+ requests per hour during peak billing cycles."

### **"Tell me about a production incident"**
> "We had a P1 incident where invoice emails stopped sending to 20,000+ customers. I was on-call. Within 12 minutes, I identified the root cause: a Redis connection pool exhaustion after a deployment. The fix: increased pool size from 10 to 50 connections and added connection recycling. I wrote a detailed RCA with 5 fields (Issue, Impact, Root Cause, Solution, Validation), and implemented Datadog alerting on Redis connection metrics. We haven't seen this issue again, and I added this check to our deployment runbook."

### **"How do you handle disagreements?"**
> "On the payment idempotency project, our Product team wanted to handle duplicates at the UI level only. I disagreed because network retries and timeouts would still create duplicates at the API level. I presented data: in a 2-week period, we had 50+ duplicate payment attempts that the UI couldn't prevent. I proposed a UUID + database unique constraint approach that guaranteed idempotency regardless of the caller. Product agreed after seeing the data. We implemented it, and duplicate charges dropped to zero."

---

## 🧪 Quick Self-Test (Answer in 30 seconds each)

1. **What's the difference between sharding and replication?**
   - Sharding: Split data across servers (horizontal partitioning)
   - Replication: Copy same data to multiple servers (redundancy)

2. **Why use Redis over Memcache?**
   - Redis: Persistence, data structures (lists, sets, sorted sets), pub/sub
   - Memcache: Simple key-value, faster for pure caching

3. **What's the CAP theorem tradeoff in your CSR project?**
   - Chose **AP** (Availability + Partition Tolerance)
   - Eventual consistency acceptable for settings (not financial data)

4. **How do you prevent SQL injection?**
   - **Parameterized queries / prepared statements**
   - Never concatenate user input into SQL strings

5. **What's idempotency and why does it matter?**
   - Same request multiple times = same result (no duplicate charges)
   - Critical for payments: network retries shouldn't double-charge

---

## 📋 Pre-Interview Checklist

**1 hour before:**
- [ ] Read this cheat sheet (10 min)
- [ ] Review your 8 projects (5 min each = 40 min)
- [ ] Practice elevator pitch out loud (2 min)
- [ ] Breathe, relax (8 min)

**During interview:**
- [ ] Smile, make eye contact
- [ ] Think aloud while coding
- [ ] Ask clarifying questions
- [ ] State time/space complexity
- [ ] Test your code with examples

**After interview:**
- [ ] Send thank-you email within 24 hours
- [ ] Note down questions you struggled with
- [ ] Practice those questions again

---

## 🎯 Final Reminders

✅ **You have 12 years of experience** - Trust your knowledge  
✅ **You built 8 production systems** - You can handle anything  
✅ **You solve P1 incidents in 12 minutes** - You work under pressure  
✅ **You built AI agents** - You're ahead of the curve  
✅ **You're on-call every week** - You own production  

**You're ready. Go get that offer! 💪**

---

**Last Updated:** November 16, 2026  
**Print this:** Ctrl+P → Save as PDF → Keep on desk  
**Review:** 1 hour before every interview
