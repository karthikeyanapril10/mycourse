# Technical Interview Q&A - Quick Reference

## PHP & Laravel

### Q: Explain Laravel's service container and dependency injection
**A:** Laravel's service container is an IoC (Inversion of Control) container that manages class dependencies. Instead of manually creating objects, you type-hint dependencies in constructors and Laravel automatically resolves and injects them. This makes code testable and loosely coupled.

**Example from my work:**
```php
// In CC application - DbFactory injected for multi-tenant DB routing
class CustomerController extends Controller {
    public function __construct(
        protected DbFactory $dbFactory,
        protected CustomerService $service
    ) {}
    
    public function show(int $customerId) {
        $connection = $this->dbFactory->getConnection($customerId);
        return $this->service->find($customerId);
    }
}
```

### Q: How do you prevent SQL injection in PHP?
**A:** Always use parameterized queries, never string concatenation.

**Laravel (Eloquent):**
```php
// GOOD - parameterized
User::where('email', $email)->where('status', $status)->first();
$users = DB::select('SELECT * FROM users WHERE email = ?', [$email]);

// BAD - vulnerable to injection
DB::select("SELECT * FROM users WHERE email = '$email'");
```

**Zend Framework (EIC):**
```php
// GOOD
$select = $db->select()
    ->from('fsiuser')
    ->where('Email = ?', $email)
    ->where('Active = ?', 1);

// BAD
$query = "SELECT * FROM fsiuser WHERE Email = '$email'";
```

### Q: Explain N+1 query problem and how to solve it
**A:** N+1 happens when you fetch N records, then make 1 additional query for each record to fetch related data.

**Problem:**
```php
// Fetches 100 customers, then 100 separate queries for accounts
$customers = Customer::all();
foreach ($customers as $customer) {
    echo $customer->accounts->count(); // N+1!
}
```

**Solution - Eager Loading:**
```php
// Just 2 queries: customers + all their accounts
$customers = Customer::with('accounts')->get();
foreach ($customers as $customer) {
    echo $customer->accounts->count(); // No additional queries
}
```

### Q: How do you handle configuration in a multi-tenant system?
**A:** In our Enterprise SaaS Company system, we use an atom-based pattern:

```php
// Hierarchical settings: System → Customer → Account → User
// Stored in fsicustomersettings table
$setting = DB::selectOne(
    'CALL FindCustSettings(?, ?)',
    [$customerId, 'Path/To/Setting']
);

// Active settings have settingsstatus = 5
// Supports inheritance and overrides
```

---

## Database & SQL

### Q: How do you optimize a slow query?
**A:** My systematic approach:

1. **Get EXPLAIN plan** to see execution strategy
2. **Identify bottlenecks**: full table scans, filesort, temporary tables
3. **Add indexes** on WHERE, JOIN, and ORDER BY columns
4. **Optimize query structure**: 
   - Avoid SELECT *
   - Limit result set early
   - Use covering indexes
   - Consider query refactoring

**Real example:**
```sql
-- SLOW (full table scan on 100M+ rows)
SELECT * FROM fsidocument 
WHERE AccountNumber = '12345' 
AND BillingDate >= '2025-01-01'
ORDER BY BillingDate DESC;

-- FAST (composite index on AccountNumber + BillingDate)
CREATE INDEX idx_account_billing ON fsidocument(AccountNumber, BillingDate);

-- Also limited columns and added LIMIT
SELECT DocumentId, BillingDate, Amount 
FROM fsidocument 
WHERE AccountNumber = '12345' 
AND BillingDate >= '2025-01-01'
ORDER BY BillingDate DESC
LIMIT 100;
```

### Q: Explain ACID properties
**A:** 
- **Atomicity**: Transaction is all-or-nothing (either all changes commit or all rollback)
- **Consistency**: Database moves from one valid state to another (constraints enforced)
- **Isolation**: Concurrent transactions don't interfere with each other
- **Durability**: Committed transactions survive crashes

**Example from DML work:**
```sql
START TRANSACTION;

UPDATE fsiuser 
SET Active = 0, UpdateUser = 'QRT14792', UpdateDate = NOW()
WHERE UserId = 12345;

UPDATE fsiaccount 
SET Status = 'INACTIVE', UpdateDate = NOW()
WHERE UserId = 12345;

-- Either both succeed or both rollback
COMMIT;
```

### Q: How do you design for multi-tenancy?
**A:** Two approaches we use:

