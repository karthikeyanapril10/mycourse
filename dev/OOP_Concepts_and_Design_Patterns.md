# OOP Concepts & Design Patterns

> **For 12+ Years Experience**: Core OOP principles, SOLID, and design patterns with real PHP/.NET examples

---

## 🎯 Why OOP Matters for Staff Engineer Interviews

**You use OOP every day at Billtrust:**
- Laravel Service Container = Dependency Injection
- Eloquent Models = Active Record pattern
- Controllers = MVC pattern
- Repository classes = Repository pattern
- Event listeners = Observer pattern

**Interviewers will ask:**
- "Explain SOLID principles with examples from your work"
- "What design patterns have you used?"
- "When do you use Composition over Inheritance?"
- "Design a system using OOP principles"

**This module:** Translate what you DO into what you SAY in interviews.

---

## 📚 Section 1: Core OOP Principles

### **Q1: Explain the 4 pillars of OOP with real examples**

**Answer:**

**1. Encapsulation (Data Hiding)**
```php
// Billtrust Example: Invoice class
class Invoice {
    private $amount;        // Hidden from outside
    private $customerId;
    private $status;
    
    public function __construct($amount, $customerId) {
        $this->amount = $amount;
        $this->customerId = $customerId;
        $this->status = 'draft';
    }
    
    // Controlled access via public methods
    public function getAmount() {
        return $this->amount;
    }
    
    public function approve() {
        if ($this->status === 'draft') {
            $this->status = 'approved';
            $this->sendNotification();  // Internal logic hidden
        }
    }
    
    private function sendNotification() {
        // Hidden implementation detail
        RabbitMQ::publish('invoice.approved', $this->toArray());
    }
}

// Usage:
$invoice = new Invoice(100.00, 12345);
$invoice->approve();  // Public interface
// $invoice->status = 'approved';  ❌ Error: private property
```

