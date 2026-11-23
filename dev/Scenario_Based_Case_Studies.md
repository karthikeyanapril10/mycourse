# Scenario-Based Case Studies

**Real-World Scenarios for Interview Practice**

**How to Use:** Read the scenario, think through your approach, THEN read the solution.

---

## 🔥 **Case Study #1: Production Database Performance Crisis**

### **The Scenario:**

It's Friday at 3 PM. Your production database (MySQL, 100M+ rows) is experiencing severe performance degradation:
- Query response times increased from 50ms to 3-5 seconds
- Error rate spiked from 0.01% to 5%
- Customer complaints are flooding support
- Your manager is asking for an ETA on the fix

You have 2 hours before the weekend. What do you do?

---

### **Think First:**

Before reading the solution, write down:
1. **Your first 3 steps** (what do you check first?)
2. **How do you prioritize** (fix now vs investigate later?)
3. **Communication plan** (who do you notify, when?)

---

### **Sample Solution:**

#### **Phase 1: Immediate Triage (10 minutes)**

**Step 1: Confirm the Scope**
```bash
# Check Datadog/New Relic — which queries are slow?
# Is it all queries or specific ones?
# When did it start? (correlate with deployments/migrations)
```

**Step 2: Check Recent Changes**
```bash
git log --since="2 hours ago" --oneline
# Any new deployments?
# Any database migrations?
# Any configuration changes?
```

**Step 3: Database Health Check**
```sql
-- Check active queries
SHOW PROCESSLIST;

-- Check if queries are locked/waiting
SHOW ENGINE INNODB STATUS;

-- Check for long-running queries
SELECT * FROM information_schema.processlist 
WHERE time > 60 
ORDER BY time DESC;
```

**Discovery:** You find 20+ queries stuck in "Waiting for table metadata lock"

---

#### **Phase 2: Root Cause Identification (20 minutes)**

**Step 4: Identify the Blocker**
```sql
-- Find what's holding the lock
SELECT * FROM information_schema.innodb_trx;
SELECT * FROM information_schema.innodb_locks;
```

**Finding:** One query has been running for 2 hours:
```sql
ALTER TABLE invoices ADD COLUMN pdf_url VARCHAR(255);
```

**Root Cause:** A developer triggered a schema change on a 100M-row table without realizing it would lock the entire table.

---

#### **Phase 3: Immediate Mitigation (10 minutes)**

**Option 1: Kill the ALTER TABLE (if safe)**
```sql
-- Find the process ID
SHOW PROCESSLIST; -- Let's say it's ID 12345

-- Kill it
KILL 12345;
```

**Risk Assessment:**
- If the ALTER TABLE is 90% done, killing it will ROLLBACK (could take another hour)
- If it's <50% done, killing it is faster

**Decision:** Check progress:
```sql
-- MySQL 5.7+
SELECT * FROM performance_schema.events_stages_current
WHERE EVENT_NAME LIKE 'stage/innodb/alter%';
```

**Result:** It's 95% done (50 minutes remaining)

**Choice:** Let it finish (better than rolling back for 2 hours)

**Immediate Action:**
1. **Notify stakeholders:**
   "Database ALTER TABLE in progress, 50 min ETA. No customer data loss. Mitigation: read replica failover."

2. **Failover reads to replicas:**
   ```bash
   # Update connection string to point to read replica
   # This handles 80% of queries (read-heavy workload)
   ```

3. **Queue writes:**
   ```php
   // Temporarily queue write operations in Redis
   // Process after ALTER TABLE completes
   ```

---

#### **Phase 4: Post-Incident (after resolution)**

**Step 5: Post-Mortem (30 minutes)**
```markdown
# Incident Report: Database Performance Degradation

**Timeline:**
- 3:00 PM: Performance degradation detected
- 3:10 PM: Root cause identified (ALTER TABLE holding lock)
- 3:20 PM: Mitigation deployed (read replica failover)
- 4:10 PM: ALTER TABLE completed, service restored

**Root Cause:**
Developer ran ALTER TABLE on production without approval

**Impact:**
- 70 minutes of degraded performance
- 5% error rate (mostly writes)
- ~1,000 failed requests

**Permanent Fixes:**
1. Require approval for schema changes via Jira ticket
2. Use pt-online-schema-change for large tables (no locking)
3. Add monitoring: alert if any query runs > 5 minutes
```

