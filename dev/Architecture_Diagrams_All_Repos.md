# 🏗️ Architecture Diagrams - All Active Repos

**Use Mermaid Live Editor to view:** https://mermaid.live

---

## 1️⃣ **EIC (eInvoice Connect) - Customer Payment Portal**

### **High-Level Architecture**

```mermaid
graph TB
    Customer[Customer Browser] -->|HTTPS| LoadBalancer[AWS Load Balancer]
    LoadBalancer --> EIC1[EIC App Server 1<br/>PHP 7.4 + Zend MVC]
    LoadBalancer --> EIC2[EIC App Server 2]
    
    EIC1 --> Redis[(Redis Cache<br/>Session + Settings)]
    EIC2 --> Redis
    
    EIC1 --> |Stack Routing| BillingMaster[(billingmaster<br/>Stack Metadata)]
    
    BillingMaster -->|CustomerId → Stack1| Stack1[(billingclient1<br/>High-Volume Customers)]
    BillingMaster -->|CustomerId → Stack2| Stack2[(billingclient2<br/>Standard Customers)]
    
    EIC1 --> WCL[WCL API<br/>Payment Gateway Integration]
    WCL --> PaymentGateway[Stripe / PayPal]
    
    EIC1 --> CSR[CSR API<br/>Settings Lookup]
    CSR --> Redis
    
    EIC1 --> SendGrid[SendGrid<br/>Email Notifications]
    
    style EIC1 fill:#3b82f6
    style Stack1 fill:#ef4444
    style Stack2 fill:#10b981
```

**One-Liner:**
> "EIC = Customer-facing portal where users view invoices, make payments, and enable AutoPay — uses database sharding (Stack1 for high-volume, Stack2 for standard) and integrates with WCL for payment processing."

---

### **Database Sharding Logic**

```mermaid
flowchart TD
    Request[API Request<br/>GET /invoices?customerId=12345] --> Routing{Lookup Customer<br/>in billingmaster}
    
    Routing -->|billingstack=1| Stack1[Query billingclient1<br/>High-Volume Customers<br/>500K+ invoices/year]
    Routing -->|billingstack=2| Stack2[Query billingclient2<br/>Standard Customers<br/><500K invoices/year]
    
    Stack1 --> Response[Return Invoices JSON]
    Stack2 --> Response
    
    style Stack1 fill:#ef4444
    style Stack2 fill:#10b981
```

**Key Files:**
- `ig70/models/DbFactory.php` — Stack routing logic
- `ig70/controllers/InvoiceController.php` — API endpoints
- `ig70/models/Invoice.php` — Data model

---

## 2️⃣ **CC (Client Connect) - Supplier Admin Portal**

### **High-Level Architecture**

```mermaid
graph TB
    Supplier[Supplier Admin] -->|HTTPS| CC[CC App<br/>Laravel 9]
    
    CC --> AMAPI[AMAPI<br/>Bulk User Enrollment]
    CC --> Redis[(Redis Cache)]
    CC --> MySQL[(billingclient1/2<br/>Customer Data)]
    
    AMAPI --> MySQL
    AMAPI --> AuditLog[(fsiAccountAudits<br/>Audit Trail)]
    
    CC --> SendGrid[SendGrid<br/>Email Notifications]
    
    CC -->|Enable MPay| MPay[MPay Service<br/>AutoPay Management]
    
    style CC fill:#3b82f6
    style AMAPI fill:#f59e0b
```

**One-Liner:**
> "CC = Supplier admin portal where suppliers manage customer accounts, enable MPay (AutoPay), and bulk-onboard users via AMAPI — integrates with EIC for customer-facing workflows."

**Key Files:**
- `application/cc/Controllers/AccountController.php` — Account management
- `application/cc/Controllers/AMAPIController.php` — Bulk enrollment
- `application/cc/Models/Account.php` — Data model

---

## 3️⃣ **CSR (Customer Settings Repository)**

### **3-Layer Caching Architecture**

