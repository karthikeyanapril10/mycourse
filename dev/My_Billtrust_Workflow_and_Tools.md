# 🛠️ My Billtrust Workflow & Tools

**Purpose:** Document my personal workflow, tools, and processes at Billtrust for interview prep and knowledge transfer.

---

## 📋 Module Overview

This module captures **how I actually work** at Billtrust — not generic best practices, but the specific tools, skills, rules, and patterns I've built over 12+ years.

**What You'll Find Here:**
1. Context files in repos (CLAUDE.md, CONTEXT.md) and how they accelerate triage
2. AWS database access via Docker (safe read-only pattern)
3. Custom skills I created (karthik-triage, fraud-investigator, etc.)
4. My global rules and memory system
5. Checkmarx Developer Assist in VS Code (pre-commit security)
6. Confluence pages I authored (high-level context)
7. Malicious actor investigation patterns

---

## 📄 Section 1: Context Files in Repositories

### **What Are Context Files?**

Context files are **AI-readable documentation** I've added to Billtrust repos to speed up triage and onboarding. They live in `.claude/` or root directories and contain:
- Architecture decisions
- Active vs legacy code paths
- Common pitfalls and "gotchas"
- Triage starting points

### **Files I've Created**

#### **1. CLAUDE.md (Per-Repo Rules)**

**Location:** `.claude/CLAUDE.md` or root `CLAUDE.md`

**Purpose:** Repo-specific instructions for AI assistants (Claude Code, GitHub Copilot)

**What It Contains:**
- **Active modules:** Which code paths are actively maintained (e.g., `ig70/` in EIC, `application/cc/` in CC)
- **Legacy areas:** Code to avoid touching (`autoemailenrollment/`, `wwwroot/`)
- **Database patterns:** How this repo queries the DB (Eloquent, Zend_Db, Phalcon ORM)
- **Testing conventions:** Cypress/Protractor/Postman patterns
- **Common bugs:** Known anti-patterns (e.g., SQL injection via string concat)
- **Deployment notes:** Environment-specific configs (dev/stage/UAT/prod)

**Example Entry (EIC):**
```markdown
## Active Modules
- `ig70/` - PRIMARY active codebase (invoicing gateway v70)
- `autoemailenrollment/` - SECONDARY (bug fixes only)
- Everything else is LEGACY - DO NOT TOUCH without approval

## Database Access
- Uses Zend_Db_Select with prepared statements
- NEVER use string concatenation in WHERE clauses
- Always parameterize: `->where('CustomerId = ?', $customerId)`

## Common Pitfalls
- fsiDocument table has 5.2B rows - ALWAYS use LIMIT
- BillingDate is varchar('MM/DD/YYYY'), not DATE - use DATE(STR_TO_DATE())
- Stack routing: query billingmaster first, then billingclient1/billingclient2
```

**How It Helps Triage:**
- ✅ **Faster root cause:** Know which module to investigate first
- ✅ **Avoid false leads:** Skip legacy code that's not in play
- ✅ **Correct SQL patterns:** Prevents timeout queries on 5B-row tables

---

#### **2. CONTEXT.md (Architecture Context)**

**Location:** Root or `.claude/CONTEXT.md`

**Purpose:** High-level architecture and data flow

**What It Contains:**
- System architecture diagrams (as ASCII or Mermaid references)
- Request/response flow (browser → WCL → EIC → DB)
- Authentication flow (SSO vs Direct Login)
- Cache layers (APCu → Redis → MySQL)
- External service dependencies (Test Data API, BTPay, Payment Platform)

**Example Entry (CSR):**
```markdown
## Architecture

Client Connect (Laravel) → CSR API (Laravel) → 3-Layer Cache → MySQL

Cache Layers:
1. APCu (in-process, 60s TTL)
2. Redis (shared, 300s TTL)
3. MySQL (source of truth)

Hit rate: 95%+ (measured via Datadog)

## Critical Settings
- Autopay settings live in fsicustomersettings (atom pattern)
- Active settings: settingsstatus = 5
- Retrieve via: CALL FindCustSettings(CustomerId, 'Path')
```

**How It Helps Triage:**
- ✅ **Understand cache behavior:** Know which layer a stale value might be stuck in
- ✅ **Trace requests:** Follow the flow from browser to database
- ✅ **Identify dependencies:** Know which external services might be down

---

#### **3. constitution.md (Non-Negotiable Rules)**

**Location:** `.claude/constitution.md`

**Purpose:** Hard rules that must NEVER be violated

**What It Contains:**
- **Security rules:** Always use parameterized queries, never log PAN/CVV
- **Multi-tenant rules:** Always filter by CustomerId/PrimaryCustomerId
- **Performance rules:** Never SELECT * from fsidocument (5.2B rows)
- **Code style rules:** PSR-12 for PHP, follow existing patterns

