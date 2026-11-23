# API Design & REST Best Practices Guide

**For Senior Software Engineer Interviews**

Your competitive advantage: **Multi-tenant API experience** (10,000+ customers, rate limiting, versioning, authentication at scale)

---

## REST Fundamentals

### Resources & HTTP Methods

```
Resource: Invoice
URL: /api/invoices

GET    /api/invoices        List all invoices
GET    /api/invoices/123    Get specific invoice
POST   /api/invoices        Create new invoice
PUT    /api/invoices/123    Update entire invoice (replace)
PATCH  /api/invoices/123    Partial update
DELETE /api/invoices/123    Delete invoice
```

**Idempotent:**
- GET, PUT, DELETE → Same request twice = same result
- POST → Creates new resource each time (NOT idempotent)

---

## URL Design

### Good API URLs

```
✅ GOOD:
GET /api/customers/123/invoices
GET /api/invoices?customer_id=123&status=unpaid
POST /api/invoices/123/payments
DELETE /api/customers/123

❌ BAD:
GET /api/getCustomerInvoices?id=123  # Verb in URL
POST /api/invoice/delete/123         # DELETE in POST
GET /api/Customers/123               # Inconsistent casing
```

**Rules:**
- Nouns, not verbs
- Plural resource names (`/invoices` not `/invoice`)
- Lowercase, hyphen-separated (`/payment-methods` not `/paymentMethods`)
- Nested for relationships (`/customers/123/invoices`)
- Query params for filtering (`?status=unpaid&limit=20`)

---

## Versioning

### 3 Approaches

**1. URL Versioning (Recommended)**
```
GET /api/v1/invoices
GET /api/v2/invoices

✅ Pros: Clear, easy to cache
❌ Cons: Multiple URLs for same resource
```

**2. Header Versioning**
```
GET /api/invoices
Headers: Accept: application/vnd.Enterprise SaaS Company.v2+json

✅ Pros: Clean URLs
❌ Cons: Harder to test (can't paste in browser)
```

**3. Query Parameter**
```
GET /api/invoices?version=2

❌ Not recommended (mixes versioning with filtering)
```

**Your Production API:**
```
/api/v1/invoices  (original)
/api/v2/invoices  (added pagination, changed date format)
/api/v3/invoices  (added filtering, breaking change)

# v1 still works (backward compatibility)
```

---

## Authentication & Authorization

### JWT (JSON Web Token)

**Flow:**
```
1. POST /api/login
   Body: {email, password}
   Response: {token: "eyJhbGciOiJIUzI1..."}

2. GET /api/invoices
   Header: Authorization: Bearer eyJhbGciOiJIUzI1...
   
3. Server validates token:
   - Signature valid?
   - Not expired?
   - User has permission?
```

**JWT Structure:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.  # Header
eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4iLCJpYXQiOjE1MTYyMzkwMjJ9.  # Payload
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c  # Signature

Decoded Payload:
{
  "sub": "1234567890",     # User ID
  "name": "John",
  "customer_id": "cust_123",
  "role": "admin",
  "iat": 1516239022,       # Issued at
  "exp": 1516242622        # Expires at (1 hour)
}
```

**Laravel Implementation:**
```php
// Generate token
$token = JWTAuth::fromUser($user);

// Validate token (middleware)
public function handle($request, Closure $next) {
    try {
        $user = JWTAuth::parseToken()->authenticate();
    } catch (Exception $e) {
        return response()->json(['error' => 'Unauthorized'], 401);
    }
    
    // Add user to request
    $request->user = $user;
    return $next($request);
}

// Access in controller
public function getInvoices(Request $request) {
    $customerId = $request->user->customer_id;
    return Invoice::where('customer_id', $customerId)->get();
}
```

---

## Rate Limiting

### Prevent Abuse

```
X-RateLimit-Limit: 1000       # Max requests per hour
X-RateLimit-Remaining: 950    # Requests left
X-RateLimit-Reset: 1699000000 # Unix timestamp when resets
```

**Algorithm: Token Bucket**
```php
class RateLimiter {
    private $redis;
    
    public function allow($userId, $limit = 1000, $window = 3600) {
        $key = "rate_limit:$userId";
        $current = $this->redis->get($key) ?? 0;
        
        if ($current >= $limit) {
            return false; // Rate limited
        }
        
        // Increment counter
        $this->redis->incr($key);
        $this->redis->expire($key, $window); // 1-hour window
        
        return true;
    }
}