```mermaid
flowchart LR
    Service[Microservice<br/>200+ Services] -->|GET /settings/12345/theme| CSR[CSR API<br/>Laravel 10]
    
    CSR -->|Layer 1<br/>~1ms| APCu[(APCu<br/>In-Memory Cache<br/>TTL: 5 min)]
    
    APCu -->|Cache Miss| Layer2{Check Layer 2}
    Layer2 -->|~5ms| Redis[(Redis<br/>Centralized Cache<br/>TTL: 15 min)]
    
    Redis -->|Cache Miss| Layer3{Check Layer 3}
    Layer3 -->|~50ms| MySQL[(MySQL<br/>Source of Truth)]
    
    MySQL -->|Backfill| Redis
    Redis -->|Backfill| APCu
    APCu -->|Return| Response[Response: 'dark'<br/>p99: <50ms]
    
    style APCu fill:#10b981
    style Redis fill:#f59e0b
    style MySQL fill:#ef4444
```

**Cache Invalidation (Version-Based)**

```mermaid
sequenceDiagram
    participant Admin as Admin UI
    participant CSR as CSR API
    participant Redis as Redis
    participant APCu as APCu (All Servers)
    
    Admin->>CSR: PUT /settings/12345/theme = 'light'
    CSR->>MySQL: UPDATE customer_settings SET value='light'
    CSR->>Redis: INCR settings_version:12345 (v1 → v2)
    CSR->>Redis: DEL setting:12345:theme
    
    Note over APCu: Next request from Server 1
    APCu-->>CSR: GET /settings/12345/theme
    APCu->>Redis: Check version (cached: v1, Redis: v2)
    Redis-->>APCu: Version mismatch! Invalidate cache
    APCu->>Redis: Fetch fresh value ('light')
    APCu->>APCu: Store locally with version v2
```

**One-Liner:**
> "CSR = Settings microservice serving 200+ downstream services with <50ms p99 latency via 3-layer caching (APCu → Redis → MySQL) and version-based invalidation across all servers."

**Key Files:**
- `application/csr/Controllers/SettingsController.php` — API endpoints
- `application/csr/Services/CacheService.php` — 3-layer caching logic
- `application/csr/Models/CustomerSetting.php` — Data model

---

## 4️⃣ **WCL (Web Communication Layer) - Integration Microservice**

### **High-Level Architecture**

```mermaid
graph TB
    EIC[EIC / CC<br/>Caller] -->|POST /integrate/payment| WCL[WCL API<br/>Phalcon MVC]
    
    WCL --> ConnPool[Connection Pool<br/>10-100 Connections]
    
    WCL --> KeyStore[AWS Secrets Manager<br/>Encrypted API Keys]
    
    WCL -->|Decrypt Key| EncryptLogic[AES-256-GCM<br/>Decryption]
    EncryptLogic --> APICall[External API Call]
    
    APICall -->|Stripe| Stripe[Payment Gateway]
    APICall -->|SendGrid| SendGrid[Email Service]
    APICall -->|Custom| OtherAPIs[Other Partners]
    
    WCL --> RedisCache[(Redis<br/>TTL-Based Cache<br/>30-min)]
    
    style WCL fill:#3b82f6
    style KeyStore fill:#f59e0b
```

**Connection Pooling Logic**

```mermaid
flowchart TD
    Request[Incoming Request] --> CheckPool{Connection<br/>Available?}
    
    CheckPool -->|Yes| ReuseConn[Reuse Existing<br/>Connection]
    CheckPool -->|No, Pool < Max| CreateNew[Create New<br/>Connection]
    CheckPool -->|No, Pool = Max| Wait[Wait for Available<br/>Connection<br/>Timeout: 5s]
    
    ReuseConn --> Execute[Execute API Call]
    CreateNew --> Execute
    Wait -->|Timeout| Error[Return 503<br/>Service Unavailable]
    Wait -->|Connection Free| ReuseConn
    
    Execute --> ReleaseConn[Release Connection<br/>Back to Pool]
    
    style Error fill:#ef4444
```