**1. Shared Database, Separate Schemas/Tables (not our approach)**
**2. Database Per Tenant (our approach In a production environment)**

```sql
-- billingmaster has tenant-to-database mapping
SELECT StackNum, DBName 
FROM billingmaster.customer 
WHERE CustomerId = 12345;

-- Route to correct database
USE billingclient1;  -- or billingclient2 based on StackNum

-- All queries scoped by CustomerId to prevent cross-tenant leaks
SELECT * FROM fsiaccount 
WHERE CustomerId = 12345  -- ALWAYS filter by tenant
AND AccountNumber = '67890';
```

**Critical safety rule:** EVERY query must filter by CustomerId or PrimaryCustomerId

---

## Security

### Q: Explain OWASP Top 10 and give examples from your work
**A:** 

1. **Broken Access Control** - Prevented by checking user permissions before data access
2. **Cryptographic Failures** - PCI data encrypted at rest, TLS in transit
3. **Injection** - Parameterized queries, input validation
4. **Insecure Design** - Security requirements in design phase, threat modeling
5. **Security Misconfiguration** - Disabled debug in production, secure headers
6. **Vulnerable Components** - Checkmarx SCA scanning, composer audit
7. **Authentication Failures** - Strong password policies, MFA, session management
8. **Software & Data Integrity** - Code signing, verified dependencies
9. **Logging Failures** - Comprehensive audit trails (33 audit tables)
10. **SSRF** - Validate and sanitize URLs before external requests

**Example - Fixing SQL Injection in legacy code:**
```php
// BEFORE (vulnerable)
$query = "SELECT * FROM fsiuser WHERE Email = '" . $_POST['email'] . "'";
$result = mysql_query($query);

// AFTER (secure)
$stmt = $db->prepare("SELECT * FROM fsiuser WHERE Email = ?");
$stmt->bind_param("s", $_POST['email']);
$stmt->execute();
```

### Q: How do you handle PCI and HIPAA compliance?
**A:**

**PCI (Payment Card Industry):**
- Never log full credit card numbers (mask to last 4 digits)
- Never log CVV codes
- Use tokenization for card storage
- Encrypt cardholder data at rest
- Restrict database access via RBAC

**HIPAA (Health Insurance Portability):**
- Never log PHI (Protected Health Information) in application logs
- Encrypt PHI at rest and in transit
- Maintain audit trails of who accessed what data
- Implement BAA (Business Associate Agreements)

**Example from code reviews:**
```php
// BAD - logs full card number
Log::info("Processing payment", ['card' => $cardNumber]);

// GOOD - masks PCI data
Log::info("Processing payment", [
    'card_last4' => substr($cardNumber, -4),
    'customer_id' => $customerId
]);
```

---

## System Design

### Q: Design a multi-tenant SaaS billing platform
**A:** Key components:

**1. Tenant Isolation Layer**
- Database routing based on tenant ID
- Separate connection pools per tenant database
- Query safety middleware to enforce tenant scoping

**2. API Gateway**
- Authentication (JWT with tenant context)
- Rate limiting per tenant
- Request routing to correct service

**3. Microservices Architecture**
- Invoice Service (generate, send, track)
- Payment Service (process, reconcile, retry)
- Customer Service (accounts, users, settings)
- Notification Service (email, SMS, webhooks)

**4. Data Layer**
- Master DB (tenant metadata, routing info)
- Tenant DBs (customer data, invoices, payments)
- Cache layer (Redis for session, settings)
- Audit DB (compliance trails)

**5. Processing Workers**
- Invoice generation queue
- Payment processing with retry logic
- Email sending with failure handling
- Report generation

**6. Monitoring & Observability**
- Splunk for logs (with tenant context)
- Datadog for metrics
- Pendo for usage analytics
- Alerting on failures and SLA breaches

**Scaling considerations:**
- Horizontal scaling of stateless services
- Database sharding (we use 2 stacks, can expand)
- Caching at multiple layers
- Async processing for non-critical paths
- Circuit breakers for external dependencies

---

## Architecture Patterns

### Q: Explain the difference between Account-Centric and User-Centric models
**A:** This is specific to our Enterprise SaaS Company platform:

**Account-Centric (AC):**
- One account = one login
- User record represents the account itself
- Single email, single login
- fsiuser.AccountNumber is populated
- Used by: standalone businesses, small customers