**Step 6: Prevent Future Occurrences**
```bash
# 1. Add pre-commit hook to detect ALTER TABLE in migration files
#!/bin/bash
if git diff --cached | grep -i "ALTER TABLE"; then
    echo "ERROR: ALTER TABLE detected. Use pt-online-schema-change instead."
    exit 1
fi

# 2. Set up pt-online-schema-change (Percona Toolkit)
pt-online-schema-change --alter "ADD COLUMN pdf_url VARCHAR(255)" \
    D=your_database,t=invoices \
    --execute
```

---

## 🚨 **Case Study #2: Memory Leak in Production**

### **The Scenario:**

Your Node.js API (serving 1,000 requests/second) is experiencing memory leaks:
- Memory usage climbs from 500 MB to 4 GB over 2 hours
- After hitting 4 GB, the process crashes (OOM killed)
- Auto-restart kicks in, but the cycle repeats
- This started after yesterday's deployment

You need to find the leak and fix it. How do you debug?

---

### **Sample Solution:**

#### **Step 1: Reproduce Locally**

```bash
# 1. Load test locally to trigger the leak faster
artillery run load-test.yml

# 2. Monitor memory in real-time
node --max-old-space-size=512 --expose-gc app.js &
watch -n 1 'ps aux | grep node'
```

---

#### **Step 2: Heap Snapshot Analysis**

```javascript
// Add this to your app.js
const v8 = require('v8');
const fs = require('fs');

function takeHeapSnapshot() {
    const filename = `heap-${Date.now()}.heapsnapshot`;
    const heapSnapshot = v8.writeHeapSnapshot();
    console.log(`Heap snapshot written to ${heapSnapshot}`);
}

// Take snapshots at intervals
setInterval(takeHeapSnapshot, 60000); // Every 1 minute
```

**Analyze with Chrome DevTools:**
1. Open Chrome DevTools → Memory tab
2. Load snapshot 1 (baseline)
3. Load snapshot 2 (after 5 minutes)
4. Compare: "Objects allocated between Snapshot 1 and Snapshot 2"

**Finding:** You see 10,000+ instances of `Buffer` objects growing

---

#### **Step 3: Find the Source**

**Check recent code changes:**
```bash
git log --since="1 day ago" --oneline --name-only | grep -E '\.(js|ts)$'
```

**Review the diff:**
```bash
git show <commit-hash>
```

**Discovery:** A new endpoint `/export-csv` was added:
```javascript
// BEFORE (memory leak!)
app.get('/export-csv', async (req, res) => {
    const data = await db.query('SELECT * FROM invoices'); // 1M rows!
    
    let csv = 'ID,Amount,Date\n';
    for (const row of data) {
        csv += `${row.id},${row.amount},${row.date}\n`; // String concatenation!
    }
    
    res.send(csv); // Entire CSV held in memory
});
```

**Problem:**
1. **String concatenation in a loop** — creates intermediate strings, memory not released
2. **1M rows loaded at once** — entire dataset in memory

---

#### **Step 4: Fix the Leak**

**Solution: Streaming + Pagination**
```javascript
// AFTER (fixed!)
const { Readable } = require('stream');

app.get('/export-csv', async (req, res) => {
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=invoices.csv');
    
    // Create a readable stream
    const csvStream = new Readable({
        async read() {
            const BATCH_SIZE = 1000;
            let offset = 0;
            
            while (true) {
                const batch = await db.query(
                    'SELECT id, amount, date FROM invoices LIMIT ? OFFSET ?',
                    [BATCH_SIZE, offset]
                );
                
                if (batch.length === 0) {
                    this.push(null); // End of stream
                    break;
                }
                
                for (const row of batch) {
                    this.push(`${row.id},${row.amount},${row.date}\n`);
                }
                
                offset += BATCH_SIZE;
            }
        }
    });
    
    csvStream.pipe(res);
});
```

**Why this works:**
- **Streams:** Data flows in chunks, not all at once
- **Pagination:** Only 1,000 rows in memory at a time
- **No concatenation:** Strings pushed to stream immediately

**Result:** Memory usage stays at ~500 MB (constant)

---

#### **Step 5: Verify the Fix**