**Example Entry:**
```markdown
## Security - NON-NEGOTIABLE

1. NEVER use string concatenation in SQL queries
   ❌ BAD: "SELECT * FROM users WHERE id = " . $id
   ✅ GOOD: "SELECT * FROM users WHERE id = ?" with bind params

2. NEVER log PCI data (PAN, CVV, full bank account)
   ❌ BAD: Log::info("Card: " . $cardNumber)
   ✅ GOOD: Log::info("Card: " . maskPan($cardNumber))

3. ALWAYS filter by tenant
   ❌ BAD: SELECT * FROM fsiaccount
   ✅ GOOD: SELECT * FROM fsiaccount WHERE CustomerId = ?
```

**How It Helps Triage:**
- ✅ **Catch security issues:** Immediately flag SQL injection, PCI exposure
- ✅ **Prevent regressions:** Know what NOT to change during a fix
- ✅ **Code review faster:** Use this as a checklist

---

### **How I Use Context Files During Triage**

**Step 1: Load Context**
```bash
# In Claude Code or Copilot
/developer eic  # Loads CLAUDE.md + CONTEXT.md + constitution.md
```

**Step 2: Ask Context-Aware Questions**
```
"Why is this query timing out?"
→ AI reads CONTEXT.md, sees fsidocument has 5.2B rows
→ Suggests adding LIMIT and proper indexes
```

**Step 3: Verify Against Rules**
```
"Is this fix safe?"
→ AI checks constitution.md for SQL injection, tenant scoping
→ Flags violations before code review
```

---

## 🐳 Section 2: AWS Database Access via Docker

### **The Problem**

Billtrust databases (MySQL) are on private AWS networks. Direct mysql client access requires:
- VPN connection
- Credentials in .env files (security risk)
- Native mysql client install (not on all dev machines)

### **My Solution: Docker-Based Gateway**

**Repo:** `inv-ai-mysql-access`

**Pattern:** Read-only PowerShell gateway that runs MySQL queries via Docker

**Why Docker?**
- ✅ No mysql client install needed
- ✅ Credentials stay in Docker, not .env files
- ✅ Read-only access enforced
- ✅ Works cross-platform (Windows/Mac/Linux)

### **How It Works**

#### **1. Gateway Script (`db-query.ps1`)**

**Location:** `C:\Users\kasekar\GH\inv-ai-mysql-access\db-query.ps1`

**Usage:**
```powershell
.\db-query.ps1 -env dev -db billingmaster -query "SELECT CustomerId, Name FROM fsicustomer WHERE Name LIKE '%ACME%'"
```

**Supported Environments:**
- `dev` (us-dev)
- `stage` (us-stage)
- `uat` (us-uat)
- `prod` (us-prod) - READ ONLY

**Supported Databases:**
- `billingmaster` (tenant routing DB)
- `billingclient1` (Stack 1 write DB)
- `billingclient2` (Stack 2 write DB)

#### **2. Docker Container**

**Image:** `mysql:8.0`

**How It Runs:**
```bash
# Docker command (abstracted by db-query.ps1)
docker run --rm \
  -e MYSQL_HOST=<aws-rds-endpoint> \
  -e MYSQL_USER=<read-only-user> \
  -e MYSQL_PASSWORD=<password> \
  mysql:8.0 \
  mysql -h$MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWORD \
    -e "SELECT ..."
```

**Key Points:**
- `--rm`: Container is deleted after query runs (no state left behind)
- Credentials injected as env vars (not stored on disk)
- Read-only user (cannot INSERT/UPDATE/DELETE)

#### **3. Schema Dumps (for Offline Reference)**

**Location:** `inv-ai-mysql-access/schema-dumps/`

**Files:**
- `billingmaster-schema.sql`
- `billingclient1-schema.sql`
- `billingclient2-schema.sql`

**Purpose:** Autocomplete and offline reference (table names, columns, indexes)

**How to Use:**
```bash
# Search for a table
grep -i "CREATE TABLE fsiaccount" schema-dumps/billingclient1-schema.sql

# Find columns
grep -A 20 "CREATE TABLE fsiDocument" schema-dumps/billingclient1-schema.sql
```

---

### **Triage Example: Finding Customer by Name**

**Problem:** NJQRT ticket says "Customer ACME Corp can't see invoices"

**Step 1: Find CustomerId**
```powershell
.\db-query.ps1 -env prod -db billingmaster -query @"
SELECT CustomerId, Name, Stack
FROM fsicustomer
WHERE Name LIKE '%ACME%'
"@
```