**One-Liner:**
> "WCL = Integration microservice routing calls to 20+ external APIs (payment gateways, email, etc.) with encrypted key storage (AWS Secrets Manager), connection pooling (prevent exhaustion), and TTL-based caching (reduce redundant calls)."

**Key Files:**
- `app/controllers/IntegrationController.php` — API proxy
- `app/services/ConnectionPool.php` — Connection management
- `app/services/EncryptionService.php` — Key decryption

---

## 5️⃣ **MPay (Managed Pay) - Supplier-Level AutoPay**

### **Idempotency Pattern**

```mermaid
sequenceDiagram
    participant Client as EIC/CC Client
    participant MPay as MPay API
    participant Redis as Redis (Lock)
    participant DB as MySQL
    participant Gateway as Payment Gateway
    
    Client->>MPay: POST /charge<br/>Idempotency-Key: uuid-1234
    MPay->>DB: SELECT * FROM payment_requests WHERE key='uuid-1234'
    
    alt Key NOT found (First Request)
        DB-->>MPay: No record
        MPay->>Redis: SETNX lock:uuid-1234 (5-min TTL)
        Redis-->>MPay: Lock acquired
        MPay->>DB: INSERT payment_requests (key, status='PROCESSING')
        MPay->>Gateway: Charge $500
        Gateway-->>MPay: Success (txn_12345)
        MPay->>DB: UPDATE payment_requests SET status='COMPLETED', response=txn_12345
        MPay->>Redis: DEL lock:uuid-1234
        MPay-->>Client: 200 OK {transaction_id: txn_12345}
    else Key found, status='PROCESSING' (Duplicate/Retry)
        DB-->>MPay: Record exists, status='PROCESSING'
        MPay-->>Client: 409 Conflict {error: 'Already processing'}
    else Key found, status='COMPLETED' (Retry after success)
        DB-->>MPay: Record exists, status='COMPLETED', response=txn_12345
        MPay-->>Client: 200 OK {transaction_id: txn_12345} (Cached)
    end
```

**One-Liner:**
> "MPay = Supplier-managed AutoPay service with idempotency pattern (Redis lock + DB state machine) preventing duplicate charges — reduced disputes by 80% via SETNX locking and status tracking (PROCESSING → COMPLETED → FAILED)."

**Key Files:**
- `app/controllers/PaymentController.php` — Idempotency logic
- `app/services/PaymentGatewayService.php` — Stripe/PayPal integration

---

## 6️⃣ **AMAPI (Account Management API) - Bulk Enrollment**

### **Bulk Insert Flow**

```mermaid
flowchart TD
    Request[POST /bulk-enroll<br/>1000 accounts] --> Validation[Pydantic Validation<br/>Email, Name, etc.]
    
    Validation --> Dedup{Bloom Filter<br/>Duplicate Check}
    
    Dedup -->|Duplicate| Skip[Skip Account<br/>Log Warning]
    Dedup -->|New| Batch[Add to Batch<br/>Size: 100]
    
    Batch -->|Batch Full| BulkInsert[MySQL Bulk INSERT<br/>100 rows at once]
    BulkInsert --> Audit[Write to fsiAccountAudits<br/>Multi-row audit]
    
    Audit --> Response[Return:<br/>1000 created,<br/>0 skipped,<br/><100ms total]
    
    style BulkInsert fill:#10b981
```

**One-Liner:**
> "AMAPI = Bulk account enrollment API processing 50K+ accounts/month with <100ms per account via batching (100 rows/INSERT), Bloom filter duplicate detection, and multi-layer audit logging (fsiAccountAudits)."

**Key Files:**
- `app/controllers/BulkEnrollController.php` — Batch processing
- `app/services/BloomFilterService.php` — Duplicate detection

---

## 7️⃣ **Biscuit (inv-bt-invoicing-ai) - AI-Assisted Triage**

### **Claude AI Skills Architecture**