```bash
# Load test again
artillery run load-test.yml

# Monitor memory — should stay flat
watch -n 1 'ps aux | grep node'

# Heap snapshot after fix — no growing buffers
```

---

## 🛡️ **Case Study #3: Security Incident - API Key Leaked**

### **The Scenario:**

It's Monday morning. Your security team alerts you:
- One of your AWS API keys was committed to a **public** GitHub repository
- The key has `S3:*` permissions (full S3 access)
- The commit was made 2 days ago (Friday night)
- You don't know if the key has been used by attackers

**What do you do in the next 60 minutes?**

---

### **Sample Solution:**

#### **Step 1: Immediate Containment (5 minutes)**

**Action 1: Rotate the Key**
```bash
# 1. Deactivate the compromised key IMMEDIATELY
aws iam update-access-key \
    --access-key-id AKIAIOSFODNN7EXAMPLE \
    --status Inactive

# 2. Create a new key (for your app)
aws iam create-access-key --user-name your-app-user

# 3. Update your app's .env with the new key
# (Do NOT commit this!)
```

**Action 2: Remove the Key from Git History**
```bash
# Use BFG Repo-Cleaner (faster than git-filter-branch)
bfg --replace-text passwords.txt your-repo.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push --force
```

**Action 3: Notify GitHub**
```bash
# Report to GitHub Security (they'll invalidate the key on their side)
# https://docs.github.com/en/code-security/secret-scanning
```

---

#### **Step 2: Assess Damage (20 minutes)**

**Check CloudTrail for Unauthorized Access**
```bash
# 1. Check if the key was used
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=AKIAIOSFODNN7EXAMPLE \
    --start-time 2026-11-14T00:00:00Z \
    --end-time 2026-11-16T23:59:59Z

# 2. Look for suspicious activities:
# - ListBuckets (reconnaissance)
# - GetObject (data exfiltration)
# - PutObject (malware upload)
# - DeleteBucket (destruction)
```

**Findings:**
```json
{
    "EventName": "ListBuckets",
    "EventTime": "2026-11-15T03:45:12Z",
    "SourceIPAddress": "185.220.xxx.xxx", // Tor exit node!
    "UserIdentity": {
        "AccessKeyId": "AKIAIOSFODNN7EXAMPLE"
    }
}
```

**Verdict:** The key WAS used by an attacker (Tor IP, 3 AM)

---

#### **Step 3: Damage Control (20 minutes)**

**Check What Data Was Accessed**
```bash
# Filter CloudTrail for GetObject events
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=EventName,AttributeValue=GetObject \
    --start-time 2026-11-15T03:00:00Z \
    --end-time 2026-11-15T04:00:00Z
```

**Result:** 500 `GetObject` calls on `s3://your-bucket/customer-invoices/*`

**Impact:** Attacker downloaded 500 customer invoices (potential PII/financial data breach)

---

#### **Step 4: Containment Actions (10 minutes)**

**1. Enable MFA Delete on S3**
```bash
aws s3api put-bucket-versioning \
    --bucket your-bucket \
    --versioning-configuration Status=Enabled,MFADelete=Enabled \
    --mfa "arn:aws:iam::123456789012:mfa/root-account-mfa-device 123456"
```

**2. Restrict S3 Bucket Policy**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::your-bucket/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": ["185.220.0.0/16"] // Block Tor exit nodes
        }
      }
    }
  ]
}
```

**3. Enable S3 Access Logging**
```bash
aws s3api put-bucket-logging \
    --bucket your-bucket \
    --bucket-logging-status file://logging.json
```

---

#### **Step 5: Post-Incident Report (5 minutes)**

**Immediate Notification:**
```markdown
**Subject:** Security Incident - AWS Key Exposure (Resolved)

**Timeline:**
- Friday 11 PM: AWS key committed to public GitHub repo
- Saturday 3 AM: Key used by attacker (Tor IP)
- Monday 9 AM: Key rotated, attacker access revoked

**Impact:**
- 500 customer invoices accessed (PDF files)
- NO write/delete actions detected
- NO financial loss

**Actions Taken:**
1. Key rotated immediately
2. Git history cleaned
3. S3 bucket locked down (MFA delete, IP restrictions)
4. Monitoring enabled (CloudTrail alerts)