// Middleware
if (!$rateLimiter->allow($userId, 1000, 3600)) {
    return response()->json([
        'error' => 'Rate limit exceeded',
        'retry_after' => 3600
    ], 429);
}
```

**Production Limits:**
- Free tier: 100 requests/hour
- Pro tier: 1,000 requests/hour
- Enterprise: 10,000 requests/hour

---

## Pagination

### 3 Approaches

**1. Offset-Based (Simple)**
```
GET /api/invoices?limit=20&offset=40

Response:
{
  "data": [...20 invoices...],
  "pagination": {
    "total": 1000,
    "limit": 20,
    "offset": 40,
    "next": "/api/invoices?limit=20&offset=60",
    "previous": "/api/invoices?limit=20&offset=20"
  }
}

✅ Pros: Simple, can jump to page 5
❌ Cons: Slow on large offsets, inconsistent if data changes
```

**2. Cursor-Based (Fast, Consistent)**
```
GET /api/invoices?limit=20&cursor=eyJpZCI6MTIzfQ==

Response:
{
  "data": [...20 invoices...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTQzfQ==",
    "has_more": true
  }
}

Cursor = base64({id: 143})  # ID of last item

✅ Pros: Fast, consistent
❌ Cons: Can't jump to specific page
```

**3. Keyset Pagination (Best for Time-Series)**
```
GET /api/invoices?limit=20&created_after=2026-11-15T10:00:00Z

✅ Pros: Very fast (index on created_at)
✅ Cons: Only forward pagination
```

---

## Error Handling

### Standard HTTP Status Codes

```
2xx Success
200 OK                 GET, PUT, PATCH successful
201 Created            POST successful, resource created
204 No Content         DELETE successful

4xx Client Errors
400 Bad Request        Invalid JSON, missing required field
401 Unauthorized       No auth token or invalid token
403 Forbidden          Valid token, no permission
404 Not Found          Resource doesn't exist
409 Conflict           Duplicate resource, version conflict
422 Unprocessable      Validation failed
429 Too Many Requests  Rate limit exceeded

5xx Server Errors
500 Internal Server    Unhandled exception
502 Bad Gateway        Upstream service down
503 Service Unavailable Maintenance mode
504 Gateway Timeout    Upstream service timeout
```

### Error Response Format

```json
{
  "error": {
    "code": "INVOICE_NOT_FOUND",
    "message": "Invoice with ID 12345 does not exist",
    "details": {
      "invoice_id": "12345",
      "customer_id": "cust_789"
    },
    "timestamp": "2026-11-16T10:30:00Z",
    "request_id": "req_abc123"  # For support/debugging
  }
}
```

**Validation Errors:**
```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Invalid request data",
    "fields": {
      "email": ["Invalid email format"],
      "amount": ["Must be greater than 0"]
    }
  }
}
```

---

## Filtering, Sorting, Searching

```
# Filtering
GET /api/invoices?status=unpaid&customer_id=123

# Sorting
GET /api/invoices?sort=-created_at,amount
# - prefix = descending

# Searching
GET /api/invoices?q=INV-12345

# Field selection (sparse fieldsets)
GET /api/invoices?fields=id,amount,status
# Returns only specified fields (saves bandwidth)

# Expand related resources
GET /api/invoices?include=customer,payments
# Embeds customer and payments in response
```

---

## Your Production API Use Cases

### 1. Invoice API

**Endpoints:**
```php
// List invoices
GET /api/v1/invoices?customer_id=123&status=unpaid&limit=20

Response:
{
  "data": [
    {
      "id": "inv_123",
      "invoice_number": "INV-12345",
      "customer_id": "cust_789",
      "amount": 1500.00,
      "currency": "USD",
      "status": "unpaid",
      "due_date": "2026-12-01",
      "created_at": "2026-11-01T10:00:00Z",
      "pdf_url": "https://s3.amazonaws.com/invoices/inv_123.pdf"
    }
  ],
  "pagination": {
    "total": 150,
    "limit": 20,
    "offset": 0,
    "next": "/api/v1/invoices?offset=20"
  }
}

// Create invoice
POST /api/v1/invoices
{
  "customer_id": "cust_789",
  "line_items": [
    {"description": "Service A", "amount": 1000.00},
    {"description": "Service B", "amount": 500.00}
  ],
  "due_date": "2026-12-01"
}

Response: 201 Created
{
  "id": "inv_124",
  "invoice_number": "INV-12346",
  "status": "draft",
  "amount": 1500.00
}

// Get single invoice
GET /api/v1/invoices/inv_123

// Update invoice
PATCH /api/v1/invoices/inv_123
{
  "status": "sent"
}

