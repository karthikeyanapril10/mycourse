# Code Examples & Practice Challenges

**Hands-On Coding Exercises for Interview Preparation**

**How to Use:**
1. Read the challenge
2. Code the solution FROM SCRATCH (no copy-paste!)
3. Test your code
4. Compare with the provided solution

---

## 📝 **Challenge #1: Implement Idempotency for Payment API**

### **Problem Statement:**

You're building a payment processing API. The same payment request might be sent multiple times due to:
- Network retries
- User impatience (double-clicking "Pay Now")
- Mobile app crashes

**Requirements:**
1. If the same `idempotency_key` is received twice, return the SAME result (don't charge twice)
2. If the first request is still processing, return 409 Conflict
3. If the first request failed, allow retry

**Input:**
```json
POST /api/payments
{
  "idempotency_key": "uuid-1234-5678",
  "amount": 100.00,
  "customer_id": 42
}
```

**Expected Behavior:**
- **First call:** Process payment, return 200 OK
- **Second call (same key):** Return cached result, 200 OK (DO NOT charge again)
- **Third call (while first is processing):** Return 409 Conflict

---

### **Your Turn: Write the Code!**

**Setup (PHP/Laravel):**
```php
// Database table: payment_requests
// Columns: id, idempotency_key, status (PROCESSING|COMPLETED|FAILED), response_data, created_at

class PaymentController extends Controller
{
    public function processPayment(Request $request)
    {
        // YOUR CODE HERE
    }
}
```

**Try it yourself before looking at the solution!**

---

### **Solution:**

```php
class PaymentController extends Controller
{
    public function processPayment(Request $request)
    {
        $idempotencyKey = $request->header('Idempotency-Key');
        $amount = $request->input('amount');
        $customerId = $request->input('customer_id');
        
        // Validate idempotency key
        if (!$idempotencyKey) {
            return response()->json(['error' => 'Idempotency-Key header required'], 400);
        }
        
        // Check for existing request
        $existing = DB::table('payment_requests')
            ->where('idempotency_key', $idempotencyKey)
            ->first();
        
        if ($existing) {
            // Case 1: Still processing
            if ($existing->status === 'PROCESSING') {
                return response()->json([
                    'error' => 'Request already processing',
                    'request_id' => $existing->id
                ], 409);
            }
            
            // Case 2: Completed — return cached result
            if ($existing->status === 'COMPLETED') {
                return response()->json(
                    json_decode($existing->response_data, true),
                    200
                );
            }
            
            // Case 3: Failed — allow retry (delete old record)
            if ($existing->status === 'FAILED') {
                DB::table('payment_requests')->where('id', $existing->id)->delete();
            }
        }
        
        // Create new request record
        $requestId = DB::table('payment_requests')->insertGetId([
            'idempotency_key' => $idempotencyKey,
            'status' => 'PROCESSING',
            'payload' => json_encode($request->all()),
            'created_at' => now(),
        ]);
        
        try {
            // Process payment (simulate gateway call)
            $result = $this->chargeCustomer($customerId, $amount);
            
            // Update status to COMPLETED
            DB::table('payment_requests')->where('id', $requestId)->update([
                'status' => 'COMPLETED',
                'response_data' => json_encode($result),
                'updated_at' => now(),
            ]);
            
            return response()->json($result, 200);
            
        } catch (Exception $e) {
            // Update status to FAILED
            DB::table('payment_requests')->where('id', $requestId)->update([
                'status' => 'FAILED',
                'error_message' => $e->getMessage(),
                'updated_at' => now(),
            ]);
            
            return response()->json(['error' => 'Payment failed'], 500);
        }
    }
    
    private function chargeCustomer($customerId, $amount)
    {
        // Simulate payment gateway call
        sleep(2); // Simulate network delay
        
        return [
            'transaction_id' => 'txn_' . uniqid(),
            'amount' => $amount,
            'customer_id' => $customerId,
            'status' => 'success',
            'timestamp' => now()->toIso8601String(),
        ];
    }
}
```

**Test Cases:**
```php
// Test 1: First request
$response1 = $this->post('/api/payments', [...], ['Idempotency-Key' => 'key-123']);
// Expected: 200 OK, transaction_id returned

// Test 2: Duplicate request (should return cached result)
$response2 = $this->post('/api/payments', [...], ['Idempotency-Key' => 'key-123']);
// Expected: 200 OK, SAME transaction_id

// Test 3: Concurrent request (while first is processing)
// Trigger two requests at the exact same time
// Expected: One returns 200 OK, the other returns 409 Conflict
```

---

## 🔧 **Challenge #2: Implement 3-Layer Caching (APCu → Redis → MySQL)**

### **Problem Statement:**

You're building a settings lookup service that serves 200+ microservices. Requirements:
- **Response time:** <50ms (p99)
- **Consistency:** Settings must be consistent across all servers
- **Invalidation:** When a setting changes, all caches must be invalidated

**Architecture:**
1. **APCu (application-level cache):** Fastest, but per-server (not shared)
2. **Redis (centralized cache):** Shared across servers
3. **MySQL (source of truth):** Persistent storage

---

### **Your Turn: Implement the Cache-Aside Pattern!**

**Setup:**
```php
class SettingsRepository
{
    private $apcu;
    private $redis;
    private $db;
    
    public function getSetting($customerId, $key)
    {
        // YOUR CODE HERE
        // 1. Check APCu
        // 2. If miss, check Redis
        // 3. If miss, check MySQL
        // 4. Backfill caches
    }
    
    public function setSetting($customerId, $key, $value)
    {
        // YOUR CODE HERE
        // 1. Update MySQL
        // 2. Invalidate caches
    }
}
```

---

### **Solution:**

```php
class SettingsRepository
{
    private $redis;
    private $db;
    
    const APCU_TTL = 300;      // 5 minutes
    const REDIS_TTL = 900;     // 15 minutes
    
    public function __construct(Redis $redis, PDO $db)
    {
        $this->redis = $redis;
        $this->db = $db;
    }
    
    public function getSetting($customerId, $key)
    {
        $cacheKey = "setting:{$customerId}:{$key}";
        
        // Layer 1: APCu (in-memory, fastest)
        $value = apcu_fetch($cacheKey, $success);
        if ($success) {
            return $value;
        }
        
        // Layer 2: Redis (centralized)
        $value = $this->redis->get($cacheKey);
        if ($value !== false) {
            // Backfill APCu
            apcu_store($cacheKey, $value, self::APCU_TTL);
            return $value;
        }
        
        // Layer 3: MySQL (source of truth)
        $stmt = $this->db->prepare(
            'SELECT value FROM customer_settings 
             WHERE customer_id = ? AND setting_key = ?'
        );
        $stmt->execute([$customerId, $key]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$row) {
            return null; // Setting not found
        }
        
        $value = $row['value'];
        
        // Backfill both caches
        $this->redis->setex($cacheKey, self::REDIS_TTL, $value);
        apcu_store($cacheKey, $value, self::APCU_TTL);
        
        return $value;
    }
    
    public function setSetting($customerId, $key, $value)
    {
        $cacheKey = "setting:{$customerId}:{$key}";
        
        // 1. Update MySQL (source of truth)
        $stmt = $this->db->prepare(
            'INSERT INTO customer_settings (customer_id, setting_key, value, updated_at)
             VALUES (?, ?, ?, NOW())
             ON DUPLICATE KEY UPDATE value = ?, updated_at = NOW()'
        );
        $stmt->execute([$customerId, $key, $value, $value]);
        
        // 2. Invalidate caches
        $this->invalidateCache($customerId, $key);
        
        return true;
    }
    
    private function invalidateCache($customerId, $key)
    {
        $cacheKey = "setting:{$customerId}:{$key}";
        
        // Invalidate Redis
        $this->redis->del($cacheKey);
        
        // Invalidate APCu (local server only)
        apcu_delete($cacheKey);
        
        // IMPORTANT: Other servers still have stale APCu cache!
        // Solution: Version-based invalidation (see below)
    }
}
```

**Problem with the above:** APCu is per-server, so other servers don't know to invalidate.

**Solution: Version-Based Invalidation**
```php
public function getSetting($customerId, $key)
{
    // 1. Check version in Redis
    $versionKey = "setting_version:{$customerId}";
    $currentVersion = $this->redis->get($versionKey) ?: 0;
    
    // 2. Check if APCu cache is stale
    $cacheKey = "setting:{$customerId}:{$key}";
    $cached = apcu_fetch($cacheKey, $success);
    
    if ($success) {
        $cachedVersion = apcu_fetch("{$cacheKey}:version");
        
        if ($cachedVersion == $currentVersion) {
            return $cached; // Cache is fresh
        } else {
            apcu_delete($cacheKey); // Cache is stale, invalidate
        }
    }
    
    // 3. Fetch from Redis or MySQL (same as before)
    // ...
    
    // 4. Store with version
    apcu_store($cacheKey, $value, self::APCU_TTL);
    apcu_store("{$cacheKey}:version", $currentVersion, self::APCU_TTL);
    
    return $value;
}

public function setSetting($customerId, $key, $value)
{
    // 1. Update MySQL
    // ...
    
    // 2. Increment version (invalidates all servers' APCu caches)
    $versionKey = "setting_version:{$customerId}";
    $this->redis->incr($versionKey);
    
    // 3. Invalidate Redis cache
    $this->redis->del("setting:{$customerId}:{$key}");
}
```

**Test Cases:**
```php
// Test 1: First fetch (MySQL → Redis → APCu)
$value1 = $repo->getSetting(123, 'theme');
// Expected: 'dark' (from MySQL, caches backfilled)

// Test 2: Second fetch (APCu hit)
$value2 = $repo->getSetting(123, 'theme');
// Expected: 'dark' (from APCu, <1ms response time)

// Test 3: Update setting
$repo->setSetting(123, 'theme', 'light');

// Test 4: Fetch again (cache invalidated, fetches from MySQL)
$value3 = $repo->getSetting(123, 'theme');
// Expected: 'light' (old cache invalidated)
```

---

## 🔐 **Challenge #3: Implement Circuit Breaker for External API**

### **Problem Statement:**

Your app calls an external payment gateway API. Sometimes the gateway is slow or down:
- **Slow:** Response time > 5 seconds
- **Down:** Connection refused or 500 errors

**Requirements:**
1. **Normal state:** Pass all requests through
2. **Failure state:** If 5 failures in 10 seconds, **open the circuit** (fail fast for 30 seconds)
3. **Recovery:** After 30 seconds, allow **one test request**. If it succeeds, close the circuit.

---

### **Your Turn: Implement the Circuit Breaker!**

```php
class CircuitBreaker
{
    private $redis;
    private $serviceName;
    
    const FAILURE_THRESHOLD = 5;
    const TIMEOUT = 30; // seconds
    
    public function call(callable $action)
    {
        // YOUR CODE HERE
    }
}
```

---

### **Solution:**

```php
class CircuitBreaker
{
    private $redis;
    private $serviceName;
    private $failureThreshold;
    private $timeout;
    
    public function __construct(Redis $redis, $serviceName, $failureThreshold = 5, $timeout = 30)
    {
        $this->redis = $redis;
        $this->serviceName = $serviceName;
        $this->failureThreshold = $failureThreshold;
        $this->timeout = $timeout;
    }
    
    public function call(callable $action)
    {
        $state = $this->getState();
        
        // OPEN: Circuit is open, fail fast
        if ($state === 'OPEN') {
            if ($this->shouldAttemptReset()) {
                $this->setState('HALF_OPEN');
            } else {
                throw new CircuitOpenException("Circuit breaker is OPEN for {$this->serviceName}");
            }
        }
        
        // HALF_OPEN: Allow one test request
        if ($state === 'HALF_OPEN') {
            try {
                $result = $action();
                $this->onSuccess();
                return $result;
            } catch (Exception $e) {
                $this->onFailure();
                throw $e;
            }
        }
        
        // CLOSED: Normal operation
        try {
            $result = $action();
            $this->onSuccess();
            return $result;
        } catch (Exception $e) {
            $this->onFailure();
            throw $e;
        }
    }
    
    private function getState()
    {
        return $this->redis->get("circuit:{$this->serviceName}:state") ?: 'CLOSED';
    }
    
    private function setState($state)
    {
        $this->redis->set("circuit:{$this->serviceName}:state", $state);
    }
    
    private function onSuccess()
    {
        // Reset failure count
        $this->redis->del("circuit:{$this->serviceName}:failures");
        $this->setState('CLOSED');
    }
    
    private function onFailure()
    {
        // Increment failure count
        $failures = $this->redis->incr("circuit:{$this->serviceName}:failures");
        $this->redis->expire("circuit:{$this->serviceName}:failures", 10);
        
        // Open circuit if threshold exceeded
        if ($failures >= $this->failureThreshold) {
            $this->setState('OPEN');
            $this->redis->setex("circuit:{$this->serviceName}:opened_at", 60, time());
        }
    }
    
    private function shouldAttemptReset()
    {
        $openedAt = $this->redis->get("circuit:{$this->serviceName}:opened_at");
        
        if (!$openedAt) {
            return false;
        }
        
        return (time() - $openedAt) >= $this->timeout;
    }
}

class CircuitOpenException extends Exception {}
```

**Usage Example:**
```php
$circuitBreaker = new CircuitBreaker($redis, 'payment_gateway');

try {
    $response = $circuitBreaker->call(function() {
        return $this->paymentGateway->charge(100.00, 'cust_123');
    });
    
    echo "Payment successful: " . $response['transaction_id'];
    
} catch (CircuitOpenException $e) {
    // Circuit is open, fail fast
    echo "Payment gateway is down. Please try again later.";
    
    // Return cached response or fallback
    return $this->getCachedPaymentStatus();
    
} catch (Exception $e) {
    // Other errors (network timeout, etc.)
    echo "Payment failed: " . $e->getMessage();
}
```

**Test Cases:**
```php
// Simulate 5 failures
for ($i = 0; $i < 5; $i++) {
    try {
        $circuitBreaker->call(function() {
            throw new Exception("Gateway timeout");
        });
    } catch (Exception $e) {
        // Expected: Circuit still CLOSED for first 4 failures
    }
}

// 6th call: Circuit should be OPEN
try {
    $circuitBreaker->call(function() {
        return "Success";
    });
} catch (CircuitOpenException $e) {
    echo "Circuit is OPEN!"; // Expected
}

// Wait 30 seconds (simulate)
sleep(30);

// Next call: Circuit should be HALF_OPEN
// If this succeeds, circuit will close
$circuitBreaker->call(function() {
    return "Success"; // Circuit closes
});
```

---

## 🗄️ **Challenge #4: Optimize a Slow SQL Query**

### **Problem Statement:**

This query takes 3-5 seconds on a table with 100M rows:

```sql
SELECT 
    customer_id,
    COUNT(*) as invoice_count,
    SUM(amount) as total_amount
FROM invoices
WHERE status = 'pending'
  AND created_at >= '2026-01-01'
GROUP BY customer_id
ORDER BY total_amount DESC
LIMIT 10;
```

**Task:** Optimize it to run in <100ms.

---

### **Your Turn: Identify the Bottleneck!**

**Step 1: Run EXPLAIN**
```sql
EXPLAIN SELECT ...;
```

**Step 2: Identify issues**
- [ ] Missing index on `status`?
- [ ] Missing index on `created_at`?
- [ ] Full table scan?
- [ ] Filesort (slow sorting)?

**Step 3: Propose fixes**

---

### **Solution:**

**Step 1: EXPLAIN Output (before optimization)**
```
+----+-------------+----------+------+---------------+------+---------+------+-----------+-----------------------------+
| id | select_type | table    | type | possible_keys | key  | key_len | ref  | rows      | Extra                       |
+----+-------------+----------+------+---------------+------+---------+------+-----------+-----------------------------+
|  1 | SIMPLE      | invoices | ALL  | NULL          | NULL | NULL    | NULL | 100000000 | Using where; Using filesort |
+----+-------------+----------+------+---------------+------+---------+------+-----------+-----------------------------+
```

**Problems:**
1. `type: ALL` → Full table scan (100M rows scanned!)
2. `Using filesort` → Sorting 100M rows in memory
3. No index used

---

**Step 2: Add Indexes**
```sql
-- Composite index (covers WHERE + GROUP BY)
CREATE INDEX idx_status_created_customer 
ON invoices (status, created_at, customer_id);

-- Covering index (includes amount for SUM)
CREATE INDEX idx_status_created_customer_amount 
ON invoices (status, created_at, customer_id, amount);
```

---

**Step 3: EXPLAIN Output (after index)**
```
+----+-------------+----------+-------+------------------------------+----------------------------------+---------+------+--------+---------------------------------------+
| id | select_type | table    | type  | possible_keys                | key                              | key_len | ref  | rows   | Extra                                 |
+----+-------------+----------+-------+------------------------------+----------------------------------+---------+------+--------+---------------------------------------+
|  1 | SIMPLE      | invoices | range | idx_status_created_customer  | idx_status_created_customer_amount | 20      | NULL | 500000 | Using where; Using index; Using filesort |
+----+-------------+----------+-------+------------------------------+----------------------------------+---------+------+--------+---------------------------------------+
```

**Improvement:**
- Rows scanned: 100M → 500K (200x reduction!)
- Using index: Yes (no table access needed)
- Still has filesort, but on 500K rows instead of 100M

---

**Step 4: Further Optimization (Materialized View)**

For even better performance, pre-compute the aggregates:

```sql
-- Create summary table
CREATE TABLE invoice_summary (
    customer_id BIGINT PRIMARY KEY,
    pending_count INT DEFAULT 0,
    pending_total DECIMAL(10,2) DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_pending_total (pending_total DESC)
);

-- Update via trigger (or cron job)
DELIMITER $$
CREATE TRIGGER update_invoice_summary
AFTER INSERT ON invoices
FOR EACH ROW
BEGIN
    IF NEW.status = 'pending' THEN
        INSERT INTO invoice_summary (customer_id, pending_count, pending_total)
        VALUES (NEW.customer_id, 1, NEW.amount)
        ON DUPLICATE KEY UPDATE 
            pending_count = pending_count + 1,
            pending_total = pending_total + NEW.amount;
    END IF;
END$$
DELIMITER ;

-- Now the query is instant!
SELECT customer_id, pending_total as total_amount
FROM invoice_summary
ORDER BY pending_total DESC
LIMIT 10;
-- Query time: <10ms (pre-aggregated!)
```

---

## 🎨 **Challenge #5: Implement Rate Limiting (Token Bucket Algorithm)**

### **Problem Statement:**

Implement a rate limiter using the **Token Bucket Algorithm**:
- Each user has a "bucket" with 100 tokens
- Each request consumes 1 token
- Tokens refill at 10/second (600/minute)
- If bucket is empty, reject request with 429 Too Many Requests

---

### **Your Turn: Implement It!**

```php
class RateLimiter
{
    private $redis;
    
    const CAPACITY = 100;        // Max tokens in bucket
    const REFILL_RATE = 10;      // Tokens per second
    
    public function allow($userId)
    {
        // YOUR CODE HERE
    }
}
```

---

### **Solution:**

```php
class RateLimiter
{
    private $redis;
    
    const CAPACITY = 100;
    const REFILL_RATE = 10;
    
    public function __construct(Redis $redis)
    {
        $this->redis = $redis;
    }
    
    public function allow($userId)
    {
        $key = "rate_limit:$userId";
        $now = microtime(true);
        
        // Get current bucket state
        $bucket = $this->redis->hGetAll($key);
        
        if (empty($bucket)) {
            // First request — initialize bucket
            $bucket = [
                'tokens' => self::CAPACITY,
                'last_refill' => $now,
            ];
        } else {
            // Calculate tokens to add since last refill
            $elapsedTime = $now - $bucket['last_refill'];
            $tokensToAdd = $elapsedTime * self::REFILL_RATE;
            
            // Refill tokens (capped at CAPACITY)
            $bucket['tokens'] = min(
                self::CAPACITY,
                $bucket['tokens'] + $tokensToAdd
            );
            $bucket['last_refill'] = $now;
        }
        
        // Check if we have enough tokens
        if ($bucket['tokens'] >= 1) {
            // Consume 1 token
            $bucket['tokens'] -= 1;
            
            // Save bucket state
            $this->redis->hMSet($key, [
                'tokens' => $bucket['tokens'],
                'last_refill' => $bucket['last_refill'],
            ]);
            $this->redis->expire($key, 3600); // Expire after 1 hour of inactivity
            
            return true; // Request allowed
        } else {
            // No tokens available
            return false; // Request denied
        }
    }
}
```

**Usage:**
```php
$rateLimiter = new RateLimiter($redis);

if (!$rateLimiter->allow($userId)) {
    return response()->json(['error' => 'Too Many Requests'], 429)
        ->header('Retry-After', 1); // Try again in 1 second
}

// Process request
return $this->handleRequest($request);
```

**Test Cases:**
```php
// Test 1: First 100 requests should succeed
for ($i = 0; $i < 100; $i++) {
    assert($rateLimiter->allow($userId) === true);
}

// Test 2: 101st request should fail (bucket empty)
assert($rateLimiter->allow($userId) === false);

// Test 3: Wait 1 second (10 tokens refilled)
sleep(1);
for ($i = 0; $i < 10; $i++) {
    assert($rateLimiter->allow($userId) === true);
}

// Test 4: 11th request should fail
assert($rateLimiter->allow($userId) === false);
```

---

## 🚀 **More Practice Challenges**

### **Challenge #6: LRU Cache Implementation**
Implement an LRU (Least Recently Used) cache with:
- `get(key)` — O(1)
- `put(key, value)` — O(1)
- Max capacity (evict least recently used when full)

**Hint:** Use a hash map + doubly-linked list

---

### **Challenge #7: Database Connection Pool**
Implement a connection pool that:
- Maintains 10-100 active connections
- Reuses connections instead of creating new ones
- Closes idle connections after 5 minutes

---

### **Challenge #8: Distributed Lock (Redis)**
Implement a distributed lock using Redis:
- `acquire($lockName, $ttl)` — Acquires lock
- `release($lockName)` — Releases lock
- Handle race conditions (two processes acquiring simultaneously)

**Hint:** Use `SET key value NX EX ttl`

---

### **Challenge #9: JWT Authentication**
Implement JWT (JSON Web Token) authentication:
- `generateToken($userId)` — Create a signed token
- `verifyToken($token)` — Verify signature and expiration
- Include claims: user_id, exp (expiration), iat (issued at)

---

### **Challenge #10: Paginated API Response**
Implement cursor-based pagination:
- `GET /api/invoices?cursor=abc123&limit=50`
- Return `{ data: [...], next_cursor: "xyz789" }`
- Handle edge cases (last page, empty result)

---

## ✅ **Practice Checklist**

After completing each challenge, check:

- [ ] **Did I write the code from scratch?** (no copy-paste)
- [ ] **Does it handle edge cases?** (empty input, null, errors)
- [ ] **Is it efficient?** (O(1), O(log n), not O(n²))
- [ ] **Can I explain it?** (walk through the code line by line)
- [ ] **Did I test it?** (run test cases, verify output)

---

**Keep practicing, and you'll master these patterns! 💪**

**Next:** Try the Mock Interview Questions with these code examples fresh in your mind!