**Step 2: Check Stack Routing**
```powershell
# Output from Step 1: CustomerId = 12345, Stack = 1

.\db-query.ps1 -env prod -db billingclient1 -query @"
SELECT COUNT(*) AS InvoiceCount
FROM fsiDocument
WHERE CustomerId = 12345
AND DocumentType = 'INV'
"@
```

**Step 3: Verify Invoice Gateway Filter**
```powershell
.\db-query.ps1 -env prod -db billingclient1 -query @"
SELECT *
FROM fsiInvoiceGatewayFilter
WHERE CustomerId = 12345
"@
```

**Result:** Found root cause in 3 queries (~2 minutes)

---

### **Safety Rules**

✅ **DO:**
- Use for read-only queries (SELECT)
- Mask PII in results before sharing
- Query with LIMIT (especially on fsidocument)
- Verify environment (dev/stage before prod)

❌ **DON'T:**
- Run INSERT/UPDATE/DELETE (gateway blocks them)
- Query fsidocument without WHERE + LIMIT
- Share raw query results with PAN/CVV in Jira
- Use for performance testing (use Datadog APM instead)

---

## 🎯 Section 3: Custom Skills I Created

### **Overview**

I've created **7 custom AI skills** (slash commands) for recurring workflows. These are invoked via `/skill-name` in Claude Code.

---

### **1. `/karthik-triage` (NJQRT Triage)**

**Purpose:** Full triage workflow for First Responders (NJQRT) tickets

**When to Use:** Any NJQRT-XXXXX ticket assigned to me

**What It Does:**
1. Fetches ticket + all comments + linked cases
2. Searches Jira backlog for similar past cases
3. Searches Confluence/KB for functionality context
4. Detects platform (BT_Invoicing vs Workspace)
5. Runs AC/UC model detection
6. Invokes researcher/developer/db-query sub-skills
7. Queries Datadog MCP for errors/traces
8. Queries Pendo MCP for usage/adoption
9. Prepares technical + business summaries
10. Posts findings to Development subtask

**Completion Trigger:** "triage over"

**Output:** Dev Update comment + 5 parent-ticket fields (Issue, Impact, Root Cause, Solution, Solution Impact)

**Key Rules:**
- RC-5 sanity check before recording root cause
- Origin/Blast Radius/Ownership follow-up mandatory
- Never assume — verify every claim against code/data
- Show proof in every answer (code lines, query results)

**Example:**
```
User: /karthik-triage NJQRT-15400
→ Fetches ticket, searches backlog, investigates code, queries DB
→ Drafts findings for approval before posting
```

---

### **2. `/fraud-malicious-investigator` (Fraud Investigation)**

**Purpose:** Reconstruct user activity timeline for fraud/account-compromise cases

**When to Use:** 
- "Investigate fraud for account XYZ"
- "Check suspicious activity"
- "Account compromise check"

**What It Does:**

**Mode A (Targeted):** Account/email → chronological timeline
- Login history (fsiocuseraudit, fsiAccountAudits)
- Payment attempts (BTPay payment gateway logs)
- Document access (Datadog APM traces)
- IP addresses + geolocation (Pendo user sessions)
- Timeline output (CSV + markdown table)

**Mode B (Discovery):** Sweep tenant for risky users
- Multiple accounts same email
- Login from multiple IPs same day
- Payment failures → retry → different card
- Rank by risk score

**Mode C (Data Exposure):** Phishing/leak questions
- Anomalous access patterns
- Download spikes (invoice PDFs)
- Email forwarding rules

**Key Patterns (High-Level):**
- **Credential stuffing:** Same email, multiple failed logins, success from new IP
- **Card testing:** Multiple $1 charges, rapid fire, different cards
- **Account takeover:** IP change + email change + payment method change within 1 hour
- **Insider abuse:** Admin user accessing invoices for unrelated customers
- **Data exfiltration:** 100+ invoice downloads in 1 session (normal: 5-10)

**Output:** Timeline table (never raw PAN/CVV)

---

### **3. `/db-query` (Database Query Skill)**

**Purpose:** Safe, credential-less MySQL queries via Docker gateway

**When to Use:**
- "What's the customerId for ACME?"
- "Query the database for..."
- "Find this account in the DB"

**What It Does:**
1. Validates query is read-only (blocks INSERT/UPDATE/DELETE)
2. Routes to correct environment + database
3. Runs query via `db-query.ps1` Docker gateway
4. Returns results as markdown table
5. Masks PII automatically

**Safety Checks:**
- Rejects queries without WHERE clause on large tables
- Enforces LIMIT on fsidocument queries
- Never returns PAN/CVV columns
- Logs all queries for audit

---

