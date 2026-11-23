# Payment Gateway - End-to-End Flow

## 📋 Table of Contents

1. [What is a Payment Gateway?](#what-is-a-payment-gateway)
2. [Key Players & Components](#key-players--components)
3. [Complete Transaction Flow](#complete-transaction-flow)
4. [Payment Methods](#payment-methods)
5. [Security & Compliance](#security--compliance)
6. [Error Handling & Retries](#error-handling--retries)
7. [Reconciliation & Settlement](#reconciliation--settlement)
8. [System Design Considerations](#system-design-considerations)
9. [Real-World Example (Enterprise SaaS Company MPay)](#real-world-example-Enterprise SaaS Company-mpay)
10. [Interview Questions](#interview-questions)

---

## What is a Payment Gateway?

**Simple definition:**
A payment gateway is the technology that securely transmits payment information from a customer to the payment processor and returns transaction results.

**Analogy:**
Think of it like a POS (Point of Sale) terminal in a physical store, but for online transactions.

**What it does:**
- Encrypts sensitive payment data
- Transmits data to payment processor
- Receives authorization/decline response
- Returns result to merchant

**What it is NOT:**
- Not a payment processor (doesn't actually process the payment)
- Not a merchant account (doesn't hold funds)
- Not a bank (doesn't settle money)

---

## Key Players & Components

### 1. Customer (Cardholder)
- The person making the payment
- Provides card/bank details
- Expects confirmation

### 2. Merchant (Your Business)
- Sells goods/services
- Wants to accept payments
- Needs funds deposited to bank account

### 3. Payment Gateway
- **Examples:** Stripe, Authorize.Net, Braintree, Adyen
- Encrypts and transmits payment data
- Returns authorization results
- May store tokenized card data

### 4. Payment Processor (Acquirer)
- **Examples:** First Data, Worldpay, Chase Paymentech
- Routes transaction to card network
- Handles merchant account
- Batches settlements

### 5. Card Network
- **Examples:** Visa, Mastercard, American Express, Discover
- Routes authorization request to issuing bank
- Sets interchange fees
- Manages fraud rules

### 6. Issuing Bank
- Customer's bank that issued the card
- Holds customer's funds
- Approves or declines transaction
- Checks fraud rules, balance, limits

### 7. Acquiring Bank (Merchant Bank)
- Merchant's bank
- Receives settlement funds
- Deposits to merchant account

---

## Complete Transaction Flow

### Phase 1: Authorization (Real-time, ~2-3 seconds)

**Step 1: Customer Initiates Payment**
```
Customer on merchant website
  ↓
Clicks "Pay Now"
  ↓
Enters credit card details:
  - Card Number (PAN)
  - Expiration Date
  - CVV
  - Billing Address
```

**Step 2: Merchant Website → Payment Gateway**
```javascript
// Frontend sends payment request
POST https://api.stripe.com/v1/charges
{
  "amount": 5000,  // $50.00 in cents
  "currency": "usd",
  "source": "tok_visa",  // Tokenized card
  "description": "Invoice #12345"
}
```

**Behind the scenes:**
- SSL/TLS encryption (HTTPS)
- Tokenization if using hosted payment form
- PCI-compliant data transmission

**Step 3: Payment Gateway → Payment Processor**
```
Payment Gateway (e.g., Stripe)
  ↓
Encrypts card data
  ↓
Adds merchant credentials
  ↓
Sends to Payment Processor (e.g., First Data)
```

**Message format (ISO 8583):**
```
Message Type: 0100 (Authorization Request)
PAN: 4111111111111111
Amount: 5000
Currency: 840 (USD)
Merchant ID: 123456789
Transaction Date/Time: 2026-11-13 22:30:00
CVV: 123
```

**Step 4: Payment Processor → Card Network**
```
Payment Processor
  ↓
Routes based on card BIN (first 6 digits)
  ↓
Sends to appropriate Card Network
  - 4xxx → Visa
  - 5xxx → Mastercard
  - 37xx → Amex
```

**Step 5: Card Network → Issuing Bank**
```
Visa/Mastercard Network
  ↓
Looks up issuing bank from BIN
  ↓
Routes authorization request to Issuing Bank
```

**Step 6: Issuing Bank Decision**
```
Issuing Bank checks:
  ✓ Card is active (not canceled/expired)
  ✓ Sufficient funds/credit available
  ✓ CVV matches
  ✓ Billing address matches (AVS - Address Verification)
  ✓ No fraud indicators (velocity, location, amount)
  ✓ Not over daily/monthly limits
  
Decision:
  → APPROVED (Authorization Code: 123456)
  → DECLINED (Reason: Insufficient Funds)
  → HOLD (Requires 3D Secure / Additional Verification)
```

**Step 7: Response Flows Back**
```
Issuing Bank
  ↓ (Authorization Code or Decline Reason)
Card Network
  ↓
Payment Processor
  ↓
Payment Gateway
  ↓
Merchant Website
  ↓
Customer sees: "Payment Successful!" or "Payment Declined"
```

**Response format:**
```json
{
  "id": "ch_3abc123",
  "status": "succeeded",
  "amount": 5000,
  "currency": "usd",
  "authorization_code": "123456",
  "last4": "4242",
  "brand": "Visa",
  "avs_result": "Y",  // Address matches
  "cvv_result": "M"   // CVV matches
}
```

**Timeline:** 2-3 seconds total

**What happened to the money?**
- **Authorization ONLY** - no money moved yet
- Issuing bank "holds" $50 on customer's card
- Customer's available credit reduced by $50
- Money still in customer's account

---

### Phase 2: Capture (1-7 days later)

**When:** Merchant ships product or delivers service

**Step 1: Merchant Requests Capture**
```javascript
// Capture previously authorized payment
POST https://api.stripe.com/v1/charges/ch_3abc123/capture
{
  "amount": 5000  // Can capture partial amount
}
```

**Step 2: Gateway Marks for Settlement**
```
Payment Gateway
  ↓
Includes transaction in daily batch
  ↓
Sends batch to Payment Processor
```

**What if merchant never captures?**
- Authorization expires (typically 7-30 days)
- Hold is released
- Customer never charged

**Partial capture example:**
```
Authorized: $100
Item out of stock, only ship $60 worth
Capture: $60
Remaining $40 authorization is voided
```

---

### Phase 3: Settlement (1-3 days after capture)

**Step 1: Batch Processing**
```
End of day (typically 11:59 PM merchant timezone)
  ↓
Payment Processor collects all captures from all merchants
  ↓
Creates settlement batches
```

**Step 2: Card Network Clearing**
```
Payment Processor → Card Network
  ↓
"Here are all Visa transactions from today"
  ↓
Card Network → Issuing Banks
  ↓
"Debit these customer accounts"
  ↓
Card Network → Acquiring Banks
  ↓
"Credit these merchant accounts"
```

**Step 3: Money Movement**
```
Day 0: Customer makes purchase
Day 1: Settlement batch sent
Day 2: Issuing bank debits customer account
Day 2: Acquiring bank credits merchant account (minus fees)
Day 3: Merchant sees funds in bank account
```

**Settlement amount calculation:**
```
Gross Sale:           $100.00
Interchange Fee:      -$1.80  (Visa/MC fee, ~1.8%)
Assessment Fee:       -$0.15  (Card network fee, ~0.15%)
Processor Fee:        -$0.30  (Payment processor markup)
Gateway Fee:          -$0.30  (Gateway transaction fee)
                      -------
Net to Merchant:      $97.45
```

**Who gets what:**
- **Customer's bank:** Debits $100 from customer
- **Merchant's bank:** Credits $97.45 to merchant
- **Card network (Visa/MC):** Gets $1.95 (interchange + assessment)
- **Payment processor:** Gets $0.30
- **Payment gateway:** Gets $0.30

---

## Payment Methods

### 1. Credit Card / Debit Card

**Flow:** As described above

**Authorization types:**
- **Sale:** Auth + Capture in one step (common for digital goods)
- **Auth-Only:** Hold funds, capture later (common for physical goods)
- **Pre-Auth:** Hold more than final amount (hotels, gas stations)

**Card types:**
- Credit cards (Visa, Mastercard, Amex, Discover)
- Debit cards (PIN or signature-based)
- Prepaid cards

---

### 2. ACH / Bank Transfer (eCheck)

**Flow:**
```
Customer provides:
  - Bank routing number (9 digits)
  - Account number
  - Account type (checking/savings)
  
Merchant submits to ACH processor
  ↓
Next business day: ACH network batches
  ↓
2-3 business days: Money debits customer account
  ↓
2-3 business days: Money credits merchant account
```

**Characteristics:**
- **Slower:** 3-5 days vs 2-3 seconds for cards
- **Cheaper:** $0.25-0.50 per transaction vs 2-3% for cards
- **Riskier:** Higher chargeback window (60 days vs 120-180 days for cards)
- **Returns:** Customer can request return within 60 days

**Common in B2B:** Enterprise SaaS Company's invoice payments often use ACH

---

### 3. Digital Wallets (Apple Pay, Google Pay, PayPal)

**Flow:**
```
Customer clicks "Pay with Apple Pay"
  ↓
Apple Pay provides tokenized card number
  ↓
Flows through standard card network
  (Gateway → Processor → Visa/MC → Issuing Bank)
  ↓
But uses device token, not real card number
```

**Benefits:**
- More secure (tokenization)
- Faster checkout (no typing card details)
- Better conversion rates

**Behind the scenes:**
- Apple/Google doesn't see transaction details
- Real card number never touches merchant
- Token maps to real card at network level

---

### 4. Buy Now Pay Later (Klarna, Affirm, Afterpay)

**Flow:**
```
Customer selects "Pay with Klarna"
  ↓
Klarna performs instant credit check
  ↓
Approves customer for installment plan
  ↓
Klarna pays merchant in full immediately
  ↓
Customer pays Klarna in 4 installments over 6 weeks
```

**Risk:**
- Merchant gets paid immediately (no risk)
- Klarna takes on credit risk
- Customer gets short-term loan

---

## Security & Compliance

### PCI-DSS Compliance

**What is it?**
Payment Card Industry Data Security Standard - rules for handling card data

**4 Levels based on transaction volume:**
- **Level 1:** > 6M transactions/year (most stringent)
- **Level 2:** 1M - 6M transactions/year
- **Level 3:** 20K - 1M transactions/year
- **Level 4:** < 20K transactions/year

**12 Requirements:**
1. Install and maintain firewall
2. Don't use vendor defaults (passwords, keys)
3. Protect stored cardholder data
4. Encrypt card data in transit
5. Use and update antivirus
6. Develop secure systems
7. Restrict access by business need
8. Assign unique ID to each person with access
9. Restrict physical access to card data
10. Track and monitor all access
11. Test security systems regularly
12. Maintain security policy

**How to avoid PCI scope:**
```
Bad (In PCI scope):
  Customer → Your server (receives card number) → Gateway
  
Good (Out of PCI scope):
  Customer → Gateway hosted form → Gateway
  Your server ← Token ← Gateway
```

**Tokenization:**
```
Real card: 4111-1111-1111-1111
   ↓
Tokenized: tok_1abc234xyz567
   ↓
Store token in your database (safe!)
   ↓
Use token for future charges (gateway maps to real card)
```

---

### 3D Secure (3DS)

**What is it?**
Additional authentication layer (like 2FA for payments)

**Names:**
- Visa: Verified by Visa
- Mastercard: Mastercard SecureCode
- Amex: SafeKey

**Flow:**
```
Customer enters card details
  ↓
Gateway detects card requires 3DS
  ↓
Redirects to issuing bank's auth page
  ↓
Customer enters SMS code / biometric / password
  ↓
Bank confirms identity
  ↓
Redirects back to merchant
  ↓
Payment proceeds
```

**Why use it?**
- **Fraud protection:** Shifts liability to issuing bank
- **Required in EU:** Strong Customer Authentication (SCA) regulation
- **Lower fraud rates:** Extra verification step

**Trade-off:**
- Lower fraud vs lower conversion (some customers abandon)

---

### Fraud Detection

**Common checks:**

**1. AVS (Address Verification Service)**
```
Customer enters:
  - Street address
  - ZIP code
  
Gateway sends to issuing bank
  ↓
Bank compares to address on file
  ↓
Returns match result:
  Y = Address and ZIP match
  A = Address matches, ZIP doesn't
  Z = ZIP matches, address doesn't
  N = Neither matches
```

**2. CVV Verification**
```
CVV (3-4 digit code on back of card)
  ↓
Sent to issuing bank
  ↓
Bank checks if it matches
  ↓
Result: M (match), N (no match), U (unavailable)
```

**3. Velocity Checks**
```
Same card used 5 times in 10 minutes? → DECLINE
Same IP address, 10 different cards? → DECLINE
High-value purchase from new customer? → REVIEW
```

**4. Geolocation**
```
Customer's IP in Nigeria
Billing address in USA
Shipping to Russia
→ High fraud risk
```

**5. Device Fingerprinting**
```
Browser type, screen resolution, timezone, installed fonts
  ↓
Creates unique device ID
  ↓
Recognizes returning customers (good)
  ↓
Flags suspicious devices (bad)
```

**6. Machine Learning Models**
```
Train on historical fraud patterns:
  - Transaction amount
  - Time of day
  - Customer history
  - Product type
  - Shipping speed
  
Score each transaction: 0-100 (fraud probability)
  0-30: Auto-approve
  31-70: Manual review
  71-100: Auto-decline
```

---

## Error Handling & Retries

### Common Decline Reasons

**1. Insufficient Funds**
```
Decline Code: 51
Message: "Insufficient funds"
Merchant action: Ask customer for different payment method
Retry: NO (won't work unless customer adds money)
```

**2. Card Expired**
```
Decline Code: 54
Message: "Expired card"
Merchant action: Ask for updated card details
Retry: NO
```

**3. Do Not Honor**
```
Decline Code: 05
Message: "Do not honor" (generic decline)
Reason: Could be fraud suspicion, credit limit, etc.
Merchant action: Ask customer to contact their bank
Retry: MAYBE after customer contacts bank
```

**4. Invalid Card Number**
```
Decline Code: 14
Message: "Invalid card number"
Merchant action: Ask customer to re-enter correctly
Retry: NO (unless typo)
```

**5. Pickup Card (Fraud)**
```
Decline Code: 04 or 07
Message: "Pickup card" / "Pickup card, special condition"
Reason: Card reported stolen/fraudulent
Merchant action: DO NOT RETRY, flag for fraud review
```

**6. Gateway Timeout**
```
No response from gateway after 30 seconds
Merchant action: RETRY (network issue, not customer issue)
Idempotency key: Ensure not double-charged
```

---

### Retry Strategy

**Immediate retries (network errors only):**
```python
async def process_payment(payment_data, max_retries=3):
    for attempt in range(max_retries):
        try:
            response = await gateway.charge(payment_data)
            return response
            
        except NetworkError as e:
            if attempt < max_retries - 1:
                await asyncio.sleep(2 ** attempt)  # Exponential backoff: 1s, 2s, 4s
                continue
            raise
            
        except DeclineError as e:
            # Don't retry declines - customer issue, not network
            raise
```

**Scheduled retries (for subscription billing):**
```
Day 1: Initial attempt → Declined (insufficient funds)
Day 3: Retry #1 (payday might have happened)
Day 7: Retry #2
Day 14: Retry #3
Day 30: Give up, suspend service
```

**Smart retry:**
```python
def should_retry(decline_code):
    # Retry these (temporary issues)
    retriable_codes = [
        '51',  # Insufficient funds (might have money later)
        '61',  # Exceeds withdrawal limit (resets daily)
        '65',  # Exceeds transaction limit
    ]
    
    # Don't retry these (permanent issues)
    do_not_retry = [
        '04',  # Pickup card (fraud)
        '07',  # Pickup card (fraud)
        '14',  # Invalid card number
        '54',  # Expired card
        '57',  # Transaction not permitted
    ]
    
    return decline_code in retriable_codes
```

---

### Idempotency

**Problem:**
```
Customer clicks "Pay"
  ↓
Gateway processes payment (SUCCESS)
  ↓
Response times out (network issue)
  ↓
Customer clicks "Pay" again
  ↓
Gateway processes AGAIN (DUPLICATE CHARGE!)
```

**Solution: Idempotency Key**
```javascript
// Generate unique key per payment attempt
const idempotencyKey = `payment_${invoiceId}_${customerId}_${timestamp}`;

// Send with payment request
POST https://api.stripe.com/v1/charges
Headers:
  Idempotency-Key: payment_12345_67890_1699999999

// Gateway caches result for 24 hours
// If same key sent again → returns cached result (no new charge)
```

**Implementation:**
```python
# Store in Redis with 24-hour TTL
def process_payment(payment_data, idempotency_key):
    # Check if already processed
    cached = redis.get(f"payment:{idempotency_key}")
    if cached:
        return json.loads(cached)
    
    # Process payment
    result = gateway.charge(payment_data)
    
    # Cache result
    redis.setex(
        f"payment:{idempotency_key}",
        86400,  # 24 hours
        json.dumps(result)
    )
    
    return result
```

---

## Reconciliation & Settlement

### Daily Reconciliation

**Purpose:** Ensure gateway charges match bank deposits

**Process:**
```
Every morning:
  ↓
1. Download settlement report from gateway
   - All successful charges from yesterday
   - Total: $10,450.75
   
2. Download bank statement
   - Deposit: $10,088.19 (after fees)
   
3. Calculate expected deposit
   Gross:      $10,450.75
   Fees (3%):    -$313.52
   Refunds:       -$49.04
   Expected:   $10,088.19 ✓ MATCHES
   
4. Match individual transactions
   Gateway Transaction ID ↔ Bank Reference Number
```

**Discrepancies to watch for:**
- Chargebacks (customer disputed charge)
- Refunds processed but not recorded
- Failed settlements (account closed, invalid account)
- Gateway fees changed

---

### Chargeback Process

**What is it?**
Customer disputes a charge with their bank

**Flow:**
```
Day 0: Customer makes purchase ($100)
Day 30: Customer calls bank: "I didn't authorize this"
Day 31: Bank initiates chargeback
  ↓
Bank debits merchant account $100
  ↓
Bank credits customer account $100
  ↓
Merchant receives chargeback notice (via gateway)
  ↓
Merchant has 7-10 days to provide evidence:
  - Proof of delivery (tracking number)
  - Customer signature
  - IP address matching billing address
  - Customer communication (emails)
  ↓
Bank reviews evidence
  ↓
Outcome:
  - Merchant wins: $100 returned to merchant
  - Customer wins: Customer keeps $100, merchant loses
```

**Chargeback reason codes:**
- **Fraud:** "I didn't make this purchase"
- **Product not received:** "Item never arrived"
- **Product not as described:** "Different from photo"
- **Duplicate charge:** "Charged twice"
- **Canceled subscription:** "I canceled but still charged"

**Chargeback fees:**
- $15-$25 per chargeback (even if you win!)
- High chargeback rate (> 1%) → gateway penalties or account termination

**Prevention:**
- Require signature for high-value orders
- Use delivery confirmation (tracking)
- Clear product descriptions
- Responsive customer service (resolve before chargeback)
- 3D Secure (shifts liability to bank)

---

## System Design Considerations

### Database Schema

```sql
-- Customers
CREATE TABLE customers (
    id BIGINT PRIMARY KEY,
    email VARCHAR(255),
    name VARCHAR(255),
    created_at TIMESTAMP
);

-- Payment Methods (Tokenized)
CREATE TABLE payment_methods (
    id BIGINT PRIMARY KEY,
    customer_id BIGINT,
    gateway_token VARCHAR(255),  -- tok_abc123 (NOT real card number!)
    type ENUM('card', 'bank_account'),
    last4 VARCHAR(4),
    brand VARCHAR(50),  -- Visa, Mastercard, etc.
    exp_month INT,
    exp_year INT,
    is_default BOOLEAN,
    created_at TIMESTAMP,
    INDEX idx_customer (customer_id)
);

-- Transactions
CREATE TABLE transactions (
    id BIGINT PRIMARY KEY,
    customer_id BIGINT,
    payment_method_id BIGINT,
    invoice_id BIGINT,
    amount DECIMAL(10,2),
    currency VARCHAR(3),
    status ENUM('pending', 'authorized', 'captured', 'failed', 'refunded', 'disputed'),
    gateway VARCHAR(50),  -- stripe, authorize_net, etc.
    gateway_transaction_id VARCHAR(255),
    authorization_code VARCHAR(50),
    decline_code VARCHAR(10),
    decline_message VARCHAR(255),
    idempotency_key VARCHAR(255) UNIQUE,
    created_at TIMESTAMP,
    authorized_at TIMESTAMP,
    captured_at TIMESTAMP,
    INDEX idx_customer (customer_id),
    INDEX idx_invoice (invoice_id),
    INDEX idx_status (status),
    INDEX idx_created (created_at)
);

-- Audit Log
CREATE TABLE payment_audit (
    id BIGINT PRIMARY KEY,
    transaction_id BIGINT,
    action VARCHAR(50),  -- 'authorize', 'capture', 'refund', 'chargeback'
    request JSON,
    response JSON,
    ip_address VARCHAR(45),
    user_agent VARCHAR(255),
    created_at TIMESTAMP,
    INDEX idx_transaction (transaction_id)
);
```

---

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CUSTOMER                                 │
│                  (Web / Mobile App)                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ HTTPS
                       ↓
┌──────────────────────────────────────────────────────────────┐
│                   LOAD BALANCER                               │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ↓              ↓              ↓
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  App Server  │ │  App Server  │ │  App Server  │
│              │ │              │ │              │
│ - Payment    │ │ - Payment    │ │ - Payment    │
│   API        │ │   API        │ │   API        │
│ - Validation │ │ - Validation │ │ - Validation │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       │                │                │
       └────────────────┼────────────────┘
                        │
         ┌──────────────┼──────────────┐
         ↓              ↓              ↓
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   Redis      │ │  PostgreSQL  │ │  Message     │
│   (Cache)    │ │  (Database)  │ │  Queue       │
│              │ │              │ │  (RabbitMQ)  │
│ - Tokens     │ │ - Customers  │ │              │
│ - Idempotent │ │ - Txns       │ │ - Async jobs │
│ - Rate limit │ │ - Audit      │ │ - Retries    │
└──────────────┘ └──────────────┘ └──────┬───────┘
                                         │
                                         ↓
                                  ┌──────────────┐
                                  │   Workers    │
                                  │              │
                                  │ - Retry      │
                                  │ - Settlement │
                                  │ - Webhooks   │
                                  └──────┬───────┘
                                         │
         ┌───────────────────────────────┼─────────────┐
         ↓                               ↓             ↓
┌──────────────────┐          ┌──────────────┐  ┌──────────────┐
│ Payment Gateway  │          │   Fraud      │  │   Monitoring │
│                  │          │   Service    │  │              │
│ - Stripe         │          │              │  │ - Datadog    │
│ - Authorize.Net  │          │ - Rules      │  │ - Splunk     │
│ - Braintree      │          │ - ML Models  │  │ - Alerts     │
└──────────────────┘          └──────────────┘  └──────────────┘
```

---

### Scalability Considerations

**1. Horizontal Scaling**
- Stateless app servers (scale to 100s of instances)
- Load balancer distributes traffic
- Session data in Redis (shared across servers)

**2. Database**
- Read replicas for reporting/analytics
- Shard by customer_id (isolate high-volume merchants)
- Archive old transactions (> 2 years) to S3

**3. Caching**
```python
# Cache customer payment methods (1 hour TTL)
cache_key = f"customer:{customer_id}:payment_methods"
payment_methods = redis.get(cache_key)
if not payment_methods:
    payment_methods = db.query(...)
    redis.setex(cache_key, 3600, json.dumps(payment_methods))
```

**4. Async Processing**
```
Synchronous (blocking):
  Customer → API → Gateway (2-3 seconds) → Response
  
Asynchronous (non-blocking):
  Customer → API → Queue → Immediate "Processing..." response
                      ↓
                   Worker → Gateway → Update DB → Webhook to customer
```

**5. Rate Limiting**
```python
# Prevent abuse: 10 payment attempts per customer per hour
key = f"rate_limit:payment:{customer_id}"
count = redis.incr(key)
if count == 1:
    redis.expire(key, 3600)  # 1 hour
if count > 10:
    raise TooManyAttemptsError()
```

---

## Real-World Example (Enterprise SaaS Company MPay)

**Your payment processing context:**

### Architecture
```
Invoice Generated in EIC
  ↓
Customer receives email with "Pay Now" link
  ↓
Clicks link → Redirects to MPay (Managed Pay)
  ↓
MPay presents payment options:
  - Credit Card (via Stripe/Authorize.Net)
  - ACH / eCheck (via Nacha network)
  - Saved payment methods (tokenized)
  ↓
Customer enters payment details
  ↓
MPay → Payment Gateway → Card Network → Issuing Bank
  ↓
Authorization response
  ↓
MPay updates invoice status in EIC
  ↓
Funds settled to Enterprise SaaS Company merchant account (2-3 days)
  ↓
Enterprise SaaS Company reconciles and remits to actual merchant
```

### Key Features

**1. Tokenization**
- First payment: Store card as token
- Future payments: Use stored token (no re-entering)
- Reduces PCI scope

**2. AutoPay**
```sql
-- Check for autopay enrollment
SELECT * FROM fsiaccountautopay 
WHERE AccountNumber = ? AND Active = 1;

-- Automatic payment on due date
-- Worker checks invoices due today
-- Processes payments with stored tokens
-- Retries on failure (smart retry logic)
```

**3. Payment Retry Logic**
```python
# From your actual work
def retry_payment(invoice_id):
    attempt = get_retry_attempt(invoice_id)
    
    if attempt == 1:
        # Immediate retry
        process_payment(invoice_id)
    elif attempt == 2:
        # Wait 1 day (payday might have occurred)
        schedule_payment(invoice_id, days=1)
    elif attempt == 3:
        # Wait 5 more days
        schedule_payment(invoice_id, days=5)
    else:
        # Give up, notify customer
        send_payment_failed_email(invoice_id)
```

**4. Multi-Gateway Support**
```python
# Route based on customer preference or gateway availability
def get_gateway(customer_id):
    customer = get_customer(customer_id)
    
    if customer.preferred_gateway:
        return customer.preferred_gateway
    elif customer.monthly_volume > 100000:
        return 'authorize_net'  # Better rates for high volume
    else:
        return 'stripe'  # Default
```

**5. Reconciliation**
```sql
-- Daily settlement report
SELECT 
    COUNT(*) as transaction_count,
    SUM(amount) as gross_amount,
    SUM(gateway_fee) as total_fees,
    SUM(amount - gateway_fee) as net_amount,
    gateway,
    DATE(settled_at) as settlement_date
FROM transactions
WHERE status = 'captured'
  AND settled_at >= CURDATE()
GROUP BY gateway, DATE(settled_at);
```

---

## Interview Questions

### Q1: Design a payment processing system for an e-commerce site processing 10M transactions/day.

**Answer:**
```
Requirements:
- 10M txns/day = ~116 txns/second average, ~350 peak
- Subsecond latency for auth
- 99.99% uptime
- PCI-compliant
- Support retries and idempotency

Architecture:
[Draw the high-level architecture diagram above]

Key components:
1. Load balancer (AWS ELB)
2. Stateless app servers (10-50 instances, autoscale)
3. Redis cluster (idempotency cache, rate limiting, session)
4. PostgreSQL (customer data, transactions) - master + read replicas
5. Message queue (RabbitMQ) for async retries
6. Payment gateway integration (Stripe or Authorize.Net)

Database sharding:
- Shard by customer_id (isolate high-volume merchants)
- 100 shards, 100K customers per shard

Caching:
- Customer payment methods (1 hour TTL)
- Fraud rules (10 min TTL)

Security:
- Never store real card numbers (use tokens)
- SSL/TLS everywhere
- PCI-DSS Level 1 compliance
- 3D Secure for high-risk transactions
```

---

### Q2: How do you handle payment retries without double-charging?

**Answer:**
```
Idempotency keys:

1. Generate unique key per payment attempt:
   key = hash(invoice_id + customer_id + timestamp)
   
2. Before processing, check Redis cache:
   cached_result = redis.get(f"payment:{key}")
   if cached_result:
       return cached_result  # Don't process again
       
3. Process payment with gateway:
   result = gateway.charge(amount, token, idempotency_key=key)
   
4. Cache result for 24 hours:
   redis.setex(f"payment:{key}", 86400, result)
   
5. Return result

If network times out and customer retries:
- Same key → Redis returns cached result
- No double charge

Gateway-level idempotency:
- Most gateways also support idempotency keys
- Send same key to gateway on retry
- Gateway returns same response (doesn't process twice)
```

---

### Q3: How do you detect and prevent fraud?

**Answer:**
```
Multiple layers:

1. AVS (Address Verification):
   - Match billing address to bank records
   - Decline if no match

2. CVV Check:
   - Require CVV for card-not-present
   - Issuing bank validates

3. 3D Secure:
   - Redirect to bank for SMS/biometric auth
   - Required for high-value or high-risk
   - Shifts liability to bank

4. Velocity Checks:
   - Same card, 5+ attempts in 10 min → DECLINE
   - Same IP, different cards → FLAG
   - New customer, high-value purchase → REVIEW

5. Geolocation:
   - IP in Country A
   - Billing in Country B
   - Shipping to Country C
   → High fraud score

6. Device Fingerprinting:
   - Browser, screen, timezone, fonts
   - Creates unique device ID
   - Recognize returning customers (good)
   - Flag suspicious devices (bad)

7. Machine Learning:
   - Train on historical fraud (labeled data)
   - Features: amount, time, customer age, product, shipping
   - Score 0-100
   - 0-30: Auto-approve
   - 31-70: Manual review
   - 71-100: Auto-decline

8. Manual Review Queue:
   - Human reviews flagged transactions
   - Checks for patterns: fake addresses, burner phones
   - Approve or decline
```

---

### Q4: What happens if the payment gateway goes down?

**Answer:**
```
Multiple strategies:

1. Multi-Gateway Failover:
   Primary: Stripe
   Fallback: Authorize.Net
   
   try:
       result = stripe.charge(...)
   except GatewayDownError:
       result = authorize_net.charge(...)
       
2. Circuit Breaker Pattern:
   - After 5 consecutive failures, open circuit
   - Don't send more requests (fail fast)
   - Retry after 60 seconds (half-open)
   - If success, close circuit (resume normal)
   
3. Queue for Retry:
   - If all gateways down, queue payment
   - Worker retries every 5 minutes
   - Customer sees "Payment processing, you'll receive confirmation"
   
4. Monitoring & Alerts:
   - Gateway response time > 5 seconds → Alert
   - Error rate > 1% → Page on-call
   - Switch to backup gateway automatically

5. Status Page:
   - If extended outage, show banner:
     "Payments temporarily unavailable. Your order is saved."
   - Prevent customer frustration
```

---

### Q5: How do you handle chargebacks?

**Answer:**
```
Process:
1. Receive chargeback notice from gateway (webhook)
2. Debit merchant account immediately (reversible if we win)
3. Store in database:
   - Transaction ID
   - Chargeback reason code
   - Evidence deadline (7-10 days)
   
4. Gather evidence automatically:
   - Delivery confirmation (tracking number)
   - Customer communication (emails, support tickets)
   - IP address (from transaction log)
   - Device fingerprint
   - 3D Secure authentication (if used)
   
5. Submit evidence to gateway portal
6. Await bank decision (30-90 days)
7. Outcome:
   - WIN: Funds returned to merchant
   - LOSE: Customer keeps money

Prevention:
- Clear product descriptions
- Require signature for high-value
- Responsive customer service (resolve before chargeback)
- 3D Secure (shifts liability to bank)
- Delivery confirmation
- Clear billing descriptor (customer recognizes charge)

Chargeback monitoring:
- Track rate: chargebacks / total transactions
- If > 1%: Gateway penalties or account termination
- Implement stricter fraud rules to reduce
```

---

## Summary Cheat Sheet

**Payment Flow (10 seconds):**
```
Customer → Merchant → Gateway → Processor → Card Network → Issuing Bank
         ← Response ← Response ← Response ← Response ← Approve/Decline
```

**Key Players:**
1. Customer (cardholder)
2. Merchant (your business)
3. Payment Gateway (Stripe, Authorize.Net)
4. Payment Processor (First Data, Worldpay)
5. Card Network (Visa, Mastercard)
6. Issuing Bank (customer's bank)
7. Acquiring Bank (merchant's bank)

**3 Phases:**
1. **Authorization:** Real-time (2-3 sec), hold funds
2. **Capture:** 1-7 days later, mark for settlement
3. **Settlement:** 1-3 days after capture, money moves

**Security:**
- **PCI-DSS:** Don't store real card numbers
- **Tokenization:** Store tokens instead
- **3D Secure:** Additional auth (like 2FA)
- **Fraud detection:** AVS, CVV, velocity, ML

**Error Handling:**
- **Idempotency:** Prevent double charges
- **Retries:** Only for network errors, not declines
- **Chargebacks:** Customer disputes, gather evidence

---

Good luck with interviews and understanding payment systems! 🚀