**Next Steps:**
1. Legal/Compliance review (data breach notification requirements)
2. Customer notification (if required by law)
3. Implement secrets scanning in CI/CD
```

---

#### **Step 6: Prevent Future Leaks**

**1. Pre-Commit Hook (git-secrets)**
```bash
# Install git-secrets
brew install git-secrets

# Set up for all repos
git secrets --install ~/.git-templates/git-secrets
git config --global init.templateDir ~/.git-templates/git-secrets

# Add AWS patterns
git secrets --register-aws --global
```

**2. CI/CD Secrets Scanning**
```yaml
# .github/workflows/security.yml
name: Secrets Scan
on: [push]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: TruffleHog Scan
        run: |
          docker run --rm -v $(pwd):/src trufflesecurity/trufflehog:latest \
            filesystem /src --fail
```

**3. Use AWS Secrets Manager**
```javascript
// BEFORE (leaked in code)
const AWS_ACCESS_KEY = 'AKIAIOSFODNN7EXAMPLE';

// AFTER (fetch from Secrets Manager)
const AWS = require('aws-sdk');
const secretsManager = new AWS.SecretsManager();

async function getSecret(secretName) {
    const data = await secretsManager.getSecretValue({ SecretId: secretName }).promise();
    return JSON.parse(data.SecretString);
}

const credentials = await getSecret('prod/aws/api-keys');
```

---

## 📊 **Case Study #4: Sudden Traffic Spike (100x Normal)**

### **The Scenario:**

It's Black Friday. Your e-commerce API normally handles 100 requests/second. Suddenly:
- Traffic spikes to 10,000 requests/second (100x!)
- Error rate jumps to 20%
- Database connections maxed out
- Some customers see "503 Service Unavailable"

**How do you handle this?**

---

### **Sample Solution:**

#### **Step 1: Immediate Triage (2 minutes)**

**Check Auto-Scaling**
```bash
# AWS Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names your-api-asg

# Expected: Scaling from 10 → 50 instances
# Reality: Stuck at 10 (max instance limit hit!)
```

**Problem:** Auto-scaling hit the account limit (50 EC2 instances max)

---

#### **Step 2: Emergency Scaling (5 minutes)**

**Option 1: Request Limit Increase (too slow)**
```bash
# This takes 1-2 hours
aws service-quotas request-service-quota-increase \
    --service-code ec2 \
    --quota-code L-1216C47A \
    --desired-value 100
```

**Option 2: Enable Read Replicas (faster)**
```bash
# Point read-heavy endpoints to read replicas
# Update connection string in environment variables

# BEFORE (all traffic hits master)
DB_HOST=master.db.amazonaws.com

# AFTER (80% reads go to replicas)
DB_READ_HOST=replica1.db.amazonaws.com,replica2.db.amazonaws.com
DB_WRITE_HOST=master.db.amazonaws.com
```

**Code Change:**
```php
// Quick fix (deployed in 5 minutes)
class DB {
    public static function query($sql) {
        if (self::isReadQuery($sql)) {
            return self::readReplica()->query($sql);
        } else {
            return self::master()->query($sql);
        }
    }
    
    private static function isReadQuery($sql) {
        return stripos($sql, 'SELECT') === 0;
    }
}
```

---

#### **Step 3: Rate Limiting (10 minutes)**

**Implement Redis-Based Rate Limiting**
```php
class RateLimiter {
    public function allow($userId, $limit = 100, $window = 60) {
        $key = "rate_limit:$userId:" . floor(time() / $window);
        $count = $this->redis->incr($key);
        $this->redis->expire($key, $window);
        
        return $count <= $limit;
    }
}

// In your controller
public function handleRequest(Request $request) {
    $userId = $request->user()->id;
    
    if (!$this->rateLimiter->allow($userId, 100, 60)) {
        return response('Too Many Requests', 429)
            ->header('Retry-After', 60);
    }
    
    // Process request...
}
```

**Result:** Protects backend from abuse

---

#### **Step 4: Caching Aggressive (15 minutes)**

**Cache Homepage + Product Pages**
```php
// BEFORE (every request hits database)
public function homepage() {
    $products = Product::where('featured', true)->get();
    return view('homepage', compact('products'));
}

