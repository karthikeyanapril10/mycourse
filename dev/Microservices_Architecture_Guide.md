# Microservices Architecture Guide

**For Senior Software Engineer Interviews**

Your competitive advantage: **Production microservices experience** (EIC, CC, CSR, WCL, MPay — 5 independent services, API communication, event-driven architecture)

---

## Monolith vs Microservices

### Monolith (Single Codebase)

```
┌─────────────────────────────┐
│      Billing Application    │
│                             │
│  ┌─────────┐ ┌───────────┐ │
│  │ Invoice │ │  Payment  │ │
│  │ Module  │ │  Module   │ │
│  └─────────┘ └───────────┘ │
│  ┌─────────┐ ┌───────────┐ │
│  │Customer │ │   Email   │ │
│  │ Module  │ │  Module   │ │
│  └─────────┘ └───────────┘ │
│                             │
│     Single Database         │
└─────────────────────────────┘
```

**Pros:**
- Simple to develop (one codebase)
- Easy to deploy (one artifact)
- No network latency (in-process calls)

**Cons:**
- Hard to scale (must scale entire app)
- One bug crashes everything
- Long deployment times (test entire app)
- Hard to adopt new tech (stuck with same stack)

---

### Microservices (Distributed System)

```
┌──────────┐    ┌──────────┐    ┌──────────┐
│ Invoice  │    │ Payment  │    │ Customer │
│ Service  │◄──►│ Service  │◄──►│ Service  │
│          │    │          │    │          │
│ DB: MySQL│    │ DB: MySQL│    │ DB: Postgres │
└──────────┘    └──────────┘    └──────────┘
     │               │               │
     └───────────────┴───────────────┘
                     │
              ┌─────────────┐
              │   Kafka     │
              │ Event Bus   │
              └─────────────┘
```

**Pros:**
- Independent scaling (scale payment service 10x, invoice 2x)
- Fault isolation (payment down ≠ invoice down)
- Tech diversity (Invoice: PHP, Payment: .NET, Customer: Go)
- Fast deploys (deploy one service, not all)

**Cons:**
- Complex (distributed system challenges)
- Network latency (API calls instead of in-process)
- Data consistency (eventual, not ACID)
- Operational overhead (10 services = 10 deployments, 10 logs, 10 monitors)

---

## Production Microservices

### Architecture

```
┌────────────────────────────────────────────┐
│         API Gateway / Load Balancer        │
└─────┬──────┬──────┬──────┬──────┬─────────┘
      │      │      │      │      │
      v      v      v      v      v
   ┌─────┐ ┌────┐ ┌────┐ ┌────┐ ┌─────┐
   │ EIC │ │ CC │ │CSR │ │WCL │ │MPay │
   │(PHP)│ │(PHP│ │(PHP│ │(PHP│ │(PHP)│
   └──┬──┘ └─┬──┘ └─┬──┘ └─┬──┘ └──┬──┘
      │      │      │      │      │
      v      v      v      v      v
   ┌──────────────────────────────────┐
   │     Shared Infrastructure        │
   │  MySQL, Redis, Kafka, S3         │
   └──────────────────────────────────┘
```

**Services:**

1. **EIC (eInvoice Connect)** — Invoice presentation, buyer portal
2. **CC (Client Connect)** — Admin/settings, customer management
3. **CSR (Customer Settings Repository)** — Centralized settings API
4. **WCL (Web Communication Layer)** — Email/notification service
5. **MPay (Managed Pay)** — Payment processing

**Communication:**
- Synchronous: REST APIs (EIC → CSR)
- Asynchronous: Kafka events (Payment → Invoice)
- Shared: Redis (session cache), MySQL (tenant DBs)

---

## Service Communication Patterns

### 1. Synchronous (REST API)

**Use Case:** Real-time data fetch

```php
// EIC needs customer settings
class InvoiceController {
    private $csrClient;
    
    public function show($customerId) {
        // Call CSR service
        $settings = $this->csrClient->get("/api/v1/customers/$customerId/settings");
        
        // Use settings to render invoice
        return view('invoice', [
            'settings' => $settings,
            'invoice' => Invoice::find($customerId)
        ]);
    }
}
```

**Pros:**
- Simple
- Immediate response
- Strong consistency

**Cons:**
- Tight coupling (EIC down if CSR down)
- Latency (network call adds 50-100ms)
- Cascading failures