```mermaid
graph TB
    User[Karthik<br/>NJQRT Engineer] -->|Invoke Skill| Claude[Claude Code<br/>AI Assistant]
    
    Claude --> Skill1[/karthik-triage<br/>Full NJQRT Workflow]
    Claude --> Skill2[/db-query<br/>Safe MySQL Gateway]
    Claude --> Skill3[/developer<br/>App Context Loader]
    Claude --> Skill4[/researcher<br/>Codebase Analysis]
    
    Skill1 --> Jira[Atlassian MCP<br/>Fetch Ticket]
    Skill1 --> CodeReview[GitHub MCP<br/>PR Analysis]
    Skill1 --> DB[MySQL MCP<br/>Query Production]
    
    Skill2 --> Gateway[db-query.ps1<br/>Docker + MySQL Client]
    Gateway --> ProdDB[(Production DB<br/>Read-Only)]
    
    Skill3 --> RepoScan[Scan Repo<br/>Find Active Modules]
    Skill4 --> DependencyMap[Map Dependencies<br/>Call Graph]
    
    Skill1 --> RCADraft[Generate RCA<br/>5-Field Jira Template]
    
    RCADraft --> JiraPost[Post to Jira<br/>via Atlassian MCP]
    
    style Claude fill:#3b82f6
    style Skill1 fill:#f59e0b
```

**Timeline Reconstruction (Security Investigation)**

```mermaid
sequenceDiagram
    participant User as Karthik
    participant Biscuit as Biscuit AI
    participant Datadog as Datadog MCP
    participant Splunk as Splunk API
    participant Pendo as Pendo MCP
    participant SendGrid as SendGrid API
    participant MySQL as MySQL Audits
    
    User->>Biscuit: Investigate malicious actor (UserId: 98765)
    
    par Parallel Log Collection
        Biscuit->>Datadog: Search traces (@user.id:98765, timestamp:...)
        Biscuit->>Splunk: Search audit logs (user_id=98765)
        Biscuit->>Pendo: Fetch user activity events
        Biscuit->>SendGrid: Fetch email logs (to_email:...)
        Biscuit->>MySQL: SELECT FROM fsiAccountAudits WHERE UserId=98765
    end
    
    Datadog-->>Biscuit: 6 API calls (login, invoices, bank change, payment, password reset, logout)
    Splunk-->>Biscuit: 2 audit rows (bank account change, password reset token)
    Pendo-->>Biscuit: 5 page views (invoices, settings, payment)
    SendGrid-->>Biscuit: 2 emails (password reset sent, bank change notification)
    MySQL-->>Biscuit: 1 audit row (bank account change, EventUser='attacker')
    
    Biscuit->>Biscuit: Correlate by timestamp<br/>Build chronological timeline
    
    Biscuit-->>User: **Timeline Report:**<br/>08:15 - Login (Tor IP)<br/>08:16 - 50 invoices viewed<br/>08:17 - Bank account changed<br/>08:18 - Password reset<br/>08:20 - Payment blocked<br/>08:22 - Logout
```

**One-Liner:**
> "Biscuit = AI-powered NJQRT assistant (Claude skills + FastAPI) automating ticket triage, codebase investigation, timeline reconstruction, and Jira posting — reduced incident resolution time by 40% via parallel log collection from 5 monitoring systems."

**Key Files:**
- `skills/workflows/karthik-triage/SKILL.md` — Triage orchestration
- `skills/utility/db-query/db-query.ps1` — Safe MySQL gateway
- `skills/workflows/bt-invoicing-qrt-post/SKILL.md` — Jira posting template

---

## 8️⃣ **Payment Repo (pay-workflow-integration-service) - .NET Payment Orchestration**

### **High-Level Architecture**

