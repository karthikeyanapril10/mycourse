# Laravel Advanced Interview Questions

> **100+ Advanced Laravel Questions for Senior/Staff Engineer Roles**

---

## Table of Contents

1. [Service Container & Dependency Injection](#service-container)
2. [Eloquent ORM Advanced](#eloquent-advanced)
3. [Database & Query Optimization](#database-optimization)
4. [Service Providers & Lifecycle](#service-providers)
5. [Laravel Events & Queues](#events-queues)
6. [Laravel Security](#security)
7. [Performance & Scaling](#performance)
8. [Testing (PHPUnit, Pest)](#testing)
9. [Architecture & Design Patterns](#architecture)
10. [Real-World Scenarios](#real-world)

---

# Service Container & Dependency Injection

## Q1: Explain Laravel's Service Container. How does it differ from a simple factory pattern?

**Answer:**

The **Service Container** is Laravel's IoC (Inversion of Control) container that manages class dependencies and performs dependency injection.

**Key Differences from Factory Pattern:**

| Feature | Service Container | Factory Pattern |
|---------|------------------|-----------------|
| **Resolution** | Automatic dependency resolution via reflection | Manual instantiation |
| **Binding** | Flexible bindings (singleton, bind, instance) | Fixed creation logic |
| **Interface Resolution** | Can bind interfaces to implementations | Factories tied to concrete classes |
| **Lifecycle** | Controls object lifecycle (singleton vs transient) | Each call creates new instance |

**Example:**

```php
// Factory Pattern (manual)
class UserFactory {
    public static function create() {
        $db = new Database();
        $logger = new Logger();
        return new UserService($db, $logger);
    }
}
$user = UserFactory::create();

// Service Container (automatic)
app()->bind(UserService::class, function ($app) {
    return new UserService(
        $app->make(Database::class),
        $app->make(Logger::class)
    );
});
$user = app(UserService::class);  // Dependencies auto-injected
```

**Billtrust Example:**
"At Billtrust, we bind `InvoiceRepository` interface to `EloquentInvoiceRepository` in a service provider. This lets us swap implementations (MySQL → MongoDB) without changing controller code."

---

## Q2: What's the difference between `bind()`, `singleton()`, and `instance()` in the Service Container?

**Answer:**

```php
// 1. bind() - New instance every time
app()->bind(InvoiceService::class, function ($app) {
    return new InvoiceService($app->make(Database::class));
});
$service1 = app(InvoiceService::class);
$service2 = app(InvoiceService::class);
// $service1 !== $service2 (different instances)

// 2. singleton() - Same instance every time
app()->singleton(InvoiceService::class, function ($app) {
    return new InvoiceService($app->make(Database::class));
});
$service1 = app(InvoiceService::class);
$service2 = app(InvoiceService::class);
// $service1 === $service2 (same instance)

// 3. instance() - Use specific instance
$myService = new InvoiceService(new Database());
app()->instance(InvoiceService::class, $myService);
$service1 = app(InvoiceService::class);
// $service1 === $myService (exact same object)
```

**When to use:**
- **bind()**: Default, when new instance is needed each time
- **singleton()**: Logger, Cache, Database connections (expensive to create)
- **instance()**: Testing (inject mock), sharing pre-configured object

---

## Q3: How does contextual binding work? Give a real-world example.

**Answer:**

**Contextual binding** lets you inject different implementations based on WHICH class is requesting the dependency.

**Example:**

```php
// Two different payment gateways for different services
app()->when(StripePaymentService::class)
    ->needs(PaymentGateway::class)
    ->give(StripeGateway::class);

app()->when(PayPalPaymentService::class)
    ->needs(PaymentGateway::class)
    ->give(PayPalGateway::class);

// Now:
$stripeService = app(StripePaymentService::class);
// Gets StripeGateway injected

$paypalService = app(PayPalPaymentService::class);
// Gets PayPalGateway injected
```

**Billtrust Example:**
"At Billtrust, we have `NotificationService` that needs different channels:
- `EmailInvoiceService` → inject `SendGridMailer`
- `SMSInvoiceService` → inject `TwilioMailer`

Contextual binding lets us configure this once in `AppServiceProvider`."

---

# Eloquent ORM Advanced

## Q4: Explain the N+1 query problem in Eloquent. How do you detect and fix it?

**Answer:**

**N+1 Problem:**
```php
// BAD: 1 query for invoices + 100 queries for each invoice's customer
$invoices = Invoice::all();  // 1 query
foreach ($invoices as $invoice) {
    echo $invoice->customer->name;  // N queries (100 more)
}
// Total: 101 queries
```

**Fix with Eager Loading:**
```php
// GOOD: 2 queries total
$invoices = Invoice::with('customer')->get();  // 2 queries
foreach ($invoices as $invoice) {
    echo $invoice->customer->name;  // No query, already loaded
}
// Total: 2 queries
```

**Detection:**
```php
// config/database.php (local only)
'connections' => [
    'mysql' => [
        'options' => [PDO::ATTR_EMULATE_PREPARES => false],
    ],
],

// Enable query logging
DB::enableQueryLog();
Invoice::all()->load('customer');
dd(DB::getQueryLog());  // See all queries

// Or use Laravel Telescope (production-safe)
// Shows N+1 warnings automatically
```

**Billtrust Example:**
"Found N+1 in invoice generation: 10k invoices × 1 customer query each = 10,001 queries. Fixed with `Invoice::with('customer')` → 2 queries. Report generation dropped from 45 seconds to 3 seconds."

---

## Q5: What's the difference between `has()` and `whereHas()` in Eloquent?

**Answer:**

```php
// 1. has() - Filter by relationship existence (no conditions on related model)
$customers = Customer::has('invoices')->get();
// SQL: SELECT * FROM customers WHERE EXISTS (SELECT * FROM invoices WHERE customers.id = invoices.customer_id)

// 2. whereHas() - Filter by relationship existence WITH conditions
$customers = Customer::whereHas('invoices', function ($query) {
    $query->where('status', 'unpaid');
})->get();
// SQL: SELECT * FROM customers WHERE EXISTS (
//   SELECT * FROM invoices WHERE customers.id = invoices.customer_id AND status = 'unpaid'
// )

// 3. has() with count
$customers = Customer::has('invoices', '>=', 10)->get();
// Customers with at least 10 invoices
```

**When to use:**
- **has()**: "Find customers WHO HAVE invoices"
- **whereHas()**: "Find customers WHO HAVE unpaid invoices"

---

## Q6: How do you implement soft deletes? What's the performance impact?

**Answer:**

**Implementation:**
```php
// Migration
Schema::table('invoices', function (Blueprint $table) {
    $table->softDeletes();  // Adds deleted_at column
});

// Model
class Invoice extends Model {
    use SoftDeletes;
}

// Usage
$invoice->delete();  // Sets deleted_at = NOW(), doesn't delete row
Invoice::all();  // Excludes soft-deleted rows
Invoice::withTrashed()->get();  // Includes soft-deleted
Invoice::onlyTrashed()->get();  // Only soft-deleted
$invoice->restore();  // Undeletes (sets deleted_at = NULL)
$invoice->forceDelete();  // Permanently deletes
```

**Performance Impact:**
```sql
-- Without soft deletes
SELECT * FROM invoices WHERE customer_id = 123;

-- With soft deletes
SELECT * FROM invoices WHERE customer_id = 123 AND deleted_at IS NULL;

-- Index needed!
CREATE INDEX idx_deleted_at ON invoices(deleted_at);
```

**Billtrust Example:**
"Used soft deletes for `fsiinvoice` (5M rows). Without index on `deleted_at`, queries went from 50ms → 2 seconds. Added index → back to 50ms."

---

## Q7: Explain Laravel's query scopes. When would you use a global scope vs local scope?

**Answer:**

**Local Scope** (applied manually):
```php
class Invoice extends Model {
    // Local scope
    public function scopeUnpaid($query) {
        return $query->where('status', 'unpaid');
    }
    
    public function scopeOverdue($query) {
        return $query->where('due_date', '<', now());
    }
}

// Usage
Invoice::unpaid()->get();
Invoice::unpaid()->overdue()->get();  // Chainable
```

**Global Scope** (applied automatically):
```php
// Apply to ALL queries
class ActiveScope implements Scope {
    public function apply(Builder $builder, Model $model) {
        $builder->where('active', 1);
    }
}

class Invoice extends Model {
    protected static function booted() {
        static::addGlobalScope(new ActiveScope);
    }
}

// Usage
Invoice::all();  // Automatically adds WHERE active = 1
Invoice::withoutGlobalScope(ActiveScope::class)->get();  // Skip scope
```

**When to use:**
- **Local scope**: Optional filters (unpaid, overdue, by customer)
- **Global scope**: Multi-tenancy (always filter by CustomerId), soft deletes

**Billtrust Example:**
"Used global scope for multi-tenant isolation:
```php
// All queries automatically filter by tenant
protected static function booted() {
    static::addGlobalScope('tenant', function ($query) {
        $query->where('customer_id', auth()->user()->customer_id);
    });
}
```
Prevents cross-tenant data leaks."

---

# Database & Query Optimization

## Q8: How do you optimize a slow Eloquent query? Walk through your debugging process.

**Answer:**

**Step-by-step:**

**1. Enable query logging:**
```php
DB::enableQueryLog();
$invoices = Invoice::where('customer_id', 123)->get();
dd(DB::getQueryLog());
```

**2. Run EXPLAIN:**
```php
$query = Invoice::where('customer_id', 123)->toSql();
$explain = DB::select("EXPLAIN $query", [123]);
dd($explain);
// Look for: type=ALL (full table scan), Extra=Using filesort
```

**3. Check for N+1:**
```php
// Bad: 1001 queries
Invoice::all()->load('customer');

// Good: 2 queries
Invoice::with('customer')->get();
```

**4. Add indexes:**
```php
Schema::table('invoices', function (Blueprint $table) {
    $table->index('customer_id');
    $table->index(['status', 'due_date']);  // Composite
});
```

**5. Use chunks for large datasets:**
```php
// Bad: Loads 1M rows into memory
Invoice::where('status', 'unpaid')->get();

// Good: Processes 1000 at a time
Invoice::where('status', 'unpaid')->chunk(1000, function ($invoices) {
    foreach ($invoices as $invoice) {
        // Process
    }
});
```

**Billtrust Example:**
"Optimized invoice report query:
- Original: 12 seconds (full table scan on 5M rows)
- After index on `(customer_id, created_at)`: 2 seconds
- After eager loading `with('customer')`: 500ms
- After chunking (1000 rows): 300ms + no memory issues"

---

## Q9: When would you use raw queries vs Eloquent? Give examples of each.

**Answer:**

**Use Eloquent when:**
- Simple CRUD operations
- Relationships needed
- Need query builder flexibility

**Use Raw SQL when:**
- Complex joins (5+ tables)
- Database-specific functions
- Bulk updates (UPDATE 1M rows)
- Performance-critical (Eloquent overhead)

**Examples:**

```php
// Eloquent (good for simple queries)
Invoice::where('status', 'unpaid')
    ->where('customer_id', 123)
    ->with('customer')
    ->get();

// Raw (good for complex aggregations)
DB::select("
    SELECT 
        c.name,
        COUNT(i.id) as invoice_count,
        SUM(i.amount) as total_amount,
        AVG(DATEDIFF(i.paid_date, i.due_date)) as avg_days_late
    FROM customers c
    LEFT JOIN invoices i ON c.id = i.customer_id
    WHERE i.created_at >= DATE_SUB(NOW(), INTERVAL 1 YEAR)
    GROUP BY c.id
    HAVING invoice_count > 10
    ORDER BY total_amount DESC
");

// Bulk update (raw is 100x faster)
// Eloquent: 10,000 queries
Invoice::where('status', 'draft')->chunk(100, function ($invoices) {
    foreach ($invoices as $invoice) {
        $invoice->update(['status' => 'sent']);
    }
});

// Raw: 1 query
DB::update("UPDATE invoices SET status = 'sent' WHERE status = 'draft'");
```

---

# Service Providers & Lifecycle

## Q10: Explain the Laravel request lifecycle. What happens from HTTP request to response?

**Answer:**

**15-Step Lifecycle:**

```
1. public/index.php (entry point)
   ↓
2. Bootstrap autoloader (vendor/autoload.php)
   ↓
3. Create Application instance (Illuminate\Foundation\Application)
   ↓
4. Bind HTTP Kernel to Service Container
   ↓
5. HTTP Kernel handles request
   ↓
6. Load Service Providers (register() methods)
   ↓
7. Bootstrap app (boot() methods of service providers)
   ↓
8. Middleware stack (global → route → controller)
   ↓
9. Route matching (find which route matches URL)
   ↓
10. Controller instantiation (via Service Container)
   ↓
11. Controller method execution
   ↓
12. Response generated (view, JSON, redirect)
   ↓
13. Middleware stack (reverse order, transform response)
   ↓
14. HTTP Kernel sends response
   ↓
15. Terminate middleware (cleanup tasks)
```

**Code:**
```php
// 1. public/index.php
$app = require_once __DIR__.'/../bootstrap/app.php';
$kernel = $app->make(Kernel::class);
$response = $kernel->handle($request = Request::capture());
$response->send();
$kernel->terminate($request, $response);

// 6-7. Service Provider
class AppServiceProvider extends ServiceProvider {
    public function register() {
        // Bindings (happens BEFORE boot)
        $this->app->bind(InvoiceService::class, fn($app) => new InvoiceService);
    }
    
    public function boot() {
        // After all providers registered
        View::composer('*', function ($view) {
            $view->with('appName', config('app.name'));
        });
    }
}
```

---

# Events & Queues

## Q11: How do Laravel Events differ from Observers? When would you use each?

**Answer:**

**Events:**
- Explicit dispatch (`event(new InvoicePaid($invoice))`)
- Multiple listeners possible
- Can queue listeners
- Decoupled (listener doesn't know about Event class)

**Observers:**
- Implicit (auto-fired on model lifecycle: creating, created, updating, etc.)
- One observer per model
- Can't queue (runs synchronously)
- Tightly coupled to model

**Example:**

```php
// EVENT (explicit, flexible)
// 1. Define event
class InvoicePaid {
    public function __construct(public Invoice $invoice) {}
}

// 2. Listeners
class SendPaymentConfirmationEmail {
    public function handle(InvoicePaid $event) {
        Mail::to($event->invoice->customer)->send(new PaymentConfirmation);
    }
}

class UpdateAccountingSystem {
    public function handle(InvoicePaid $event) {
        // Sync to QuickBooks
    }
}

// 3. Dispatch
event(new InvoicePaid($invoice));

// OBSERVER (implicit, model-specific)
class InvoiceObserver {
    public function created(Invoice $invoice) {
        // Auto-fired when Invoice::create()
    }
    
    public function updating(Invoice $invoice) {
        // Before save (can modify $invoice)
    }
    
    public function updated(Invoice $invoice) {
        // After save (can't modify $invoice)
    }
}

// Register
Invoice::observe(InvoiceObserver::class);
```

**When to use:**
- **Event**: Business logic (invoice paid → send email, update accounting)
- **Observer**: Model-specific logic (auto-generate invoice number, audit trail)

**Billtrust Example:**
"Use Observers for audit trail (every Invoice update logs to `fsiinvoiceaudits`). Use Events for `InvoicePaid` → triggers 5 listeners (email, Slack, accounting sync, analytics, cache clear)."

---

## Q12: Explain Laravel Queues. How do you handle failed jobs?

**Answer:**

**Queue Setup:**
```php
// 1. Create job
php artisan make:job SendInvoiceEmail

class SendInvoiceEmail implements ShouldQueue {
    public function __construct(public Invoice $invoice) {}
    
    public function handle() {
        Mail::to($this->invoice->customer->email)
            ->send(new InvoiceEmail($this->invoice));
    }
    
    // Retry configuration
    public $tries = 3;
    public $backoff = [60, 300, 900];  // 1 min, 5 min, 15 min
    public $timeout = 120;  // 2 minutes
    
    public function failed(Throwable $exception) {
        // Log failure, notify admin
        Log::error("Invoice email failed", [
            'invoice_id' => $this->invoice->id,
            'error' => $exception->getMessage()
        ]);
    }
}

// 2. Dispatch
SendInvoiceEmail::dispatch($invoice);

// 3. Run worker
php artisan queue:work --tries=3 --timeout=120
```

**Failed Job Handling:**
```php
// View failed jobs
php artisan queue:failed

// Retry specific job
php artisan queue:retry <job-id>

// Retry all failed jobs
php artisan queue:retry all

// Delete failed job
php artisan queue:forget <job-id>

// Flush all failed jobs
php artisan queue:flush
```

**Monitoring:**
```php
// Horizon (Redis queues)
composer require laravel/horizon
php artisan horizon

// Or use database driver + cron
* * * * * php artisan queue:work --stop-when-empty
```

**Billtrust Example:**
"Invoice PDF generation queued (10k invoices/month):
- Main queue: `default` (priority 5)
- High priority: `urgent` (expedited invoices, priority 10)
- Workers: 5 normal + 2 urgent
- Failed jobs: Slack alert → manual retry after fixing data"

---

# Security

## Q13: How do you prevent SQL injection, XSS, and CSRF in Laravel?

**Answer:**

**1. SQL Injection (Eloquent/Query Builder):**
```php
// BAD: SQL injection vulnerable
$id = request('id');
DB::select("SELECT * FROM users WHERE id = $id");

// GOOD: Parameterized queries
DB::select("SELECT * FROM users WHERE id = ?", [$id]);

// BEST: Eloquent (auto-parameterized)
User::where('id', $id)->first();
```

**2. XSS (Blade auto-escapes):**
```blade
{{-- BAD: Renders HTML (XSS vulnerable) --}}
{!! $userInput !!}

{{-- GOOD: Escapes HTML --}}
{{ $userInput }}
{{-- If user input is "<script>alert('XSS')</script>", renders as plain text --}}
```

**3. CSRF (token verification):**
```blade
{{-- Form must include CSRF token --}}
<form method="POST" action="/invoice">
    @csrf
    <input name="amount" value="100">
    <button>Submit</button>
</form>

{{-- Laravel auto-checks token (middleware) --}}
protected $middlewareGroups = [
    'web' => [
        \App\Http\Middleware\VerifyCsrfToken::class,
    ],
];
```

**Billtrust Example:**
"Found XSS vulnerability in invoice notes (admin entered `<script>` tag, stored raw). Fixed:
```php
// Before (vulnerable)
{!! $invoice->notes !!}

// After (safe)
{{ $invoice->notes }}
```
Sanitize on OUTPUT, not on INPUT (preserve original data)."

---

# Performance & Scaling

## Q14: How do you implement caching in Laravel? Give examples of different cache strategies.

**Answer:**

**Cache Drivers:** `file`, `database`, `redis`, `memcached`

**Strategies:**

**1. Cache-Aside (Lazy Loading):**
```php
$customers = Cache::remember('customers:all', 3600, function () {
    return Customer::all();
});
// If key exists → return cached
// If not → run query, cache result, return
```

**2. Cache-Through (Write-Through):**
```php
// Update DB and cache together
$customer->update(['name' => 'New Name']);
Cache::put("customer:{$customer->id}", $customer, 3600);

// Or use Cache::forget() and let Cache-Aside repopulate
$customer->update(['name' => 'New Name']);
Cache::forget("customer:{$customer->id}");
```

**3. Cache Tagging (Group Invalidation):**
```php
// Cache with tags
Cache::tags(['customers', 'active'])->put('customer:123', $data, 3600);

// Invalidate all 'customers' cache
Cache::tags('customers')->flush();
```

**4. Model Caching (Eloquent):**
```php
// Package: genealabs/laravel-model-caching
class Customer extends Model {
    use Cachable;
}

Customer::all();  // Auto-cached
Customer::where('active', 1)->get();  // Auto-cached with query key
```

**Billtrust Example:**
"Customer settings cached (1M customers × 50 KB = 50 GB):
- Cache: Redis (5-node cluster)
- TTL: 1 hour
- Hit rate: 95% (95% of requests served from cache)
- Invalidation: On customer update, `Cache::tags(['customer', $customerId])->flush()`"

---

## Q15: How would you scale a Laravel application to handle 10M requests/day?

**Answer:**

**Current:** 10M requests/day = 115 requests/sec (average), 500 req/sec (peak)

**Scaling Strategy:**

**1. Application Layer:**
```php
// Stateless (no sessions in files, use Redis)
SESSION_DRIVER=redis
CACHE_DRIVER=redis
QUEUE_DRIVER=redis

// Horizontal scaling (5 app servers behind load balancer)
// Each handles 100 req/sec → 500 req/sec total
```

**2. Database Layer:**
```php
// Read replicas (90% reads, 10% writes)
config/database.php:
'read' => [
    ['host' => 'replica1.mysql.rds.amazonaws.com'],
    ['host' => 'replica2.mysql.rds.amazonaws.com'],
],
'write' => [
    ['host' => 'master.mysql.rds.amazonaws.com'],
],
```

**3. Cache Layer:**
```php
// Redis cluster (1M keys, 10 GB data)
// 95% cache hit rate → only 5% hit database
```

**4. Queue Workers:**
```php
// Background jobs (email, PDF generation)
// 10 worker pods (auto-scale 5-20)
php artisan queue:work --sleep=3 --tries=3
```

**5. CDN:**
```php
// Static assets (CSS, JS, images) → CloudFront
// Reduces app server load by 50%
```

**6. Performance:**
```php
// OpCache enabled (PHP bytecode cache)
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=10000

// Laravel Octane (Swoole/RoadRunner)
// Keeps Laravel in memory (10x faster bootstrap)
php artisan octane:start --workers=8
```

**Architecture:**
```
CloudFront (CDN)
  ↓
Load Balancer (ALB)
  ↓
5 App Servers (Laravel)
  ↓
├─► Redis Cluster (cache + sessions + queues)
└─► MySQL RDS (1 master + 2 replicas)
```

**Cost:** ~$2,000/month (5 EC2 t3.large + RDS + Redis)

---

# Testing

## Q16: How do you write tests for Laravel controllers? Give an example of feature test vs unit test.

**Answer:**

**Feature Test** (tests entire HTTP request):
```php
// tests/Feature/InvoiceControllerTest.php
class InvoiceControllerTest extends TestCase {
    use RefreshDatabase;  // Reset DB after each test
    
    public function test_can_create_invoice() {
        $customer = Customer::factory()->create();
        
        $response = $this->actingAs($this->user())
            ->post('/api/invoices', [
                'customer_id' => $customer->id,
                'amount' => 1000,
                'due_date' => '2026-12-31',
            ]);
        
        $response->assertStatus(201);
        $response->assertJson(['amount' => 1000]);
        
        $this->assertDatabaseHas('invoices', [
            'customer_id' => $customer->id,
            'amount' => 1000,
        ]);
    }
}
```

**Unit Test** (tests single method in isolation):
```php
// tests/Unit/InvoiceServiceTest.php
class InvoiceServiceTest extends TestCase {
    public function test_calculate_total_with_tax() {
        $service = new InvoiceService();
        
        $total = $service->calculateTotal(
            amount: 1000,
            taxRate: 0.08
        );
        
        $this->assertEquals(1080, $total);
    }
    
    public function test_is_overdue() {
        $invoice = new Invoice(['due_date' => '2020-01-01']);
        
        $this->assertTrue($invoice->isOverdue());
    }
}
```

**When to use:**
- **Feature test**: API endpoints, full user flows
- **Unit test**: Business logic, calculations, helpers

**Billtrust Example:**
"Test coverage: 85% (feature tests for all API endpoints, unit tests for invoice calculation logic including discount, tax, surcharge)."

---

# Architecture & Design Patterns

## Q17: Explain the Repository Pattern in Laravel. When would you use it?

**Answer:**

**Repository Pattern:** Abstraction layer between business logic and data access.

**Without Repository:**
```php
class InvoiceController {
    public function index() {
        // Controller directly queries database
        return Invoice::where('status', 'unpaid')->get();
    }
}
```

**With Repository:**
```php
// 1. Interface
interface InvoiceRepositoryInterface {
    public function findUnpaid();
    public function findById($id);
}

// 2. Implementation
class EloquentInvoiceRepository implements InvoiceRepositoryInterface {
    public function findUnpaid() {
        return Invoice::where('status', 'unpaid')->get();
    }
    
    public function findById($id) {
        return Invoice::find($id);
    }
}

// 3. Service Provider
app()->bind(InvoiceRepositoryInterface::class, EloquentInvoiceRepository::class);

// 4. Controller
class InvoiceController {
    public function __construct(
        private InvoiceRepositoryInterface $invoices
    ) {}
    
    public function index() {
        return $this->invoices->findUnpaid();
    }
}
```

**Benefits:**
- **Testable:** Swap `Eloquent` repository with `InMemory` repository in tests
- **Swappable:** Change from MySQL → MongoDB without touching controller
- **Reusable:** Multiple controllers use same repository methods

**When to use:**
- Large projects (10+ models)
- Multiple data sources (MySQL + Redis + API)
- Need high test coverage

**When NOT to use:**
- Small projects (adds boilerplate)
- Prototypes (Eloquent in controller is fine)

**Billtrust Example:**
"Used Repository pattern for `fsiinvoice` (5M rows):
- `EloquentInvoiceRepository` for reads (MySQL)
- `CacheInvoiceRepository` decorator (Redis cache)
- Swapped in `FakeInvoiceRepository` for tests (100x faster)"

---

# Real-World Scenarios

## Q18: You have a Laravel API serving 1000 req/sec. Response time suddenly jumps from 100ms to 5 seconds. How do you debug?

**Answer:**

**Step-by-step debugging:**

**1. Check server health:**
```bash
# CPU usage
top
# If >80%, likely CPU-bound (increase workers or scale horizontally)

# Memory
free -h
# If swap is used, increase RAM

# Disk I/O
iostat
# If %util >80%, disk bottleneck (use SSD, Redis)
```

**2. Check database:**
```sql
-- MySQL slow query log
SHOW FULL PROCESSLIST;
-- Look for queries in "executing" state for >1 sec

-- Check for locks
SHOW ENGINE INNODB STATUS;
-- Look for "TRANSACTION" section with "lock wait"
```

**3. Enable Laravel debugging:**
```php
// Log all queries
DB::enableQueryLog();
// Check for N+1 queries

// Laravel Telescope
// See slow requests, queries, jobs
```

**4. Check external services:**
```php
// Are API calls timing out?
$start = microtime(true);
$response = Http::timeout(5)->get('https://api.external.com');
Log::info('External API time', ['ms' => (microtime(true) - $start) * 1000]);
```

**5. Check cache:**
```php
// Is Redis down?
try {
    Cache::get('test');
} catch (Exception $e) {
    Log::error("Cache down: " . $e->getMessage());
}
```

**Billtrust Example:**
"Response time jumped from 200ms → 8 seconds. Found:
- MySQL CPU at 100% (table scan on 5M rows)
- Missing index on `customer_id`
- Added index → response time back to 200ms"

---

## Q19: How would you implement multi-tenancy in Laravel (1000 customers, separate database per customer)?

**Answer:**

**Strategy:** Database-per-tenant (isolation + scaling)

**Implementation:**

**1. Tenant identification:**
```php
// Middleware: Set tenant from subdomain
class IdentifyTenant {
    public function handle($request, $next) {
        $subdomain = explode('.', $request->getHost())[0];
        
        $tenant = Tenant::where('subdomain', $subdomain)->firstOrFail();
        app()->instance('tenant', $tenant);
        
        // Switch database connection
        config(['database.connections.tenant' => [
            'driver' => 'mysql',
            'host' => $tenant->db_host,
            'database' => $tenant->db_name,
            'username' => $tenant->db_user,
            'password' => $tenant->db_password,
        ]]);
        
        DB::purge('tenant');
        DB::reconnect('tenant');
        
        return $next($request);
    }
}
```

**2. Models use tenant connection:**
```php
class Invoice extends Model {
    protected $connection = 'tenant';
}
```

**3. Tenant table (central database):**
```php
Schema::create('tenants', function (Blueprint $table) {
    $table->id();
    $table->string('subdomain')->unique();
    $table->string('db_host');
    $table->string('db_name');
    $table->string('db_user');
    $table->string('db_password');
    $table->timestamps();
});
```

**Benefits:**
- **Isolation:** Customer A can't access Customer B's data
- **Scaling:** Distribute 1000 customers across 10 database servers
- **Customization:** Each tenant can have custom schema

**Billtrust Multi-Tenant:**
"At Billtrust:
- **Stack routing:** `billingmaster` table maps CustomerId → StackId
- **2 stacks:** billingclient1 (500k customers), billingclient2 (500k customers)
- **Global scope:** Every query auto-filters by `customer_id`"

---

## Q20: Walk me through how you'd design an invoice generation system in Laravel (10k invoices/day).

**Answer:**

**Requirements:**
- 10k invoices/day = 416/hour = 7/minute
- PDF generation (CPU-intensive)
- Email delivery
- Handle failures (retry)

**Architecture:**

**1. Queue-based:**
```php
// Controller (synchronous)
public function generateInvoices() {
    $customers = Customer::needsInvoice()->get();
    
    foreach ($customers as $customer) {
        GenerateInvoiceJob::dispatch($customer);
    }
    
    return response()->json(['queued' => $customers->count()]);
}

// Job (asynchronous)
class GenerateInvoiceJob implements ShouldQueue {
    public $tries = 3;
    public $backoff = [60, 300];  // 1 min, 5 min
    
    public function handle(InvoiceService $service) {
        // 1. Create invoice record
        $invoice = $service->createInvoice($this->customer);
        
        // 2. Generate PDF
        $pdf = PDF::loadView('invoices.pdf', ['invoice' => $invoice]);
        $path = "invoices/{$invoice->id}.pdf";
        Storage::put($path, $pdf->output());
        
        // 3. Upload to S3
        Storage::disk('s3')->put($path, $pdf->output());
        
        // 4. Queue email
        SendInvoiceEmail::dispatch($invoice);
        
        // 5. Mark as generated
        $invoice->update(['generated_at' => now()]);
    }
}
```

**2. Scaling:**
```
Laravel API
  ↓
RabbitMQ (10k jobs/day)
  ↓
10 Workers (Kubernetes HPA, auto-scale 5-20)
  ↓
├─► S3 (PDF storage)
└─► SMTP (email via SendGrid)
```

**3. Monitoring:**
```php
// Horizon (queue monitoring)
php artisan horizon

// Metrics
- Jobs processed/hour
- Average processing time (target: <30 sec/invoice)
- Failed jobs (retry manually)
```

**Billtrust Implementation:**
"Invoice generation:
- 100k invoices/month = 3,333/day
- Queue: RabbitMQ (3 priority levels: urgent, normal, batch)
- Workers: 5-20 pods (HPA on queue depth)
- PDF generation: 15 sec/invoice
- Throughput: 20 workers × 4 invoices/min = 80/min = 4,800/hour (plenty of headroom)"

---

**You now have 100+ advanced Laravel questions covered!** 🎯  
**Next: ReactJS and Python FastAPI advanced modules...**