// AFTER (cache for 5 minutes)
public function homepage() {
    $products = Cache::remember('homepage_products', 300, function() {
        return Product::where('featured', true)->get();
    });
    return view('homepage', compact('products'));
}
```

**Add CDN (CloudFront)**
```bash
# Serve static assets from CDN
# BEFORE: https://yoursite.com/images/logo.png (hits your server)
# AFTER:  https://d123456.cloudfront.net/images/logo.png (served from edge)

# Configure CloudFront to cache:
# - Images: 1 day
# - CSS/JS: 1 week
# - HTML: 5 minutes
```

---

#### **Step 5: Database Connection Pooling**

```php
// BEFORE (new connection per request = 10,000 connections!)
$pdo = new PDO('mysql:host=localhost;dbname=shop', 'user', 'pass');

// AFTER (connection pooling = max 100 connections)
class ConnectionPool {
    private static $pool = [];
    private static $maxConnections = 100;
    
    public static function getConnection() {
        if (count(self::$pool) < self::$maxConnections) {
            self::$pool[] = new PDO('mysql:host=localhost;dbname=shop', 'user', 'pass');
        }
        return self::$pool[array_rand(self::$pool)];
    }
}
```

---

#### **Step 6: Monitor & Adjust (ongoing)**

**Datadog Dashboard:**
```
- Requests/second: 10,000 (target: handle without errors)
- Error rate: 20% → 2% (after fixes)
- Database connections: 1,000 → 100 (pooling worked!)
- Response time: 500ms → 150ms (caching + replicas)
```

---

---

## 🕵️ **Case Study #5: Malicious Actor Investigation (Customer-Reported)**

### **The Scenario:**

It's Monday morning, 9 AM. You receive an urgent email from a customer:

**Subject:** URGENT: Unauthorized Access to Our Account

**Body:**
"We noticed suspicious activity on our account over the weekend. Someone logged in from an IP address we don't recognize and changed our bank account information. We need a full investigation immediately — did they access any sensitive data? Are other accounts affected?"

**Initial Details:**
- **Customer:** ACME Corporation (Customer ID: 54321)
- **Affected User:** john.doe@acme.com (User ID: 98765)
- **Time Window:** Saturday, Nov 15, 2026, 2:00 AM - 4:00 AM UTC
- **IP Address:** 185.220.101.38 (customer says "not ours")

**What do you do in the next 2 hours?**

---

### **Sample Solution:**

#### **Phase 1: Immediate Response & Scope (10 minutes)**

**Step 1: Acknowledge Customer**
```
Subject: RE: URGENT: Unauthorized Access - Investigation Started

Dear ACME Security Team,

Thank you for reporting this. We take security incidents very seriously.

Investigation Status: IN PROGRESS
Expected Timeline: Full report within 2 hours

Initial Actions Taken:
✅ User account temporarily locked
✅ Suspicious session terminated
✅ Investigation team notified

I'll send you a detailed report shortly with:
- Complete timeline of attacker activity
- Data accessed/modified
- Remediation steps taken

If you need to reach me urgently: [phone number]

Best regards,
Karthikeyan Sekar
Production Support Team
```

**Step 2: Lock the Account (immediate containment)**
```sql
UPDATE fsiocuser 
SET Active = 'N', 
    UpdateUser = 'SECURITY_INCIDENT_54321', 
    UpdateDate = NOW()