**Why Encapsulation?**
- Prevents invalid state (can't set `status` directly, must use `approve()`)
- Hides complexity (`sendNotification` is internal)
- Easier to refactor (change notification logic without breaking callers)

---

**2. Inheritance (Code Reuse)**
```php
// Billtrust Example: Base Notification class
abstract class Notification {
    protected $customerId;
    protected $message;
    
    public function __construct($customerId, $message) {
        $this->customerId = $customerId;
        $this->message = $message;
    }
    
    abstract public function send();  // Subclasses must implement
    
    protected function log() {
        Logger::info("Notification sent to customer {$this->customerId}");
    }
}

class EmailNotification extends Notification {
    public function send() {
        SendGrid::send($this->getCustomerEmail(), $this->message);
        $this->log();  // Inherited method
    }
    
    private function getCustomerEmail() {
        return Customer::find($this->customerId)->email;
    }
}

class SMSNotification extends Notification {
    public function send() {
        Twilio::send($this->getCustomerPhone(), $this->message);
        $this->log();  // Inherited method
    }
    
    private function getCustomerPhone() {
        return Customer::find($this->customerId)->phone;
    }
}

// Usage:
$email = new EmailNotification(12345, "Invoice ready");
$email->send();  // Sends via SendGrid, logs automatically
```

**Why Inheritance?**
- DRY: `log()` method written once, used by all subclasses
- Polymorphism: Both EmailNotification and SMSNotification are Notifications
- Extensibility: Add PushNotification without changing existing code

---

**3. Polymorphism (Many Forms)**
```php
// Billtrust Example: Payment processing
interface PaymentProcessor {
    public function charge($amount, $token);
}

class StripeProcessor implements PaymentProcessor {
    public function charge($amount, $token) {
        return Stripe::charge(['amount' => $amount, 'source' => $token]);
    }
}

class AuthorizeNetProcessor implements PaymentProcessor {
    public function charge($amount, $token) {
        return AuthorizeNet::charge($amount, $token);
    }
}

class PaymentService {
    private $processor;
    
    public function __construct(PaymentProcessor $processor) {
        $this->processor = $processor;  // Accepts ANY PaymentProcessor
    }
    
    public function processPayment($amount, $token) {
        try {
            $result = $this->processor->charge($amount, $token);
            $this->logSuccess($result);
            return $result;
        } catch (Exception $e) {
            $this->logFailure($e);
            throw $e;
        }
    }
}

// Usage:
$service = new PaymentService(new StripeProcessor());
$service->processPayment(100.00, 'tok_visa');

// Switch to Authorize.Net without changing PaymentService code:
$service = new PaymentService(new AuthorizeNetProcessor());
$service->processPayment(100.00, 'tok_visa');
```

**Why Polymorphism?**
- Flexibility: Swap payment processors without changing `PaymentService`
- Testability: Mock `PaymentProcessor` in tests
- Open/Closed: `PaymentService` closed for modification, open for extension

---

**4. Abstraction (Hide Complexity)**
```php
// Billtrust Example: Database abstraction
// User doesn't need to know SQL details
class InvoiceRepository {
    public function findByCustomer($customerId) {
        // Abstraction: Hide SQL complexity
        return DB::table('fsiinvoice')
            ->where('CustomerId', $customerId)
            ->where('Status', 'approved')
            ->orderBy('InvoiceDate', 'desc')
            ->get();
    }
    
    public function create($data) {
        // Abstraction: Hide validation, audit logging
        $this->validate($data);
        $invoice = DB::table('fsiinvoice')->insert($data);
        $this->logAudit('invoice_created', $invoice->id);
        return $invoice;
    }
    
    private function validate($data) { /* ... */ }
    private function logAudit($action, $id) { /* ... */ }
}

// Usage (simple interface, complex implementation hidden):
$repo = new InvoiceRepository();
$invoices = $repo->findByCustomer(12345);
```

**Why Abstraction?**
- Simplicity: Caller doesn't write SQL
- Consistency: Validation + audit logging happens automatically
- Maintainability: Change DB schema, update repository only

---

**Your Experience:**
"At Billtrust, we use all 4 pillars daily:
- **Encapsulation**: Invoice status can only change via approved methods, preventing invalid states
- **Inheritance**: Base Notification class for Email/SMS/Push, sharing logging and retry logic
- **Polymorphism**: PaymentProcessor interface lets us swap Stripe/Authorize.Net without changing business logic
- **Abstraction**: Repository pattern hides SQL complexity, ensuring all invoice queries include tenant scoping"

---

### **Q2: Composition vs Inheritance — when to use which?**

**Answer:**

**Inheritance (IS-A relationship):**
```php
class Vehicle {
    protected $speed;
    public function accelerate() { $this->speed += 10; }
}

class Car extends Vehicle {
    // Car IS-A Vehicle
}
```

**Composition (HAS-A relationship):**
```php
class Car {
    private $engine;  // Car HAS-AN Engine
    
    public function __construct(Engine $engine) {
        $this->engine = $engine;
    }
    
    public function start() {
        $this->engine->start();
    }
}

class Engine {
    public function start() { /* ... */ }
}
```

---

**When to Use Inheritance:**

✅ **True IS-A relationship** (Car is a Vehicle, EmailNotification is a Notification)  
✅ **Shared behavior** that belongs to ALL subclasses  
✅ **Polymorphism needed** (treat all subclasses the same via parent type)

**Billtrust Example:**
```php
abstract class BaseController {
    protected function getUserId() {
        return Auth::user()->id;
    }
    
    protected function getCustomerId() {
        return Auth::user()->customer_id;
    }
}

class InvoiceController extends BaseController {
    public function index() {
        $customerId = $this->getCustomerId();  // Inherited
        return Invoice::where('customer_id', $customerId)->get();
    }
}

class PaymentController extends BaseController {
    public function index() {
        $customerId = $this->getCustomerId();  // Inherited
        return Payment::where('customer_id', $customerId)->get();
    }
}
```

**Why Inheritance here?**
- InvoiceController IS-A Controller
- All controllers need `getUserId()`, `getCustomerId()`
- Polymorphism: Middleware treats all controllers the same

---

**When to Use Composition:**

✅ **HAS-A relationship** (Car has an Engine, not "is an Engine")  
✅ **Multiple behaviors** (can't inherit from 2 classes in PHP)  
✅ **Behavior can change at runtime** (swap components)

**Billtrust Example:**
```php
// ❌ BAD: Inheritance for behavior
class InvoiceWithEmail extends Invoice {
    public function send() { /* email logic */ }
}

class InvoiceWithSMS extends Invoice {
    public function send() { /* SMS logic */ }
}

// What if we need BOTH email AND SMS? Can't inherit from both!

// ✅ GOOD: Composition
class Invoice {
    private $notifiers = [];  // HAS-A collection of Notifiers
    
    public function addNotifier(Notifier $notifier) {
        $this->notifiers[] = $notifier;
    }
    
    public function send() {
        foreach ($this->notifiers as $notifier) {
            $notifier->notify($this);
        }
    }
}

interface Notifier {
    public function notify(Invoice $invoice);
}

class EmailNotifier implements Notifier {
    public function notify(Invoice $invoice) {
        SendGrid::send($invoice->getCustomerEmail(), $invoice->getBody());
    }
}

class SMSNotifier implements Notifier {
    public function notify(Invoice $invoice) {
        Twilio::send($invoice->getCustomerPhone(), $invoice->getSummary());
    }
}

// Usage (flexible!):
$invoice = new Invoice();
$invoice->addNotifier(new EmailNotifier());
$invoice->addNotifier(new SMSNotifier());  // Both!
$invoice->send();  // Sends via email AND SMS
```

**Why Composition here?**
- Flexibility: Can add/remove notifiers at runtime
- Multiple behaviors: Email + SMS + Push (can't do with inheritance)
- Single Responsibility: Invoice focuses on invoice logic, Notifiers handle notification

---

**Rule of Thumb:**
```
Prefer Composition over Inheritance

Use Inheritance when:
  - True IS-A relationship
  - Shared behavior belongs to ALL subclasses
  - Polymorphism needed

Use Composition when:
  - HAS-A relationship
  - Need multiple behaviors
  - Behavior can change at runtime
  - Would violate Single Responsibility Principle
```

**Your Experience:**
"At Billtrust, we use Composition for notification delivery — an Invoice HAS notifiers (email, SMS, push), not IS-A EmailInvoice. This lets us combine multiple channels without messy inheritance hierarchies. We use Inheritance for controllers and services where true IS-A relationships exist and shared middleware logic applies to all subclasses."

---

### **Q3: Interface vs Abstract Class — when to use each?**

**Answer:**

**Interface (Contract Only):**
```php
interface PaymentGateway {
    public function authorize($amount, $cardToken);
    public function capture($transactionId);
    public function refund($transactionId, $amount);
}

// No implementation, no state, only method signatures
```

**Abstract Class (Partial Implementation):**
```php
abstract class BasePaymentGateway {
    protected $apiKey;
    
    public function __construct($apiKey) {
        $this->apiKey = $apiKey;  // Shared state
    }
    
    public function authorize($amount, $cardToken) {
        $this->logRequest('authorize', $amount);  // Shared behavior
        return $this->doAuthorize($amount, $cardToken);  // Delegate to subclass
    }
    
    abstract protected function doAuthorize($amount, $cardToken);  // Must implement
    
    protected function logRequest($action, $amount) {
        Logger::info("Payment {$action}: {$amount}");
    }
}
```

---

**When to Use Interface:**

✅ **Contract only** (no shared implementation)  
✅ **Multiple inheritance** (class can implement multiple interfaces)  
✅ **Loose coupling** (depends on behavior, not implementation)

**Billtrust Example:**
```php
interface Cacheable {
    public function getCacheKey();
    public function getCacheTTL();
}

interface Auditable {
    public function getAuditData();
}

class Invoice implements Cacheable, Auditable {
    // Can implement BOTH interfaces
    
    public function getCacheKey() {
        return "invoice:{$this->id}";
    }
    
    public function getCacheTTL() {
        return 3600;  // 1 hour
    }
    
    public function getAuditData() {
        return [
            'invoice_id' => $this->id,
            'amount' => $this->amount,
            'customer_id' => $this->customer_id
        ];
    }
}

// Service depends on interface, not concrete class:
class CacheService {
    public function remember(Cacheable $obj) {
        $key = $obj->getCacheKey();
        $ttl = $obj->getCacheTTL();
        return Cache::remember($key, $ttl, fn() => $obj);
    }
}

// Works with ANY Cacheable object:
$cache = new CacheService();
$cache->remember($invoice);  // Invoice is Cacheable
$cache->remember($customer);  // Customer is Cacheable
```

**Why Interface here?**
- Multiple behaviors: Invoice is both Cacheable AND Auditable
- Loose coupling: CacheService doesn't care about Invoice internals
- Polymorphism: Any Cacheable object works

---

**When to Use Abstract Class:**

✅ **Shared implementation** (not just contract)  
✅ **Shared state** (properties)  
✅ **Template Method pattern** (shared flow, subclass customizes steps)

**Billtrust Example:**
```php
abstract class BaseReport {
    protected $customerId;
    protected $startDate;
    protected $endDate;
    
    public function __construct($customerId, $startDate, $endDate) {
        $this->customerId = $customerId;
        $this->startDate = $startDate;
        $this->endDate = $endDate;
    }
    
    // Template Method: Shared flow
    public function generate() {
        $this->validateDates();  // Shared
        $data = $this->fetchData();  // Subclass-specific
        $formatted = $this->formatData($data);  // Subclass-specific
        $this->log();  // Shared
        return $formatted;
    }
    
    protected function validateDates() {
        if ($this->startDate > $this->endDate) {
            throw new InvalidArgumentException("Start date must be before end date");
        }
    }
    
    protected function log() {
        Logger::info("Report generated for customer {$this->customerId}");
    }
    
    abstract protected function fetchData();  // Must implement
    abstract protected function formatData($data);  // Must implement
}

class InvoiceReport extends BaseReport {
    protected function fetchData() {
        return DB::table('fsiinvoice')
            ->where('CustomerId', $this->customerId)
            ->whereBetween('InvoiceDate', [$this->startDate, $this->endDate])
            ->get();
    }
    
    protected function formatData($data) {
        return $data->map(fn($inv) => [
            'invoice_number' => $inv->InvoiceNumber,
            'amount' => $inv->Amount
        ]);
    }
}

class PaymentReport extends BaseReport {
    protected function fetchData() {
        return DB::table('fsipayment')
            ->where('CustomerId', $this->customerId)
            ->whereBetween('PaymentDate', [$this->startDate, $this->endDate])
            ->get();
    }
    
    protected function formatData($data) {
        return $data->map(fn($pay) => [
            'payment_id' => $pay->PaymentId,
            'amount' => $pay->Amount
        ]);
    }
}

// Usage:
$report = new InvoiceReport(12345, '2024-01-01', '2024-01-31');
$data = $report->generate();  // Shared flow, custom data fetching
```

**Why Abstract Class here?**
- Shared state: All reports have `customerId`, `startDate`, `endDate`
- Shared behavior: `validateDates()`, `log()`, `generate()` flow
- Template Method: `generate()` defines the flow, subclasses customize steps

---

**Interface vs Abstract Class:**

| Feature | Interface | Abstract Class |
|---------|-----------|----------------|
| Implementation | None (contract only) | Partial (shared code) |
| State (properties) | ❌ No | ✅ Yes |
| Multiple inheritance | ✅ Yes (implement many) | ❌ No (extend one) |
| When to use | Define behavior contract | Share code + template flow |

**Rule of Thumb:**
```
Use Interface when:
  - Defining a contract (no shared implementation)
  - Multiple inheritance needed
  - Loose coupling (depend on behavior, not class)

Use Abstract Class when:
  - Sharing code between subclasses
  - Sharing state (properties)
  - Template Method pattern (shared flow, custom steps)
```

**Your Experience:**
"At Billtrust, we use Interfaces for cross-cutting concerns like Cacheable, Auditable, Queueable — behaviors that many unrelated classes need. We use Abstract Classes for report generation where all reports share validation, logging, and flow control, but differ in data fetching. This keeps our codebase DRY while maintaining flexibility."

---

## 📚 Section 2: SOLID Principles

### **Q4: Explain SOLID with PHP examples from your work**

**Answer:**

**SOLID = 5 principles for maintainable OOP code**

---

**S = Single Responsibility Principle (SRP)**

**Definition:** A class should have ONE reason to change.

**❌ Bad (God Object):**
```php
class Invoice {
    public function calculate() { /* business logic */ }
    public function saveToDatabase() { /* persistence */ }
    public function sendEmail() { /* notification */ }
    public function generatePDF() { /* rendering */ }
}

// Invoice has 4 reasons to change:
//   1. Business rules change
//   2. Database schema changes
//   3. Email provider changes
//   4. PDF template changes
```

**✅ Good (Single Responsibility):**
```php
class Invoice {
    public function calculate() { /* business logic ONLY */ }
}

class InvoiceRepository {
    public function save(Invoice $invoice) { /* persistence ONLY */ }
}

class InvoiceNotifier {
    public function sendEmail(Invoice $invoice) { /* notification ONLY */ }
}

class InvoicePDFGenerator {
    public function generate(Invoice $invoice) { /* rendering ONLY */ }
}

// Each class has ONE reason to change
```

---

**O = Open/Closed Principle (OCP)**

**Definition:** Open for extension, closed for modification.

**❌ Bad (Modifying existing code):**
```php
class PaymentProcessor {
    public function process($method, $amount) {
        if ($method === 'stripe') {
            Stripe::charge($amount);
        } elseif ($method === 'authorize_net') {
            AuthorizeNet::charge($amount);
        } elseif ($method === 'paypal') {  // ← Adding PayPal requires modifying this class
            PayPal::charge($amount);
        }
    }
}
```

**✅ Good (Extension without modification):**
```php
interface PaymentGateway {
    public function charge($amount);
}

class StripeGateway implements PaymentGateway {
    public function charge($amount) { Stripe::charge($amount); }
}

class AuthorizeNetGateway implements PaymentGateway {
    public function charge($amount) { AuthorizeNet::charge($amount); }
}

class PayPalGateway implements PaymentGateway {  // ← New class, no modification!
    public function charge($amount) { PayPal::charge($amount); }
}

class PaymentProcessor {
    private $gateway;
    
    public function __construct(PaymentGateway $gateway) {
        $this->gateway = $gateway;
    }
    
    public function process($amount) {
        $this->gateway->charge($amount);  // No modification needed!
    }
}
```

---

**L = Liskov Substitution Principle (LSP)**

**Definition:** Subclass should be substitutable for parent without breaking behavior.

**❌ Bad (Violates LSP):**
```php
class Bird {
    public function fly() { /* flying logic */ }
}

class Penguin extends Bird {
    public function fly() {
        throw new Exception("Penguins can't fly!");  // ← Breaks LSP!
    }
}

function makeBirdFly(Bird $bird) {
    $bird->fly();  // Crashes if $bird is Penguin
}
```

**✅ Good (Respects LSP):**
```php
interface Bird {
    public function move();
}

class FlyingBird implements Bird {
    public function move() { $this->fly(); }
    private function fly() { /* flying logic */ }
}

class Penguin implements Bird {
    public function move() { $this->swim(); }  // No fly() method!
    private function swim() { /* swimming logic */ }
}

function makeBirdMove(Bird $bird) {
    $bird->move();  // Works for ALL birds
}
```

**Billtrust Example:**
```php
// ❌ Bad
class PaymentGateway {
    public function refund($transactionId, $amount) { /* refund logic */ }
}

class BitcoinGateway extends PaymentGateway {
    public function refund($transactionId, $amount) {
        throw new Exception("Bitcoin doesn't support refunds!");  // ← Breaks LSP
    }
}

// ✅ Good
interface RefundableGateway {
    public function refund($transactionId, $amount);
}

class StripeGateway implements RefundableGateway {
    public function refund($transactionId, $amount) { /* refund */ }
}

class BitcoinGateway {  // Does NOT implement RefundableGateway
    public function charge($amount) { /* charge only */ }
}
```

---

**I = Interface Segregation Principle (ISP)**

**Definition:** Don't force classes to implement methods they don't need.

**❌ Bad (Fat Interface):**
```php
interface Worker {
    public function work();
    public function eat();
    public function sleep();
}

class HumanWorker implements Worker {
    public function work() { /* ... */ }
    public function eat() { /* ... */ }
    public function sleep() { /* ... */ }
}

class RobotWorker implements Worker {
    public function work() { /* ... */ }
    public function eat() { /* Nothing */ }  // ← Robots don't eat!
    public function sleep() { /* Nothing */ }  // ← Robots don't sleep!
}
```

**✅ Good (Segregated Interfaces):**
```php
interface Workable {
    public function work();
}

interface Eatable {
    public function eat();
}

interface Sleepable {
    public function sleep();
}

class HumanWorker implements Workable, Eatable, Sleepable {
    public function work() { /* ... */ }
    public function eat() { /* ... */ }
    public function sleep() { /* ... */ }
}

class RobotWorker implements Workable {
    public function work() { /* ... */ }  // Only implements what it needs!
}
```

**Billtrust Example:**
```php
// ❌ Bad
interface PaymentProcessor {
    public function authorize($amount);
    public function capture($transactionId);
    public function refund($transactionId);
    public function recurring($amount, $frequency);  // ← Not all gateways support recurring!
}

// ✅ Good
interface PaymentProcessor {
    public function authorize($amount);
    public function capture($transactionId);
}

interface RefundableProcessor {
    public function refund($transactionId);
}

interface RecurringProcessor {
    public function recurring($amount, $frequency);
}

class StripeProcessor implements PaymentProcessor, RefundableProcessor, RecurringProcessor {
    // Implements all 3 (Stripe supports everything)
}

class BitcoinProcessor implements PaymentProcessor {
    // Only implements basic payment (no refunds, no recurring)
}
```

---

**D = Dependency Inversion Principle (DIP)**

**Definition:** Depend on abstractions, not concretions.

**❌ Bad (Depends on concrete class):**
```php
class InvoiceService {
    private $mailer;
    
    public function __construct() {
        $this->mailer = new SendGridMailer();  // ← Hardcoded dependency!
    }
    
    public function sendInvoice(Invoice $invoice) {
        $this->mailer->send($invoice->getEmail(), $invoice->getBody());
    }
}

// Can't swap SendGrid for SES without modifying InvoiceService
```

**✅ Good (Depends on abstraction):**
```php
interface Mailer {
    public function send($to, $body);
}

class SendGridMailer implements Mailer {
    public function send($to, $body) { SendGrid::send($to, $body); }
}

class SESMailer implements Mailer {
    public function send($to, $body) { AWS_SES::send($to, $body); }
}

class InvoiceService {
    private $mailer;
    
    public function __construct(Mailer $mailer) {  // ← Depends on interface!
        $this->mailer = $mailer;
    }
    
    public function sendInvoice(Invoice $invoice) {
        $this->mailer->send($invoice->getEmail(), $invoice->getBody());
    }
}

// Usage (Laravel DI):
$service = new InvoiceService(new SendGridMailer());  // Inject dependency
$service = new InvoiceService(new SESMailer());  // Easy to swap!
```

**Billtrust Example (Laravel Service Container):**
```php
// config/app.php (bind interface to implementation)
$app->bind(Mailer::class, SendGridMailer::class);

// Controller (Laravel injects automatically)
class InvoiceController {
    public function __construct(private Mailer $mailer) {}  // ← DI!
    
    public function send(Invoice $invoice) {
        $this->mailer->send($invoice->getEmail(), $invoice->getBody());
    }
}

// No `new` keyword! Laravel resolves Mailer → SendGridMailer automatically
```

---

**Your Experience:**
"At Billtrust, we apply SOLID daily:
- **SRP**: Repository pattern separates persistence from business logic
- **OCP**: Payment gateway interface lets us add new providers without modifying existing code
- **LSP**: All notification classes (Email, SMS, Push) are interchangeable via the Notifier interface
- **ISP**: Cacheable, Auditable, Queueable interfaces are small and focused
- **DIP**: Laravel DI container injects dependencies (Mailer, Cache, DB) so we depend on interfaces, not concrete classes"

---

### **Q5: Single Responsibility Principle — refactor a God Object**

**Answer:**

**❌ God Object (Before Refactoring):**
```php
class InvoiceProcessor {
    public function processInvoice($customerId, $items) {
        // 1. Validate customer
        $customer = DB::table('fsicustomer')->where('CustomerId', $customerId)->first();
        if (!$customer) {
            throw new Exception("Customer not found");
        }
        
        // 2. Calculate total
        $total = 0;
        foreach ($items as $item) {
            $total += $item['price'] * $item['quantity'];
        }
        
        // 3. Apply discount
        if ($customer->DiscountPercent > 0) {
            $total -= $total * ($customer->DiscountPercent / 100);
        }
        
        // 4. Save to database
        $invoiceId = DB::table('fsiinvoice')->insertGetId([
            'CustomerId' => $customerId,
            'Amount' => $total,
            'Status' => 'draft',
            'InvoiceDate' => now()
        ]);
        
        // 5. Generate PDF
        $pdf = PDF::loadView('invoice.template', compact('customer', 'items', 'total'));
        $pdfPath = "invoices/{$invoiceId}.pdf";
        Storage::put($pdfPath, $pdf->output());
        
        // 6. Send email
        $email = $customer->Email;
        SendGrid::send($email, "Your invoice is ready", "Invoice attached", $pdfPath);
        
        // 7. Log to audit trail
        DB::table('fsiaudit')->insert([
            'EntityId' => $invoiceId,
            'Action' => 'invoice_created',
            'UserId' => Auth::id(),
            'CreatedAt' => now()
        ]);
        
        // 8. Publish event
        RabbitMQ::publish('invoice.created', ['invoice_id' => $invoiceId]);
        
        return $invoiceId;
    }
}

// 8 responsibilities in one method!
```

**Problems:**
- Changes to discount logic require modifying this class
- Changes to email provider require modifying this class
- Changes to PDF template require modifying this class
- Hard to test (must mock DB, PDF, SendGrid, RabbitMQ all at once)
- Violates SRP: 8 reasons to change

---

**✅ Refactored (Single Responsibility per Class):**

**1. Customer Validator**
```php
class CustomerValidator {
    public function validate($customerId) {
        $customer = DB::table('fsicustomer')->where('CustomerId', $customerId)->first();
        if (!$customer) {
            throw new CustomerNotFoundException();
        }
        return $customer;
    }
}
```

**2. Invoice Calculator**
```php
class InvoiceCalculator {
    public function calculate($items, $discountPercent) {
        $subtotal = array_reduce($items, fn($sum, $item) => 
            $sum + ($item['price'] * $item['quantity']), 0);
        
        $discount = $subtotal * ($discountPercent / 100);
        return $subtotal - $discount;
    }
}
```

**3. Invoice Repository**
```php
class InvoiceRepository {
    public function create($customerId, $amount) {
        return DB::table('fsiinvoice')->insertGetId([
            'CustomerId' => $customerId,
            'Amount' => $amount,
            'Status' => 'draft',
            'InvoiceDate' => now()
        ]);
    }
}
```

**4. PDF Generator**
```php
class InvoicePDFGenerator {
    public function generate($invoice, $customer, $items) {
        $pdf = PDF::loadView('invoice.template', compact('invoice', 'customer', 'items'));
        $path = "invoices/{$invoice->id}.pdf";
        Storage::put($path, $pdf->output());
        return $path;
    }
}
```

**5. Email Notifier**
```php
class InvoiceEmailNotifier {
    public function send($customer, $pdfPath) {
        SendGrid::send(
            $customer->Email,
            "Your invoice is ready",
            "Invoice attached",
            $pdfPath
        );
    }
}
```

**6. Audit Logger**
```php
class AuditLogger {
    public function log($entityId, $action) {
        DB::table('fsiaudit')->insert([
            'EntityId' => $entityId,
            'Action' => $action,
            'UserId' => Auth::id(),
            'CreatedAt' => now()
        ]);
    }
}
```

**7. Event Publisher**
```php
class EventPublisher {
    public function publish($event, $data) {
        RabbitMQ::publish($event, $data);
    }
}
```

**8. Orchestrator (puts it all together)**
```php
class InvoiceProcessor {
    public function __construct(
        private CustomerValidator $validator,
        private InvoiceCalculator $calculator,
        private InvoiceRepository $repository,
        private InvoicePDFGenerator $pdfGenerator,
        private InvoiceEmailNotifier $notifier,
        private AuditLogger $logger,
        private EventPublisher $publisher
    ) {}
    
    public function processInvoice($customerId, $items) {
        // Each step delegated to a focused class
        $customer = $this->validator->validate($customerId);
        $total = $this->calculator->calculate($items, $customer->DiscountPercent);
        $invoiceId = $this->repository->create($customerId, $total);
        $pdfPath = $this->pdfGenerator->generate($invoiceId, $customer, $items);
        $this->notifier->send($customer, $pdfPath);
        $this->logger->log($invoiceId, 'invoice_created');
        $this->publisher->publish('invoice.created', ['invoice_id' => $invoiceId]);
        
        return $invoiceId;
    }
}
```

**Benefits:**
- ✅ Each class has ONE reason to change
- ✅ Easy to test: Mock one dependency at a time
- ✅ Reusable: `InvoiceCalculator` can be used elsewhere
- ✅ Maintainable: Change PDF logic without touching email logic

---

**Your Experience:**
"At Billtrust, we refactored our invoice generation from a 500-line God Object to 7 focused classes following SRP. This made testing easier (we can test discount calculation in isolation), improved reusability (InvoiceCalculator is now used by 3 different services), and reduced bugs (changing PDF templates no longer breaks email sending)."

---

### **Q6: Dependency Inversion — how Laravel DI works**

**Answer:**

**Problem Without DI:**
```php
class InvoiceController {
    private $mailer;
    
    public function __construct() {
        $this->mailer = new SendGridMailer();  // ← Hardcoded!
    }
    
    public function send(Invoice $invoice) {
        $this->mailer->send($invoice->getEmail(), $invoice->getBody());
    }
}

// Problems:
// 1. Can't test (must actually send via SendGrid in tests)
// 2. Can't swap mailers (tightly coupled to SendGrid)
// 3. Violates Open/Closed (must modify class to change mailer)
```

---

**Solution: Dependency Injection**

**Step 1: Define Interface**
```php
interface Mailer {
    public function send($to, $subject, $body);
}
```

**Step 2: Implementations**
```php
class SendGridMailer implements Mailer {
    public function send($to, $subject, $body) {
        SendGrid::send($to, $subject, $body);
    }
}

class SESMailer implements Mailer {
    public function send($to, $subject, $body) {
        AWS_SES::send($to, $subject, $body);
    }
}

class FakeMailer implements Mailer {
    public function send($to, $subject, $body) {
        // For testing: Store in memory instead of sending
        $this->sent[] = compact('to', 'subject', 'body');
    }
}
```

**Step 3: Inject Dependency**
```php
class InvoiceController {
    public function __construct(private Mailer $mailer) {}  // ← Injected!
    
    public function send(Invoice $invoice) {
        $this->mailer->send($invoice->getEmail(), 'Invoice', $invoice->getBody());
    }
}
```

**Step 4: Laravel DI Container (Automatic Resolution)**
```php
// app/Providers/AppServiceProvider.php
public function register() {
    // Bind interface to concrete implementation
    $this->app->bind(Mailer::class, SendGridMailer::class);
    
    // Or conditional binding:
    if (config('mail.driver') === 'ses') {
        $this->app->bind(Mailer::class, SESMailer::class);
    } else {
        $this->app->bind(Mailer::class, SendGridMailer::class);
    }
}

// routes/web.php
Route::get('/send-invoice/{id}', [InvoiceController::class, 'send']);

// Laravel automatically resolves:
// 1. Sees InvoiceController needs Mailer
// 2. Looks up binding: Mailer → SendGridMailer
// 3. Creates new SendGridMailer()
// 4. Injects into InvoiceController
// 5. Calls send() method
// No `new` keyword anywhere!
```

**Step 5: Testing (Fake Implementation)**
```php
// tests/Feature/InvoiceControllerTest.php
public function test_send_invoice() {
    // Swap real mailer for fake in tests
    $this->app->bind(Mailer::class, FakeMailer::class);
    
    $invoice = Invoice::factory()->create();
    
    $response = $this->get("/send-invoice/{$invoice->id}");
    
    $response->assertStatus(200);
    
    // Assert email was "sent" (stored in FakeMailer)
    $fake = app(Mailer::class);
    $this->assertCount(1, $fake->sent);
    $this->assertEquals($invoice->email, $fake->sent[0]['to']);
}
```

---

**Benefits:**
- ✅ Testable: Swap SendGridMailer for FakeMailer in tests
- ✅ Flexible: Switch from SendGrid to SES without changing InvoiceController
- ✅ Follows DIP: InvoiceController depends on Mailer interface, not concrete class

---

**Billtrust Example (Real Code):**
```php
// app/Repositories/InvoiceRepository.php
class InvoiceRepository {
    public function __construct(private DB $db) {}  // ← Injected!
    
    public function findByCustomer($customerId) {
        return $this->db->table('fsiinvoice')
            ->where('CustomerId', $customerId)
            ->get();
    }
}

// app/Services/InvoiceService.php
class InvoiceService {
    public function __construct(
        private InvoiceRepository $repo,  // ← Injected!
        private Mailer $mailer,           // ← Injected!
        private Cache $cache              // ← Injected!
    ) {}
    
    public function getInvoices($customerId) {
        return $this->cache->remember("invoices:{$customerId}", 3600, fn() =>
            $this->repo->findByCustomer($customerId)
        );
    }
    
    public function sendInvoice(Invoice $invoice) {
        $this->mailer->send($invoice->getEmail(), 'Invoice', $invoice->getBody());
    }
}

// app/Http/Controllers/InvoiceController.php
class InvoiceController {
    public function __construct(private InvoiceService $service) {}  // ← Injected!
    
    public function index() {
        $invoices = $this->service->getInvoices(Auth::user()->customer_id);
        return view('invoices.index', compact('invoices'));
    }
}

// Laravel resolves the entire dependency tree automatically:
// InvoiceController → InvoiceService → InvoiceRepository → DB
//                                   → Mailer → SendGridMailer
//                                   → Cache → RedisCache
```

---

**Your Experience:**
"At Billtrust, we leverage Laravel's DI container extensively. Our InvoiceService depends on abstract interfaces (Mailer, Cache, DB) rather than concrete classes, making it easy to swap implementations (SendGrid → SES, Redis → Memcached) without changing business logic. In tests, we bind fake implementations to run the full invoice flow without actually sending emails or hitting the database."

---

## 📚 Section 3: Design Patterns

### **Q7: Singleton pattern — when to use (and when NOT to)**

**Answer:**

**What is Singleton?**
Ensures only ONE instance of a class exists globally.

**Implementation:**
```php
class DatabaseConnection {
    private static $instance = null;
    private $connection;
    
    // Private constructor prevents direct instantiation
    private function __construct() {
        $this->connection = new PDO(/* connection details */);
    }
    
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    public function query($sql) {
        return $this->connection->query($sql);
    }
}

// Usage:
$db1 = DatabaseConnection::getInstance();
$db2 = DatabaseConnection::getInstance();
// $db1 === $db2 (same instance!)
```

---

**When to Use Singleton:**

✅ **Expensive object** that should only be created once  
✅ **Shared resource** (database connection, file handle, logger)  
✅ **Global configuration** (app settings, feature flags)

**Billtrust Example:**
```php
class Logger {
    private static $instance = null;
    private $logFile;
    
    private function __construct() {
        $this->logFile = fopen('/var/log/app.log', 'a');
    }
    
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    public function log($message) {
        fwrite($this->logFile, "[" . date('Y-m-d H:i:s') . "] {$message}\n");
    }
}

// Usage (all classes log to the same file handle):
Logger::getInstance()->log("Invoice created");
Logger::getInstance()->log("Payment processed");
```

---

**When NOT to Use Singleton:**

❌ **Hard to test** (global state persists across tests)  
❌ **Violates Dependency Inversion** (can't inject mock)  
❌ **Tight coupling** (every class depends on global state)  
❌ **Concurrency issues** (not thread-safe by default)

**Anti-Pattern Example:**
```php
class UserSession {
    private static $instance = null;
    private $userId;
    
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    public function setUserId($userId) {
        $this->userId = $userId;
    }
    
    public function getUserId() {
        return $this->userId;
    }
}

// Usage (bad!):
class InvoiceController {
    public function create() {
        $userId = UserSession::getInstance()->getUserId();  // ← Global state!
        // ...
    }
}

// Problems:
// 1. Can't test InvoiceController without setting up UserSession first
// 2. Can't mock UserSession (hardcoded getInstance())
// 3. Tests contaminate each other (global state persists)
```

**Better Alternative (Dependency Injection):**
```php
class InvoiceController {
    public function __construct(private User $user) {}  // ← Injected!
    
    public function create() {
        $userId = $this->user->id;  // No global state!
        // ...
    }
}

// Laravel injects current user automatically
```

---

**Modern Singleton (Laravel Service Container):**
```php
// Instead of manual singleton:
class Logger {
    private static $instance = null;
    // ...
}

// Use Laravel's singleton binding:
$app->singleton(Logger::class, function () {
    return new Logger('/var/log/app.log');
});

// Usage (automatically resolved, testable):
class InvoiceService {
    public function __construct(private Logger $logger) {}  // ← Injected!
    
    public function createInvoice() {
        $this->logger->log("Invoice created");
    }
}

// In tests:
$this->app->singleton(Logger::class, fn() => new FakeLogger());
```

---

**Your Experience:**
"At Billtrust, we avoid manual Singleton implementations because they're hard to test. Instead, we use Laravel's singleton binding for shared resources like database connections and loggers. This gives us the performance benefits of Singleton (single instance) while maintaining testability (we can inject mocks in tests)."

---

### **Q8: Factory pattern — how you use it in Billtrust**

**Answer:**

**What is Factory Pattern?**
Creates objects without exposing the creation logic.

**Problem:**
```php
// ❌ Client code decides which class to instantiate
class InvoiceService {
    public function sendNotification(Invoice $invoice, $channel) {
        if ($channel === 'email') {
            $notifier = new EmailNotifier();
        } elseif ($channel === 'sms') {
            $notifier = new SMSNotifier();
        } elseif ($channel === 'push') {
            $notifier = new PushNotifier();
        }
        
        $notifier->send($invoice);
    }
}

// Every time we add a channel, we modify this method!
```

---

**Solution: Factory Pattern**

**Step 1: Common Interface**
```php
interface Notifier {
    public function send(Invoice $invoice);
}

class EmailNotifier implements Notifier {
    public function send(Invoice $invoice) {
        SendGrid::send($invoice->getEmail(), $invoice->getBody());
    }
}

class SMSNotifier implements Notifier {
    public function send(Invoice $invoice) {
        Twilio::send($invoice->getPhone(), $invoice->getSummary());
    }
}

class PushNotifier implements Notifier {
    public function send(Invoice $invoice) {
        Firebase::send($invoice->getDeviceToken(), $invoice->getSummary());
    }
}
```

**Step 2: Factory**
```php
class NotifierFactory {
    public static function create($channel): Notifier {
        return match($channel) {
            'email' => new EmailNotifier(),
            'sms' => new SMSNotifier(),
            'push' => new PushNotifier(),
            default => throw new InvalidArgumentException("Unknown channel: {$channel}")
        };
    }
}
```

**Step 3: Client Code (Clean!)**
```php
class InvoiceService {
    public function sendNotification(Invoice $invoice, $channel) {
        $notifier = NotifierFactory::create($channel);  // Factory decides!
        $notifier->send($invoice);
    }
}

// Adding a new channel? Add to factory, not every client!
```

---

**Billtrust Real Example: Payment Gateway Factory**

```php
interface PaymentGateway {
    public function authorize($amount, $cardToken);
    public function capture($transactionId);
}

class StripeGateway implements PaymentGateway {
    public function authorize($amount, $cardToken) {
        return Stripe::charge(['amount' => $amount, 'source' => $cardToken]);
    }
    
    public function capture($transactionId) {
        return Stripe::capture($transactionId);
    }
}

class AuthorizeNetGateway implements PaymentGateway {
    public function authorize($amount, $cardToken) {
        return AuthorizeNet::authorize($amount, $cardToken);
    }
    
    public function capture($transactionId) {
        return AuthorizeNet::capture($transactionId);
    }
}

class PaymentGatewayFactory {
    public static function create($customerPreference): PaymentGateway {
        // Business logic: Which gateway to use?
        if ($customerPreference === 'stripe') {
            return new StripeGateway();
        } elseif ($customerPreference === 'authorize_net') {
            return new AuthorizeNetGateway();
        }
        
        // Default: Stripe
        return new StripeGateway();
    }
}

// Usage:
class PaymentService {
    public function processPayment($amount, $cardToken, $customerPreference) {
        $gateway = PaymentGatewayFactory::create($customerPreference);
        $transaction = $gateway->authorize($amount, $cardToken);
        
        if ($transaction->status === 'authorized') {
            $gateway->capture($transaction->id);
        }
    }
}
```

---

**Advanced: Abstract Factory (Family of Objects)**

```php
// Create a full "suite" of payment objects
interface PaymentGatewayFactory {
    public function createProcessor(): PaymentProcessor;
    public function createRefunder(): PaymentRefunder;
    public function createReporter(): PaymentReporter;
}

class StripeFactory implements PaymentGatewayFactory {
    public function createProcessor() { return new StripeProcessor(); }
    public function createRefunder() { return new StripeRefunder(); }
    public function createReporter() { return new StripeReporter(); }
}

class AuthorizeNetFactory implements PaymentGatewayFactory {
    public function createProcessor() { return new AuthorizeNetProcessor(); }
    public function createRefunder() { return new AuthorizeNetRefunder(); }
    public function createReporter() { return new AuthorizeNetReporter(); }
}

// Usage:
$factory = new StripeFactory();  // Or AuthorizeNetFactory
$processor = $factory->createProcessor();
$refunder = $factory->createRefunder();
$reporter = $factory->createReporter();

// All 3 objects are "Stripe family" (consistent)
```

---

**Your Experience:**
"At Billtrust, we use Factory pattern for payment gateway selection — customers can choose Stripe or Authorize.Net, and PaymentGatewayFactory creates the appropriate gateway based on their preference. This keeps client code clean (no if/else chains) and makes it easy to add new gateways (just add one line to the factory, no changes to PaymentService)."

---

### **Q9-Q13: More Design Patterns (Condensed)**

Due to length, I'll summarize the remaining patterns. Let me know if you want any expanded!

---

**Q9: Observer Pattern (Event-Driven)**

```php
// Laravel Events
Event::listen('invoice.created', function($invoice) {
    // Send email notification
    Notification::send($invoice->customer, new InvoiceCreated($invoice));
});

Event::listen('invoice.created', function($invoice) {
    // Update analytics
    Analytics::track('invoice_created', $invoice->toArray());
});

Event::listen('invoice.created', function($invoice) {
    // Check for fraud
    FraudDetector::analyze($invoice);
});

// Fire event (all listeners notified):
Event::fire('invoice.created', $invoice);
```

**Use at Billtrust:** RabbitMQ event publishing, Laravel event listeners

---

**Q10: Repository Pattern (Data Access Layer)**

```php
interface InvoiceRepository {
    public function find($id);
    public function findByCustomer($customerId);
    public function create($data);
}

class EloquentInvoiceRepository implements InvoiceRepository {
    public function find($id) {
        return Invoice::find($id);
    }
    
    public function findByCustomer($customerId) {
        return Invoice::where('customer_id', $customerId)->get();
    }
    
    public function create($data) {
        return Invoice::create($data);
    }
}

// Service depends on interface, not Eloquent:
class InvoiceService {
    public function __construct(private InvoiceRepository $repo) {}
    
    public function getInvoices($customerId) {
        return $this->repo->findByCustomer($customerId);
    }
}
```

**Use at Billtrust:** All database access goes through repositories

---

**Q11: Strategy Pattern (Interchangeable Algorithms)**

```php
interface DiscountStrategy {
    public function calculate($amount);
}

class PercentageDiscount implements DiscountStrategy {
    public function __construct(private $percent) {}
    
    public function calculate($amount) {
        return $amount * ($this->percent / 100);
    }
}

class FixedDiscount implements DiscountStrategy {
    public function __construct(private $fixed) {}
    
    public function calculate($amount) {
        return min($this->fixed, $amount);
    }
}

class Invoice {
    private $discountStrategy;
    
    public function setDiscountStrategy(DiscountStrategy $strategy) {
        $this->discountStrategy = $strategy;
    }
    
    public function calculateTotal($subtotal) {
        $discount = $this->discountStrategy->calculate($subtotal);
        return $subtotal - $discount;
    }
}

// Usage:
$invoice = new Invoice();
$invoice->setDiscountStrategy(new PercentageDiscount(10));  // 10% off
$total = $invoice->calculateTotal(100);  // $90

$invoice->setDiscountStrategy(new FixedDiscount(5));  // $5 off
$total = $invoice->calculateTotal(100);  // $95
```

**Use at Billtrust:** Discount calculation, payment method selection

---

**Q12: Decorator Pattern (Add Behavior Dynamically)**

```php
// Laravel Middleware is Decorator pattern
class InvoiceMiddleware {
    public function handle($request, $next) {
        // Before
        Log::info("Processing invoice request");
        
        $response = $next($request);  // Call next middleware
        
        // After
        Log::info("Invoice request completed");
        
        return $response;
    }
}
```

**Use at Billtrust:** Laravel middleware (auth, logging, caching)

---

**Q13: Facade Pattern (Simplified Interface)**

```php
// Complex subsystem:
class SendGridClient { /* ... */ }
class EmailValidator { /* ... */ }
class EmailTemplateEngine { /* ... */ }

// Facade (simple interface):
class EmailFacade {
    public static function send($to, $subject, $body) {
        $validator = new EmailValidator();
        $validator->validate($to);
        
        $template = new EmailTemplateEngine();
        $html = $template->render($body);
        
        $client = new SendGridClient();
        $client->send($to, $subject, $html);
    }
}

// Usage (simple!):
EmailFacade::send('user@example.com', 'Invoice', $invoice->getBody());
```

**Use at Billtrust:** Laravel Facades (Mail, Cache, DB, Queue)

---

## 🎯 Practice Plan

**Week 1:**
- [ ] Record yourself explaining SOLID (10 min)
- [ ] Draw 3 design patterns on paper (Singleton, Factory, Observer)

**Week 2:**
- [ ] Explain OOP with Billtrust examples ("At Billtrust, we use...")
- [ ] Practice refactoring a God Object

**Interview Day:**
- Have 3 patterns ready to explain with real examples
- Practice: "SOLID" acronym → expand each principle (2 min total)

You already USE these patterns daily — now you can explain them! 🚀