### **4. `/qrt-automation` (Automation Coverage)**

**Purpose:** Write Cypress test coverage for NJQRT fixes

**When to Use:**
- "Automate NJQRT-15400"
- "Write automation for this fix"
- "Add regression spec"

**What It Does:**

**Mode A (Write Coverage):**
1. Reads Dev ticket + fix PR
2. Maps dev test cases to F/R test IDs
3. Self-provisions customer via Test Data API
4. Writes Cypress spec (Page Object pattern)
5. Proves pre-fix RED / post-fix GREEN
6. Creates PR in automation repo

**Mode B (Review Automation PR):**
1. Runs automation-specific review checklist:
   - CI green ≠ tests pass (check actual assertions)
   - Discrimination evidence (did it catch the bug?)
   - Shared page-object blast radius
   - Assertions vs artifacts (screenshots aren't tests)
2. Drafts verdict for approval

---

### **5. `/eic-autopay` (AutoPay Validation)**

**Purpose:** Full DB-backed AutoPay settings sweep

**When to Use:**
- "EIC autopay check for customer 12345"
- "Validate autopay settings"
- "AutoPay not triggering investigation"

**What It Does:**
1. Detects AC (Account-Centric) vs UC (User-Centric) schema
2. Runs 15+ queries across tables:
   - `fsiaccountautopay` (enrollment config)
   - `fsicustomersettings` (AutopayVersion atom)
   - `fsionlinebillingparms` (AutoPayActive column)
   - `fsiDocumentTemplate` (eligibility)
   - `fsieftRisk` (risk records)
   - Payment history (last 6 months)
3. Checks universality (other customers affected?)
4. Separates DB-verifiable from Platform-only settings
5. Produces consolidated markdown table (query + result + verdict)

**Output:** One table, copy-pasteable to Jira comment

---

### **6. `/dml-review` (DML/DDL Case Review)**

**Purpose:** Structured review of DML/DDL Jira tickets before DBA approval

**When to Use:**
- "Review my DML tickets"
- "Review DML NJQRT-15335"
- "DDL review"

**What It Does:**
1. Fetches assigned DML/DDL cases in "Code Review" status
2. Runs AI-review gate checks:
   - Apply Date ≤ 12h past (acceptable)
   - Affected Records ≤ 100k
   - At least one .sql/.js/.json attached
   - USE statement matches target env
   - No TRUNCATE/DROP/DDL on permanent objects
   - No forced index hints
   - No UPDATE/DELETE without WHERE
   - No system databases targeted
3. **Data verification** (live queries):
   - Row-level facts (CustomerId, status constants)
   - Byte fidelity check (CRC32 of INSERT data vs source)
   - Rollback 1:1 match with seed
4. Posts verdict to Jira

**Auto-Transition:** If all checks green → moves case to "DBA2Apply"

---

### **7. `/release-review` (Release Readiness)**

**Purpose:** Multi-stage release review (Pre-Cut → Stage → UAT → PROD)

**When to Use:**
- "Run release readiness"
- "Pre-release branch analysis"
- "UAT sign-off"

**What It Does:**

**Stage 1 (Pre-Cut Readiness):**
- Git branch state (uncommitted changes, commits ahead)
- Jira ticket hygiene (all fix-version tickets closed?)
- MR links recorded?

**Stage 2 (Stage Deployment Sign-off):**
- Records Production Pipeline ID
- Verifies Checkmarx scan (NEW findings only)
- Marks cert ticket "QA Review"

**Stage 3 (Pre-UAT Readiness):**
- Re-verifies ticket/field hygiene
- Only transitions to "Ready for Security Approval" if 100% green

**Stage 4 (UAT Sign-off):**
- Same as Stage 2, UAT environment

**Stage 5 (Pre-PROD Checklist):**
- Rollback plan verified
- Monitoring alerts configured
- Oncall schedule confirmed

**Stage 6 (Post-PROD Closeout):**
- Verifies deployment success
- Closes all tickets
- Archives release notes

---

## 🧠 Section 4: My Global Rules & Memory System

### **Global Rules (from ~/.claude/CLAUDE.md)**

These are **standing instructions** that apply to ALL my work, across all repos.

#### **1. Verification Protocol (NON-NEGOTIABLE)**

**Rule:** Every claim needs code proof or data proof before sharing.

**Why:** Repeated incidents (NJQRT-14987, 14947, 13296, 15094) where unverified claims were stated as fact.

**How:**
- Run the query/read the code FIRST
- Show the proof IN the answer (not just "I verified")
- Never inherit a claim from an earlier session without re-verifying

#### **2. Tool-Call Loop Guard**

**Rule:** If tool calls repeat without progress, abort within 5 seconds.

**Why:** Agent emitted dozens of no-op `echo` commands instead of the approved action (NJQRT-15077).

**How:**
- Detect stuck loop (same call 3+ times)
- Stop emitting calls
- State what got stuck + intended action
- Ask user how to proceed

#### **3. Commit Approval Gate**

**Rule:** Show full diff + commit message, wait for explicit approval before ANY git commit/push.

**Why:** Prevents unauthorized commits, even after a plan is approved.

**How:**
- Plan approval ≠ commit approval
- Every commit is a separate approval gate
- Never stage/commit/push without showing diff first

#### **4. Jira Post Approval (Critical Rule)**

**Rule:** NEVER post comments, transitions, or any writes to Jira without showing draft + getting approval.

**Why:** Comments are customer/sales-facing; mistakes are public.

**How:**
- Draft FIRST
- Show to user
- Wait for "approved" / "post it"
- Then and only then call MCP write tool

#### **5. Root Cause Sanity Check (RC-5)**

**Rule:** Before recording ANY root cause, answer 5 questions:

1. **Prior conclusion:** What did this ticket already conclude? If changing it, say why.
2. **Universality:** Is my cause also present on SUCCEEDING cases? (If yes, not the discriminator)
3. **Reachability:** Does my blamed code actually EXECUTE on the failing request?
4. **Signature:** Does my chain produce the EXACT error string observed?
5. **Fix vs Mask:** Does my fix restore function, or only stop the error appearing?

**Why:** Prevents false root causes that explain symptoms but aren't the actual defect.

---

### **Memory System (Auto-Memory)**

**Location:** `~/.claude/projects/c--Users-kasekar-GH/memory/`

**What It Stores:**

1. **User memories:** My role, preferences, knowledge level
2. **Feedback memories:** Corrections and confirmations (what to avoid, what to keep doing)
3. **Project memories:** Ongoing work, goals, timelines
4. **Reference memories:** Where to find things (Linear projects, Grafana dashboards, Slack channels)

**Example Memories:**

**feedback_verify_before_proposing.md:**
```markdown
---
name: verify-before-proposing
description: Manually verify every claim against source before including in ANY draft
metadata:
  type: feedback
---

Manually verify every claim, detail, and fact against source material before including it
in ANY draft — code-behavior claims, test/comparison matrices, root-cause analysis, fix
proposals, emails, Jira comments, documents.

**Why:** 6th occurrence NJQRT-13296 — built a 3-table PHP behavior matrix asserting a
condition always redirects when the variable is a strict boolean and the comparison was
`=== 1` (always false in PHP).

**How to apply:** While drafting each claim, check it against actual code or query result.
"Let me check" AFTER user pushes back is too late.
```

**project_njqrt15274_dml_rollout_phasing.md:**
```markdown
---
name: njqrt15274-dml-rollout-phasing
description: Reported account first, then rest of customer, then other AC customers on request
metadata:
  type: project
---

For NJQRT-15274 (SSOValidateAccountBeforeLinkingToUser default Y rollout):
- Phase 1: Reported account only
- Phase 2: Rest of customer's accounts
- Phase 3: Other AC customers (on explicit request)
- UC customers excluded (needs cross-table migration, separate POC)

**Why:** UC schema different — fsionlineaccount vs fsiuseraccount.
```

---

## 🔒 Section 5: Checkmarx Developer Assist in VS Code

### **What Is It?**

**Checkmarx Developer Assist** is a VS Code extension that scans code for security issues **pre-commit** (before git add).

### **Why I Use It**

**Problem:** Waiting for CI Checkmarx scan after push wastes time (5-10 min scan + fix + re-push = 15+ min loop).

**Solution:** Scan locally BEFORE commit → catch issues in dev phase.

### **Setup**

#### **1. Install Extension**
```bash
# VS Code Extensions Marketplace
ext install Checkmarx.checkmarx-ast
```

#### **2. Authenticate**
```bash
# CLI auth (tenant: billtrust)
cx auth login --tenant billtrust
```

#### **3. Scan on Save (Optional)**
```json
// .vscode/settings.json
{
  "checkmarx.scanOnSave": true,
  "checkmarx.showInProblems": true
}
```

### **How I Use It**

#### **Pre-Commit Workflow**

**Step 1: Write Code**
```php
// Example: Payment processing
$amount = $_POST['amount'];
$query = "SELECT * FROM payments WHERE amount = $amount"; // ❌ SQL Injection!
```

**Step 2: Save File**
→ Checkmarx scans in background (5-10 seconds)

**Step 3: Check Problems Panel**
```
⚠️ HIGH: SQL Injection via unsanitized user input
   File: PaymentController.php:42
   Fix: Use parameterized query
```

**Step 4: Fix Before Commit**
```php
// Fixed
$amount = $_POST['amount'];
$query = "SELECT * FROM payments WHERE amount = ?";
$stmt = $pdo->prepare($query);
$stmt->execute([$amount]); // ✅ Safe
```

**Step 5: Re-Scan**
→ Checkmarx: ✅ No issues found

**Step 6: Commit**
```bash
git add PaymentController.php
git commit -m "fix: SQL injection in payment amount query"
```

**Result:** No CI failure, no re-push loop.

---

### **What It Catches**

| Vulnerability | Example | Severity |
|---|---|---|
| **SQL Injection** | String concat in WHERE clause | HIGH |
| **XSS** | Unescaped user input in HTML | HIGH |
| **Hardcoded Secrets** | API key in source code | CRITICAL |
| **Path Traversal** | Unsanitized file path | MEDIUM |
| **LDAP Injection** | Unescaped LDAP filter | MEDIUM |
| **Command Injection** | shell_exec() with user input | HIGH |

---

### **Interview Answer**

**Q: "How do you catch security issues before code review?"**

**A:** 
"I use Checkmarx Developer Assist in VS Code for pre-commit security scanning. It runs in the background on save and flags issues like SQL injection, XSS, hardcoded secrets in the Problems panel. This catches vulnerabilities in the dev phase — before commit — so I never push insecure code to CI. It's saved me from at least a dozen CI failures."

**Follow-up Q: "Example?"**

**A:**
"Recently I was writing a payment query and accidentally used string concatenation for the amount filter. Checkmarx flagged it as HIGH severity SQL injection within 10 seconds. I fixed it to use parameterized queries, re-scanned, got the green light, then committed. Without it, I would've pushed, failed CI Checkmarx scan, then had to fix and re-push — 15 minute loop avoided."

---

## 📚 Section 6: Confluence Pages I Created

**Note:** High-level bullet points only — context, not full content.

### **1. NJQRT Fraud Investigation Template**

**URL:** `https://billtrust.atlassian.net/wiki/spaces/.../NJQRT+Fraud+Investigation`

**Purpose:** Standardized workflow for fraud/account-compromise cases

**Key Sections:**
- **Data Sources:** Which tables/logs to check (fsiocuseraudit, BTPay gateway, Datadog, Pendo)
- **Timeline Reconstruction:** How to build chronological activity log
- **Red Flags:** Patterns indicating fraud (IP change + email change + payment within 1 hour)
- **Escalation Path:** When to involve Security team vs handle in NJQRT
- **Sample Queries:** MySQL queries for login history, payment attempts, document access

---

### **2. EIC AutoPay Investigation Checklist**

**URL:** `https://billtrust.atlassian.net/wiki/spaces/.../EIC+AutoPay+Checklist`

**Purpose:** Step-by-step AutoPay troubleshooting

**Key Sections:**
- **AC vs UC Detection:** How to identify customer model (AccountNumber presence in fsionlineaccount)
- **Settings Hierarchy:** Account-level → Customer-level → Template-level
- **DB Tables:** 8 tables that control AutoPay (fsiaccountautopay, fsicustomersettings, etc.)
- **Common Gotchas:** Schema default 'Y' enrolls guest users (BTPay payment stubs)
- **Platform vs EIC:** Which settings live in Platform API vs EIC database

---

### **3. Database Sharding Guide (EIC Stack 1/2)**

**URL:** `https://billtrust.atlassian.net/wiki/spaces/.../EIC+Stack+Sharding`

**Purpose:** How EIC's horizontal sharding works

**Key Sections:**
- **Routing Logic:** billingmaster.fsicustomer.Stack → billingclient1 or billingclient2
- **Stack Assignment:** New customers assigned round-robin (alternates 1/2)
- **Cross-Stack Queries:** When you need data from BOTH stacks (use UNION)
- **Migration Notes:** How Stack 3 migration happened (2019) and lessons learned
- **Performance:** 100M+ invoice rows per stack, <50ms p99 latency

---

### **4. Test Data API Usage Guide**

**URL:** `https://billtrust.atlassian.net/wiki/spaces/.../Test+Data+API`

**Purpose:** How to provision test customers via AWS API

**Key Sections:**
- **Authentication:** API key + bearer token (SSM Parameter Store)
- **Endpoints:** Create customer, update settings, create documents, delete customer
- **Customer Models:** AC vs UC provisioning differences
- **Settings Atoms:** How to set AutopayVersion, EnableEBill, etc.
- **Cleanup:** Always delete test customers after test (or they pollute dev)

---

### **5. NJQRT Triage Best Practices**

**URL:** `https://billtrust.atlassian.net/wiki/spaces/.../NJQRT+Triage+Best+Practices`

**Purpose:** How I triage NJQRT tickets (before it became `/karthik-triage` skill)

**Key Sections:**
- **Step 0:** Read the ticket + ALL comments + linked cases FIRST
- **Step 1:** Reproduce the issue (dev environment if possible)
- **Step 2:** Hypothesis generation (3+ possible causes)
- **Step 3:** Hypothesis testing (DB queries, code tracing, Datadog logs)
- **Step 4:** Root cause validation (RC-5 sanity check)
- **Step 5:** Blast radius analysis (how many customers affected?)
- **Step 6:** Solution proposal (fix vs workaround)
- **Step 7:** Jira update (technical + business summaries)

---

## 🕵️ Section 7: Malicious Actor Investigation Patterns

**Context:** Patterns I've identified in fraud investigations, NOT code or queries.

### **Pattern 1: Credential Stuffing**

**Indicators:**
- Same email address, 10+ failed login attempts
- Different passwords each attempt (brute force list)
- Success from new IP address (different city/country than previous logins)
- Immediate email change after successful login
- Immediate payment method change

**Timeline:**
1. 10:00 AM - 10 failed logins (IPs from botnet)
2. 10:05 AM - 1 successful login (legitimate password from data breach)
3. 10:06 AM - Email changed to attacker's email
4. 10:07 AM - Payment method added (attacker's card)
5. 10:10 AM - 5 invoices downloaded (data exfiltration)

**Data Sources:**
- Login audit table (failed vs success)
- IP geolocation (Pendo user sessions)
- Email change audit
- Payment method audit

---

### **Pattern 2: Card Testing (Carding)**

**Indicators:**
- Multiple $1 or $0.50 charges (testing if card is valid)
- Rapid fire (10+ attempts in 1 minute)
- Different card numbers each time (stolen card list)
- All from same IP address
- After valid card found → 1 large charge ($500+)

**Timeline:**
1. 2:00 PM - $1 charge declined (card 1)
2. 2:00 PM - $1 charge declined (card 2)
3. 2:01 PM - $1 charge declined (card 3)
4. 2:01 PM - $1 charge SUCCESS (card 4)
5. 2:02 PM - $500 charge SUCCESS (same card 4)

**Data Sources:**
- BTPay payment gateway logs (transaction attempts)
- Payment decline reasons (insufficient funds vs invalid card)
- IP address (all from same source)

---

### **Pattern 3: Account Takeover (ATO)**

**Indicators:**
- IP change (previous logins from USA, now from Russia)
- Email change within 1 hour of IP change
- Payment method change immediately after email change
- Invoice download spike (10+ invoices in 1 session, normal is 2-3)
- Password reset requested (forgot password flow)

**Timeline:**
1. Jan 1 - Jan 30: Normal logins from New York (IP: 1.2.3.4)
2. Jan 31, 9:00 AM: Login from Moscow (IP: 5.6.7.8) ⚠️
3. Jan 31, 9:05 AM: Email changed ⚠️
4. Jan 31, 9:10 AM: Payment method changed ⚠️
5. Jan 31, 9:15 AM: 25 invoices downloaded ⚠️

**Data Sources:**
- Login history (IP address, timestamp)
- Email audit (old email → new email)
- Payment method audit
- Document download logs (Datadog APM)

---

### **Pattern 4: Insider Abuse**

**Indicators:**
- Admin user (not customer) accessing invoices
- Access to customers they don't manage (CustomerId outside their territory)
- Download spike (100+ invoices in 1 day, normal is 5-10 for support)
- After-hours access (2:00 AM downloads)
- Personal email forwarding rules set up

**Timeline:**
1. Jan 1-15: Normal support activity (5-10 invoice views/day)
2. Jan 16, 2:00 AM: 100 invoice downloads (all for competitor customers) ⚠️
3. Jan 17: Email forwarding rule created → personal Gmail ⚠️
4. Jan 18: Terminated employee (learned from HR)

**Data Sources:**
- Admin user audit (EmpId, IPAddress)
- Document access logs (CustomerId, AccountNumber)
- Email rules audit (forwarding destinations)
- HR termination records

---

### **Pattern 5: Data Exfiltration**

**Indicators:**
- Automated download pattern (every 30 seconds, exact timing)
- API calls instead of UI (curl/Postman, not browser)
- All invoices for 1 customer (not selective)
- Large volume (500+ invoices, normal user: 10-20)
- Specific date range (last 2 years, targeting historical data)

**Timeline:**
1. 10:00 AM - API call: Download invoice 1
2. 10:00:30 AM - API call: Download invoice 2
3. 10:01 AM - API call: Download invoice 3
... (continues every 30 seconds)
4. 12:00 PM - 500 invoices downloaded

**Data Sources:**
- API access logs (user agent: curl, not browser)
- Document download logs (timestamp pattern)
- Rate limiting alerts (exceeded 100 req/hour threshold)

---

### **How I Investigate**

**Step 1: Identify Pattern**
- Read ticket description
- Look for keywords: "fraud", "suspicious", "unauthorized", "multiple IPs"

**Step 2: Run Timeline Query**
- Get all activity for user/account (last 30 days)
- Sort chronologically
- Flag anomalies (IP change, email change, payment spike)

**Step 3: Cross-Reference Data Sources**
- Login audit (when did IP change?)
- Email audit (when did email change?)
- Payment audit (when did payment method change?)
- Document logs (when did download spike?)

**Step 4: Determine Pattern**
- Does it match credential stuffing? (10+ failed → 1 success → email change)
- Does it match card testing? (10+ $1 charges → 1 success)
- Does it match ATO? (IP change → email change → payment change)
- Does it match insider abuse? (admin user, after-hours, competitor customers)
- Does it match exfiltration? (automated, API, 500+ downloads)

**Step 5: Draft Timeline for Jira**
- Markdown table (timestamp, event, source)
- Never include PAN/CVV
- Mask email/IP if needed
- Recommendation (escalate to Security vs handle in NJQRT)

---

## ✅ Interview Prep: How to Talk About Your Workflow

### **Q: "Walk me through your triage process"**

**Answer:**
"I start by reading the full ticket — description, all comments, linked cases — to understand what was already tried. Then I load the repo context via `/developer eic` which pulls in CLAUDE.md, CONTEXT.md, and constitution.md — these are AI-readable docs I've added to our repos that specify active vs legacy code, common pitfalls, and security rules.

Next, I search our Jira backlog and Confluence for similar past cases — often the answer is already documented. If it's a new issue, I invoke sub-skills: `/researcher` explores the codebase, `/db-query` runs read-only MySQL queries via a Docker gateway I built, and for complex investigations I'll query Datadog for error traces or Pendo for user behavior.

Once I have a root cause hypothesis, I run it through RC-5 — a 5-question sanity check: Does this explain the EXACT error? Is it present on succeeding cases too? Does my blamed code actually execute? Does my fix restore function or just mask the error? And what was the prior conclusion — am I changing it?

Finally, I draft findings in two versions — technical for developers, business for stakeholders — get approval, then post to the Jira Development subtask. The whole process is tracked in my `/karthik-triage` skill."

---

### **Q: "How do you handle security in your code?"**

**Answer:**
"I use a multi-layer approach:

**Pre-commit:** Checkmarx Developer Assist in VS Code scans my code on save and flags issues like SQL injection, XSS, hardcoded secrets in the Problems panel. This catches vulnerabilities before I even commit.

**Pre-push:** Our repos have constitution.md files with hard rules — always use parameterized queries, never log PAN/CVV, always filter by tenant. I validate against these before creating a PR.

**CI:** Our GitHub Actions pipeline runs Checkmarx AST scans and SonarQube quality gates. I check for NEW findings only — pre-existing issues are baseline, not blockers.

**Post-merge:** I monitor Datadog for errors and Pendo for unexpected user behavior that might indicate a security issue slipped through.

This layered approach means I'm not just relying on CI to catch issues — I'm proactive about security from the first line of code."

---

### **Q: "Tell me about a fraud investigation you handled"**

**Answer:**
"We had a case where a customer reported unauthorized invoice downloads. I used the fraud investigation pattern I documented in Confluence:

First, I pulled a timeline of all activity for that account over the last 30 days — login history, email changes, payment methods, document downloads. I noticed an IP change from New York to Moscow, followed within 1 hour by an email change, payment method change, and 25 invoice downloads (normal is 2-3).

This matched the Account Takeover pattern: IP change → email change → payment change → data exfiltration. I cross-referenced the new email against our user database and found it was used on 3 other accounts — all with similar patterns.

I escalated to Security with a full timeline, they confirmed it was a credential stuffing attack from a data breach, and we locked down all affected accounts. I then created a Confluence page documenting the pattern so future triages could recognize it faster."

---

## 🎯 Next Steps

1. **Review this module** (~1 hour read)
2. **Practice explaining your workflow** (say it out loud)
3. **Update your resume** with specific tools (Checkmarx, Docker, custom skills)
4. **Prepare STAR stories** for each section
5. **Be ready to demo** (show CLAUDE.md in a repo, run db-query.ps1, explain RC-5)

---

**Last Updated:** November 17, 2026  
**Next Module:** System Design & Architecture
