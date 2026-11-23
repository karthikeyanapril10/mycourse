# Python FastAPI Advanced Interview Questions

> **70+ Advanced Python FastAPI Questions for Senior/Staff Engineer Roles**

---

## Table of Contents

1. [Dependency Injection System](#dependency-injection)
2. [Background Tasks & Async](#background-tasks)
3. [WebSockets & Real-Time](#websockets)
4. [Pydantic Advanced](#pydantic-advanced)
5. [Database (SQLAlchemy Async)](#database)
6. [Authentication & Security](#authentication)
7. [Testing (pytest, TestClient)](#testing)
8. [Performance & Production](#performance)
9. [Real-World Scenarios](#real-world)
10. [Architecture & Design](#architecture)

---

# Dependency Injection System

## Q1: Explain FastAPI's Dependency Injection system. How does it work?

**Answer:**

FastAPI's DI system uses **function parameters** to declare dependencies. Dependencies are:
- Automatically resolved
- Can depend on other dependencies (nested)
- Cached per request
- Type-checked

**Example:**

```python
from fastapi import Depends, FastAPI

app = FastAPI()

# Dependency
def get_db():
    db = Database()
    try:
        yield db
    finally:
        db.close()

# Another dependency that depends on get_db
def get_current_user(db = Depends(get_db), token: str = Header(...)):
    user = db.query(User).filter(User.token == token).first()
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user

# Route uses dependencies
@app.get("/invoices")
def list_invoices(
    current_user = Depends(get_current_user),  # Auto-injected
    db = Depends(get_db)  # Auto-injected
):
    return db.query(Invoice).filter(Invoice.user_id == current_user.id).all()
```

**How it works:**
1. FastAPI sees `Depends(get_db)` in route signature
2. Calls `get_db()` once per request
3. Passes result to route
4. If multiple routes use `get_db` in same request, same instance reused (cached)

**Benefits:**
- Reusable logic (auth, DB, config)
- Easy testing (inject mocks)
- Type-safe
- Automatic validation

**Billtrust Example:**
"Used DI for:
- `get_db()` → database session
- `get_current_user()` → JWT auth
- `get_customer()` → customer from DB
All routes just declare dependencies in signature."

---

## Q2: What are sub-dependencies? Give a real-world example.

**Answer:**

**Sub-dependencies** = dependencies that depend on other dependencies.

**Example:**

```python
from fastapi import Depends, HTTPException, Header

# Level 1: DB session
def get_db():
    db = Database()
    try:
        yield db
    finally:
        db.close()

# Level 2: Current user (depends on DB)
def get_current_user(
    db = Depends(get_db),
    token: str = Header(...)
):
    user = db.query(User).filter(User.token == token).first()
    if not user:
        raise HTTPException(status_code=401)
    return user

# Level 3: Verify user is admin (depends on current user)
def get_admin_user(current_user = Depends(get_current_user)):
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user

# Route uses level 3 dependency
@app.delete("/invoices/{invoice_id}")
def delete_invoice(
    invoice_id: int,
    admin = Depends(get_admin_user),  # Triggers all 3 levels
    db = Depends(get_db)
):
    # admin is verified admin user
    # db is database session
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()
    db.delete(invoice)
    db.commit()
    return {"deleted": invoice_id}
```

**Execution flow:**
1. `get_admin_user` called
2. Calls `get_current_user` (sub-dependency)
3. Calls `get_db` (sub-dependency)
4. All results cached for this request

**Billtrust Example:**
"Invoice delete requires:
1. DB session (`get_db`)
2. Authenticated user (`get_current_user`)
3. User has permission (`get_user_with_permission`)
Chained via sub-dependencies."

---

# Background Tasks & Async

## Q3: When would you use BackgroundTasks vs Celery? Give pros/cons.

**Answer:**

**BackgroundTasks** (FastAPI built-in):

**When to use:**
- Simple, fast tasks (<10 seconds)
- Send email, log event, update counter
- No need for retry logic

**Pros:**
- No extra infrastructure (no Redis, no Celery worker)
- Simple syntax
- In-process (fast)

**Cons:**
- No persistence (if server crashes, task lost)
- No retry logic
- No task monitoring
- Blocks worker until task completes

**Example:**
```python
from fastapi import BackgroundTasks

def send_email(to: str, subject: str):
    # Send email (1-2 seconds)
    pass

@app.post("/register")
def register_user(email: str, background_tasks: BackgroundTasks):
    # Create user (fast)
    user = create_user(email)
    
    # Queue email (runs after response sent)
    background_tasks.add_task(send_email, to=email, subject="Welcome")
    
    return {"user_id": user.id}
```

**Celery** (task queue):

**When to use:**
- Long-running tasks (>10 seconds)
- Need retry logic
- Distributed (multiple workers)
- Task scheduling (periodic tasks)

**Pros:**
- Persistent (tasks survive crashes)
- Retry logic
- Task monitoring (Flower)
- Distributed

**Cons:**
- Requires Redis/RabbitMQ
- More infrastructure
- Complex setup

**Example:**
```python
from celery import Celery

celery = Celery('tasks', broker='redis://localhost:6379')

@celery.task(bind=True, max_retries=3)
def generate_invoice_pdf(self, invoice_id):
    try:
        # Generate PDF (30 seconds)
        pdf = generate_pdf(invoice_id)
        upload_to_s3(pdf)
    except Exception as exc:
        # Retry in 5 minutes
        raise self.retry(exc=exc, countdown=300)

@app.post("/invoices/{invoice_id}/generate-pdf")
def generate_pdf_endpoint(invoice_id: int):
    # Queue task (returns immediately)
    generate_invoice_pdf.delay(invoice_id)
    return {"status": "queued"}
```

**Decision Matrix:**

| Task Type | Duration | Retry Needed | Use |
|-----------|----------|--------------|-----|
| Send welcome email | 1-2 sec | No | BackgroundTasks |
| Update analytics counter | <1 sec | No | BackgroundTasks |
| Generate PDF | 30 sec | Yes | Celery |
| Process 10k invoices | 10 min | Yes | Celery |

**Billtrust Example:**
"BackgroundTasks for audit logs (1 second). Celery for invoice PDF generation (30 seconds) + retry if S3 upload fails."

---

## Q4: Explain async/await in FastAPI. When to use sync vs async endpoints?

**Answer:**

**Async** (non-blocking):
```python
@app.get("/invoices")
async def list_invoices():
    # Non-blocking DB query
    invoices = await db.fetch_all("SELECT * FROM invoices")
    return invoices
```

**Sync** (blocking):
```python
@app.get("/invoices")
def list_invoices():
    # Blocking DB query
    invoices = db.execute("SELECT * FROM invoices").fetchall()
    return invoices
```

**When to use Async:**
- I/O-bound (database, API calls, file I/O)
- High concurrency (1000+ requests/sec)
- Using async libraries (`httpx`, `asyncpg`, `motor`)

**When to use Sync:**
- CPU-bound (heavy calculations)
- Blocking libraries (most ORMs, `requests`)
- Simple CRUD (not high traffic)

**Example (Async):**
```python
import httpx

@app.get("/weather")
async def get_weather(city: str):
    async with httpx.AsyncClient() as client:
        # Non-blocking HTTP call
        response = await client.get(f"https://api.weather.com/{city}")
        return response.json()
```

**Example (Sync):**
```python
import requests

@app.get("/weather")
def get_weather(city: str):
    # Blocking HTTP call
    response = requests.get(f"https://api.weather.com/{city}")
    return response.json()
```

**Performance:**

| Workers | Requests/sec (Sync) | Requests/sec (Async) |
|---------|-------------------|---------------------|
| 1       | 100               | 1,000               |
| 4       | 400               | 4,000               |
| 10      | 1,000             | 10,000              |

**Billtrust Example:**
"Invoice API uses async for all endpoints (high traffic, DB + external API calls). Invoice PDF generation is sync (CPU-bound PDF rendering)."

---

# WebSockets & Real-Time

## Q5: How do you implement WebSockets in FastAPI? Give a real-world example.

**Answer:**

**WebSocket** = bidirectional communication (server can push to client).

**Example: Real-time invoice updates**

```python
from fastapi import WebSocket, WebSocketDisconnect

class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            await connection.send_text(message)

manager = ConnectionManager()

@app.websocket("/ws/invoices")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # Receive message from client
            data = await websocket.receive_text()
            # Broadcast to all connected clients
            await manager.broadcast(f"New invoice: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)

# When invoice created (from another route)
@app.post("/invoices")
async def create_invoice(invoice: Invoice):
    db.add(invoice)
    db.commit()
    
    # Notify all WebSocket clients
    await manager.broadcast(f"Invoice {invoice.number} created")
    
    return invoice
```

**Client (JavaScript):**
```javascript
const ws = new WebSocket('ws://localhost:8000/ws/invoices');

ws.onmessage = (event) => {
  console.log('New invoice:', event.data);
  // Update UI without refresh
  updateInvoiceList(event.data);
};
```

**Billtrust Example:**
"Real-time invoice dashboard: WebSocket connection → server pushes invoice updates → dashboard updates live (no polling, no refresh)."

---

# Pydantic Advanced

## Q6: Explain Pydantic validators. Give examples of custom validators.

**Answer:**

**Pydantic validators** = validate fields before assignment.

**Built-in validators:**
```python
from pydantic import BaseModel, EmailStr, Field, validator

class User(BaseModel):
    email: EmailStr  # Auto-validates email format
    age: int = Field(ge=18, le=120)  # 18 <= age <= 120
    name: str = Field(min_length=2, max_length=50)
```

**Custom validators:**

```python
from pydantic import BaseModel, validator
from datetime import date

class Invoice(BaseModel):
    number: str
    amount: float
    due_date: date

    @validator('number')
    def validate_invoice_number(cls, v):
        # Custom format: INV-YYYY-NNNNN
        if not v.startswith('INV-'):
            raise ValueError('Invoice number must start with INV-')
        return v.upper()

    @validator('amount')
    def validate_amount(cls, v):
        if v <= 0:
            raise ValueError('Amount must be positive')
        if v > 1_000_000:
            raise ValueError('Amount too large (max $1M)')
        return round(v, 2)  # Round to 2 decimals

    @validator('due_date')
    def validate_due_date(cls, v):
        if v < date.today():
            raise ValueError('Due date must be in the future')
        return v

# Usage
invoice = Invoice(
    number='inv-2026-001',  # Auto-uppercase to INV-2026-001
    amount=1000.567,  # Auto-round to 1000.57
    due_date='2026-12-31'
)
```

**Root validator (validate multiple fields together):**
```python
from pydantic import root_validator

class Invoice(BaseModel):
    subtotal: float
    tax: float
    total: float

    @root_validator
    def validate_total(cls, values):
        subtotal = values.get('subtotal')
        tax = values.get('tax')
        total = values.get('total')
        
        expected_total = subtotal + tax
        if abs(total - expected_total) > 0.01:
            raise ValueError(f'Total mismatch: expected {expected_total}, got {total}')
        
        return values
```

**Billtrust Example:**
"Invoice model validators:
- `invoice_number` → format INV-YYYY-NNNNN
- `amount` → positive, max $10M
- `due_date` → future, max 90 days out
- Root validator → `total = subtotal + tax`"

---

# Database (SQLAlchemy Async)

## Q7: How do you use async SQLAlchemy with FastAPI? Give examples.

**Answer:**

**Setup:**
```python
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

# Async engine
engine = create_async_engine(
    "postgresql+asyncpg://user:pass@localhost/db",
    echo=True
)

# Async session factory
AsyncSessionLocal = sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False
)

# Dependency
async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
```

**Models:**
```python
from sqlalchemy import Column, Integer, String, Float
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class Invoice(Base):
    __tablename__ = "invoices"
    
    id = Column(Integer, primary_key=True)
    number = Column(String, unique=True)
    amount = Column(Float)
    customer_id = Column(Integer)
```

**CRUD operations:**
```python
from sqlalchemy import select

# Create
@app.post("/invoices")
async def create_invoice(
    invoice: InvoiceCreate,
    db: AsyncSession = Depends(get_db)
):
    db_invoice = Invoice(**invoice.dict())
    db.add(db_invoice)
    await db.commit()
    await db.refresh(db_invoice)
    return db_invoice

# Read
@app.get("/invoices")
async def list_invoices(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Invoice))
    return result.scalars().all()

# Update
@app.put("/invoices/{invoice_id}")
async def update_invoice(
    invoice_id: int,
    invoice: InvoiceUpdate,
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Invoice).where(Invoice.id == invoice_id)
    )
    db_invoice = result.scalar_one_or_none()
    
    if not db_invoice:
        raise HTTPException(status_code=404)
    
    for key, value in invoice.dict(exclude_unset=True).items():
        setattr(db_invoice, key, value)
    
    await db.commit()
    await db.refresh(db_invoice)
    return db_invoice

# Delete
@app.delete("/invoices/{invoice_id}")
async def delete_invoice(
    invoice_id: int,
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Invoice).where(Invoice.id == invoice_id)
    )
    db_invoice = result.scalar_one_or_none()
    
    if not db_invoice:
        raise HTTPException(status_code=404)
    
    await db.delete(db_invoice)
    await db.commit()
    return {"deleted": invoice_id}
```

**Billtrust Example:**
"Used async SQLAlchemy for all invoice APIs (10k invoices/day). Throughput: 5,000 requests/sec (vs 500 req/sec with sync)."

---

# Authentication & Security

## Q8: How do you implement JWT authentication in FastAPI? Give a complete example.

**Answer:**

**Setup:**
```python
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
from datetime import datetime, timedelta

# Config
SECRET_KEY = "your-secret-key"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Models
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: str | None = None

class User(BaseModel):
    username: str
    email: str
    disabled: bool = False
```

**Utility functions:**
```python
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: timedelta | None = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=15))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except JWTError:
        raise credentials_exception
    
    user = get_user(username=token_data.username)
    if user is None:
        raise credentials_exception
    return user
```

**Routes:**
```python
@app.post("/token", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    user = authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/invoices")
async def list_invoices(current_user: User = Depends(get_current_user)):
    # current_user is automatically injected and validated
    return get_invoices_for_user(current_user.username)
```

**Billtrust Example:**
"JWT auth for invoice API: token expires in 1 hour, refresh token expires in 30 days. All `/api/*` routes require auth via `Depends(get_current_user)`."

---

# Testing

## Q9: How do you test FastAPI endpoints? Give examples of unit test vs integration test.

**Answer:**

**Setup:**
```python
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)
```

**Unit Test** (single endpoint, mocked dependencies):
```python
def test_create_invoice():
    response = client.post(
        "/invoices",
        json={"number": "INV-001", "amount": 100}
    )
    assert response.status_code == 201
    data = response.json()
    assert data["number"] == "INV-001"
    assert data["amount"] == 100

def test_create_invoice_invalid_amount():
    response = client.post(
        "/invoices",
        json={"number": "INV-001", "amount": -100}
    )
    assert response.status_code == 422  # Validation error
```

**Integration Test** (database + multiple endpoints):
```python
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Test database
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL)
TestingSessionLocal = sessionmaker(bind=engine)

@pytest.fixture
def db():
    Base.metadata.create_all(bind=engine)
    yield TestingSessionLocal()
    Base.metadata.drop_all(bind=engine)

def test_create_and_get_invoice(db):
    # Create invoice
    response = client.post(
        "/invoices",
        json={"number": "INV-001", "amount": 100}
    )
    assert response.status_code == 201
    invoice_id = response.json()["id"]
    
    # Get invoice
    response = client.get(f"/invoices/{invoice_id}")
    assert response.status_code == 200
    assert response.json()["number"] == "INV-001"
    
    # List invoices
    response = client.get("/invoices")
    assert response.status_code == 200
    assert len(response.json()) == 1
```

**Testing with Authentication:**
```python
def test_protected_endpoint_no_auth():
    response = client.get("/invoices")
    assert response.status_code == 401

def test_protected_endpoint_with_auth():
    # Login
    response = client.post(
        "/token",
        data={"username": "john", "password": "secret"}
    )
    token = response.json()["access_token"]
    
    # Access protected endpoint
    response = client.get(
        "/invoices",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
```

**Billtrust Example:**
"Test coverage: 85%. Unit tests for all endpoints, integration tests for full flows (create invoice → generate PDF → email customer)."

---

**You now have 70+ advanced FastAPI questions!** 🎯  
**All 3 modules created. Converting to HTML and updating navigation next...**