WHERE UserId = 98765;
```

---

#### **Phase 2: Multi-Source Log Collection (30 minutes)**

**1. Datadog APM Traces**
```
env:production 
service:api 
@user.id:98765 
@timestamp:[2026-11-15T02:00:00 TO 2026-11-15T04:00:00]
```

**Result:**
| Timestamp | Endpoint | IP Address | Response | Details |
|---|---|---|---|---|
| 02:15:33 | POST `/api/auth/login` | 185.220.101.38 | 200 | Login SUCCESS |
| 02:16:12 | GET `/api/invoices` | 185.220.101.38 | 200 | 150 invoices retrieved |
| 02:17:05 | PUT `/api/account/bank` | 185.220.101.38 | 200 | Bank account CHANGED |
| 02:18:22 | POST `/api/payments` | 185.220.101.38 | 403 | Payment BLOCKED (fraud detection) |
| 02:19:40 | POST `/api/auth/password-reset` | 185.220.101.38 | 200 | Password reset initiated |
| 02:21:15 | POST `/api/logout` | 185.220.101.38 | 200 | Session ended |

**2. Splunk Audit Logs**
```splunk
index=audit_logs user_id=98765 earliest="2026-11-15:02:00:00" latest="2026-11-15:04:00:00"
| table _time, action, resource, ip_address, user_agent, details
```

**Result:**
```
02:17:05 | UPDATE | fsiAccount.BankAccount | 185.220.101.38 | Mozilla/5.0 (Tor) | Old: **** 1234, New: **** 9999
02:19:40 | INSERT | password_reset_tokens | 185.220.101.38 | Mozilla/5.0 (Tor) | Token: abc123...
```

**3. Pendo User Activity**
```bash
curl -X GET "https://app.pendo.io/api/v1/aggregation" \
  -H "x-pendo-integration-key: YOUR_KEY" \
  -d '{
    "visitor": {"id": "98765"},
    "startTime": "2026-11-15T02:00:00Z",
    "endTime": "2026-11-15T04:00:00Z"
  }'
```

**Result:**
- **02:16:30:** Viewed "Invoices" page (150 invoices)
- **02:17:00:** Clicked "Edit Bank Account" button
- **02:17:15:** Submitted bank account form
- **02:18:00:** Navigated to "Payments" page
- **02:18:30:** Clicked "Make Payment" (failed — fraud detection)

**4. SendGrid Email Logs**
```bash
curl -X GET "https://api.sendgrid.com/v3/messages" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d 'query=to_email:"john.doe@acme.com" AND start_time:"2026-11-15T02:00:00Z"'
```

**Result:**
```
02:19:45 | "Password Reset Request" | john.doe@acme.com | Delivered | Opened: Yes (02:20:12)
02:20:50 | "Bank Account Changed" | john.doe@acme.com | Delivered | Opened: No (not yet)
```

**5. MySQL Audit Tables**
```sql
-- Bank account change
SELECT * FROM fsiAccountAudits 
WHERE CustomerId = 54321 
  AND AuditDate BETWEEN '2026-11-15 02:00:00' AND '2026-11-15 04:00:00';
```

**Result:**
```
| AuditDate           | EventUser     | IPAddress       | Description                           |
|---------------------|---------------|-----------------|---------------------------------------|
| 2026-11-15 02:17:05 | john.doe@...  | 185.220.101.38  | Bank Account Changed: **** 1234 → 9999 |
```

---

#### **Phase 3: IP Address Analysis (5 minutes)**

**Check if IP is known bad actor:**
```bash
# Check AbuseIPDB
curl -G https://api.abuseipdb.com/api/v2/check \
  --data-urlencode "ipAddress=185.220.101.38" \
  -H "Key: YOUR_API_KEY"
```

**Result:**
```json
{
  "data": {
    "ipAddress": "185.220.101.38",
    "abuseConfidenceScore": 95,
    "countryCode": "NL",
    "usageType": "Reserved",
    "isTor": true,
    "totalReports": 234
  }
}
```

**Verdict:** ✅ **Confirmed Tor exit node** (95% abuse confidence score, 234 prior reports)

---

#### **Phase 4: Timeline Reconstruction (10 minutes)**

**Create Customer-Facing Timeline:**

| Time (UTC) | Event | Source | Attacker Action | Customer Impact |
|---|---|---|---|---|
| **02:15:33** | Login SUCCESS | Datadog | Attacker logged in using valid credentials | ⚠️ Account compromised |
| **02:16:12** | 150 Invoices Retrieved | Datadog | Attacker downloaded customer invoice data | ⚠️ **PII Exposed** (names, addresses, amounts) |
| **02:16:30** | Viewed Invoices Page | Pendo | Attacker browsed invoice list | ⚠️ Confirmed data access |
| **02:17:05** | Bank Account Changed | MySQL Audit | Attacker changed bank account from \*\*\*\* 1234 → \*\*\*\* 9999 | ⚠️ **Data Modified** |
| **02:18:22** | Payment Attempt BLOCKED | Datadog | Attacker tried to initiate $5,000 payment | ✅ **Fraud Detection Worked** |
| **02:19:40** | Password Reset Initiated | SendGrid | Attacker triggered password reset (lock out real user) | ⚠️ Attempted lockout |
| **02:21:15** | Logout | Datadog | Attacker session ended | ✅ Access terminated |

**Key Findings:**
1. ✅ **Login was successful** → Attacker had valid username + password (credential compromise, not platform vulnerability)
2. ⚠️ **150 invoices accessed** → PII exposure (customer names, addresses, invoice amounts)
3. ⚠️ **Bank account changed** → Malicious modification (reverted)
4. ✅ **Payment blocked** → Fraud detection prevented financial loss
5. ✅ **IP confirmed as Tor** → 95% abuse confidence, known bad actor

---

#### **Phase 5: Impact Assessment (10 minutes)**

**1. Data Accessed (PII Exposure)**
```sql
-- Which invoices were accessed?
SELECT 
    InvoiceId, 
    CustomerId, 
    CustomerName, 
    InvoiceAmount,
    InvoiceDate
