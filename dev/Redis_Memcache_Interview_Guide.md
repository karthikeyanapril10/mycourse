# Redis & Memcache Implementation Guide

**For Senior Software Engineer Interviews**

Your competitive advantage: **Production Redis experience at scale** (10,000+ tenants, customer settings cache, session storage, 1-hour TTLs, 80% database load reduction)

---

## Table of Contents

1. [Redis vs Memcache: Quick Comparison](#redis-vs-memcache-quick-comparison)
2. [Redis Data Structures](#redis-data-structures)
3. [Caching Patterns](#caching-patterns)
4. [Cache Eviction Policies](#cache-eviction-policies)
5. [Redis Persistence](#redis-persistence)
6. [Distributed Caching & Clustering](#distributed-caching--clustering)
7. [Production Redis Experience](#your-Enterprise SaaS Company-redis-experience)
8. [Performance Optimization](#performance-optimization)
9. [Common Pitfalls & Best Practices](#common-pitfalls--best-practices)
10. [Interview Questions & Answers](#interview-questions--answers)

---

## Redis vs Memcache: Quick Comparison

### When to Use What

| Feature | Redis | Memcache |
|---------|-------|----------|
| **Data Structures** | Strings, Lists, Sets, Sorted Sets, Hashes, Bitmaps, HyperLogLog | Strings only (key-value) |
| **Persistence** | Yes (RDB snapshots, AOF logs) | No (memory only) |
| **Replication** | Master-Slave, Clustering | No built-in (client-side sharding) |
| **Max Key Size** | 512 MB | 1 MB |
| **Max Value Size** | 512 MB | 1 MB |
| **Multi-threading** | Single-threaded (event loop) | Multi-threaded |
| **Atomic Operations** | Yes (INCR, DECR, list ops) | Limited (CAS - Compare-And-Set) |
| **Pub/Sub** | Yes | No |
| **TTL Granularity** | Seconds or milliseconds | Seconds |
| **Use Cases** | Sessions, leaderboards, queues, caching complex objects | Simple key-value caching, high throughput |

### Decision Framework

**Choose Redis when:**
- You need complex data structures (sorted sets, lists, hashes)
- Persistence is important (can't afford to lose cache on restart)
- You need atomic operations (counters, leaderboards)
- You want pub/sub messaging
- You need replication and failover

**Choose Memcache when:**
- Simple key-value cache is sufficient
- Highest raw throughput is critical (multi-threaded)
- Memory efficiency for strings is priority
- You already have a Memcache infrastructure

**Enterprise Choice: Redis (ElastiCache)**
- Chosen for: complex objects (customer settings), persistence, clustering, atomic operations

---

## Redis Data Structures

### 1. Strings (Most Common)

```redis
SET user:1001:name "John Doe"
GET user:1001:name
SETEX session:abc123 3600 "session_data"  # Set with 3600s TTL
INCR page:views:homepage                   # Atomic increment
DECR inventory:item:42
```

**Use Cases:**
- Session storage ← **Your real-world use case**
- Cache HTML fragments
- Rate limiting counters
- Distributed locks (SETNX)

### 2. Hashes (Objects/Records)

```redis
HSET user:1001 name "John" email "john@example.com" age 30
HGET user:1001 email
HGETALL user:1001
HINCRBY user:1001 login_count 1
```

**Use Cases:**
- Cache database rows ← **Your customer settings cache**
- Store user profiles
- Session attributes

**Why Hashes Over Strings?**
- Memory efficient (up to 50% savings for small objects)
- Update individual fields without fetching entire object
- Atomic field operations (HINCRBY)

### 3. Lists (Ordered Collections)

```redis
LPUSH queue:jobs "job1"
RPUSH queue:jobs "job2"
LPOP queue:jobs          # FIFO queue
LRANGE recent:logs 0 99  # Last 100 log entries
```

**Use Cases:**
- Job queues
- Activity feeds
- Recent items (capped lists with LTRIM)

### 4. Sets (Unique Collections)

```redis
SADD user:1001:tags "php" "mysql" "redis"
SISMEMBER user:1001:tags "redis"  # O(1) membership check
SINTER user:1001:tags user:1002:tags  # Find common tags
```

**Use Cases:**
- Unique visitors tracking
- Tags/categories
- Social graph (followers, following)

### 5. Sorted Sets (Ranked Collections)

```redis
ZADD leaderboard 1500 "player1" 2000 "player2"
ZRANGE leaderboard 0 9 WITHSCORES  # Top 10
ZINCRBY leaderboard 50 "player1"   # Add 50 points
ZRANK leaderboard "player1"        # Get rank
```

**Use Cases:**
- Leaderboards ← **Potential Enterprise SaaS Company use for customer rankings**
- Time-series data (score = timestamp)
- Priority queues
- Rate limiting (sliding window)

---

## Caching Patterns

### 1. Cache-Aside (Lazy Loading) ← **Most Common**

**Flow:**
1. App requests data from cache
2. **Cache miss** → Load from database
3. Write to cache with TTL
4. Return data
5. **Cache hit** (next time) → Return from cache

```php
function getCustomerSettings($customerId) {
    $cacheKey = "customer:$customerId:settings";
    
    // 1. Try cache first
    $settings = Redis::get($cacheKey);
    
    if ($settings !== null) {
        return json_decode($settings, true);  // Cache hit
    }
    
    // 2. Cache miss - load from DB
    $settings = DB::table('fsicustomersettings')
        ->where('customerid', $customerId)
        ->where('settingsstatus', 5)  // Active only
        ->get();
    
    // 3. Store in cache with 1-hour TTL
    Redis::setex($cacheKey, 3600, json_encode($settings));
    
    return $settings;
}
```

**Your production implementation:**
- Customer settings cache
- 1-hour TTL
- 80% database load reduction

**Pros:**
- Cache only what's actually requested (memory efficient)
- System still works if cache is down (degrades gracefully)

**Cons:**
- Initial cache miss penalty (first request is slow)
- Cache stampede risk (multiple requests on miss)

### 2. Write-Through

**Flow:**
1. App writes to cache AND database **synchronously**
2. Cache is always consistent with DB
3. Reads always hit cache (no misses after first write)

```php
function updateCustomerEmail($customerId, $newEmail) {
    $cacheKey = "customer:$customerId:profile";
    
    DB::beginTransaction();
    
    // 1. Update database
    DB::table('fsionlinecustomer')
        ->where('customerid', $customerId)
        ->update(['emailprimary' => $newEmail]);
    
    // 2. Update cache immediately
    $profile = $this->loadCustomerProfile($customerId);
    Redis::setex($cacheKey, 3600, json_encode($profile));
    
    DB::commit();
}
```

**Pros:**
- Strong consistency (cache always matches DB)
- No cache misses for reads after write

**Cons:**
- Write latency (wait for both cache + DB)
- Wasted cache space (caching data that's rarely read)

### 3. Write-Behind (Write-Back)

**Flow:**
1. App writes to cache immediately
2. Returns success to user
3. **Async background job** writes to database later
4. High write throughput

```php
// Fast write to cache
Redis::hset("customer:$customerId:settings", 'last_login', time());
Redis::lpush('queue:db_writes', json_encode([
    'table' => 'fsionlinecustomer',
    'id' => $customerId,
    'data' => ['last_login' => time()]
]));

// Separate worker drains queue and writes to DB
```

**Pros:**
- Very fast writes (cache speed)
- Batching writes to DB (efficiency)

**Cons:**
- Risk of data loss if cache crashes before DB write
- Complex implementation (need queue + worker)

**When to Use:**
- High write volume (analytics, counters)
- Write latency is critical
- Acceptable to lose recent writes on crash

### 4. Read-Through

**Flow:**
- Cache sits in front of DB
- Cache itself loads from DB on miss (not the app)
- App only talks to cache

**Pros:**
- Simple app code (always use cache API)
- Consistent cache loading logic

**Cons:**
- Cache becomes single point of failure
- Less common in practice (most use cache-aside)

---

## Cache Eviction Policies

### When Cache is Full, What Gets Removed?

| Policy | Behavior | Use Case |
|--------|----------|----------|
| **LRU** (Least Recently Used) | Evict items not accessed recently | General-purpose (most common) ← **Production default** |
| **LFU** (Least Frequently Used) | Evict items with fewest accesses | Long-lived cache, hot-spot access |
| **TTL** (Time-To-Live) | Evict expired items first | Session cache, time-sensitive data |
| **Random** | Evict random items | Fast, but no intelligence |
| **Volatile-LRU** | LRU but only on keys with TTL | Mix of permanent + temp data |
| **Allkeys-LRU** | LRU across all keys | Standard cache (keys may or may not have TTL) |

### Production Configuration:

```bash
# ElastiCache Redis configuration
maxmemory-policy allkeys-lru
maxmemory 4gb
```

**Why LRU?**
- Customer settings: Frequently accessed customers stay cached
- Inactive customers evicted naturally
- Balance between memory usage and hit rate

---

## Redis Persistence

### Two Persistence Mechanisms:

### 1. RDB (Redis Database Snapshot)

**How it works:**
- Point-in-time snapshot saved to disk
- Configurable intervals (e.g., every 15 min if 100+ writes)
- Fork process → child writes snapshot while parent serves requests
- Fast restarts (binary format)

**Configuration:**
```redis
save 900 1      # Save if 1+ keys changed in 15 min
save 300 10     # Save if 10+ keys changed in 5 min
save 60 10000   # Save if 10000+ keys changed in 1 min
```

**Pros:**
- Compact single file
- Fast restarts
- Good for backups

**Cons:**
- Data loss window (5-15 min of writes if crash happens)
- Fork can be expensive on large datasets

### 2. AOF (Append-Only File)

**How it works:**
- Logs every write operation to disk
- Can replay log to rebuild dataset
- More durable (smaller data loss window)

**Configuration:**
```redis
appendonly yes
appendfsync everysec  # Sync to disk every second
```

**Pros:**
- Better durability (1 sec data loss max)
- Human-readable log
- Auto-rewrites to compact

**Cons:**
- Larger files than RDB
- Slower restarts (must replay log)

### Your production setup:

**ElastiCache Redis with RDB backups:**
- Daily snapshot to S3
- Acceptable to lose 1 hour of cache on crash (can rebuild from DB)
- Session cache is okay to lose (users re-login)

**Interview Answer:**
> *"In a production environment, we use RDB snapshots for our Redis cache because it's a cache, not primary storage. We can tolerate losing recent cached data on a crash since we can always rebuild from MySQL. RDB gives us fast restarts and good backup capability. For a critical use case like a shopping cart, I'd use AOF with `appendfsync everysec` for better durability."*

---

## Distributed Caching & Clustering

### Problem: Single Redis Instance Limits

- **Memory**: Single node max ~100 GB practical
- **Throughput**: Single-threaded, ~100k ops/sec max
- **Availability**: Single point of failure

### Solution 1: Client-Side Sharding (Memcache Style)

```php
function getShardedCache($key) {
    $nodes = ['redis1:6379', 'redis2:6379', 'redis3:6379'];
    $hash = crc32($key);
    $nodeIndex = $hash % count($nodes);
    $redis = new Redis($nodes[$nodeIndex]);
    return $redis->get($key);
}
```

**Pros:**
- Simple
- Linear scalability

**Cons:**
- Adding/removing nodes requires full re-hash (cache invalidation)
- No automatic failover
- Client must handle sharding logic

### Solution 2: Consistent Hashing

**Fixes the re-hash problem:**
- Hash ring: Each node owns a range of hash values
- Adding a node only affects adjacent ranges (not all keys)
- ~1/N keys are invalidated (N = number of nodes)

```
Hash Ring (0-360):
Node A: 0-120
Node B: 121-240
Node C: 241-360

Add Node D at 180:
Node A: 0-120 (unchanged)
Node B: 121-180 (shrinks, some keys move to D)
Node D: 181-240 (new)
Node C: 241-360 (unchanged)
```

### Solution 3: Redis Cluster (Built-in Sharding)

**How it works:**
- 16,384 hash slots (0-16383)
- Each master node owns a range of slots
- `HASH_SLOT = CRC16(key) mod 16384`
- Clients redirected to correct node

**Architecture:**
```
Master 1 (slots 0-5460)    → Replica 1a
Master 2 (slots 5461-10922) → Replica 2a
Master 3 (slots 10923-16383) → Replica 3a
```

**Benefits:**
- Automatic sharding
- Automatic failover (replica promoted if master dies)
- No single point of failure

**Your production setup:**

```
ElastiCache Redis Cluster:
- 3 master nodes (sharded)
- 3 read replicas (1 per master)
- Automatic failover enabled
- Multi-AZ deployment
```

### Solution 4: Redis Sentinel (High Availability, No Sharding)

**Single master + replicas with auto-failover:**
- Sentinel nodes monitor master
- If master dies, Sentinels elect a new master from replicas
- No sharding (all data on all nodes)

**Use when:**
- Dataset fits in one node
- High availability is critical
- Don't need horizontal scaling

---

## Production Redis Experience

### 1. Customer Settings Cache

**Problem Solved:**
- MySQL `fsicustomersettings` table queried on every page load
- 10,000+ tenants × 100+ settings each = millions of rows
- Database CPU was bottleneck

**Solution:**
```php
class CustomerSettingsCache {
    private $redis;
    private $ttl = 3600; // 1 hour
    
    public function getSettings($customerId) {
        $cacheKey = "customer:$customerId:settings";
        
        // Try cache first
        $cached = $this->redis->get($cacheKey);
        if ($cached) {
            return json_decode($cached, true);
        }
        
        // Cache miss - load from DB
        $settings = DB::table('fsicustomersettings')
            ->where('customerid', $customerId)
            ->where('settingsstatus', 5)
            ->get()
            ->keyBy('fullpath');  // Index by setting path
        
        // Store in cache
        $this->redis->setex($cacheKey, $this->ttl, json_encode($settings));
        
        return $settings;
    }
    
    public function invalidate($customerId) {
        $cacheKey = "customer:$customerId:settings";
        $this->redis->del($cacheKey);
    }
}
```

**Impact:**
- **80% database load reduction**
- Page load time: 800ms → 200ms
- Cache hit rate: ~95%

### 2. Session Storage

**Problem:**
- PHP file-based sessions don't scale (sticky sessions required)
- Need sessions accessible from any web server

**Solution:**
```php
// config/session.php
'driver' => 'redis',
'connection' => 'default',
'ttl' => 7200,  // 2 hours

// Session key format:
// session:<session_id>
```

**Benefits:**
- No sticky sessions needed
- Horizontal scaling of web tier
- Fast session reads/writes

### 3. Cache Invalidation Strategy

**Challenges:**
1. **Write-through for critical data:**
   ```php
   // When customer setting updated via CSR
   DB::table('fsicustomersettings')->update([...]);
   $this->cache->invalidate($customerId);  // Immediate
   ```

2. **TTL-based for read-heavy data:**
   - 1-hour TTL acceptable for most settings
   - Eventual consistency is fine

3. **Event-based invalidation:**
   ```php
   Event::listen('CustomerUpdated', function($customer) {
       Redis::del("customer:{$customer->id}:*");
   });
   ```

### 4. Monitoring & Metrics

**CloudWatch Alarms:**
- `EngineCPUUtilization` > 75%
- `Evictions` > 1000/min (cache too small)
- `CacheHitRate` < 80% (TTL too short or cache too small)
- `CurrConnections` > 5000 (connection leak)

**Redis Commands for Debugging:**
```redis
INFO stats           # Hit rate, evictions, ops/sec
INFO memory          # Memory usage, fragmentation
SLOWLOG GET 10       # Slow queries
CLIENT LIST          # Active connections
KEYS customer:*      # Find keys (DO NOT USE IN PROD!)
SCAN 0 MATCH customer:* COUNT 100  # Use this instead
```

---

## Performance Optimization

### 1. Use Pipelining (Batch Commands)

**Problem:** Network round-trip for each command

**Bad (3 round-trips):**
```php
$redis->get('key1');
$redis->get('key2');
$redis->get('key3');
```

**Good (1 round-trip):**
```php
$redis->pipeline(function ($pipe) {
    $pipe->get('key1');
    $pipe->get('key2');
    $pipe->get('key3');
});
```

**Impact:** 10x-100x faster for bulk operations

### 2. Use Hashes for Small Objects

**Memory savings:**
```redis
# Bad: 1000 keys = ~100 KB overhead
SET user:1:name "John"
SET user:1:email "john@example.com"
SET user:1:age "30"

# Good: 1 hash = ~1 KB overhead
HSET user:1 name "John" email "john@example.com" age 30
```

**When hash is smaller:**
- Object has < 100 fields
- Each field < 64 bytes
- Up to 50% memory savings

### 3. Avoid KEYS Command in Production

**Bad (blocks entire Redis):**
```redis
KEYS customer:*  # Scans all keys, O(N)
```

**Good (non-blocking, paginated):**
```redis
SCAN 0 MATCH customer:* COUNT 100
# Returns cursor + batch of keys
# Call again with cursor until cursor = 0
```

### 4. Set Appropriate TTLs

**Too short:** High cache miss rate, database load
**Too long:** Stale data, memory waste

**Guidelines:**
- **Session data:** 30 min - 2 hours
- **User profiles:** 1-24 hours
- **Application settings:** 5-60 minutes
- **Static content:** 24+ hours

**Production Settings:**
- Customer settings: 1 hour (good balance)
- Sessions: 2 hours (matches UI timeout)

### 5. Monitor Memory Fragmentation

```redis
INFO memory
# mem_fragmentation_ratio: 1.5

# If ratio > 1.5, restart Redis to reclaim memory
# Or enable activedefrag (Redis 4.0+)
CONFIG SET activedefrag yes
```

---

## Common Pitfalls & Best Practices

### 1. Cache Stampede (Thundering Herd)

**Problem:**
- Popular cache key expires
- 1000 requests hit at once
- All miss cache → 1000 DB queries

**Solution A: Probabilistic Early Expiration**
```php
function getWithEarlyExpiration($key, $ttl = 3600) {
    $cached = Redis::get($key);
    
    if ($cached) {
        $data = json_decode($cached, true);
        $expiresAt = $data['expires_at'];
        $now = time();
        
        // Randomly refresh 1 min before actual expiry
        $delta = $expiresAt - $now;
        $beta = 1.0;
        $randomRefresh = $delta * $beta * log(rand() / getrandmax());
        
        if ($randomRefresh < 0) {
            // Refresh in background, return stale data
            $this->refreshInBackground($key);
        }
        
        return $data['value'];
    }
    
    // Cache miss - normal flow
    return $this->loadAndCache($key, $ttl);
}
```

**Solution B: Distributed Lock**
```php
function getWithLock($key) {
    $cached = Redis::get($key);
    if ($cached) return $cached;
    
    // Try to acquire lock (SETNX with TTL)
    $lockKey = "lock:$key";
    $lockAcquired = Redis::set($lockKey, 1, 'NX', 'EX', 10);
    
    if ($lockAcquired) {
        // I won the lock - load from DB
        $data = $this->loadFromDB($key);
        Redis::setex($key, 3600, $data);
        Redis::del($lockKey);
        return $data;
    } else {
        // Someone else is loading - wait and retry
        sleep(0.05); // 50ms
        return $this->getWithLock($key); // Recursive retry
    }
}
```

### 2. Large Keys / Values

**Problem:**
- Redis is single-threaded
- `GET` of 10 MB value blocks all other commands

**Solution:**
- Break large objects into chunks
- Use Redis hash (HGET one field instead of entire object)
- Consider storing large data in S3, cache only metadata/URL

```php
// Bad
Redis::set('customer:1:invoice_pdf', $10mbPdf);  // Blocks Redis

// Good
$s3Url = S3::put('invoices/customer-1.pdf', $10mbPdf);
Redis::setex('customer:1:invoice_url', 3600, $s3Url);  // Small
```

### 3. Connection Pooling

**Bad (new connection per request):**
```php
function handle() {
    $redis = new Redis();
    $redis->connect('localhost', 6379);  // TCP handshake every time
    $data = $redis->get('key');
    $redis->close();
}
```

**Good (persistent connections):**
```php
// Laravel Redis uses persistent connections by default
Redis::get('key');  // Reuses connection
```

**Connection Limits:**
- Default Redis: 10,000 connections max
- Each connection: ~10 KB memory
- Monitor with: `INFO clients`

### 4. Serialization Overhead

```php
// Slow
$settings = ['key' => 'value'];
Redis::set('settings', serialize($settings));  // PHP serialize

// Faster
Redis::set('settings', json_encode($settings));  // JSON

// Fastest (if data is already string)
Redis::set('settings:key', 'value');
```

**Benchmarks (1000 iterations):**
- `json_encode`: 10ms
- `serialize`: 50ms
- `igbinary_serialize`: 5ms (binary, requires extension)

### 5. Hot Key Problem

**Problem:**
- One key gets millions of requests
- Single Redis shard is bottleneck

**Solution A: Client-Side Caching**
```php
// Local in-memory cache (APCu) for 10 seconds
$localCache = apcu_fetch('hot_key');
if ($localCache) return $localCache;

$redisData = Redis::get('hot_key');
apcu_store('hot_key', $redisData, 10);
return $redisData;
```

**Solution B: Replicate Hot Key**
```php
// Store same data under multiple keys
for ($i = 0; $i < 10; $i++) {
    Redis::setex("hot_key:$i", 3600, $data);
}

// Randomly pick a replica
$i = rand(0, 9);
return Redis::get("hot_key:$i");
```

---

## Interview Questions & Answers

### Q1: "How would you cache a database query result in Redis?"

**Your Answer:**

> *"I'd use cache-aside pattern, which is what we use In a production environment for customer settings. Here's the flow:*
> 
> *1. Check Redis first: `$cached = Redis::get('customer:123:settings')`*
> *2. If cache hit, decode and return immediately*
> *3. On cache miss, query MySQL with proper indexes and tenant scoping*
> *4. Store in Redis with appropriate TTL: `Redis::setex('customer:123:settings', 3600, json_encode($data))`*
> *5. Return the data*
> 
> *For the TTL, I consider data freshness requirements. Customer settings change infrequently, so 1 hour is acceptable. For real-time data like inventory, I'd use 30-60 seconds, or invalidate on writes.*
> 
> *Key considerations:*
> *- Use predictable key naming: `<entity>:<id>:<attribute>`*
> *- Serialize efficiently (JSON is good default)*
> *- Set memory limits and LRU eviction policy*
> *- Monitor cache hit rate — we maintain 95%+ In a production environment*
> *- Always have fallback to DB (cache should degrade gracefully)."*

---

### Q2: "Explain the difference between Redis and Memcache. When would you use each?"

**Your Answer:**

> *"Both are in-memory key-value stores, but Redis is much more feature-rich:*
> 
> **Key Differences:**
> *- **Data structures:** Redis supports lists, sets, sorted sets, hashes. Memcache is strings only.*
> *- **Persistence:** Redis can persist to disk (RDB/AOF). Memcache is ephemeral.*
> *- **Replication:** Redis has built-in replication and clustering. Memcache requires client-side sharding.*
> *- **Operations:** Redis has atomic operations (INCR, list push/pop). Memcache has basic get/set + CAS.*
> 
> **When to use Memcache:**
> *- Simple string caching with highest raw throughput (multi-threaded)*
> *- You already have Memcache infrastructure*
> 
> **When to use Redis (my preference):**
> *- Need complex data structures — we use hashes for customer settings In a production environment*
> *- Want persistence — we use RDB snapshots for backup*
> *- Need atomic operations — counters, rate limiting*
> *- Want pub/sub messaging*
> 
> *In a production environment, we use AWS ElastiCache for Redis in a clustered setup with 3 master nodes and read replicas for high availability. This reduced our database load by 80%."*

---

### Q3: "What caching patterns do you know? Explain cache-aside vs write-through."

**Your Answer:**

> *"I've implemented several caching patterns In a production environment:*
> 
> **Cache-Aside (Lazy Loading) — Our primary pattern:**
> *- App reads from cache first*
> *- On miss, load from DB and populate cache*
> *- Pros: Only cache what's requested, memory efficient*
> *- Cons: First request is slow (cold cache)*
> *- **Use case:** Customer settings — 1-hour TTL, 95% hit rate*
> 
> **Write-Through:**
> *- Every write goes to cache AND database synchronously*
> *- Cache is always consistent with DB*
> *- Pros: No cache misses after initial write, strong consistency*
> *- Cons: Write latency (both cache + DB), cache pollution (store data that's never read)*
> *- **Use case:** User profiles where read-heavy and consistency is critical*
> 
> **Write-Behind (Write-Back):**
> *- Write to cache immediately, async write to DB later*
> *- Pros: Very fast writes, can batch DB writes*
> *- Cons: Data loss risk if cache crashes*
> *- **Use case:** Analytics counters, audit logs*
> 
> **Refresh-Ahead:**
> *- Proactively refresh popular keys before they expire*
> *- Prevents cache stampede on hot keys*
> *- **Use case:** Homepage data, popular product pages*
> 
> *For most use cases, I start with cache-aside because it's simple, memory-efficient, and degrades gracefully if cache goes down."*

---

### Q4: "How do you handle cache invalidation?"

**Your Answer:**

> *"Cache invalidation is one of the two hard problems in computer science. In a production environment, we use multiple strategies depending on the use case:*
> 
> **1. TTL-Based (Simplest):**
> *- Set expiration on every key*
> *- For customer settings: 1-hour TTL*
> *- Pros: Simple, automatic cleanup*
> *- Cons: Stale data possible, cache stampede on expiry*
> 
> **2. Event-Based Invalidation:**
> ```php
> // When customer setting updated
> Event::listen('CustomerSettingUpdated', function($customer) {
>     Redis::del("customer:{$customer->id}:settings");
> });
> ```
> *- Immediate consistency*
> *- Use for critical data (billing info, permissions)*
> 
> **3. Tag-Based Invalidation (Laravel):**
> ```php
> Cache::tags(['customer', 'settings'])->flush();
> ```
> *- Invalidate related groups of keys*
> *- Use for complex dependencies*
> 
> **4. Versioned Keys:**
> ```php
> $version = Redis::incr('customer:123:version');
> Redis::set("customer:123:settings:v$version", $data);
> ```
> *- Old versions expire naturally*
> *- No explicit deletes needed*
> 
> **Cache Stampede Prevention:**
> *- Stagger TTLs: `rand(3500, 3700)` instead of fixed 3600*
> *- Probabilistic early refresh*
> *- Distributed locks for expensive queries*
> 
> **Monitoring:**
> *- Track cache invalidation rate (should be < 5% of reads)*
> *- If invalidations spike, might need longer TTL or event-based approach.*"*

---

### Q5: "How would you scale Redis for high availability and increased capacity?"

**Your Answer:**

> *"In a production environment, we run AWS ElastiCache Redis Cluster in production. Here's how I'd approach scaling:*
> 
> **For High Availability:**
> 
> **1. Master-Replica Replication:**
> *- 1 master + 2 read replicas*
> *- Writes go to master, reads can hit replicas*
> *- If master fails, promote replica*
> *- Use Redis Sentinel for automatic failover*
> 
> **2. Multi-AZ Deployment:**
> *- Replicas in different availability zones*
> *- Survives datacenter failure*
> *- Our setup: us-east-1a (master) + us-east-1b, us-east-1c (replicas)*
> 
> **For Increased Capacity:**
> 
> **1. Redis Cluster (Horizontal Scaling):**
> *- 16,384 hash slots distributed across nodes*
> *- Example: 3 master nodes = 5461 slots each*
> *- Linear scaling: 3 nodes → 6 nodes = 2x capacity*
> *- Automatic resharding when adding nodes*
> 
> **2. Client-Side Sharding (Alternative):**
> *- Consistent hashing in application code*
> *- More control, but no automatic failover*
> 
> **3. Vertical Scaling (Short-term):**
> *- Upgrade instance type: cache.m5.large → cache.m5.xlarge*
> *- Doubles memory: 6.4 GB → 12.8 GB*
> *- Limited by largest instance size*
> 
> **Our Production Setup:**
> ```
> ElastiCache Redis Cluster (cluster mode enabled)
> - 3 master nodes (cache.r5.large, 13 GB each)
> - 3 read replicas (1 per master)
> - Total capacity: ~39 GB
> - Multi-AZ: Yes
> - Automatic failover: Enabled
> - Backup: Daily snapshots to S3
> ```
> 
> **Monitoring for Scaling Decisions:**
> *- Memory > 80% → Add nodes or scale up*
> *- CPU > 75% → Add read replicas*
> *- Evictions > 1000/min → Increase memory*
> *- Network throughput > 80% → Scale up instance type*"*

---

### Q6: "Explain Redis persistence. RDB vs AOF?"

**Your Answer:**

> *"Redis offers two persistence mechanisms, and you can use both together:*
> 
> **RDB (Redis Database Snapshot):**
> *- Point-in-time snapshot saved to disk*
> *- Happens at intervals: every 5 min if 10+ writes*
> *- Fork process to avoid blocking reads/writes*
> *- Compact binary format, fast restarts*
> *- **Downside:** Lose last 5-15 minutes of writes if crash*
> 
> **AOF (Append-Only File):**
> *- Logs every write operation*
> *- Can sync every second or every command*
> *- Replay log on restart to rebuild dataset*
> *- **Downside:** Larger files, slower restarts*
> 
> **When to Use What:**
> 
> *In a production environment, we use **RDB** for our cache:*
> *- It's acceptable to lose cache data on crash*
> *- We can rebuild from MySQL (source of truth)*
> *- Fast restarts are important*
> *- Daily backup to S3 for disaster recovery*
> 
> *If we were using Redis as **primary storage** (e.g., session store for financial transactions), I'd use **AOF with appendfsync everysec**:*
> *- Max 1 second of data loss*
> *- Worth the slower restart*
> 
> **Hybrid Approach (Recommended for Critical Data):**
> ```redis
> appendonly yes
> appendfsync everysec
> save 900 1     # RDB backup every 15 min
> ```
> *- AOF for durability*
> *- RDB for fast backups and disaster recovery*
> 
> **Real-World Trade-off:**
> *- Cache use case: RDB is sufficient (our choice)*
> *- Session store: AOF (1 sec loss acceptable)*
> *- Financial transactions: Database is source of truth, not Redis*"*

---

### Q7: "What's the cache stampede problem and how do you prevent it?"

**Your Answer:**

> *"Cache stampede happens when a popular cache key expires and hundreds of requests hit simultaneously, all missing cache and hitting the database:*
> 
> **Scenario:**
> *1. Key `homepage:data` with 1-hour TTL expires at 3:00 PM*
> *2. 1000 concurrent requests at 3:00:01 PM*
> *3. All see cache miss*
> *4. All query database simultaneously*
> *5. Database CPU spikes to 100%, site slows down*
> 
> **Solutions I've Implemented:**
> 
> **1. Probabilistic Early Refresh (Best IMO):**
> *- Randomly refresh cache 1-5 min before actual expiry*
> *- Spreads out refresh load*
> ```php
> $expiresAt = $data['expires_at'];
> $delta = $expiresAt - time();
> $randomRefresh = $delta * log(rand() / getrandmax());
> if ($randomRefresh < 0) {
>     $this->refreshInBackground($key);
> }
> ```
> 
> **2. Distributed Lock (Request Coalescing):**
> *- First request acquires lock (SETNX) and loads from DB*
> *- Other requests wait briefly and retry*
> *- Only 1 DB query happens*
> ```php
> $lockAcquired = Redis::set("lock:$key", 1, 'NX', 'EX', 10);
> if ($lockAcquired) {
>     $data = DB::query(...);
>     Redis::setex($key, 3600, $data);
> } else {
>     sleep(0.05); // 50ms
>     return $this->getFromCache($key); // Retry
> }
> ```
> 
> **3. Stagger TTLs:**
> *- Instead of fixed 3600s, use random: `rand(3400, 3600)`*
> *- Prevents all keys expiring at same time*
> 
> **4. Cache Warming:**
> *- Refresh popular keys in background cron job*
> *- Before they expire*
> 
> **What We Use In a production environment:**
> *- Staggered TTLs (simple, effective)*
> *- Locks for very expensive queries (reports)*
> *- Monitor DB query spikes as early warning*"*

---

### Q8: "How do you monitor and troubleshoot Redis performance issues?"

**Your Answer:**

> *"In a production environment, we monitor Redis through AWS CloudWatch and direct Redis commands:*
> 
> **Key Metrics We Track:**
> 
> **1. Hit Rate (Most Important):**
> ```
> Hit Rate = CacheHits / (CacheHits + CacheMisses) × 100%
> 
> Our target: > 95%
> ```
> *- If < 80%, investigate:*
>   *- TTL too short?*
>   *- Cache too small (evictions)?*
>   *- Wrong keys being cached?*
> 
> **2. Memory Usage:**
> ```redis
> INFO memory
> used_memory: 4.2GB
> used_memory_rss: 4.8GB
> mem_fragmentation_ratio: 1.14  # Good (< 1.5)
> ```
> *- Alarm at 80% memory*
> *- If fragmentation > 1.5, restart Redis*
> 
> **3. Evictions:**
> ```redis
> INFO stats
> evicted_keys: 150  # per second
> ```
> *- Means cache is too small*
> *- Alarm at > 1000 evictions/min*
> *- Solution: Increase memory or optimize key size*
> 
> **4. CPU Usage:**
> *- Single-threaded, so > 75% means bottleneck*
> *- Investigate:*
>   *- Slow commands (KEYS, SMEMBERS on large sets)*
>   *- Large values (> 1 MB)*
> 
> **5. Latency:**
> ```redis
> SLOWLOG GET 10  # Commands taking > 10ms
> ```
> *- Normal: < 1ms average*
> *- Slow: > 10ms (investigate)*
> 
> **6. Connections:**
> ```redis
> INFO clients
> connected_clients: 250
> ```
> *- Max: 10,000 connections*
> *- If growing unbounded: connection leak*
> 
> **Troubleshooting Workflow:**
> 
> **Symptom: High DB Load**
> *1. Check cache hit rate*
> *2. Check eviction rate*
> *3. Increase cache size or optimize TTLs*
> 
> **Symptom: Slow Redis Response**
> *1. `SLOWLOG GET` — identify slow commands*
> *2. `INFO commandstats` — most frequent commands*
> *3. Look for `KEYS`, large `SMEMBERS`, big values*
> *4. Use `SCAN` instead of `KEYS`*
> 
> **Symptom: Memory Full**
> *1. `INFO memory` — check fragmentation*
> *2. Find largest keys: `redis-cli --bigkeys`*
> *3. Review TTLs (too long?)*
> *4. Scale up instance*
> 
> **Production Incident Example (Enterprise SaaS Company):**
> *- Cache hit rate dropped from 95% to 60%*
> *- Evictions spiked to 5000/min*
> *- Root cause: New feature cached 10 MB objects*
> *- Solution: Moved large objects to S3, cached URLs only*
> *- Result: Hit rate back to 95%, evictions near zero*"*

---

### Q9: "Design a rate limiter using Redis."

**Your Answer:**

> *"I'd use Redis for rate limiting because it's fast, atomic, and distributed. Here's a sliding window implementation:*
> 
> **Requirements:**
> *- Limit: 100 requests per minute per user*
> *- Accurate (not allow bursts)*
> *- Distributed (works across multiple servers)*
> 
> **Solution: Sorted Set + Sliding Window**
> 
> ```php
> function isRateLimited($userId) {
>     $key = "rate_limit:$userId";
>     $now = microtime(true);
>     $windowStart = $now - 60; // 60 seconds ago
>     $limit = 100;
>     
>     // Remove requests older than 1 minute
>     Redis::zremrangebyscore($key, 0, $windowStart);
>     
>     // Count requests in current window
>     $count = Redis::zcard($key);
>     
>     if ($count < $limit) {
>         // Add current request (score = timestamp)
>         Redis::zadd($key, $now, $now); // Unique ID = timestamp
>         Redis::expire($key, 60); // Auto-cleanup
>         return false; // Not rate limited
>     }
>     
>     return true; // Rate limited
> }
> ```
> 
> **Why This Works:**
> *- Sorted set stores timestamps as scores*
> *- Sliding window: Only count last 60 seconds*
> *- Atomic operations (ZADD, ZREMRANGEBYSCORE)*
> *- Works across multiple servers*
> 
> **Alternative: Token Bucket (Simpler, But Allows Bursts):**
> ```php
> function checkTokenBucket($userId) {
>     $key = "tokens:$userId";
>     $tokens = Redis::get($key);
>     
>     if ($tokens === null) {
>         // First request - give 100 tokens
>         Redis::setex($key, 60, 99);
>         return true;
>     }
>     
>     if ($tokens > 0) {
>         Redis::decr($key);
>         return true;
>     }
>     
>     return false; // No tokens left
> }
> ```
> 
> **Production Considerations:**
> *1. **Multi-key operations:** Use Lua script for atomicity*
> ```lua
> local key = KEYS[1]
> local now = ARGV[1]
> local window = ARGV[2]
> local limit = ARGV[3]
> redis.call('zremrangebyscore', key, 0, now - window)
> local count = redis.call('zcard', key)
> if count < tonumber(limit) then
>     redis.call('zadd', key, now, now)
>     redis.call('expire', key, window)
>     return 1
> else
>     return 0
> end
> ```
> 
> *2. **Return info to client:***
> ```json
> {
>   "allowed": false,
>   "limit": 100,
>   "remaining": 0,
>   "reset_at": 1699000000
> }
> ```
> 
> *3. **Different limits per plan:***
> *- Free tier: 100/min*
> *- Pro tier: 1000/min*
> *- Enterprise: 10000/min*
> 
> *4. **Distributed across Redis cluster:***
> *- Use same user ID → same hash slot → same node*
> *- No cross-node transactions needed*
> 
> **Real-World Usage (Production API Gateway):**
> *- Rate limit API calls per customer*
> *- 1000 requests/min per tenant*
> *- Redis sorted set approach*
> *- Return 429 Too Many Requests when limited*"*

---

### Q10: "What are some Redis anti-patterns or things to avoid?"

**Your Answer:**

> *"From production experience In a production environment, here are key anti-patterns:*
> 
> **1. Using KEYS in Production (Blocks Entire Redis)**
> ```redis
> # BAD - scans all keys, O(N)
> KEYS customer:*
> 
> # GOOD - non-blocking, paginated
> SCAN 0 MATCH customer:* COUNT 100
> ```
> 
> **2. Storing Large Values (> 1 MB)**
> *- Redis is single-threaded*
> *- GET of 10 MB value blocks all other requests*
> *- **Solution:** Store in S3, cache URL/metadata in Redis*
> 
> **3. No TTL on Keys (Memory Leak)**
> *- Without TTL, keys never expire*
> *- Eventually run out of memory*
> *- **Always set expiration:** `SETEX key 3600 value`*
> 
> **4. Not Using Connection Pooling**
> *- Opening new connection per request is slow*
> *- TCP handshake + auth overhead*
> *- **Use persistent connections** (Laravel Redis does this)*
> 
> **5. Inefficient Serialization**
> ```php
> # Slow
> Redis::set('key', serialize($data));  # PHP serialize
> 
> # Fast
> Redis::set('key', json_encode($data));  # JSON
> 
> # Faster (for repeated fields)
> Redis::hset('user:1', 'name', 'John', 'email', 'john@example.com');
> ```
> 
> **6. Not Monitoring Hit Rate**
> *- If hit rate < 80%, cache isn't helping*
> *- Might be caching wrong data or TTL too short*
> 
> **7. Cache Stampede (Not Preventing)**
> *- All requests hit DB simultaneously when key expires*
> *- **Use:** Staggered TTLs, locks, early refresh*
> 
> **8. Using Redis as Primary Database**
> *- Redis is for caching or ephemeral data*
> *- **Critical data belongs in a real database** (MySQL, Postgres)*
> *- Even with AOF, Redis can lose data*
> 
> **9. Not Setting maxmemory-policy**
> ```redis
> # Without this, Redis crashes when full
> maxmemory 4gb
> maxmemory-policy allkeys-lru  # Evict least-recently-used
> ```
> 
> **10. Ignoring Replication Lag**
> *- Master-replica has async replication (milliseconds lag)*
> *- Read-after-write from replica might return stale data*
> *- **Solution:** Read from master for critical data*
> 
> **11. Using SELECT (Multiple Databases)**
> *- Redis supports 16 databases (0-15)*
> *- But doesn't work with clustering*
> *- **Better:** Use key prefixes (`app1:key`, `app2:key`)*
> 
> **12. Not Using Lua Scripts for Multi-Command Atomicity**
> ```php
> # Race condition - not atomic
> $current = Redis::get('counter');
> Redis::set('counter', $current + 1);
> 
> # Atomic
> Redis::eval('return redis.call("INCR", KEYS[1])', 1, 'counter');
> # Or just: Redis::incr('counter');
> ```
> 
> **Real Incident (Enterprise SaaS Company):**
> *- Developer used `KEYS customer:*` in production*
> *- Scanned 10 million keys*
> *- Blocked Redis for 5 seconds*
> *- 500 errors site-wide*
> *- **Fix:** Code review caught it after incident, now blocked by policy*"*

---

## Summary: Your Redis Talking Points

**When Asked About Caching:**

> *"In a production environment, I implemented Redis ElastiCache to cache customer settings for 10,000+ multi-tenant customers. This reduced database load by 80% and improved page load times from 800ms to 200ms.*
> 
> *Our architecture uses a clustered setup with 3 master nodes and read replicas across multiple availability zones. We maintain a 95%+ cache hit rate using cache-aside pattern with 1-hour TTLs.*
> 
> *I monitor key metrics like hit rate, evictions, and memory usage through CloudWatch. When we had cache stampede issues, I implemented probabilistic early refresh and distributed locks.*
> 
> *For session storage, we use Redis instead of file-based sessions so we can horizontally scale our web tier without sticky sessions."*

---

## Next Steps

1. **Practice drawing Redis architecture** on a whiteboard
2. **Memorize key metrics:** 95% hit rate, 80% DB reduction, 1-hour TTL
3. **Code the cache-aside pattern** from memory (you'll be asked to write code)
4. **Know the trade-offs:** RDB vs AOF, cache-aside vs write-through
5. **Review the 10 interview questions** above until you can answer without notes

---

**You now have deep Redis/Memcache knowledge backed by real production experience!** 🚀