**Circuit Breaker Pattern:**
```php
class CircuitBreaker {
    private $failureThreshold = 5;
    private $timeout = 30; // seconds
    
    public function call($service, $request) {
        $failures = Redis::get("failures:$service") ?? 0;
        
        if ($failures >= $this->failureThreshold) {
            $openedAt = Redis::get("circuit_opened:$service");
            if (time() - $openedAt < $this->timeout) {
                throw new CircuitOpenException("$service is down");
            }
            // Try again after timeout
            Redis::del("circuit_opened:$service");
        }
        
        try {
            $response = Http::timeout(5)->get($request);
            Redis::set("failures:$service", 0); // Reset on success
            return $response;
        } catch (Exception $e) {
            Redis::incr("failures:$service");
            if (Redis::get("failures:$service") >= $this->failureThreshold) {
                Redis::set("circuit_opened:$service", time());
            }
            throw $e;
        }
    }
}
```

---

### 2. Asynchronous (Event-Driven)

**Use Case:** Eventually consistent state sync

```
Payment Service: Payment captured
   ↓
Kafka: payment.captured event
   ↓
Invoice Service: Mark invoice paid
Email Service: Send receipt
Analytics Service: Update dashboard
```

**Implementation:**
```php
// Payment service (producer)
class PaymentService {
    public function capturePayment($invoiceId, $amount) {
        // Process payment
        $payment = Payment::create([...]);
        
        // Publish event
        Kafka::publish('payment_events', [
            'event_type' => 'payment.captured',
            'invoice_id' => $invoiceId,
            'amount' => $amount,
            'payment_id' => $payment->id,
            'timestamp' => now()
        ]);
    }
}

// Invoice service (consumer)
class PaymentEventHandler {
    public function handlePaymentCaptured($event) {
        Invoice::where('id', $event['invoice_id'])
            ->update(['status' => 'paid', 'paid_at' => $event['timestamp']]);
    }
}
```

**Pros:**
- Loose coupling (services independent)
- High availability (async = no blocking)
- Scalable (add consumers without changing producer)

**Cons:**
- Eventual consistency (invoice not immediately paid)
- Complex debugging (trace across services)
- Duplicate handling (idempotency required)

---

### 3. Saga Pattern (Distributed Transaction)

**Use Case:** Multi-service transaction with rollback

```
Order → Payment → Inventory → Shipping

Success Path:
1. Order Service: Create order
2. Payment Service: Charge card
3. Inventory Service: Reserve items
4. Shipping Service: Create shipment

Failure Path (Compensating Transactions):
1. Payment Service: Card declined
2. Inventory Service: Nothing to rollback (never ran)
3. Order Service: Cancel order
```

**Orchestration-Based Saga:**
```php
// Saga orchestrator
class OrderSaga {
    public function execute($orderId) {
        try {
            // Step 1: Create order
            $order = OrderService::create($orderId);
            
            // Step 2: Charge payment
            $payment = PaymentService::charge($order->total);
            
            // Step 3: Reserve inventory
            $reservation = InventoryService::reserve($order->items);
            
            // Step 4: Create shipment
            $shipment = ShippingService::create($order);
            
            return ['status' => 'success'];
            
        } catch (PaymentException $e) {
            // Compensate: Cancel order
            OrderService::cancel($orderId);
            throw $e;
            
        } catch (InventoryException $e) {
            // Compensate: Refund payment, cancel order
            PaymentService::refund($payment->id);
            OrderService::cancel($orderId);
            throw $e;
        }
    }
}
```

**Choreography-Based Saga (Event-Driven):**
```
1. Order Service: order.created event
2. Payment Service: Listens, charges card
   → On success: payment.succeeded event
   → On failure: payment.failed event
3. Inventory Service: Listens to payment.succeeded, reserves items
   → inventory.reserved event
4. Order Service: Listens to payment.failed
   → Publishes order.cancelled event
```

---

## Data Management

### Database Per Service

```
✅ GOOD (Database per service):
Invoice Service → invoice_db (MySQL)
Payment Service → payment_db (MySQL)
Customer Service → customer_db (Postgres)

❌ BAD (Shared database):
All services → shared_db
```