**User-Centric (UC):**
- Multiple users per account
- Users can access multiple accounts
- Parent-child customer relationships
- fsiuser.AccountNumber is NULL
- fsionlineaccount links users to accounts
- Used by: enterprises, managed billing relationships

**Data implications:**
```sql
-- Finding AC customer accounts
SELECT * FROM fsiuser 
WHERE CustomerId = ? AND AccountNumber IS NOT NULL;

-- Finding UC customer accounts  
SELECT u.*, oa.AccountNumber 
FROM fsiuser u
JOIN fsionlineaccount oa ON u.UserId = oa.UserId
WHERE u.CustomerId = ?;
```

### Q: How do you ensure zero-downtime deployments?
**A:** Our strategy:

1. **Database Changes:**
   - Backward-compatible migrations first
   - Deploy code that works with both old and new schema
   - Clean up old schema after code fully deployed

2. **Rolling Deployments:**
   - Update one pod/server at a time
   - Health checks before routing traffic
   - Automatic rollback on failures

3. **Feature Flags:**
   - New features behind flags
   - Gradual rollout to subset of users
   - Quick disable without code deployment

4. **Blue-Green Deployments:**
   - Deploy to green environment
   - Test thoroughly
   - Switch traffic via load balancer
   - Keep blue as instant rollback

---

## Testing

### Q: How do you test a multi-tenant application?
**A:** 

**Unit Tests:**
- Test tenant isolation in data access layer
- Mock tenant context in services
- Verify query scoping

**Integration Tests:**
- Test with multiple tenant contexts
- Verify cross-tenant data leakage prevention
- Test tenant routing logic

**E2E Tests (Cypress/Protractor):**
- Test full user flows for different tenant types
- AC vs UC customer scenarios
- Test permission boundaries

**Example Cypress test:**
```javascript
describe('Multi-tenant isolation', () => {
  it('should only show data for logged-in tenant', () => {
    cy.loginAs('customer1@example.com');
    cy.visit('/accounts');
    cy.get('[data-test=account-row]')
      .should('have.length.greaterThan', 0)
      .each($row => {
        // Verify all accounts belong to customer1
        expect($row).to.contain('Customer1');
      });
  });
});
```

---

## Problem-Solving Scenarios

### Q: A query is timing out in production. Walk me through your debugging process.

**My systematic approach:**

**1. Immediate response (5 min):**
- Check monitoring: error rate, affected users
- Review recent deployments (was this change-related?)
- Quick query EXPLAIN to see obvious issues

**2. Investigation (30 min):**
```sql
-- Capture slow query from logs
-- Run EXPLAIN
EXPLAIN SELECT ... FROM fsidocument WHERE ...;

-- Look for:
-- - type: ALL (full table scan) - BAD
-- - rows: high number scanned
-- - Extra: Using filesort, Using temporary
```

**3. Analysis:**
- Compare table size: `SELECT COUNT(*) FROM table;`
- Check existing indexes: `SHOW INDEX FROM table;`
- Analyze query patterns: Are we filtering on indexed columns?

**4. Solutions (prioritized):**
- **Quick win**: Add LIMIT if appropriate, add index on filter columns
- **Medium term**: Refactor query, denormalize if needed, add covering index
- **Long term**: Partition table, archive old data, cache results

**5. Validation:**
- Test fix in staging with production-scale data
- Monitor metrics after deployment
- Document for future similar issues

**Real example:** Customer report timing out
- Problem: 100M+ row table, no index on date range filter
- Solution: Added composite index on (CustomerId, BillingDate)
- Result: 3-minute query → 2 seconds

---

## Leadership & Communication

### Q: How do you explain technical issues to non-technical stakeholders?

**My dual-audience approach:**

**Technical explanation:**
"The SSO authentication flow failed because EmailValidationController checks `$this->isSSO === 1`, but the property is cast to boolean, making this comparison always false due to PHP's strict type checking."

**Business explanation:**
"When enterprise customers try to log in through their company's single sign-on system, they're being incorrectly redirected to a page that asks them to verify their email—even though SSO already verified it. This creates friction and support tickets. The root cause is a type mismatch in our authentication logic that's blocking valid SSO users."

**Framework:**
1. What the user experiences (the symptom)
2. Why it matters (business impact)
3. What's broken (root cause in plain language)
4. How we'll fix it (solution)
5. What won't be affected (scope containment)

---

Ready to ace your interview! 🚀