// Delete invoice (soft delete)
DELETE /api/v1/invoices/inv_123
```

### 2. Multi-Tenant Scoping

```php
// Middleware: Ensure user only sees their customer's data
class TenantScopeMiddleware {
    public function handle($request, Closure $next) {
        $user = $request->user;
        $customerId = $user->customer_id;
        
        // Add global scope to all queries
        Invoice::addGlobalScope('tenant', function ($query) use ($customerId) {
            $query->where('customer_id', $customerId);
        });
        
        return $next($request);
    }
}

// Now this is safe (can't access other customers):
Invoice::all()  # Auto-scoped to customer_id
```

---

## Interview Questions & Answers

### Q1: "Design a RESTful API for a blogging platform. What endpoints would you create?"

**Your Answer:**

> *"Here's how I'd design it:*
> 
> **Resources: Posts, Comments, Users**
> 
> **Posts:**
> ```
> GET    /api/v1/posts              List all posts
> GET    /api/v1/posts/123          Get specific post
> POST   /api/v1/posts              Create new post
> PUT    /api/v1/posts/123          Update entire post
> PATCH  /api/v1/posts/123          Partial update (e.g., just title)
> DELETE /api/v1/posts/123          Delete post
> ```
> 
> **Comments (Nested Resource):**
> ```
> GET    /api/v1/posts/123/comments          List comments on post
> POST   /api/v1/posts/123/comments          Add comment to post
> DELETE /api/v1/comments/456                Delete specific comment
> ```
> 
> **Filtering & Pagination:**
> ```
> GET /api/v1/posts?author_id=789&status=published&limit=20&offset=0
> GET /api/v1/posts?sort=-created_at  # Newest first
> GET /api/v1/posts?q=kubernetes      # Search
> ```
> 
> **Authentication:**
> ```
> POST /api/v1/auth/login
> Body: {email, password}
> Response: {token: "eyJhbGc..."}
> 
> All endpoints require:
> Header: Authorization: Bearer eyJhbGc...
> ```
> 
> **Example Request:**
> ```
> POST /api/v1/posts
> Headers:
>   Authorization: Bearer eyJhbGc...
>   Content-Type: application/json
> Body:
> {
>   "title": "My First Post",
>   "content": "Hello world!",
>   "tags": ["tech", "api"],
>   "status": "draft"
> }
> 
> Response: 201 Created
> {
>   "id": "post_123",
>   "title": "My First Post",
>   "author_id": "user_456",
>   "created_at": "2026-11-16T10:30:00Z",
>   "url": "/api/v1/posts/post_123"
> }
> ```
> 
> **Versioning:** /api/v1 in URL (easy to deprecate v1, launch v2)*
> 
> **Rate Limiting:** 1000 requests/hour per user*
> 
> **Error Handling:**
> ```json
> {
>   "error": {
>     "code": "POST_NOT_FOUND",
>     "message": "Post with ID post_123 does not exist"
>   }
> }
> ```"*

---

### Q2: "How do you handle versioning in APIs? When do you increment the version?"

**Your Answer:**

> *"In a production environment, we use URL versioning (`/api/v1`, `/api/v2`) because it's explicit and easy to cache.*
> 
> **When to Increment Version:**
> 
> **Breaking Changes (Require New Version):**
> *- Removing a field from response*
> *- Changing field type (string → number)*
> *- Changing field name (`invoice_id` → `id`)*
> *- Changing date format (ISO 8601 → Unix timestamp)*
> *- Removing an endpoint*
> *- Changing authentication method*
> 
> **Non-Breaking Changes (Same Version):**
> *- Adding new optional fields to request*
> *- Adding new fields to response (clients ignore unknown fields)*
> *- Adding new endpoints*
> *- Making required field optional*
> 
> **Example:**
> 
> **v1 Response:**
> ```json
> {
>   "invoice_id": "INV-123",
>   "amount": "1500.00",
>   "created": "11/16/2026"
> }
> ```
> 
> **v2 Response (Breaking Changes):**
> ```json
> {
>   "id": "inv_123",              # Renamed
>   "amount": 1500.00,             # Changed to number
>   "created_at": "2026-11-16T10:30:00Z"  # ISO 8601
> }
> ```
> 
> **Both versions live simultaneously:**
> ```
> GET /api/v1/invoices/123  # Old clients (still works)
> GET /api/v2/invoices/123  # New clients
> ```
> 
> **Deprecation Strategy:**
> *1. Launch v2*
> *2. Email customers: "v1 deprecated, migrate to v2 by Dec 1"*
> *3. Add warning header to v1 responses:*
> ```
> Sunset: Sat, 01 Dec 2026 00:00:00 GMT
> Warning: 299 - "API v1 is deprecated, use v2"
> ```
> *4. After 6 months, shut down v1*
> 
> **Code Implementation:**
> ```php
> // routes/api.php
> Route::prefix('v1')->group(function () {
>     Route::get('/invoices', [InvoiceControllerV1::class, 'index']);
> });
> 
> Route::prefix('v2')->group(function () {
>     Route::get('/invoices', [InvoiceControllerV2::class, 'index']);
> });
> ```
> 
> **Key Rule: Never break existing clients. Always backward compatible OR new version."*

---

### Q3: "How would you implement rate limiting for an API?"

**Your Answer:**

> *"In a production environment, I'd use the token bucket algorithm with Redis:*
> 
> **Algorithm:**
> *- Each user gets a bucket with N tokens (e.g., 1000)*
> *- Each request consumes 1 token*
> *- Bucket refills at rate R (e.g., 1000 tokens/hour)*
> *- If bucket empty → 429 Too Many Requests*
> 
> **Implementation (Laravel + Redis):**
> ```php
> class RateLimitMiddleware {
>     public function handle($request, Closure $next) {
>         $userId = $request->user->id;
>         $limit = $this->getUserLimit($userId);  # 100, 1000, or 10000
>         $window = 3600; # 1 hour
>         
>         $key = "rate_limit:$userId";
>         $current = Redis::get($key) ?? 0;
>         
>         if ($current >= $limit) {
>             return response()->json([
>                 'error' => 'Rate limit exceeded',
>                 'retry_after' => Redis::ttl($key)
>             ], 429)->withHeaders([
>                 'X-RateLimit-Limit' => $limit,
>                 'X-RateLimit-Remaining' => 0,
>                 'X-RateLimit-Reset' => time() + Redis::ttl($key)
>             ]);
>         }
>         
>         // Increment
>         Redis::incr($key);
>         Redis::expire($key, $window);
>         
>         $remaining = $limit - $current - 1;
>         
>         // Add headers to response
>         $response = $next($request);
>         $response->withHeaders([
>             'X-RateLimit-Limit' => $limit,
>             'X-RateLimit-Remaining' => $remaining,
>             'X-RateLimit-Reset' => time() + Redis::ttl($key)
>         ]);
>         
>         return $response;
>     }
>     
>     private function getUserLimit($userId) {
>         $plan = User::find($userId)->subscription_plan;
>         return match($plan) {
>             'free' => 100,
>             'pro' => 1000,
>             'enterprise' => 10000
>         };
>     }
> }
> ```
> 
> **Response Headers:**
> ```
> HTTP/1.1 200 OK
> X-RateLimit-Limit: 1000
> X-RateLimit-Remaining: 950
> X-RateLimit-Reset: 1699000000
> ```
> 
> **When Exceeded:**
> ```
> HTTP/1.1 429 Too Many Requests
> X-RateLimit-Limit: 1000
> X-RateLimit-Remaining: 0
> X-RateLimit-Reset: 1699000000
> Retry-After: 3600
> 
> {
>   "error": "Rate limit exceeded. Try again in 1 hour."
> }
> ```
> 
> **Per-Endpoint Limits:**
> ```php
> // Heavy endpoint (reports): 10/hour
> Route::get('/reports', [ReportController::class, 'index'])
>     ->middleware('rate_limit:10,3600');
> 
> // Light endpoint: 1000/hour
> Route::get('/invoices', [InvoiceController::class, 'index'])
>     ->middleware('rate_limit:1000,3600');
> ```
> 
> **Monitoring:**
> *- Track users hitting limits (indicate plan upgrade needed)*
> *- Alert if global rate limit breached (DDoS?)*"*

---

## Summary: Your API Design Expertise

**When Asked About APIs:**

> *"In a production environment, I designed and maintained RESTful APIs serving 10,000+ customers. We use URL versioning (/api/v1, /api/v2) with backward compatibility — never break existing clients.*
> 
> *Authentication is JWT-based with 1-hour expiration. Rate limiting via Redis token bucket — 100/hour free tier, 1000/hour pro, 10000/hour enterprise. All responses include X-RateLimit headers.*
> 
> *For multi-tenancy, we use middleware global scopes to ensure customers only access their own data. Pagination is cursor-based for performance on large datasets.*
> 
> *Error responses follow RFC 7807 (application/problem+json) with structured error codes, human-readable messages, and request IDs for support. All 4xx/5xx responses are logged to CloudWatch with full request context for debugging."*

---

**API Design expertise complete!** 🌐

Creating final guide (Microservices)...
