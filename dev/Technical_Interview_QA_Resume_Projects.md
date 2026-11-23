# Technical Interview Q&A - Resume Projects (12+ Years Experience)

**Deep-Dive Questions & Answers for Your 8 Projects**

---

## 📋 TABLE OF CONTENTS

1. [eInvoice Connect (EIC)](#1-einvoice-connect-eic)
2. [Client Connect (CC)](#2-client-connect-cc)
3. [Customer Settings Repository (CSR)](#3-customer-settings-repository-csr)
4. [Web Communication Layer (WCL)](#4-web-communication-layer-wcl)
5. [Managed Pay (MPay)](#5-managed-pay-mpay)
6. [Account Management API (AMAPI)](#6-account-management-api-amapi)
7. [Multi-Domain Whitelabel Platform](#7-multi-domain-whitelabel-platform)
8. [Incident Remediation & RCA Tracker](#8-incident-remediation--rca-tracker)
9. [Cross-Project Architecture Questions](#9-cross-project-architecture-questions)
10. [Performance & Scalability](#10-performance--scalability)
11. [Security & Compliance](#11-security--compliance)
12. [Database Design & Optimization](#12-database-design--optimization)
13. [Leadership & Decision Making](#13-leadership--decision-making)
14. [Debugging & Production Issues](#14-debugging--production-issues)

---

## 1. eInvoice Connect (EIC)

### Q1.1: Explain the database sharding strategy (Stack1/Stack2). Why did you choose this approach?

**Answer:**

**What is Stack1/Stack2:**
- We implemented horizontal sharding to distribute customer data across two separate MySQL databases
- **Stack1:** Customers with CustomerId % 2 == 0
- **Stack2:** Customers with CustomerId % 2 == 1

**Why we chose this:**
1. **Performance:** Single database was hitting 100M+ rows, causing slow queries
2. **Write throughput:** Split write load across two separate RDS instances
3. **Blast radius:** Database failure only affects 50% of customers, not all
4. **Maintenance:** Can upgrade/patch one stack while other serves traffic

**How routing works:**
```php
// Simplified routing logic
function getDbConnection($customerId) {
    $stack = ($customerId % 2 == 0) ? 'stack1' : 'stack2';
    return WCL::getConnection($stack);
}
```

**Trade-offs:**
- ✅ Better performance, reduced blast radius
- ❌ Cross-stack queries impossible (can't JOIN between Stack1 and Stack2)
- ❌ Rebalancing customers between stacks is complex

**Alternative considered:** Vertical sharding (separate tables), but rejected because all tables needed to scale together.

---

### Q1.2: How does the authenticated email workflow with 10-minute activation work? What happens after 10 minutes?

**Answer:**

**Flow:**
1. User requests email (forgot password, verify email, etc.)
2. System generates random 6-digit code
3. Code stored in `email_verification_codes` table with:
   - `code` (hashed with bcrypt)
   - `email`
   - `expires_at` (NOW() + 10 minutes)
   - `created_at`
4. Email sent with code via WCL microservice
5. User enters code on verification page
6. System checks:
   ```php
   WHERE email = ? 
   AND expires_at > NOW() 
   AND attempts < 3
   ```
7. If valid → Mark as verified, delete code
8. If expired → Show "Code expired, request new one"

**After 10 minutes:**
- Code is still in DB but `expires_at < NOW()` so validation fails
- Background cron job deletes expired codes every 15 minutes
- User must request new code

**Security measures:**
- Bcrypt hashed codes (not plain text)
- Max 3 attempts per code
- Rate limiting: 1 request per email per 60 seconds
- IP-based rate limiting (10 requests/minute)

**Why 10 minutes:**
- Balance between security (short window) and UX (enough time for user to check email)
- Industry standard for email verification

---

### Q1.3: You support 12+ languages. How is multi-language handled technically? What's the performance impact?

**Answer:**

**Architecture:**

**1. Translation Storage:**
```
Table: fsi_translations
- translation_id (PK)
- language_code (en, es, fr, de, etc.)
- translation_key (invoice.total, payment.success, etc.)
- translated_text (actual translation)
- last_updated
```

**2. Loading Strategy:**
```php
// On first request, load all translations for user's language
$language = $user->getPreferredLanguage(); // from CSR settings
$translations = Cache::remember("translations:{$language}", 3600, function() use ($language) {
    return DB::table('fsi_translations')
        ->where('language_code', $language)
        ->pluck('translated_text', 'translation_key')
        ->toArray();
});
```

**3. Usage in code:**
```php
// Instead of hardcoded strings:
echo __('invoice.total'); // Looks up translation from cache
```

**Performance optimization:**
- **Redis cache:** Translations cached for 1 hour, eliminates DB hits
- **Lazy loading:** Only load language user requested (not all 12)
- **CDN:** Static translated content served from CloudFront
- **Impact:** ~5ms overhead for cache lookup vs 50-100ms for DB query

**Challenges solved:**
- **RTL languages:** Arabic/Hebrew need CSS direction changes
- **Date formats:** Different locales (MM/DD/YYYY vs DD/MM/YYYY)
- **Currency:** $1,000.00 vs 1.000,00€
- **Pluralization:** "1 invoice" vs "2 invoices"

**Fallback strategy:**
If translation missing → Fall back to English → Log missing key for translator

---

### Q1.4: How does sub-user delegation work? What permissions can be delegated?

**Answer:**

**Architecture:**

**1. User Hierarchy:**
```
Primary User (Account Owner)
└── Sub-User 1 (View Only)
└── Sub-User 2 (View + Pay)
└── Sub-User 3 (Full Access)
```

**2. Database Schema:**
```sql
CREATE TABLE fsi_sub_users (
    sub_user_id INT PRIMARY KEY,
    primary_user_id INT, -- Links to parent
    email VARCHAR(255),
    permission_level ENUM('view', 'view_pay', 'full'),
    can_view_invoices BOOLEAN DEFAULT 1,
    can_make_payments BOOLEAN DEFAULT 0,
    can_manage_autopay BOOLEAN DEFAULT 0,
    can_manage_sub_users BOOLEAN DEFAULT 0,
    created_by INT,
    created_at TIMESTAMP
);
```

**3. Permission Check (Middleware):**
```php
class SubUserPermission {
    public function checkPermission($subUser, $action) {
        $permissions = [
            'view_invoices' => $subUser->can_view_invoices,
            'make_payment' => $subUser->can_make_payments,
            'manage_autopay' => $subUser->can_manage_autopay,
            'manage_sub_users' => $subUser->can_manage_sub_users,
        ];
        
        if (!$permissions[$action]) {
            throw new UnauthorizedException("Sub-user lacks permission: {$action}");
        }
    }
}
```

**4. Audit Trail:**
Every action logs:
```sql
INSERT INTO fsi_audit_log (user_id, sub_user_id, action, ip_address, timestamp)
VALUES (123, 456, 'payment_made', '192.168.1.1', NOW());
```

**Permission Levels:**
- **View Only:** See invoices, payment history (no actions)
- **View + Pay:** Can make one-time payments
- **Full Access:** Everything except delete primary account

**Use cases:**
- Accountant views invoices but can't pay (View Only)
- AP clerk makes payments (View + Pay)
- CFO has full access (Full Access)

**Security:**
- Sub-users can't elevate their own permissions
- Only primary user can delete sub-users
- Email verification required for new sub-users
- 2FA can be enforced per sub-user

---

### Q1.5: What's the AutoPay threshold logic? Walk through the payment decision flow.

**Answer:**

**Configuration:**
```php
AutoPay Settings (stored in fsi_autopay_config):
- autopay_enabled: true
- threshold_amount: $500
- payment_account_id: 789 (which bank account to use)
- autopay_day: 5 (days before due date)
```

**Decision Flow (runs daily cron):**

```php
// 1. Find all invoices eligible for AutoPay
$invoices = DB::table('fsi_invoices')
    ->join('fsi_autopay_config', 'fsi_invoices.customer_id', '=', 'fsi_autopay_config.customer_id')
    ->where('fsi_autopay_config.autopay_enabled', true)
    ->where('fsi_invoices.status', 'unpaid')
    ->where('fsi_invoices.due_date', '<=', DB::raw('DATE_ADD(NOW(), INTERVAL fsi_autopay_config.autopay_day DAY)'))
    ->get();

// 2. For each invoice, check threshold
foreach ($invoices as $invoice) {
    $autopayConfig = getAutopayConfig($invoice->customer_id);
    
    // Apply threshold logic
    if ($invoice->total_amount <= $autopayConfig->threshold_amount) {
        // Amount is UNDER threshold → Process payment automatically
        processAutoPayment($invoice, $autopayConfig->payment_account_id);
    } else {
        // Amount is OVER threshold → Send notification, don't pay
        sendThresholdExceededNotification($invoice, $autopayConfig->threshold_amount);
    }
}
```

**Example Scenarios:**

**Scenario 1: Invoice $300, Threshold $500**
- Invoice total < threshold → ✅ Auto-pay
- Payment processed 5 days before due date
- Confirmation email sent

**Scenario 2: Invoice $800, Threshold $500**
- Invoice total > threshold → ❌ Don't auto-pay
- Email sent: "Invoice $800 exceeds your AutoPay threshold of $500. Manual payment required."
- Invoice remains unpaid until manual action

**Why threshold exists:**
- Prevent large unexpected charges
- Customer controls maximum auto-payment amount
- Compliance: Prevents disputes on large amounts

**Retry logic:**
If payment fails:
```php
Retry Schedule:
- Attempt 1: Immediate
- Attempt 2: +6 hours
- Attempt 3: +24 hours
- After 3 failures: Disable AutoPay, send alert
```

**Edge cases handled:**
- Payment account expired → Disable AutoPay, alert customer
- Insufficient funds → Retry with exponential backoff
- Duplicate prevention → Idempotency key per invoice

---

## 2. Client Connect (CC)

### Q2.1: This is a supplier admin portal. Explain the difference in architecture between CC and EIC.

**Answer:**

**Key Differences:**

| Aspect | EIC (Customer Portal) | CC (Supplier Portal) |
|---|---|---|
| **User Base** | End customers (1000s) | Supplier admins (10-50 per supplier) |
| **Auth** | Email/password, SSO | Email/password, MFA required |
| **Data Scope** | Single customer's invoices/payments | ALL customers under supplier |
| **Caching** | Per-customer cache | Aggregated cache (reports) |
| **Writes** | High (payments, settings) | Low (config changes) |
| **Reads** | Moderate (view invoices) | Very high (reports, monitoring) |
| **Performance** | <300ms page load | <1s for dashboards (acceptable) |

**Architecture Differences:**

**EIC (Customer-Focused):**
```
User Login → Stack Routing (Stack1 or Stack2 based on CustomerId) 
         → Redis Cache (customer-specific) 
         → Display invoices/payments
```

**CC (Supplier-Focused):**
```
Admin Login → Query ALL stacks (Stack1 + Stack2) 
          → Aggregate data 
          → Redis Cache (report-level, not per-customer) 
          → Display consolidated reports
```

**Example Query Difference:**

**EIC (single customer):**
```php
// Fast - single customer, single stack
$invoices = DB::connection($stack)
    ->table('fsi_invoices')
    ->where('customer_id', $customerId)
    ->get();
```

**CC (all customers):**
```php
// Slower - must query both stacks and merge
$stack1Invoices = DB::connection('stack1')
    ->table('fsi_invoices')
    ->whereBetween('invoice_date', [$startDate, $endDate])
    ->get();

$stack2Invoices = DB::connection('stack2')
    ->table('fsi_invoices')
    ->whereBetween('invoice_date', [$startDate, $endDate])
    ->get();

$allInvoices = $stack1Invoices->merge($stack2Invoices);
```

**Why separate applications:**
- Different UX (customer-friendly vs admin-heavy)
- Different performance requirements
- Different security models (MFA mandatory for CC)
- Separate deployment cycles (EIC changes don't affect CC)

---

### Q2.2: How does "payment on behalf of customer" work? What are the security considerations?

**Answer:**

**Use Case:**
Supplier admin needs to process payment for customer who's having issues (e.g., technical problem, urgent payment needed).

**Workflow:**

**1. Authorization Check:**
```php
// Admin must have 'make_payment_on_behalf' permission
if (!$admin->hasPermission('make_payment_on_behalf')) {
    throw new UnauthorizedException("Admin lacks permission to pay on behalf");
}

// Admin must belong to same supplier as customer
if ($customer->supplier_id !== $admin->supplier_id) {
    throw new UnauthorizedException("Cross-supplier payment not allowed");
}
```

**2. Payment Flow:**
```php
function makePaymentOnBehalf($adminId, $customerId, $invoiceId, $amount, $reason) {
    // 1. Create audit record BEFORE payment
    DB::table('fsi_admin_actions')->insert([
        'admin_id' => $adminId,
        'customer_id' => $customerId,
        'action_type' => 'payment_on_behalf',
        'invoice_id' => $invoiceId,
        'amount' => $amount,
        'reason' => $reason, // Required field
        'ip_address' => request()->ip(),
        'timestamp' => now(),
    ]);
    
    // 2. Process payment using customer's default payment account
    $paymentAccount = getCustomerDefaultPaymentAccount($customerId);
    $result = processPayment($paymentAccount, $amount, $invoiceId);
    
    // 3. Send notification to customer
    sendEmail($customer->email, [
        'subject' => 'Payment Processed on Your Behalf',
        'body' => "Admin {$admin->name} processed payment of ${$amount} for invoice #{$invoiceId}. Reason: {$reason}",
    ]);
    
    // 4. Log in both systems
    logToDatadog('payment_on_behalf', [
        'admin' => $adminId,
        'customer' => $customerId,
        'amount' => $amount,
    ]);
    
    return $result;
}
```

**Security Measures:**

**1. Multi-Factor Authentication:**
- Admin must re-authenticate with MFA before each "on behalf" payment
- MFA token expires after 10 minutes

**2. Approval Workflow (for large amounts):**
```php
if ($amount > 10000) {
    // Requires second admin approval
    createApprovalRequest($adminId, $customerId, $amount);
    sendApprovalEmail($supervisorAdmins);
    return "Pending approval from supervisor";
}
```

**3. Daily Limits:**
```php
$dailyTotal = DB::table('fsi_admin_actions')
    ->where('admin_id', $adminId)
    ->where('action_type', 'payment_on_behalf')
    ->whereDate('timestamp', today())
    ->sum('amount');

if ($dailyTotal + $amount > 50000) {
    throw new LimitExceededException("Daily limit of $50,000 exceeded");
}
```

**4. Customer Consent (optional):**
- Some customers enable "admin can pay on behalf" flag
- If disabled, admin payment is blocked

**Audit Trail:**
Every "on behalf" payment creates:
- Entry in `fsi_admin_actions` table
- Datadog event for monitoring
- Email to customer (transparency)
- Monthly report to compliance team

**Why this feature exists:**
- Customer's payment portal down → Admin can process payment to avoid late fee
- Customer out of office → Admin can pay urgent invoice
- Technical issue on customer side → Admin bypass as workaround

---

### Q2.3: Explain the bulk user onboarding via AMAPI integration. What's the error handling strategy?

**Answer:**

**Flow:**

**1. Admin uploads CSV file (via CC):**
```csv
email,first_name,last_name,role,customer_id
john@example.com,John,Doe,view_only,12345
jane@example.com,Jane,Smith,view_pay,12345
```

**2. CC validates CSV:**
```php
function validateCsv($file) {
    $errors = [];
    
    foreach ($file->rows as $index => $row) {
        // Email validation
        if (!filter_var($row['email'], FILTER_VALIDATE_EMAIL)) {
            $errors[] = "Row {$index}: Invalid email '{$row['email']}'";
        }
        
        // Role validation
        $validRoles = ['view_only', 'view_pay', 'full_access'];
        if (!in_array($row['role'], $validRoles)) {
            $errors[] = "Row {$index}: Invalid role '{$row['role']}'";
        }
        
        // Customer ID existence check
        if (!customerExists($row['customer_id'])) {
            $errors[] = "Row {$index}: Customer {$row['customer_id']} not found";
        }
    }
    
    if (!empty($errors)) {
        return ['success' => false, 'errors' => $errors];
    }
    
    return ['success' => true];
}
```

**3. CC calls AMAPI (bulk endpoint):**
```php
$response = Http::post('https://amapi.internal/api/v1/bulk-enroll', [
    'users' => $validatedRows,
    'created_by' => $admin->id,
    'idempotency_key' => uniqid('bulk_', true), // Prevent duplicate processing
]);
```

**4. AMAPI processes in background (queue):**
```php
// AMAPI side - Queue job
dispatch(new BulkEnrollUsers($users, $idempotencyKey));

// Job processor
class BulkEnrollUsers {
    public function handle() {
        $results = [];
        
        foreach ($this->users as $user) {
            try {
                // Create user account
                $account = createAccount($user);
                
                // Send welcome email
                sendWelcomeEmail($user['email'], $account);
                
                $results[] = ['email' => $user['email'], 'status' => 'success', 'account_id' => $account->id];
            } catch (Exception $e) {
                // Log error but continue processing others
                $results[] = ['email' => $user['email'], 'status' => 'failed', 'error' => $e->getMessage()];
                
                Log::error("Bulk enroll failed for {$user['email']}", ['exception' => $e]);
            }
        }
        
        // Store results for admin to review
        storeResults($this->idempotencyKey, $results);
        
        // Notify admin when done
        sendCompletionEmail($admin, $results);
    }
}
```

**5. CC polls AMAPI for results:**
```php
// Every 5 seconds, check status
$status = Http::get("https://amapi.internal/api/v1/bulk-status/{$idempotencyKey}");

if ($status['completed']) {
    // Show results to admin
    return view('bulk-results', [
        'success_count' => $status['success_count'],
        'failed_count' => $status['failed_count'],
        'failed_rows' => $status['failed_rows'],
    ]);
}
```

**Error Handling Strategy:**

**1. Partial Success Model:**
- If 100 users uploaded, 95 succeed, 5 fail → Still consider it success
- Failed rows returned to admin with specific error messages

**2. Idempotency:**
- Same CSV uploaded twice → AMAPI detects via idempotency key
- Returns cached results instead of re-processing

**3. Retry Logic:**
- Transient errors (DB connection timeout) → Retry up to 3 times
- Permanent errors (invalid email format) → No retry, report to admin

**4. Rollback (not implemented):**
- We DON'T rollback successful users if later ones fail
- Reason: Users already received welcome emails, partial success is acceptable

**5. Admin Notification:**
```
Subject: Bulk User Upload Complete

✅ Successfully created: 95 users
❌ Failed: 5 users

Failed rows:
- Row 23: Email 'invalid@' is invalid
- Row 45: Customer 99999 does not exist
- Row 78: User 'john@example.com' already exists

Download failed rows CSV to fix and re-upload.
```

**Performance:**
- 1,000 users → ~2-3 minutes (async processing)
- Real-time progress updates via WebSocket (not polling)

---

## 3. Customer Settings Repository (CSR)

### Q3.1: CSR serves 200+ microservices. How do you ensure <50ms lookup time? Explain the caching strategy.

**Answer:**

**Challenge:**
200+ microservices making thousands of requests/second → CSR would be bottleneck if every request hit database.

**Solution: 3-Layer Caching**

**Layer 1: Application-Level Cache (Redis)**
```php
function getSetting($customerId, $settingKey) {
    $cacheKey = "settings:{$customerId}:{$settingKey}";
    
    // Check Redis first
    $cachedValue = Redis::get($cacheKey);
    if ($cachedValue !== null) {
        // Cache hit - return in ~5ms
        return json_decode($cachedValue, true);
    }
    
    // Cache miss - query database
    $setting = DB::table('csr_settings')
        ->where('customer_id', $customerId)
        ->where('setting_key', $settingKey)
        ->first();
    
    // Store in Redis with TTL
    Redis::setex($cacheKey, 3600, json_encode($setting)); // 1 hour TTL
    
    return $setting;
}
```

**Layer 2: Local In-Memory Cache (OPcache + APCu)**
```php
// Even faster - stored in PHP process memory (no network call)
function getSettingWithLocalCache($customerId, $settingKey) {
    $localCacheKey = "{$customerId}:{$settingKey}";
    
    // Check APCu (local to this PHP process)
    $local = apcu_fetch($localCacheKey, $success);
    if ($success) {
        return $local; // <1ms response
    }
    
    // Fall back to Redis (Layer 1)
    $value = getSetting($customerId, $settingKey);
    
    // Store locally for 5 minutes
    apcu_store($localCacheKey, $value, 300);
    
    return $value;
}
```

**Layer 3: CDN Edge Cache (CloudFront)**
For static settings (rarely change):
```
Request → CloudFront Edge (cached for 1 hour) → CSR API
```

**Cache Invalidation Strategy:**

**1. When setting is updated:**
```php
function updateSetting($customerId, $settingKey, $newValue) {
    // 1. Update database
    DB::table('csr_settings')
        ->where('customer_id', $customerId)
        ->where('setting_key', $settingKey)
        ->update(['setting_value' => $newValue]);
    
    // 2. Invalidate Redis cache
    Redis::del("settings:{$customerId}:{$settingKey}");
    
    // 3. Publish invalidation event (for APCu across servers)
    Redis::publish('cache:invalidate', json_encode([
        'customer_id' => $customerId,
        'setting_key' => $settingKey,
    ]));
    
    // 4. Invalidate CloudFront (if static)
    if (isStaticSetting($settingKey)) {
        CloudFront::invalidate("/settings/{$customerId}/{$settingKey}");
    }
}

// Each server subscribes to invalidation channel
Redis::subscribe(['cache:invalidate'], function ($message) {
    $data = json_decode($message, true);
    apcu_delete("{$data['customer_id']}:{$data['setting_key']}");
});
```

**Performance Breakdown:**

| Cache Layer | Hit Rate | Latency | When Used |
|---|---|---|---|
| APCu (local) | 60% | <1ms | Same server, recent request |
| Redis (network) | 35% | ~5ms | Different server or cold APCu |
| MySQL (database) | 5% | ~20-30ms | Cache miss on new setting |

**Result:** Average: ~8ms, P95: <50ms

**Why 3 layers:**
- APCu: Eliminates network latency for hot paths
- Redis: Shared cache across servers (consistency)
- Database: Source of truth

**Monitoring:**
```php
Datadog::histogram('csr.lookup.latency', $latency, [
    'cache_layer' => $cacheLayer, // 'apcu', 'redis', 'mysql'
    'customer_id' => $customerId,
]);
```

---

### Q3.2: What's the versioned settings with rollback capability? How is it implemented?

**Answer:**

**Problem:**
Admin updates setting → Breaks customer's integration → Need to rollback to previous value.

**Solution: Version Control for Settings**

**Database Schema:**
```sql
CREATE TABLE csr_settings_versions (
    version_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT,
    setting_key VARCHAR(255),
    setting_value TEXT,
    version_number INT, -- Auto-increment per customer+key
    changed_by INT, -- Admin who made change
    change_reason TEXT, -- Why was this changed?
    is_active BOOLEAN DEFAULT 0, -- Only 1 active version per customer+key
    created_at TIMESTAMP,
    INDEX (customer_id, setting_key, version_number)
);
```

**How it works:**

**1. Getting current setting (always latest active version):**
```php
function getCurrentSetting($customerId, $settingKey) {
    return DB::table('csr_settings_versions')
        ->where('customer_id', $customerId)
        ->where('setting_key', $settingKey)
        ->where('is_active', 1)
        ->first();
}
```

**2. Updating setting (creates new version):**
```php
function updateSetting($customerId, $settingKey, $newValue, $changedBy, $reason) {
    DB::transaction(function() use ($customerId, $settingKey, $newValue, $changedBy, $reason) {
        // 1. Mark current version as inactive
        DB::table('csr_settings_versions')
            ->where('customer_id', $customerId)
            ->where('setting_key', $settingKey)
            ->where('is_active', 1)
            ->update(['is_active' => 0]);
        
        // 2. Get next version number
        $nextVersion = DB::table('csr_settings_versions')
            ->where('customer_id', $customerId)
            ->where('setting_key', $settingKey)
            ->max('version_number') + 1;
        
        // 3. Insert new version
        DB::table('csr_settings_versions')->insert([
            'customer_id' => $customerId,
            'setting_key' => $settingKey,
            'setting_value' => $newValue,
            'version_number' => $nextVersion,
            'changed_by' => $changedBy,
            'change_reason' => $reason,
            'is_active' => 1,
            'created_at' => now(),
        ]);
        
        // 4. Invalidate cache
        Redis::del("settings:{$customerId}:{$settingKey}");
    });
}
```

**3. Viewing version history:**
```php
function getSettingHistory($customerId, $settingKey) {
    return DB::table('csr_settings_versions')
        ->where('customer_id', $customerId)
        ->where('setting_key', $settingKey)
        ->orderBy('version_number', 'desc')
        ->get();
}

// Returns:
// Version 5 (active): "new_value" - Changed by Admin123 - 2026-11-16 10:00
// Version 4: "old_value" - Changed by Admin456 - 2026-11-15 14:30
// Version 3: "older_value" - Changed by Admin123 - 2026-11-10 09:00
```

**4. Rollback to previous version:**
```php
function rollbackSetting($customerId, $settingKey, $targetVersion, $rolledBackBy, $reason) {
    // 1. Verify target version exists
    $targetSetting = DB::table('csr_settings_versions')
        ->where('customer_id', $customerId)
        ->where('setting_key', $settingKey)
        ->where('version_number', $targetVersion)
        ->first();
    
    if (!$targetSetting) {
        throw new Exception("Version {$targetVersion} not found");
    }
    
    // 2. Create NEW version with old value (don't just reactivate old one)
    $nextVersion = DB::table('csr_settings_versions')
        ->where('customer_id', $customerId)
        ->where('setting_key', $settingKey)
        ->max('version_number') + 1;
    
    DB::transaction(function() use ($customerId, $settingKey, $targetSetting, $nextVersion, $rolledBackBy, $reason) {
        // Mark current as inactive
        DB::table('csr_settings_versions')
            ->where('customer_id', $customerId)
            ->where('setting_key', $settingKey)
            ->where('is_active', 1)
            ->update(['is_active' => 0]);
        
        // Insert new version (with old value)
        DB::table('csr_settings_versions')->insert([
            'customer_id' => $customerId,
            'setting_key' => $settingKey,
            'setting_value' => $targetSetting->setting_value, // Value from old version
            'version_number' => $nextVersion,
            'changed_by' => $rolledBackBy,
            'change_reason' => "Rollback to version {$targetSetting->version_number}: {$reason}",
            'is_active' => 1,
            'created_at' => now(),
        ]);
        
        // Invalidate cache
        Redis::del("settings:{$customerId}:{$settingKey}");
    });
}
```

**Example Timeline:**
```
Version 1: "feature_enabled = false" (Nov 1)
Version 2: "feature_enabled = true" (Nov 10) ← Admin enables feature
Version 3: "feature_enabled = false" (Nov 11) ← Rollback! Customer complained
```

**Why this reduces errors by 90%:**
- **Before:** Admin changed setting → Broke customer → Manual DB query to fix
- **After:** Admin changed setting → Broke customer → 1-click rollback via UI
- **Confidence:** Admins more willing to test changes (easy rollback)

**Audit Benefits:**
- Full history of who changed what and why
- Compliance requirement (SOC 2)
- Debugging: "When did this setting change?"

---

## 4. Web Communication Layer (WCL)

### Q4.1: WCL provides DB connections dynamically. How does connection pooling work? What about connection leaks?

**Answer:**

**Challenge:**
200+ microservices each opening DB connections → Exhaust MySQL max_connections (default 151).

**Solution: Connection Pooling in WCL**

**Architecture:**

```
Microservice A ──┐
Microservice B ──┼──> WCL (Connection Pool Manager) ──> MySQL (Stack1)
Microservice C ──┘                                   └──> MySQL (Stack2)
```

**Implementation:**

**1. Pool Configuration:**
```php
// WCL maintains pool per database
$poolConfig = [
    'stack1' => [
        'min_connections' => 10,  // Always keep 10 open
        'max_connections' => 50,  // Never exceed 50
        'max_idle_time' => 300,   // Close idle connections after 5 min
        'connection_timeout' => 5, // Wait max 5 sec for available connection
    ],
    'stack2' => [
        'min_connections' => 10,
        'max_connections' => 50,
        'max_idle_time' => 300,
        'connection_timeout' => 5,
    ],
];
```

**2. Getting Connection (from pool):**
```php
function getConnection($stack, $customerId) {
    $pool = ConnectionPool::getInstance($stack);
    
    // Try to get available connection from pool
    $connection = $pool->acquire();
    
    if ($connection) {
        // Reuse existing connection
        return $connection;
    }
    
    // Pool exhausted, check if we can create new one
    if ($pool->currentSize() < $poolConfig[$stack]['max_connections']) {
        // Create new connection
        $connection = new PDO("mysql:host={$dbHost};dbname={$dbName}", $user, $pass, [
            PDO::ATTR_PERSISTENT => true, // Persistent connection
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        ]);
        
        $pool->add($connection);
        return $connection;
    }
    
    // Wait for connection to become available (with timeout)
    $connection = $pool->waitForConnection($poolConfig[$stack]['connection_timeout']);
    
    if (!$connection) {
        throw new ConnectionPoolExhaustedException("No connections available after {$timeout}s");
    }
    
    return $connection;
}
```

**3. Releasing Connection (back to pool):**
```php
// After query completes
function releaseConnection($connection, $stack) {
    $pool = ConnectionPool::getInstance($stack);
    
    // Reset connection state (important!)
    $connection->exec('ROLLBACK'); // Rollback any uncommitted transactions
    $connection->exec('SET SESSION sql_mode = DEFAULT'); // Reset session variables
    
    // Mark as available in pool
    $pool->release($connection);
}
```

**4. Connection Leak Detection:**
```php
// Every 60 seconds, check for leaked connections
Scheduler::everyMinute(function() {
    foreach (['stack1', 'stack2'] as $stack) {
        $pool = ConnectionPool::getInstance($stack);
        
        $leakedConnections = $pool->getConnectionsOlderThan(600); // 10 minutes
        
        foreach ($leakedConnections as $conn) {
            Log::warning("Connection leak detected", [
                'stack' => $stack,
                'connection_id' => $conn->id,
                'acquired_at' => $conn->acquired_at,
                'acquired_by' => $conn->acquired_by_service, // Which microservice?
            ]);
            
            // Force close leaked connection
            $pool->forceClose($conn);
            
            // Alert on-call engineer
            PagerDuty::trigger("Connection leak from {$conn->acquired_by_service}");
        }
    }
});
```

**5. Monitoring:**
```php
// Expose metrics to Datadog
Datadog::gauge('wcl.connection_pool.size', $pool->currentSize(), ['stack' => $stack]);
Datadog::gauge('wcl.connection_pool.available', $pool->availableCount(), ['stack' => $stack]);
Datadog::gauge('wcl.connection_pool.in_use', $pool->inUseCount(), ['stack' => $stack]);

// Alert if pool near exhaustion
if ($pool->availableCount() < 5) {
    Datadog::event('Connection pool nearly exhausted', "Only {$available} connections left in {$stack}");
}
```

**How it prevents leaks:**
- **Timeout:** Connections held >10 min are force-closed
- **Try-finally:** Microservices use try-finally to ensure release
```php
$conn = WCL::getConnection('stack1', $customerId);
try {
    $result = $conn->query("SELECT...");
} finally {
    WCL::releaseConnection($conn, 'stack1'); // Always released even if exception
}
```
- **Health checks:** Every 5 min, test connection validity, close stale ones

**Performance Impact:**
- **Without pooling:** 50ms to open new connection per request
- **With pooling:** <1ms to acquire from pool
- **Result:** 50x faster connection acquisition

---

### Q4.2: Encrypted key authentication - how does each application get a unique key? Key rotation strategy?

**Answer:**

**Problem:**
Can't use username/password for service-to-service auth (too easy to leak).

**Solution: API Key Authentication with Encryption**

**Architecture:**

**1. Key Generation (when new microservice onboards):**
```php
function generateApiKey($serviceName) {
    // 1. Generate random 256-bit key
    $rawKey = random_bytes(32); // 32 bytes = 256 bits
    $apiKey = base64_encode($rawKey);
    
    // 2. Hash for storage (never store plain key!)
    $hashedKey = hash('sha256', $rawKey);
    
    // 3. Store in database
    DB::table('wcl_api_keys')->insert([
        'service_name' => $serviceName,
        'key_hash' => $hashedKey,
        'key_prefix' => substr($apiKey, 0, 8), // For identification
        'created_at' => now(),
        'expires_at' => now()->addYear(), // Keys expire after 1 year
        'is_active' => true,
    ]);
    
    // 4. Return plain key ONCE (send to service owner via secure channel)
    return $apiKey;
}

// Example generated key:
// "wkl_live_a8f3e9c2b1d4f7a6e5c8b2d9f1a4e7c3b6d8f2a5e9c1b4d7f3a6e8c2b5d9f1a4"
```

**2. Key Usage (microservice makes request to WCL):**
```php
// Microservice A (EIC) calls WCL
$response = Http::withHeaders([
    'X-WCL-API-Key' => env('WCL_API_KEY'), // Stored in .env
    'X-WCL-Service' => 'eic',
])->get('https://wcl.internal/api/settings/12345/theme_color');
```

**3. Key Verification (WCL receives request):**
```php
class WclAuthMiddleware {
    public function handle($request, $next) {
        $providedKey = $request->header('X-WCL-API-Key');
        
        if (!$providedKey) {
            return response()->json(['error' => 'Missing API key'], 401);
        }
        
        // Hash the provided key
        $hashedKey = hash('sha256', base64_decode($providedKey));
        
        // Look up in database
        $apiKey = DB::table('wcl_api_keys')
            ->where('key_hash', $hashedKey)
            ->where('is_active', true)
            ->where('expires_at', '>', now())
            ->first();
        
        if (!$apiKey) {
            Log::warning('Invalid API key attempted', [
                'ip' => $request->ip(),
                'service' => $request->header('X-WCL-Service'),
            ]);
            return response()->json(['error' => 'Invalid API key'], 401);
        }
        
        // Attach service identity to request
        $request->attributes->set('authenticated_service', $apiKey->service_name);
        
        // Rate limiting per service
        $this->checkRateLimit($apiKey->service_name);
        
        return $next($request);
    }
    
    private function checkRateLimit($service) {
        $key = "wcl:ratelimit:{$service}";
        $requests = Redis::incr($key);
        
        if ($requests == 1) {
            Redis::expire($key, 60); // 1-minute window
        }
        
        if ($requests > 1000) { // 1000 requests/min limit
            throw new RateLimitExceededException("Service {$service} exceeded 1000 req/min");
        }
    }
}
```

**4. Key Rotation Strategy:**

**Automatic Rotation (every 90 days):**
```php
// Cron job runs daily
Scheduler::daily(function() {
    $keysNearExpiry = DB::table('wcl_api_keys')
        ->where('expires_at', '<', now()->addDays(30))
        ->where('is_active', true)
        ->get();
    
    foreach ($keysNearExpiry as $key) {
        // 1. Generate new key
        $newKey = generateApiKey($key->service_name);
        
        // 2. Email service owner
        Mail::to($key->owner_email)->send(new ApiKeyRotation($newKey, $key->expires_at));
        
        // 3. Keep OLD key active for 30-day grace period (dual keys)
        // This allows service to update without downtime
    }
});

// After 30 days, disable old key
Scheduler::daily(function() {
    DB::table('wcl_api_keys')
        ->where('expires_at', '<', now())
        ->update(['is_active' => false]);
});
```

**Manual Rotation (emergency - key compromised):**
```php
function rotateKeyImmediately($serviceName, $reason) {
    DB::transaction(function() use ($serviceName, $reason) {
        // 1. Revoke ALL keys for service
        DB::table('wcl_api_keys')
            ->where('service_name', $serviceName)
            ->update(['is_active' => false, 'revoked_reason' => $reason]);
        
        // 2. Generate new key
        $newKey = generateApiKey($serviceName);
        
        // 3. Alert service owner (critical!)
        PagerDuty::trigger("API key rotated for {$serviceName}. Update immediately: {$newKey}");
        
        // 4. Log incident
        Log::critical("Emergency key rotation", [
            'service' => $serviceName,
            'reason' => $reason,
        ]);
    });
}
```

**Security Best Practices:**

**1. Never log full keys:**
```php
// BAD:
Log::info("Request from key: {$apiKey}");

// GOOD:
Log::info("Request from key: {$keyPrefix}***"); // wkl_live_a8f3e9c2***
```

**2. Encrypt keys at rest:**
```php
// In .env file, keys are encrypted
WCL_API_KEY=encrypted:AES256:a8f3e9c2b1d4f7a6e5c8b2d9f1a4e7c3

// Application decrypts on boot
$apiKey = decrypt(env('WCL_API_KEY'));
```

**3. Separate keys per environment:**
```
dev: wkl_dev_...
stage: wkl_stage_...
prod: wkl_live_...
```

**Benefits:**
- Each service isolated (compromised key affects 1 service, not all)
- Auditability (know which service made which call)
- Revocable (disable misbehaving service)
- Rate limiting per service

---

## 5. Managed Pay (MPay)

### Q5.1: How do you ensure idempotency to prevent duplicate charges? Walk through the implementation.

**Answer:**

**Problem:**
Network timeout → Customer retries payment → Charged twice.

**Solution: Idempotency Keys**

**Flow:**

**1. Client generates idempotency key (before first request):**
```javascript
// Frontend (EIC or CC)
const idempotencyKey = `payment_${customerId}_${invoiceId}_${Date.now()}`;

axios.post('/api/mpay/create-autopay', {
    customer_id: 12345,
    invoice_id: 67890,
    amount: 500.00,
    payment_account_id: 789,
}, {
    headers: {
        'X-Idempotency-Key': idempotencyKey,
    },
});
```

**2. MPay receives request and checks idempotency:**
```php
class IdempotencyMiddleware {
    public function handle($request, $next) {
        $idempotencyKey = $request->header('X-Idempotency-Key');
        
        if (!$idempotencyKey) {
            return response()->json(['error' => 'Idempotency key required'], 400);
        }
        
        // Check if we've seen this key before
        $cached = Redis::get("idempotency:{$idempotencyKey}");
        
        if ($cached) {
            // Return cached response (duplicate request detected)
            Log::info("Duplicate request detected", ['key' => $idempotencyKey]);
            
            return response()->json(json_decode($cached, true), 200);
        }
        
        // Lock the key (prevent race condition)
        $lock = Redis::lock("idempotency:lock:{$idempotencyKey}", 30);
        
        if (!$lock->get()) {
            // Another request with same key is processing
            return response()->json(['error' => 'Duplicate request in progress'], 409);
        }
        
        try {
            // Process request
            $response = $next($request);
            
            // Cache the response for 24 hours
            Redis::setex(
                "idempotency:{$idempotencyKey}",
                86400,
                json_encode($response->getData())
            );
            
            return $response;
        } finally {
            $lock->release();
        }
    }
}
```

**3. AutoPay creation (with database idempotency check):**
```php
function createAutoPay($customerId, $invoiceId, $amount, $paymentAccountId, $idempotencyKey) {
    // Double-check in database (Redis could be flushed)
    $existing = DB::table('mpay_autopay_configs')
        ->where('idempotency_key', $idempotencyKey)
        ->first();
    
    if ($existing) {
        // Already processed
        return ['status' => 'duplicate', 'autopay_id' => $existing->id];
    }
    
    // Create AutoPay
    $autopayId = DB::table('mpay_autopay_configs')->insertGetId([
        'customer_id' => $customerId,
        'invoice_id' => $invoiceId,
        'amount' => $amount,
        'payment_account_id' => $paymentAccountId,
        'idempotency_key' => $idempotencyKey, // Store for future checks
        'status' => 'pending',
        'created_at' => now(),
    ]);
    
    // Process payment
    $result = processPayment($paymentAccountId, $amount, $invoiceId);
    
    // Update status
    DB::table('mpay_autopay_configs')
        ->where('id', $autopayId)
        ->update(['status' => $result['status']]);
    
    return ['status' => 'success', 'autopay_id' => $autopayId];
}
```

**4. Actual payment processing (also idempotent):**
```php
function processPayment($paymentAccountId, $amount, $invoiceId) {
    // Payment gateway call with idempotency
    $paymentGatewayKey = "pay_{$paymentAccountId}_{$invoiceId}_{$amount}";
    
    $response = Http::post('https://payment-gateway.com/charge', [
        'account_id' => $paymentAccountId,
        'amount' => $amount,
        'idempotency_key' => $paymentGatewayKey, // Gateway also supports idempotency
    ]);
    
    if ($response['status'] == 'duplicate') {
        // Gateway already processed this
        return ['status' => 'completed', 'transaction_id' => $response['original_transaction_id']];
    }
    
    return ['status' => 'completed', 'transaction_id' => $response['transaction_id']];
}
```

**Example Scenarios:**

**Scenario 1: Normal flow**
```
Request 1: idempotency-key-123 → Process → Success → Cache response
```

**Scenario 2: Duplicate request (network retry)**
```
Request 1: idempotency-key-123 → Processing...
Request 2: idempotency-key-123 → Redis lock acquired by Request 1 → Return 409 Conflict
Request 1: Completes → Cache response
Request 3: idempotency-key-123 → Return cached response from Request 1
```

**Scenario 3: Redis flush (cache lost)**
```
Request 1: idempotency-key-123 → Success → Cached in Redis
Redis flush (all cache lost)
Request 2: idempotency-key-123 → Redis cache miss → Check database → Find existing record → Return duplicate
```

**Key Design Decisions:**

**1. Idempotency key format:**
```
payment_{customer_id}_{invoice_id}_{timestamp}
```
- Must be unique per intent
- Same invoice paid by same customer → Different timestamp → Different key

**2. TTL (Time To Live):**
- Redis cache: 24 hours (long enough for retries)
- Database: Forever (permanent audit trail)

**3. Response caching:**
- Cache entire response (not just success/failure)
- Includes transaction ID, timestamps, etc.

**Result: 80% dispute reduction**
- Before: Customers charged twice → Dispute → Refund manually
- After: Duplicate charges prevented → No disputes

---

## 6. Account Management API (AMAPI)

### Q6.1: How do you achieve <100ms response time for 50,000 accounts/month? What's the caching strategy?

**Answer:**

**Challenge:**
Bulk enrollment API called frequently → Must be fast even at scale.

**Optimization Strategies:**

**1. Redis Caching (Duplicate Detection):**

**Problem:** Check if account already exists (expensive DB query).

```php
// SLOW (100-200ms):
$exists = DB::table('fsi_accounts')
    ->where('email', $email)
    ->exists(); // Full table scan if no index
```

**Solution: Redis Bloom Filter**
```php
// FAST (<5ms):
function accountExists($email) {
    // Bloom filter: Probabilistic data structure
    // False positive possible, false negative impossible
    $bloomKey = 'accounts:bloom';
    
    $mightExist = Redis::command('BF.EXISTS', [$bloomKey, $email]);
    
    if (!$mightExist) {
        // Definitely doesn't exist
        return false;
    }
    
    // Might exist → Confirm with DB (only on potential match)
    return DB::table('fsi_accounts')->where('email', $email)->exists();
}

// When account created:
function createAccount($email, $name, $customerId) {
    $accountId = DB::table('fsi_accounts')->insertGetId([...]);
    
    // Add to Bloom filter
    Redis::command('BF.ADD', ['accounts:bloom', $email]);
    
    return $accountId;
}
```

**Result:**
- 95% of checks return in <5ms (Bloom filter)
- 5% confirm with DB in ~20ms
- **Average: ~8ms** (vs 100ms before)

**2. Database Indexing:**
```sql
-- Email index (critical!)
CREATE INDEX idx_email ON fsi_accounts(email);

-- Composite index for common query
CREATE INDEX idx_customer_email ON fsi_accounts(customer_id, email);

-- Result: 100ms → 5ms query time
```

**3. Batch Processing (for bulk operations):**
```php
// BAD (N queries):
foreach ($users as $user) {
    DB::table('fsi_accounts')->insert([
        'email' => $user['email'],
        'customer_id' => $user['customer_id'],
    ]); // 1000 users = 1000 INSERT queries = 10+ seconds
}

// GOOD (1 query):
$records = [];
foreach ($users as $user) {
    $records[] = [
        'email' => $user['email'],
        'customer_id' => $user['customer_id'],
        'created_at' => now(),
    ];
}

DB::table('fsi_accounts')->insert($records); // 1 INSERT with 1000 rows = 200ms
```

**4. Connection Pooling (via WCL):**
```php
// Reuse DB connection across requests
$conn = WCL::getConnection('stack1', $customerId);
// No connection overhead (50ms saved)
```

**5. Async Processing (for non-critical tasks):**
```php
function createAccount($email, $name, $customerId) {
    // 1. Create account synchronously (must return ID immediately)
    $accountId = DB::table('fsi_accounts')->insertGetId([...]);
    
    // 2. Send welcome email asynchronously (don't block response)
    dispatch(new SendWelcomeEmail($accountId, $email))->onQueue('emails');
    
    // 3. Return immediately
    return $accountId; // <100ms response
}

// Email sent in background (doesn't affect response time)
class SendWelcomeEmail {
    public function handle() {
        Mail::to($this->email)->send(new WelcomeEmail());
    }
}
```

**6. Response Compression:**
```php
// Gzip response (reduce transfer time)
return response()->json($data, 200, [
    'Content-Encoding' => 'gzip',
]); // 500KB → 50KB response
```

**Performance Breakdown:**

| Operation | Before | After | Optimization |
|---|---|---|---|
| Duplicate check | 100ms | 5ms | Bloom filter |
| Account insert | 50ms | 10ms | Batch insert |
| DB connection | 50ms | 1ms | Connection pooling |
| Email sending | 200ms | 0ms (async) | Background queue |
| Response transfer | 50ms | 10ms | Gzip compression |
| **Total** | **450ms** | **26ms** | **17x faster** |

**Result: <100ms P95 latency** (avg ~30ms)

---

## 7. Multi-Domain Whitelabel Platform

### Q7.1: How is the dynamic RBAC (role-based access control) implemented? How do custom role names work?

**Answer:**

**Challenge:**
Different customers want different role names:
- School: "Teacher" / "Student"
- Gym: "Trainer" / "Member"
- Hospital: "Doctor" / "Patient"

**Solution: Permission-Based RBAC (not hardcoded roles)**

**Database Schema:**

```sql
-- 1. Permissions (fixed - what CAN be done)
CREATE TABLE rbac_permissions (
    permission_id INT PRIMARY KEY,
    permission_key VARCHAR(100) UNIQUE, -- 'create_content', 'view_content', 'delete_users'
    description TEXT
);

-- 2. Roles (dynamic - customer-defined names)
CREATE TABLE rbac_roles (
    role_id INT PRIMARY KEY,
    customer_id INT, -- Each customer has own roles
    role_name VARCHAR(100), -- Customer chooses name: "Teacher", "Trainer", etc.
    role_key VARCHAR(100), -- Internal: 'instructor', 'learner'
    created_at TIMESTAMP,
    UNIQUE(customer_id, role_key) -- Prevent duplicate roles per customer
);

-- 3. Role-Permission Mapping
CREATE TABLE rbac_role_permissions (
    role_id INT,
    permission_id INT,
    PRIMARY KEY (role_id, permission_id)
);

-- 4. User-Role Assignment
CREATE TABLE rbac_user_roles (
    user_id INT,
    role_id INT,
    customer_id INT,
    PRIMARY KEY (user_id, customer_id)
);
```

**Implementation:**

**1. Customer sets up roles (admin portal):**
```php
function createCustomRole($customerId, $roleName, $roleKey, $permissions) {
    // 1. Create role
    $roleId = DB::table('rbac_roles')->insertGetId([
        'customer_id' => $customerId,
        'role_name' => $roleName, // "Yoga Instructor"
        'role_key' => $roleKey,   // 'instructor' (internal mapping)
        'created_at' => now(),
    ]);
    
    // 2. Assign permissions
    $permissionRecords = [];
    foreach ($permissions as $permissionKey) {
        $permissionId = DB::table('rbac_permissions')
            ->where('permission_key', $permissionKey)
            ->value('permission_id');
        
        $permissionRecords[] = [
            'role_id' => $roleId,
            'permission_id' => $permissionId,
        ];
    }
    
    DB::table('rbac_role_permissions')->insert($permissionRecords);
    
    return $roleId;
}

// Example usage:
createCustomRole(
    customerId: 123,
    roleName: "Yoga Instructor", // Customer-facing name
    roleKey: "instructor",       // Maps to template
    permissions: ['create_content', 'edit_content', 'view_students']
);

createCustomRole(
    customerId: 456,
    roleName: "Personal Trainer", // Different customer, different name
    roleKey: "instructor",         // Same internal key!
    permissions: ['create_content', 'edit_content', 'view_students']
);
```

**2. Permission check (at runtime):**
```php
class RbacMiddleware {
    public function handle($request, $next, $requiredPermission) {
        $user = $request->user();
        
        // 1. Get user's role
        $role = DB::table('rbac_user_roles')
            ->join('rbac_roles', 'rbac_user_roles.role_id', '=', 'rbac_roles.role_id')
            ->where('rbac_user_roles.user_id', $user->id)
            ->where('rbac_user_roles.customer_id', $user->customer_id)
            ->first();
        
        if (!$role) {
            return response()->json(['error' => 'No role assigned'], 403);
        }
        
        // 2. Check if role has required permission
        $hasPermission = DB::table('rbac_role_permissions')
            ->join('rbac_permissions', 'rbac_role_permissions.permission_id', '=', 'rbac_permissions.permission_id')
            ->where('rbac_role_permissions.role_id', $role->role_id)
            ->where('rbac_permissions.permission_key', $requiredPermission)
            ->exists();
        
        if (!$hasPermission) {
            Log::warning("Permission denied", [
                'user' => $user->id,
                'role' => $role->role_name, // "Yoga Instructor"
                'permission' => $requiredPermission,
            ]);
            
            return response()->json(['error' => 'Insufficient permissions'], 403);
        }
        
        return $next($request);
    }
}

// Route usage:
Route::post('/content/create', [ContentController::class, 'create'])
    ->middleware('rbac:create_content'); // Check permission
```

**3. UI Customization (shows custom role name):**
```php
function getDashboard($user) {
    $role = $user->getRole();
    
    return view('dashboard', [
        'role_name' => $role->role_name, // "Yoga Instructor" (not "instructor")
        'permissions' => $role->getPermissions(),
    ]);
}
```

**Example for 3 Customers:**

| Customer | Role Key | Customer's Name | Permissions |
|---|---|---|---|
| Yoga Studio | `instructor` | "Yoga Instructor" | create_content, view_students |
| Gym | `instructor` | "Personal Trainer" | create_content, view_students |
| School | `instructor` | "Teacher" | create_content, view_students, grade_assignments |

**Benefits:**
- **Flexibility:** Customer chooses role name
- **Consistency:** Permissions are standardized
- **Scalability:** Add new permission without changing code
- **Auditability:** Know exactly what each role can do

**Caching:**
```php
// Cache permissions per user (avoid DB hit on every request)
$permissions = Cache::remember("user:{$userId}:permissions", 3600, function() use ($userId) {
    return getUserPermissions($userId);
});
```

---

## 8. Incident Remediation & RCA Tracker

### Q8.1: How do you handle 100+ features across 1000+ customers? What's the data model for tracking issues?

**Answer:**

**Challenge:**
- 100 features × 1000 customers = 100,000 possible combinations
- Need to track which customer has which issue on which feature

**Database Schema:**

```sql
-- 1. Features (the 100+ features)
CREATE TABLE features (
    feature_id INT PRIMARY KEY,
    feature_key VARCHAR(100) UNIQUE, -- 'invoice_pdf', 'autopay', 'email_notifications'
    feature_name VARCHAR(255),       -- Display name
    owning_team VARCHAR(100),        -- 'billing_team', 'payments_team'
    created_at TIMESTAMP
);

-- 2. Customers (the 1000+ customers)
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(255),
    tier VARCHAR(50), -- 'enterprise', 'standard', 'free'
    created_at TIMESTAMP
);

-- 3. Incidents (the actual issues)
CREATE TABLE incidents (
    incident_id INT PRIMARY KEY AUTO_INCREMENT,
    incident_key VARCHAR(50) UNIQUE, -- 'INC-2026-11-16-001'
    feature_id INT,                  -- Which feature is broken
    customer_id INT,                 -- Which customer reported it
    severity ENUM('critical', 'high', 'medium', 'low'),
    category ENUM('data_issue', 'settings_issue', 'edge_case', 'dependency'),
    title VARCHAR(500),
    description TEXT,
    root_cause TEXT,                 -- Filled after triage
    slo_deadline TIMESTAMP,          -- When must be fixed (based on severity)
    status ENUM('new', 'triaging', 'rca_found', 'fixing', 'testing', 'deployed', 'closed'),
    assignee_id INT,
    reporter_id INT,
    created_at TIMESTAMP,
    resolved_at TIMESTAMP,
    INDEX (feature_id, customer_id),
    INDEX (severity, status),
    INDEX (slo_deadline)
);

-- 4. Release Notes (tracking what was fixed when)
CREATE TABLE release_notes (
    release_id INT PRIMARY KEY,
    release_version VARCHAR(50),     -- 'v2.5.3'
    release_date DATE,
    notes TEXT
);

-- 5. Incident-Release Mapping
CREATE TABLE incident_releases (
    incident_id INT,
    release_id INT,
    PRIMARY KEY (incident_id, release_id)
);

-- 6. RCA Search Index (for finding similar issues)
CREATE TABLE rca_search_index (
    incident_id INT,
    search_tokens TEXT, -- Tokenized version of RCA for full-text search
    FULLTEXT(search_tokens)
);
```

**Key Workflows:**

**1. Creating Incident:**
```php
function createIncident($featureKey, $customerId, $severity, $title, $description, $category) {
    // 1. Generate incident key
    $incidentKey = 'INC-' . date('Y-m-d') . '-' . str_pad(getNextIncidentNumber(), 3, '0', STR_PAD_LEFT);
    
    // 2. Calculate SLO deadline based on severity
    $sloDeadlines = [
        'critical' => now()->addHours(4),   // 4 hours
        'high'     => now()->addHours(24),  // 1 day
        'medium'   => now()->addDays(7),    // 1 week
        'low'      => now()->addDays(30),   // 1 month
    ];
    
    // 3. Auto-assign based on feature ownership
    $feature = DB::table('features')->where('feature_key', $featureKey)->first();
    $assignee = getTeamLead($feature->owning_team);
    
    // 4. Insert incident
    $incidentId = DB::table('incidents')->insertGetId([
        'incident_key' => $incidentKey,
        'feature_id' => $feature->feature_id,
        'customer_id' => $customerId,
        'severity' => $severity,
        'category' => $category,
        'title' => $title,
        'description' => $description,
        'slo_deadline' => $sloDeadlines[$severity],
        'status' => 'new',
        'assignee_id' => $assignee->id,
        'reporter_id' => auth()->id(),
        'created_at' => now(),
    ]);
    
    // 5. Alert assignee
    notify($assignee)->about(new IncidentAssigned($incidentId, $severity));
    
    return $incidentId;
}
```

**2. Finding Similar Past Incidents (historical RCA search):**
```php
function findSimilarIncidents($currentIncidentId) {
    $incident = DB::table('incidents')->find($currentIncidentId);
    
    // 1. Search by feature + category (exact match)
    $exactMatches = DB::table('incidents')
        ->where('feature_id', $incident->feature_id)
        ->where('category', $incident->category)
        ->where('status', 'closed')
        ->where('root_cause', '!=', null)
        ->get();
    
    // 2. Full-text search on RCA (fuzzy match)
    $keywords = extractKeywords($incident->description);
    $fuzzyMatches = DB::table('incidents')
        ->join('rca_search_index', 'incidents.incident_id', '=', 'rca_search_index.incident_id')
        ->whereRaw("MATCH(search_tokens) AGAINST(? IN BOOLEAN MODE)", [implode(' ', $keywords)])
        ->where('incidents.status', 'closed')
        ->get();
    
    return [
        'exact_matches' => $exactMatches,
        'fuzzy_matches' => $fuzzyMatches,
    ];
}

// Example usage:
$similar = findSimilarIncidents(INC-2026-11-16-001);
// Returns:
// - 3 exact matches: Same feature (autopay) + category (edge_case)
// - 7 fuzzy matches: Similar keywords in RCA ("threshold", "decimal", "rounding")
```

**3. SLO Monitoring (alerts for missed deadlines):**
```php
// Cron runs every hour
Scheduler::hourly(function() {
    $overdueCritical = DB::table('incidents')
        ->where('severity', 'critical')
        ->where('slo_deadline', '<', now())
        ->where('status', '!=', 'closed')
        ->get();
    
    foreach ($overdueCritical as $incident) {
        // Page on-call engineer
        PagerDuty::trigger("Critical incident {$incident->incident_key} SLO MISSED", [
            'incident_id' => $incident->incident_id,
            'customer' => $incident->customer_id,
            'overdue_by' => now()->diffInHours($incident->slo_deadline),
        ]);
        
        // Escalate to manager
        notify($incident->assignee->manager)->about(new SloMissed($incident));
    }
});
```

**4. Categorization (Critical/High/Medium/Low):**
```php
function calculateSeverity($customerId, $featureKey, $impactedUsers) {
    $customer = DB::table('customers')->find($customerId);
    
    // Auto-calculate severity based on:
    // 1. Customer tier
    // 2. Feature criticality
    // 3. Number of users impacted
    
    if ($customer->tier == 'enterprise' && $impactedUsers > 100) {
        return 'critical'; // Enterprise customer, many users
    }
    
    if (in_array($featureKey, ['payment_processing', 'invoice_generation'])) {
        return 'high'; // Critical feature regardless of customer
    }
    
    if ($impactedUsers > 50) {
        return 'medium'; // Moderate user impact
    }
    
    return 'low';
}
```

**5. Release Notes Generation:**
```php
function generateReleaseNotes($releaseVersion, $releaseDate) {
    // Find all incidents fixed in this release
    $incidents = DB::table('incidents')
        ->join('incident_releases', 'incidents.incident_id', '=', 'incident_releases.incident_id')
        ->join('releases', 'incident_releases.release_id', '=', 'releases.release_id')
        ->where('releases.release_version', $releaseVersion)
        ->get();
    
    $notes = "## Release {$releaseVersion} - {$releaseDate}\n\n";
    
    foreach (['critical', 'high', 'medium', 'low'] as $severity) {
        $filtered = $incidents->where('severity', $severity);
        
        if ($filtered->count() > 0) {
            $notes .= "### {$severity} Fixes\n";
            
            foreach ($filtered as $incident) {
                $notes .= "- **{$incident->incident_key}**: {$incident->title}\n";
            }
            
            $notes .= "\n";
        }
    }
    
    return $notes;
}

// Output:
// ## Release v2.5.3 - 2026-11-16
//
// ### Critical Fixes
// - **INC-2026-11-15-001**: Payment processing timeout for enterprise customers
//
// ### High Fixes
// - **INC-2026-11-14-003**: AutoPay threshold not applying correctly
// - **INC-2026-11-13-007**: Email notifications delayed by 24 hours
```

**Scale Management:**
- **100 features** → Indexed by `feature_id`
- **1000 customers** → Indexed by `customer_id`
- **10,000+ incidents** → Full-text search on RCA
- **Query performance:** <100ms (indexed lookups)

---

## 9. Cross-Project Architecture Questions

### Q9.1: Explain the microservices communication pattern. How do EIC, CC, CSR, WCL, and MPay talk to each other?

**Answer:**

**Architecture Overview:**

```
┌─────────┐     ┌─────────┐     ┌─────────┐
│   EIC   │     │   CC    │     │  AMAPI  │
│(Customer│     │(Supplier│     │  (Bulk  │
│ Portal) │     │ Portal) │     │ Enroll) │
└────┬────┘     └────┬────┘     └────┬────┘
     │               │               │
     ├───────────────┼───────────────┤
     │               │               │
     ▼               ▼               ▼
┌────────────────────────────────────────┐
│          WCL (Web Communication Layer) │
│  - Customer settings                   │
│  - DB connections (Stack1/Stack2)      │
│  - Encrypted auth                      │
└────────────────────────────────────────┘
     │               │               │
     ▼               ▼               ▼
┌─────────┐     ┌─────────┐     ┌─────────┐
│   CSR   │     │  MPay   │     │ MySQL   │
│(Settings│     │(AutoPay │     │Stack1/2 │
│  Repo)  │     │ Service)│     │         │
└─────────┘     └─────────┘     └─────────┘
```

**Communication Patterns:**

**1. Synchronous REST API (most common):**
```php
// EIC needs customer theme color from CSR
$response = Http::withHeaders([
    'X-WCL-API-Key' => env('WCL_API_KEY'),
    'X-Service-Name' => 'eic',
])->get('https://wcl.internal/api/settings/12345/theme_color');

$themeColor = $response->json()['value'];
```

**2. Service-to-Service via WCL (settings lookup):**
```php
// All apps go through WCL for settings (not direct to CSR)
// Why? WCL caches + provides consistent interface

// EIC → WCL → CSR
$settings = WCL::getSettings($customerId, ['theme_color', 'language', 'logo_url']);

// Behind the scenes, WCL:
// 1. Checks Redis cache
// 2. If miss, calls CSR REST API
// 3. Caches result
// 4. Returns to EIC
```

**3. Event-Driven (asynchronous):**
```php
// When MPay config changes, notify EIC and CC
class MPayConfigUpdated implements ShouldQueue {
    public function handle() {
        // Publish event to Redis pub/sub
        Redis::publish('mpay:config:updated', json_encode([
            'customer_id' => $this->customerId,
            'mpay_enabled' => $this->enabled,
        ]));
    }
}

// EIC subscribes to events
Redis::subscribe(['mpay:config:updated'], function ($message) {
    $data = json_decode($message, true);
    
    // Invalidate local cache
    Cache::forget("mpay:status:{$data['customer_id']}");
});
```

**4. Database Sharing (avoided!):**
```
❌ BAD: EIC reads directly from MPay's database table
✅ GOOD: EIC calls MPay REST API
```
**Why?** Each service owns its data. Direct DB access creates tight coupling.

**Communication Matrix:**

| From → To | Protocol | Purpose | Example |
|---|---|---|---|
| EIC → WCL | REST (sync) | Get settings, DB connection | `GET /api/settings/:id/:key` |
| CC → WCL | REST (sync) | Get settings, DB connection | `GET /api/settings/:id/:key` |
| CC → AMAPI | REST (sync) | Bulk enroll users | `POST /api/bulk-enroll` |
| CC → MPay | REST (sync) | Enable MPay for customer | `POST /api/mpay/enable` |
| EIC → MPay | REST (sync) | Activate AutoPay | `POST /api/mpay/activate` |
| MPay → EIC | Event (async) | Notify payment completed | Redis pub/sub |
| CSR → All | Event (async) | Notify setting changed | Redis pub/sub |
| All → CSR | None | Settings managed via WCL | — |

**Failure Handling:**

**1. Circuit Breaker (prevent cascade failure):**
```php
class WclClient {
    private $circuitBreaker;
    
    public function getSettings($customerId, $keys) {
        if ($this->circuitBreaker->isOpen()) {
            // WCL is down, return cached/default values
            return $this->getFallbackSettings($keys);
        }
        
        try {
            $response = Http::timeout(5)->get("https://wcl.internal/api/settings/{$customerId}");
            
            $this->circuitBreaker->recordSuccess();
            return $response->json();
        } catch (TimeoutException $e) {
            $this->circuitBreaker->recordFailure();
            
            if ($this->circuitBreaker->shouldOpen()) {
                // Too many failures, open circuit
                $this->circuitBreaker->open();
            }
            
            return $this->getFallbackSettings($keys);
        }
    }
    
    private function getFallbackSettings($keys) {
        // Return default values when WCL down
        return [
            'theme_color' => '#0000FF',
            'language' => 'en',
            'logo_url' => '/default-logo.png',
        ];
    }
}
```

**2. Retry with Exponential Backoff:**
```php
$response = retry(3, function () use ($customerId) {
    return Http::timeout(5)->get("https://wcl.internal/api/settings/{$customerId}");
}, 100); // Wait 100ms, then 200ms, then 400ms between retries
```

**3. Timeout (don't wait forever):**
```php
// All service calls have 5-second timeout
Http::timeout(5)->get(...);

// If WCL takes >5s, fail fast and use fallback
```

**Service Discovery (how services find each other):**
```
# .env file (each service)
WCL_URL=https://wcl.internal
CSR_URL=https://csr.internal
MPAY_URL=https://mpay.internal

# In production, use DNS or service mesh (e.g., Kubernetes Service)
```

**Monitoring:**
```php
// Track inter-service calls
Datadog::increment('service.call', 1, [
    'from' => 'eic',
    'to' => 'wcl',
    'endpoint' => '/api/settings',
    'status' => $response->status(),
]);
```

---

### Q9.2: How would you design a new microservice? Walk through your decision-making process.

**Answer:**

**Scenario:** Need to build a "Notification Preferences" service (users control which emails/SMS they receive).

**Decision Framework:**

**1. Should this be a microservice or part of existing service?**

**Microservice criteria (YES if 2+ are true):**
- ✅ **Independent domain:** Notification preferences are separate from payments/billing
- ✅ **Different scaling needs:** Notifications scale with user actions (high read/write), not invoices
- ✅ **Independent deployment:** Can deploy notification changes without touching billing code
- ✅ **Team ownership:** Could have dedicated team managing notifications
- ❌ **Data isolation:** Could share `users` table with EIC
- ✅ **Technology choice:** Might want different stack (Node.js for real-time?)

**Decision: YES, build as microservice**

**2. What data does it own?**

**Tables owned by Notification Preferences service:**
```sql
-- This service owns:
CREATE TABLE notification_preferences (
    user_id INT,
    channel ENUM('email', 'sms', 'push'),
    preference_key VARCHAR(100), -- 'invoice_arrival', 'payment_reminder'
    enabled BOOLEAN,
    PRIMARY KEY (user_id, channel, preference_key)
);

-- NOT owned by this service (owned by EIC):
users (user_id, email, name) ← Don't duplicate!
```

**3. API Design:**

**REST endpoints:**
```
GET    /api/v1/preferences/:user_id
POST   /api/v1/preferences/:user_id
PUT    /api/v1/preferences/:user_id/:key
DELETE /api/v1/preferences/:user_id/:key

# Examples:
GET /api/v1/preferences/12345
→ { "email": { "invoice_arrival": true, "payment_reminder": false }, ... }

PUT /api/v1/preferences/12345/invoice_arrival
{ "channel": "email", "enabled": false }
→ 200 OK
```

**4. How does it integrate with existing services?**

**Integration points:**

**A. EIC calls Notification Preferences:**
```php
// When user updates preferences in EIC portal
function updateEmailPreference($userId, $preference, $enabled) {
    // EIC → Notification Preferences service
    $response = Http::put("https://notif-prefs.internal/api/v1/preferences/{$userId}/{$preference}", [
        'channel' => 'email',
        'enabled' => $enabled,
    ]);
    
    // Invalidate WCL cache
    WCL::invalidateCache("user:{$userId}:prefs");
}
```

**B. WCL (or other services) check preferences before sending:**
```php
// Before sending email, check if user wants it
function shouldSendEmail($userId, $emailType) {
    // Check via WCL (cached)
    $prefs = WCL::getSettings($userId, ['notification_prefs']);
    
    return $prefs['notification_prefs'][$emailType] ?? true; // Default: enabled
}

if (shouldSendEmail($userId, 'invoice_arrival')) {
    sendEmail($userId, 'invoice_arrival', $invoiceData);
}
```

**C. Event-driven updates:**
```php
// When preference changes, notify other services
Redis::publish('user:prefs:updated', json_encode([
    'user_id' => $userId,
    'preference' => $preference,
    'enabled' => $enabled,
]));

// WCL subscribes and invalidates cache
```

**5. Tech Stack Decision:**

| Concern | Decision | Reasoning |
|---|---|---|
| Language | **PHP** (Laravel) | Consistency with EIC/CC/CSR |
| Database | **MySQL** | Small data, ACID needed |
| Cache | **Redis** | Consistency with other services |
| Deployment | **Kubernetes** | Same infrastructure |
| Auth | **WCL API keys** | Reuse existing auth |

**Alternative considered:**
- Node.js for real-time → Rejected (adds complexity, PHP is fast enough)

**6. Performance Requirements:**

**SLA:**
- **Latency:** <100ms P95 (non-blocking)
- **Availability:** 99.5% (less critical than payments)
- **Throughput:** 1000 req/sec peak

**How to achieve:**
- Redis caching (preferences change rarely)
- Read replicas (99% reads, 1% writes)
- Async writes (eventual consistency OK)

**7. Failure Modes:**

**Q: What if Notification Preferences service is down?**

**A: Default to "allow" (send notifications):**
```php
try {
    $allowed = Http::timeout(2)->get("https://notif-prefs.internal/api/v1/check/{$userId}/{$type}");
    return $allowed->json()['enabled'];
} catch (Exception $e) {
    // Service down → Fail open (send notification)
    Log::warning("Notif Prefs service down, defaulting to allow");
    return true;
}
```

**Why fail open?**
- Missing a notification is worse than getting unwanted one
- User can unsubscribe via email link

**8. Deployment Strategy:**

**Phase 1: Soft Launch (read-only)**
- Deploy service
- Migrate existing preferences from EIC DB
- EIC reads from new service (but still writes to old DB)
- Monitor for discrepancies

**Phase 2: Dual Write**
- EIC writes to BOTH old DB and new service
- Compare writes (ensure consistency)

**Phase 3: Full Cutover**
- EIC stops reading from old DB
- Only reads/writes to new service
- Old table archived (not deleted yet)

**Phase 4: Cleanup**
- After 30 days, drop old table

**9. Monitoring & Alerting:**

**Metrics:**
```php
Datadog::increment('notif_prefs.preference.updated');
Datadog::histogram('notif_prefs.api.latency', $latency);
Datadog::gauge('notif_prefs.db.connections', $dbConnections);
```

**Alerts:**
- P95 latency >200ms for 5 minutes → Page on-call
- Error rate >1% for 10 minutes → Page on-call
- 5xx errors → Slack #engineering

**10. Documentation:**

**What to document:**
- API spec (OpenAPI/Swagger)
- Data model (ERD)
- Integration guide (how to call from EIC/CC)
- Runbook (how to debug issues)

---

## 10. Performance & Scalability

### Q10.1: One of your APIs is slow (500ms). Walk through your debugging process.

**Answer:**

**Step-by-Step Debug Process:**

**1. Reproduce & Measure (get baseline):**
```bash
# Test API locally
curl -w "@curl-format.txt" https://api.internal/invoices/12345

# curl-format.txt:
# time_total: %{time_total}s
# time_connect: %{time_connect}s
# time_starttransfer: %{time_starttransfer}s

# Output:
# time_total: 0.523s ← Confirmed slow
# time_connect: 0.002s ← Network is fast
# time_starttransfer: 0.520s ← Server processing is slow
```

**2. Check Application Performance Monitoring (Datadog APM):**
```
Datadog → APM → Traces → Filter: /invoices/:id
Sort by: Duration (desc)

Trace breakdown:
├─ Total: 523ms
├─ Middleware: 5ms
├─ Controller: 3ms
├─ Database Queries: 480ms ← BOTTLENECK!
│  ├─ Query 1 (invoices table): 450ms ← Culprit!
│  └─ Query 2 (payments table): 30ms
└─ Response formatting: 35ms
```

**3. Identify Slow Query:**
```php
// Datadog shows this query is slow:
SELECT * FROM fsi_invoices WHERE customer_id = 12345 ORDER BY invoice_date DESC
// 450ms execution time

// Enable MySQL slow query log to confirm:
// /var/log/mysql/slow.log:
# Time: 2026-11-16T10:00:00.000Z
# Query_time: 0.450
SELECT * FROM fsi_invoices WHERE customer_id = 12345 ORDER BY invoice_date DESC;
```

**4. Analyze Query with EXPLAIN:**
```sql
EXPLAIN SELECT * FROM fsi_invoices WHERE customer_id = 12345 ORDER BY invoice_date DESC;

+----+-------------+---------------+------+---------------+------+
| id | select_type | table         | type | possible_keys | key  |
+----+-------------+---------------+------+---------------+------+
|  1 | SIMPLE      | fsi_invoices  | ALL  | NULL          | NULL |
+----+-------------+---------------+------+---------------+------+

# type: ALL ← Full table scan! No index used.
# rows: 5,000,000 ← Scanning 5M rows to find 100 for this customer
```

**5. Root Cause: Missing Index**
```sql
-- Check existing indexes
SHOW INDEX FROM fsi_invoices;

# Result: Only PRIMARY KEY (invoice_id), no index on customer_id!
```

**6. Solution: Add Composite Index**
```sql
-- Create index on (customer_id, invoice_date)
CREATE INDEX idx_customer_date ON fsi_invoices(customer_id, invoice_date DESC);

-- Why composite?
-- 1. Filter by customer_id (WHERE clause)
-- 2. Sort by invoice_date (ORDER BY clause)
-- Index covers both operations → No additional sort needed
```

**7. Test After Index:**
```sql
EXPLAIN SELECT * FROM fsi_invoices WHERE customer_id = 12345 ORDER BY invoice_date DESC;

+----+-------------+---------------+-------+----------------------+---------------------+
| id | select_type | table         | type  | possible_keys        | key                 |
+----+-------------+---------------+-------+----------------------+---------------------+
|  1 | SIMPLE      | fsi_invoices  | range | idx_customer_date    | idx_customer_date   |
+----+-------------+---------------+-------+----------------------+---------------------+

# type: range ← Using index!
# rows: 100 ← Only scanning relevant 100 rows (not 5M)
# Using index ← Covered index (no table access needed)

# New execution time: 8ms (vs 450ms before) → 56x faster!
```

**8. Verify End-to-End Improvement:**
```bash
curl -w "@curl-format.txt" https://api.internal/invoices/12345

# Output:
# time_total: 0.045s ← Down from 523ms! (11.6x faster)
```

**9. Additional Optimizations (if still slow):**

**A. Add Redis Caching:**
```php
function getInvoices($customerId) {
    $cacheKey = "invoices:{$customerId}";
    
    return Cache::remember($cacheKey, 300, function() use ($customerId) {
        return DB::table('fsi_invoices')
            ->where('customer_id', $customerId)
            ->orderBy('invoice_date', 'desc')
            ->get();
    }); // Now: 5ms (cache hit), 45ms (cache miss)
}
```

**B. Pagination (don't return all invoices):**
```php
// Before: Return ALL invoices for customer (could be 1000s)
$invoices = DB::table('fsi_invoices')->where('customer_id', $customerId)->get();

// After: Return 20 per page
$invoices = DB::table('fsi_invoices')
    ->where('customer_id', $customerId)
    ->paginate(20); // Much faster
```

**C. Lazy Loading vs Eager Loading:**
```php
// Before (N+1 problem):
$invoices = Invoice::where('customer_id', $customerId)->get();
foreach ($invoices as $invoice) {
    echo $invoice->customer->name; // Separate query per invoice!
}
// 1 query for invoices + 100 queries for customers = 101 queries

// After (eager loading):
$invoices = Invoice::with('customer')->where('customer_id', $customerId)->get();
foreach ($invoices as $invoice) {
    echo $invoice->customer->name; // Data already loaded
}
// 1 query for invoices + 1 query for customers = 2 queries
```

**10. Document & Monitor:**
```php
// Add monitoring alert
Datadog::histogram('api.invoices.latency', $latency, ['customer_id' => $customerId]);

// Alert if P95 > 100ms
if ($latency > 100) {
    Datadog::event('API slow', "Invoice API took {$latency}ms for customer {$customerId}");
}
```

**Summary of Debug Process:**
1. ✅ Reproduce (curl)
2. ✅ Check APM (Datadog traces)
3. ✅ Identify slow query
4. ✅ Analyze with EXPLAIN
5. ✅ Root cause (missing index)
6. ✅ Fix (add index)
7. ✅ Verify improvement
8. ✅ Consider additional optimizations
9. ✅ Monitor ongoing

**Result: 523ms → 45ms (11.6x faster)**

---

## 11. Security & Compliance

### Q11.1: How do you ensure PCI-DSS compliance when handling payment data?

**Answer:**

**PCI-DSS Requirements We Must Meet:**

**1. Never Store Sensitive Card Data:**

**❌ NEVER store:**
- Full PAN (Primary Account Number / card number)
- CVV/CVC (3-digit security code)
- Track data (magnetic stripe)

**✅ CAN store (if encrypted):**
- Cardholder name
- Expiration date
- Last 4 digits of card (for display)

**Implementation:**
```php
// When customer enters card for AutoPay
function savePaymentMethod($customerId, $cardNumber, $cvv, $expiry, $name) {
    // 1. NEVER store full card number or CVV in our DB
    
    // 2. Send to payment gateway for tokenization
    $response = Http::post('https://payment-gateway.com/tokenize', [
        'card_number' => $cardNumber,     // Send once, never store
        'cvv' => $cvv,                    // Send once, never store
        'expiry' => $expiry,
        'cardholder_name' => $name,
    ]);
    
    $token = $response['token']; // e.g., "tok_a8f3e9c2b1d4"
    
    // 3. Store ONLY the token (not actual card data)
    DB::table('payment_accounts')->insert([
        'customer_id' => $customerId,
        'payment_token' => $token,         // Safe to store
        'last_4_digits' => substr($cardNumber, -4), // For display: "****1234"
        'expiry_month' => substr($expiry, 0, 2),
        'expiry_year' => substr($expiry, 2, 2),
        'cardholder_name' => encrypt($name), // Encrypted
        'created_at' => now(),
    ]);
    
    // 4. Discard actual card number (never logged, never stored)
    unset($cardNumber, $cvv);
    
    return ['token' => $token, 'last_4' => substr($cardNumber, -4)];
}

// When processing payment:
function chargeCard($paymentAccountId, $amount) {
    $account = DB::table('payment_accounts')->find($paymentAccountId);
    
    // Use token (not actual card number)
    $response = Http::post('https://payment-gateway.com/charge', [
        'token' => $account->payment_token, // Gateway knows real card number
        'amount' => $amount,
    ]);
    
    return $response;
}
```

**2. Encrypt Data in Transit (HTTPS everywhere):**
```nginx
# Nginx config
server {
    listen 443 ssl http2;
    
    # TLS 1.2+ only (PCI requirement)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256';
    
    # HSTS (force HTTPS)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Disable weak ciphers
    ssl_prefer_server_ciphers on;
}

# Reject HTTP requests
server {
    listen 80;
    return 301 https://$host$request_uri; # Force redirect to HTTPS
}
```

**3. Encrypt Data at Rest:**
```php
// Laravel automatic encryption for sensitive fields
class PaymentAccount extends Model {
    protected $casts = [
        'cardholder_name' => 'encrypted',  // Auto encrypt/decrypt
        'billing_address' => 'encrypted',
    ];
}

// MySQL database encryption (AWS RDS)
# RDS instance encrypted with KMS key
# All backups also encrypted
# Snapshots encrypted
```

**4. Access Control (who can see payment data):**
```php
// Only specific admins can view payment accounts
Route::get('/payment-accounts/{id}', function($id) {
    // Check permission
    if (!auth()->user()->hasPermission('view_payment_data')) {
        abort(403, 'Insufficient permissions');
    }
    
    // Log access (audit trail)
    DB::table('audit_log')->insert([
        'user_id' => auth()->id(),
        'action' => 'view_payment_account',
        'resource_id' => $id,
        'ip_address' => request()->ip(),
        'timestamp' => now(),
    ]);
    
    // Return masked data (even for admins)
    $account = PaymentAccount::find($id);
    return [
        'last_4' => $account->last_4_digits,  // "1234"
        'expiry' => $account->expiry,         // "12/25"
        'name' => decrypt($account->cardholder_name), // Decrypted on-the-fly
        'token' => null, // NEVER expose token
    ];
});
```

**5. Logging & Monitoring (but NEVER log card data):**
```php
// BAD - logs card number:
Log::info("Processing payment", ['card' => $cardNumber]); // ❌ PCI violation!

// GOOD - logs safe info only:
Log::info("Processing payment", [
    'customer_id' => $customerId,
    'last_4' => $last4,          // Safe to log
    'amount' => $amount,
    'payment_account_id' => $id,
]);

// Scrub logs (ensure no accidental leaks)
function scrubLog($message) {
    // Remove any 16-digit sequences (card numbers)
    $message = preg_replace('/\b\d{13,16}\b/', '****', $message);
    
    // Remove CVV patterns
    $message = preg_replace('/\bcvv[:\s]*\d{3,4}\b/i', 'cvv:***', $message);
    
    return $message;
}
```

**6. Network Segmentation:**
```
Internet
   ↓
[WAF - Web Application Firewall]
   ↓
[Public Subnet: EIC, CC] ← No card data stored here
   ↓
[Private Subnet: MPay] ← Tokenized data only
   ↓
[Payment Gateway (external)] ← Actual card data lives here (PCI Level 1)
```

**7. Quarterly Vulnerability Scans:**
```bash
# Automated scans with approved scanning vendor (ASV)
# - Every 3 months
# - Checks for known vulnerabilities
# - SSL/TLS configuration
# - Open ports
# - Default passwords

# Example findings:
# ✅ PASS: TLS 1.2+ enabled
# ✅ PASS: No default credentials
# ❌ FAIL: Port 22 (SSH) open to public → Must restrict to VPN only
```

**8. Annual PCI Audit (Self-Assessment Questionnaire):**
```
SAQ A-EP (for e-commerce using payment gateway)

✅ Requirement 1: Firewall configured
✅ Requirement 2: Default passwords changed
✅ Requirement 3: Cardholder data encrypted
✅ Requirement 4: Data encrypted in transit (HTTPS)
✅ Requirement 5: Anti-virus installed
✅ Requirement 6: Systems patched
✅ Requirement 7: Access restricted (need-to-know)
✅ Requirement 8: Unique user IDs
✅ Requirement 9: Physical access controlled (AWS datacenter)
✅ Requirement 10: Logs monitored (Datadog)
✅ Requirement 11: Quarterly scans
✅ Requirement 12: Security policy documented

Result: COMPLIANT
```

**9. Incident Response Plan:**
```
IF card data leak suspected:
1. Isolate affected systems (within 1 hour)
2. Notify payment gateway (immediately)
3. Notify affected customers (within 24 hours)
4. Notify card brands (Visa/Mastercard) if >1000 cards
5. Forensic investigation
6. File breach report
```

**10. Developer Training:**
```
# All developers complete PCI training annually:
- Never log card numbers
- Never store CVV
- Always use tokens
- HTTPS everywhere
- Report suspected breaches immediately

# Code review checklist:
✅ No card numbers in logs
✅ No card numbers in database
✅ All payment data encrypted
✅ Access properly restricted
```

**Our PCI Level: SAQ A-EP** (payment page redirects to gateway, but we handle payment data transiently)

**Result: Zero PCI violations since implementation**

---

*This is Part 1 of 2. The guide continues with more Q&A sections...*

**Total Questions So Far: 50+**

Would you like me to continue with the remaining sections:
- Database Design & Optimization (10 questions)
- Leadership & Decision Making (8 questions)  
- Debugging & Production Issues (12 questions)
- Scenario-Based Questions (15 questions)

This will bring the total to **95+ comprehensive interview questions** for 12+ years experience level.