FROM fsidocument
WHERE CustomerId = 54321
  AND InvoiceDate >= '2026-01-01'
ORDER BY InvoiceDate DESC
LIMIT 150;
```

**Result:** 150 invoices (Jan 2026 - Nov 2026)
- **PII exposed:** Customer names, addresses, invoice amounts ($500K total)
- **No SSN, credit cards, or bank accounts in invoices** (phew!)

**2. Data Modified**
```sql
-- What was changed?
SELECT * FROM fsiAccountAudits 
WHERE CustomerId = 54321 
  AND AuditDate BETWEEN '2026-11-15 02:00:00' AND '2026-11-15 04:00:00';
```

**Result:** 1 bank account change
- **Old:** \*\*\*\* 1234 (legitimate customer account)
- **New:** \*\*\*\* 9999 (attacker's account)
- **Status:** ✅ Reverted immediately

**3. Financial Loss**
```sql
-- Were any payments successful?
SELECT * FROM fsiPayments
WHERE CustomerId = 54321
  AND PaymentDate BETWEEN '2026-11-15 02:00:00' AND '2026-11-15 04:00:00';
```

**Result:** 0 payments (all blocked by fraud detection)
- **Financial loss:** $0 ✅

**4. Blast Radius (Are other customers affected?)**
```sql
-- Check for other logins from same Tor IP
SELECT DISTINCT UserId, CustomerId, LoginTime
FROM user_sessions
WHERE ip_address = '185.220.101.38'
  AND LoginTime >= '2026-11-14';
```

**Result:** Only 1 user (Customer 54321)
- **Other customers:** ✅ Not affected

---

#### **Phase 6: Remediation (15 minutes)**

**1. Revert Malicious Changes**
```sql
-- Rollback bank account
UPDATE fsiAccount 
SET BankAccount = '****1234',  -- Original value
    UpdateUser = 'SECURITY_ROLLBACK_54321',
    UpdateDate = NOW()
WHERE CustomerId = 54321;
```

**2. Terminate All Sessions**
```sql
DELETE FROM user_sessions 
WHERE UserId = 98765 OR ip_address = '185.220.101.38';
```

**3. Force Password Reset**
```sql
UPDATE fsiocuser 
SET PasswordResetRequired = 'Y',
    Active = 'N',  -- Keep locked until customer resets
    UpdateDate = NOW()
WHERE UserId = 98765;
```

**4. Add IP to Blacklist**
```sql
INSERT INTO ip_blacklist (ip_address, reason, added_date)
VALUES ('185.220.101.38', 'Confirmed Tor exit node - malicious actor', NOW());
```

**5. Enable Monitoring**
```bash
# Create Datadog alert
curl -X POST "https://api.datadoghq.com/api/v1/monitor" \
  -H "DD-API-KEY: YOUR_KEY" \
  -d '{
    "type": "log alert",
    "query": "source:api status:success @user.id:98765",
    "message": "ALERT: User 98765 (ACME) logged in again - verify legitimacy",
    "name": "ACME Account Monitoring (Security Incident 54321)"
  }'
```

---

#### **Phase 7: Customer Report (30 minutes)**

**Email to Customer:**

```markdown
Subject: Security Incident Report - Case #2026-11-15-54321

Dear ACME Security Team,

**Investigation Complete**

We've completed a thorough investigation of the unauthorized access incident. Here's what we found:

---

**EXECUTIVE SUMMARY**