**Why Separate?**
- Loose coupling (schema changes don't break other services)
- Technology flexibility (Invoice: MySQL, Customer: Postgres, Analytics: MongoDB)
- Independent scaling

**Challenge: Cross-Service Queries**

```
❌ BAD (Direct DB access):
Invoice Service queries Payment DB directly

✅ GOOD (API call):
Invoice Service → API → Payment Service → Payment DB

✅ BETTER (Event sourcing):
Payment Service publishes payment.captured event
Invoice Service maintains its own payment cache
```

**Your production setup:**
- Tenant DBs: `billingclient1`, `billingclient2` (shared across services)
- CSR: Centralized settings API (abstracts DB)
- Each service owns its tables

---

## Service Discovery

### Problem: How do services find each other?

**Static Configuration:**
```yaml
services:
  csr:
    url: https://csr.Enterprise SaaS Company.com
  payment:
    url: https://payment.Enterprise SaaS Company.com
```

**Service Discovery (Kubernetes):**
```yaml
# Service creates DNS entry
apiVersion: v1
kind: Service
metadata:
  name: csr
  namespace: invoicing-prod
# DNS: csr.invoicing-prod.svc.cluster.local
```

**EIC calls CSR:**
```php
$response = Http::get('http://csr.invoicing-prod.svc.cluster.local/api/v1/settings');
```

---

## API Gateway Pattern

### Centralized Entry Point

```
Client
  ↓
API Gateway (Kong, AWS API Gateway)
  ├─ /invoices/*     → EIC Service
  ├─ /payments/*     → Payment Service
  ├─ /customers/*    → Customer Service
  └─ /settings/*     → CSR Service
```

**Benefits:**
- Single endpoint for clients
- Centralized auth, rate limiting, logging
- Service routing (no client changes when service moves)

**API Gateway (Kong) Config:**
```yaml
services:
  - name: invoice-service
    url: http://eic.invoicing-prod.svc.cluster.local
    routes:
      - name: invoice-route
        paths:
          - /api/invoices

  - name: payment-service
    url: http://payment.invoicing-prod.svc.cluster.local
    routes:
      - name: payment-route
        paths:
          - /api/payments

plugins:
  - name: rate-limiting
    config:
      minute: 1000
  
  - name: jwt
    config:
      secret_is_base64: false
```

---

## Interview Questions & Answers

### Q1: "When would you use microservices vs a monolith?"

**Your Answer:**

> *"Start with a monolith, migrate to microservices when:*
> 
> **Use Monolith When:**
> *- **Small team** (< 10 developers) — overhead not worth it*
> *- **Simple domain** — e-commerce with 3 models (products, orders, users)*
> *- **Rapid iteration** — startup finding product-market fit*
> *- **Low scale** — < 1000 users, single server handles it*
> 
> **Migrate to Microservices When:**
> *- **Scaling bottlenecks** — payment service needs 10x instances, but invoice only 2x*
> *- **Team size** — 50+ developers, monolith = merge conflicts*
> *- **Deploy velocity** — want to deploy payment changes without testing entire app*
> *- **Fault isolation** — reporting crashes shouldn't take down checkout*
> *- **Technology diversity** — machine learning team wants Python, core app is PHP*
> 
> **In a production environment:**
> *- Started: Monolith (all PHP, single codebase)*
> *- Problem: Invoice changes required full regression test (3 days)*
> *- Solution: Split into 5 services (EIC, CC, CSR, WCL, MPay)*
> *- Result: Deploy invoice changes in 1 hour, payment independently*
> 
> **When NOT to Use Microservices:**
> *- Premature optimization (small app, 2 developers)*
> *- Distributed monolith (same team owns all services, deploy together)*
> *- No clear boundaries (services call each other 100x per request)*
> 
> **My Rule: Start monolith, extract services when pain > cost."*

---

### Q2: "How do you handle data consistency across microservices?"

**Your Answer:**

> *"In microservices, you trade ACID for eventual consistency. Here are the patterns:*
> 
> **Pattern 1: Eventual Consistency (Event-Driven)**
> ```
> Payment Service: Charge succeeded
>   ↓ Kafka event
> Invoice Service: Mark paid (eventually, within seconds)
> ```
> 
> **Pattern 2: Saga Pattern (Distributed Transaction)**
> *- Orchestrator coordinates multi-service transaction*
> *- Compensating transactions on failure*
> *- Example: Order → Payment → Inventory → Shipping*
> 
> **Pattern 3: API Composition (Read-Time Join)**
> ```
> GET /api/invoices/123 needs payment status
>   ↓
> 1. Invoice Service: Fetch invoice
> 2. Payment Service API: Fetch payment status
> 3. Combine and return
> ```
> 
> **Pattern 4: CQRS (Denormalize for Reads)**
> ```
> Write Side:
> - Payment Service: Captures payment
> - Publishes payment.captured event
> 
> Read Side:
> - Invoice Service: Listens to event
> - Updates local payment_status cache
> - Reads from cache (fast, eventual)
> ```
> 
> **Real enterprise example:**
> 
> **Problem:** Invoice page needs customer settings (from CSR service)
> 
> **Bad Approach (Synchronous):**
> ```php
> // Every invoice load = API call to CSR (slow, coupled)
> $settings = Http::get("https://csr/api/customers/$id/settings");
> ```
> 
> **Good Approach (Cache + Events):**
> ```php
> // Cache settings in Redis (1 hour TTL)
> $settings = Redis::get("customer:$id:settings");
> 
> if (!$settings) {
>     $settings = Http::get("https://csr/api/customers/$id/settings");
>     Redis::setex("customer:$id:settings", 3600, $settings);
> }
> 
> // When CSR changes setting → Kafka event → Invalidate cache
> ```
> 
> **Tradeoffs:**
> *- **Immediate consistency:** Tight coupling, slow, simple*
> *- **Eventual consistency:** Loose coupling, fast, complex*
> 
> **When to Use Each:**
> *- Payment processing: Strong consistency (Saga pattern)*
> *- Analytics dashboard: Eventual (events)*
> *- Invoice display: Eventual with cache (CQRS)*"*

---

### Q3: "How do you handle failures in a microservices architecture?"

**Your Answer:**

> *"Failures are normal in distributed systems. In a production environment, we use multiple patterns:*
> 
> **1. Circuit Breaker (Prevent Cascade)**
> ```php
> Invoice Service calls Payment Service:
> - Normal: Pass through
> - 5 failures in 1 min: Open circuit (fail fast)
> - After 30s: Half-open (try 1 request)
> - If success: Close circuit (back to normal)
> ```
> 
> **2. Retry with Exponential Backoff**
> ```php
> try {
>     $response = Http::retry(3, 100)->get($url);
>     // Retry 3 times: 100ms, 200ms, 400ms
> } catch (Exception $e) {
>     Log::error('Service unavailable', ['service' => $url]);
>     // Fallback or fail gracefully
> }
> ```
> 
> **3. Timeout (Don't Wait Forever)**
> ```php
> $response = Http::timeout(5)->get($url);
> // Max 5 seconds, then exception
> ```
> 
> **4. Fallback (Degrade Gracefully)**
> ```php
> try {
>     $recommendations = RecommendationService::get($userId);
> } catch (Exception $e) {
>     // Service down → use cached or default
>     $recommendations = Cache::get("recs:$userId", []);
> }
> ```
> 
> **5. Bulkhead Pattern (Isolate Resources)**
> ```
> Connection Pool:
> - Payment Service: 20 connections
> - Reporting Service: 5 connections
> 
> If Reporting hangs:
> - Uses 5 connections
> - Payment still has 20 (isolated)
> ```
> 
> **6. Health Checks (Kubernetes)**
> ```yaml
> livenessProbe:
>   httpGet:
>     path: /health
>     port: 80
>   initialDelaySeconds: 30
>   periodSeconds: 10
> 
> # If fails 3x → restart pod
> ```
> 
> **7. Dead Letter Queue (Async Failures)**
> ```
> Payment event processing fails 3x
>   ↓
> Send to DLQ
>   ↓
> Manual investigation
> ```
> 
> **Real Enterprise SaaS Company Incident:**
> 
> **Problem:** CSR service went down (database crash)
> 
> **Without Circuit Breaker:**
> *- EIC calls CSR (5s timeout)*
> *- 1000 requests/min × 5s = 5000 threads waiting*
> *- EIC runs out of memory*
> *- Both services down (cascading failure)*
> 
> **With Circuit Breaker:**
> *- CSR fails 5 times → circuit opens*
> *- EIC fails fast (no waiting)*
> *- EIC serves cached settings*
> *- Users see slightly stale data (acceptable)*
> *- CSR recovers → circuit closes*
> *- Result: EIC stayed up, 0 user downtime*"*

---

## Summary: Your Microservices Expertise

**When Asked About Microservices:**

> *"In a production environment, I work with 5 production microservices: EIC, CC, CSR, WCL, and MPay. Each service has its own database tables, deployment pipeline, and scaling profile.*
> 
> *Communication is hybrid: synchronous REST APIs for real-time reads (EIC → CSR for settings), asynchronous Kafka events for state changes (payment captured → invoice paid). We use circuit breakers to prevent cascading failures and cache frequently-accessed data in Redis.*
> 
> *For distributed transactions, we use the saga pattern with compensating transactions. Example: AutoPay enrollment spans 4 services — if payment tokenization fails, we rollback the account link and user creation.*
> 
> *Services are deployed on Kubernetes with independent scaling (payment service: 10 pods, invoice: 5 pods). API Gateway (Kong) provides centralized auth, rate limiting, and routing. CloudWatch tracks cross-service request traces with correlation IDs.*
> 
> *Data consistency is eventual via Kafka events, with idempotency keys to handle duplicates. We maintain 99.9% uptime despite individual service failures through circuit breakers, timeouts, and graceful degradation."*

---

**All 6 interview guides complete!** 🎉

You now have:
1. ✅ Kafka & RabbitMQ Messaging
2. ✅ Elasticsearch & Search Systems
3. ✅ CI/CD Pipelines & DevOps
4. ✅ Kubernetes Deep Dive
5. ✅ API Design & REST
6. ✅ Microservices Architecture

**Total interview prep: 18 comprehensive guides covering every senior engineer topic!**