```mermaid
graph TB
    EIC[EIC/CC/MPay] -->|REST API| PayAPI[Payment Service<br/>.NET Core 6]
    
    PayAPI --> RabbitMQ[RabbitMQ<br/>Async Workers]
    
    RabbitMQ --> ChargeWorker[Charge Worker]
    RabbitMQ --> RefundWorker[Refund Worker]
    RabbitMQ --> WebhookWorker[Webhook Worker]
    
    ChargeWorker --> |ACH/Credit Card| Stripe[Stripe Gateway]
    ChargeWorker --> |ACH/Credit Card| PayPal[PayPal Gateway]
    
    RefundWorker --> Stripe
    RefundWorker --> PayPal
    
    WebhookWorker --> |Verify HMAC| SigValidation[Signature Validation<br/>HMAC-SHA256]
    
    PayAPI --> MySQL[(billingclient1/2<br/>Payment Records)]
    
    PayAPI --> Datadog[Datadog APM<br/>Traces + Metrics]
    
    style PayAPI fill:#3b82f6
    style RabbitMQ fill:#f59e0b
```

**Webhook Signature Validation Flow**

```mermaid
flowchart TD
    Webhook[POST /webhooks/stripe<br/>X-Stripe-Signature: ...] --> Extract[Extract Headers:<br/>timestamp, signature]
    
    Extract --> BuildPayload[Build Signed Payload:<br/>timestamp.body]
    
    BuildPayload --> HMAC[Compute HMAC-SHA256<br/>Key: webhook_secret]
    
    HMAC --> Compare{Signature<br/>Match?}
    
    Compare -->|Yes| Process[Process Webhook<br/>Update Payment Status]
    Compare -->|No| Reject[Return 401<br/>Invalid Signature]
    
    Process --> Response[Return 200 OK]
    
    style Reject fill:#ef4444
    style Process fill:#10b981
```

**One-Liner:**
> "Payment repo = .NET Core microservice orchestrating ACH/credit card charges via Stripe/PayPal with async workers (RabbitMQ), webhook HMAC validation (prevent replay attacks), and Datadog APM tracing — you debugged cross-team issues via Claude AI code analysis."

**Key Files:**
- `PaymentService/Controllers/PaymentController.cs` — API endpoints
- `PaymentService/Services/StripeService.cs` — Stripe integration
- `PaymentService/Workers/ChargeWorker.cs` — Async payment processing
- `PaymentService/Services/WebhookValidator.cs` — HMAC signature validation

---

## 🎯 **For Interviews: Architecture Questions**

**Q: "Explain EIC's database sharding strategy."**
> "EIC uses 2-stack sharding: `billingclient1` for high-volume customers (500K+ invoices/year) and `billingclient2` for standard customers. Routing logic queries `billingmaster.BillingStack` column to determine which MySQL instance to hit — prevents hot-spotting on a single database and allows independent scaling."

**Q: "How does CSR achieve <50ms p99 latency serving 200+ microservices?"**
> "3-layer caching: APCu (in-memory, 5-min TTL, ~1ms) → Redis (centralized, 15-min TTL, ~5ms) → MySQL (source of truth, ~50ms). Version-based invalidation ensures all servers invalidate stale APCu caches when settings change — INCR `settings_version` in Redis, next request checks version mismatch and refreshes."

**Q: "What's the idempotency pattern in MPay?"**
> "Redis SETNX lock + MySQL state machine. Client sends `Idempotency-Key: uuid-1234` → (1) Check DB for existing request, (2) If not found, acquire Redis lock, (3) INSERT with status='PROCESSING', (4) Call payment gateway, (5) UPDATE status='COMPLETED', (6) Release lock. Duplicate requests return cached result or 409 Conflict if still processing — reduced disputes 80%."

**Q: "How does Biscuit (AI assistant) reconstruct timelines for security investigations?"**
> "Parallel log collection from 5 sources (Datadog, Splunk, Pendo, SendGrid, MySQL audits) using their respective APIs/MCPs, then correlate events by timestamp to build a chronological timeline. For example: 08:15 Login (Datadog) → 08:16 Invoices viewed (Pendo) → 08:17 Bank changed (MySQL audit) → 08:18 Password reset (SendGrid) → 08:20 Payment blocked (Datadog) → customer report generated in <60 minutes."

---

**NEXT:** Interactive HTML course pages with quizzes + flashcards!