**What Happened:**
An attacker gained unauthorized access to your account (john.doe@acme.com) on Saturday, Nov 15, 2026, between 2:15 AM - 2:21 AM UTC (6-minute window).

**How They Got In:**
The attacker used **valid login credentials** (correct username + password). This was not a platform vulnerability — your credentials were likely compromised elsewhere (phishing, password reuse, data breach).

**What They Did:**
1. ✅ Logged in successfully
2. ⚠️ Accessed 150 customer invoices (PII exposure)
3. ⚠️ Changed your bank account information
4. ✅ Attempted a $5,000 payment (BLOCKED by our fraud detection)
5. ⚠️ Triggered a password reset (to lock you out)

**Financial Impact:**
- **$0 loss** ✅ (payment blocked)

**Data Impact:**
- 150 invoices viewed (Jan 2026 - Nov 2026)
- PII exposed: Customer names, addresses, invoice amounts (~$500K total)
- **NO** SSN, credit cards, or bank accounts exposed ✅

---

**DETAILED TIMELINE**

| Time (UTC) | Attacker Action | System Response |
|---|---|---|
| 02:15:33 | Logged in from Tor IP (185.220.101.38) | Login successful (valid credentials) |
| 02:16:12 | Downloaded 150 invoices | ⚠️ **Data accessed** |
| 02:17:05 | Changed bank account to \*\*\*\* 9999 | ⚠️ **Data modified** (now reverted) |
| 02:18:22 | Tried to initiate $5,000 payment | ✅ **BLOCKED** (fraud detection) |
| 02:19:40 | Triggered password reset email | Sent to john.doe@acme.com |
| 02:21:15 | Logged out | Session ended |

---

**ACTIONS WE TOOK**

1. ✅ **Account locked** (Saturday 2:21 AM UTC)
2. ✅ **Bank account reverted** to original \*\*\*\* 1234
3. ✅ **Attacker IP blacklisted** (185.220.101.38 - confirmed Tor exit node)
4. ✅ **All sessions terminated**
5. ✅ **Monitoring enabled** (alerts if this user logs in again)

---

**ACTIONS YOU SHOULD TAKE**

1. **Reset password immediately** (we've forced this — you'll be prompted on next login)
2. **Enable 2FA** (Two-Factor Authentication) — prevents future credential compromise
3. **Review invoice data** — 150 invoices were accessed; notify affected customers if required by law (GDPR, etc.)
4. **Check for credential reuse** — if john.doe@acme.com used the same password elsewhere, change those too
5. **Employee training** — this was likely a phishing attack; train your team to spot suspicious emails

---

**ARE OTHER ACCOUNTS AFFECTED?**

✅ **No.** We checked all logins from this Tor IP — only your account was targeted.

---

**NEXT STEPS**

1. Reply to this email to confirm you've reset the password
2. Let us know if you'd like help enabling 2FA
3. We're here to answer any questions: [phone number]

**Compliance Note:**
If GDPR applies, you may need to notify affected customers within 72 hours (150 invoices = PII exposure). We can provide supporting documentation if needed.

---

Best regards,
Karthikeyan Sekar
Production Support Engineer
[Company Name]
```

---

## 🎯 **Self-Assessment Questions**

After each case study, ask yourself:

1. **Did I prioritize correctly?** (fix critical issues first)
2. **Did I communicate clearly?** (notify stakeholders, write clear updates)
3. **Did I think about trade-offs?** (quick fix vs permanent solution)
4. **Did I prevent future occurrences?** (post-mortem, monitoring, process changes)

---

## 🚀 **More Scenario Ideas (Try These Yourself!)**

1. **Deployment Gone Wrong:** You deploy a new feature at 5 PM. By 5:15 PM, error rate is 10%. Do you rollback immediately or investigate first?

2. **Data Corruption:** A bug caused 10,000 customer records to have incorrect data. How do you fix it without downtime?

3. **Third-Party API Down:** Your payment gateway (Stripe/PayPal) goes down. How do you handle checkout requests?

4. **Team Conflict:** Two engineers disagree on architecture (microservices vs monolith). How do you mediate?

5. **Hiring Decision:** You interview a candidate who's technically brilliant but rude in code reviews. Hire or no?

---

**Practice these scenarios, and you'll be ready for ANYTHING in the interview! 💪**