# Python & FastAPI Interview Guide

**For Full-Stack AI-First Developer Interviews**

Your competitive advantage: **Backend + AI/ML expertise** (Python for microservices, FastAPI for high-performance APIs, AI model serving)

---

## Table of Contents

1. [Why Python + FastAPI for Modern Development](#why-python--fastapi)
2. [FastAPI Fundamentals](#fastapi-fundamentals)
3. [Python Best Practices](#python-best-practices)
4. [Async/Await Patterns](#asyncawait-patterns)
5. [Pydantic Models & Validation](#pydantic-models--validation)
6. [API Development Patterns](#api-development-patterns)
7. [AI/ML Model Serving](#aiml-model-serving)
8. [Testing & Documentation](#testing--documentation)
9. [Interview Questions & Answers](#interview-questions--answers)

---

## Why Python + FastAPI?

### The Modern Stack

```
Traditional PHP Stack:
├── Laravel (web framework)
├── MySQL (database)
└── Redis (cache)

AI-First Full-Stack:
├── FastAPI (Python - high-performance APIs)
├── React (frontend)
├── PostgreSQL/MongoDB (database)
├── Redis (cache)
└── ML Models (scikit-learn, TensorFlow, PyTorch)
```

### Why FastAPI?

**Performance:**
- 2-3x faster than Flask/Django
- On par with Node.js and Go
- Built on Starlette (async) and Pydantic (validation)

**Developer Experience:**
- Auto-generated OpenAPI docs (Swagger UI)
- Type hints everywhere (editor autocomplete)
- Async/await native support
- Less boilerplate than Django

**AI/ML Ready:**
- Perfect for serving ML models
- Async for heavy compute operations
- Easy integration with numpy, pandas, scikit-learn

---

## FastAPI Fundamentals

### Hello World

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "Hello World"}

@app.get("/health")
async def health():
    return {"status": "healthy"}
```

Run: `uvicorn main:app --reload`

### Path Parameters & Query Strings

```python
# Path parameter
@app.get("/users/{user_id}")
async def get_user(user_id: int):
    return {"user_id": user_id}

# Query parameters
@app.get("/items")
async def list_items(skip: int = 0, limit: int = 10):
    return {"skip": skip, "limit": limit}

# Both together
@app.get("/users/{user_id}/orders")
async def get_user_orders(
    user_id: int,
    status: str = "all",
    limit: int = 20
):
    return {
        "user_id": user_id,
        "status": status,
        "limit": limit
    }
```

---

## Pydantic Models & Validation

### Request/Response Models

```python
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime

class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    full_name: str
    age: Optional[int] = Field(None, ge=0, le=150)

class UserResponse(BaseModel):
    id: int
    email: str
    full_name: str
    created_at: datetime
    
    class Config:
        from_attributes = True  # ORM mode

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    age: Optional[int] = None

# Use in endpoints
@app.post("/users", response_model=UserResponse)
async def create_user(user: UserCreate):
    # Validation happens automatically
    # user.email is guaranteed to be valid email
    # user.password is guaranteed >= 8 chars
    db_user = save_to_db(user)
    return db_user

@app.patch("/users/{user_id}", response_model=UserResponse)
async def update_user(user_id: int, user: UserUpdate):
    return update_in_db(user_id, user)
```

**Benefits:**
- Automatic validation (400 error if invalid)
- Type hints (IDE autocomplete)
- Auto-generated API docs
- Data serialization/deserialization

---

## Async/Await Patterns

### When to Use Async

```python
# ✅ GOOD: Use async for I/O operations
@app.get("/users/{user_id}")
async def get_user(user_id: int):
    # Database query (I/O-bound)
    user = await db.fetch_one(
        "SELECT * FROM users WHERE id = $1", user_id
    )
    
    # HTTP call to external API (I/O-bound)
    profile = await httpx.get(f"https://api.example.com/profiles/{user_id}")
    
    return {"user": user, "profile": profile.json()}

# ❌ BAD: Don't use async for CPU-intensive work
@app.post("/ml/predict")
async def predict(data: InputData):
    # This blocks the event loop!
    result = model.predict(data.features)  # CPU-intensive
    return {"prediction": result}

# ✅ GOOD: Use background tasks or thread pool
from fastapi import BackgroundTasks
import asyncio
from concurrent.futures import ThreadPoolExecutor

executor = ThreadPoolExecutor(max_workers=4)

@app.post("/ml/predict")
async def predict(data: InputData):
    loop = asyncio.get_event_loop()
    # Run CPU-intensive work in thread pool
    result = await loop.run_in_executor(
        executor, 
        model.predict, 
        data.features
    )
    return {"prediction": result}
```

### Concurrent Requests

```python
import httpx
import asyncio

@app.get("/dashboard")
async def get_dashboard(user_id: int):
    # Run 3 API calls concurrently
    async with httpx.AsyncClient() as client:
        user_task = client.get(f"/api/users/{user_id}")
        orders_task = client.get(f"/api/orders?user_id={user_id}")
        stats_task = client.get(f"/api/stats/{user_id}")
        
        # Wait for all to complete
        user, orders, stats = await asyncio.gather(
            user_task, orders_task, stats_task
        )
    
    return {
        "user": user.json(),
        "orders": orders.json(),
        "stats": stats.json()
    }
```

---

## Dependency Injection

```python
from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session

# Database session dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Current user dependency
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    user = decode_token(token, db)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user

# Use in endpoints
@app.get("/me")
async def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

@app.get("/orders")
async def get_orders(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    orders = db.query(Order).filter(Order.user_id == current_user.id).all()
    return orders
```

---

## API Development Patterns

### CRUD Operations

```python
from typing import List

@app.post("/items", response_model=ItemResponse, status_code=201)
async def create_item(
    item: ItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db_item = Item(**item.dict(), owner_id=current_user.id)
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

@app.get("/items", response_model=List[ItemResponse])
async def list_items(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    items = db.query(Item).offset(skip).limit(limit).all()
    return items

@app.get("/items/{item_id}", response_model=ItemResponse)
async def get_item(item_id: int, db: Session = Depends(get_db)):
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item

@app.put("/items/{item_id}", response_model=ItemResponse)
async def update_item(
    item_id: int,
    item: ItemUpdate,
    db: Session = Depends(get_db)
):
    db_item = db.query(Item).filter(Item.id == item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    for key, value in item.dict(exclude_unset=True).items():
        setattr(db_item, key, value)
    
    db.commit()
    db.refresh(db_item)
    return db_item

@app.delete("/items/{item_id}", status_code=204)
async def delete_item(item_id: int, db: Session = Depends(get_db)):
    db_item = db.query(Item).filter(Item.id == item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    db.delete(db_item)
    db.commit()
    return None
```

---

## AI/ML Model Serving

### Serving a Trained Model

```python
from fastapi import FastAPI, File, UploadFile
import numpy as np
import pickle
from typing import List
from pydantic import BaseModel

app = FastAPI()

# Load model at startup
model = None

@app.on_event("startup")
async def load_model():
    global model
    with open("model.pkl", "rb") as f:
        model = pickle.load(f)

class PredictionInput(BaseModel):
    features: List[float]

class PredictionOutput(BaseModel):
    prediction: float
    confidence: float

@app.post("/predict", response_model=PredictionOutput)
async def predict(input_data: PredictionInput):
    # Convert to numpy array
    features = np.array([input_data.features])
    
    # Get prediction
    prediction = model.predict(features)[0]
    confidence = model.predict_proba(features).max()
    
    return {
        "prediction": float(prediction),
        "confidence": float(confidence)
    }

# Batch predictions
class BatchPredictionInput(BaseModel):
    batch: List[List[float]]

@app.post("/predict/batch")
async def batch_predict(input_data: BatchPredictionInput):
    features = np.array(input_data.batch)
    predictions = model.predict(features)
    
    return {
        "predictions": predictions.tolist(),
        "count": len(predictions)
    }

# Image classification
@app.post("/classify/image")
async def classify_image(file: UploadFile = File(...)):
    # Read image
    contents = await file.read()
    
    # Preprocess
    image = preprocess_image(contents)
    
    # Predict
    prediction = image_model.predict(image)
    class_name = decode_prediction(prediction)
    
    return {
        "class": class_name,
        "confidence": float(prediction.max())
    }
```

### Real-World AI API Example

```python
from transformers import pipeline
from fastapi import FastAPI, BackgroundTasks
import asyncio
from concurrent.futures import ThreadPoolExecutor

app = FastAPI()

# Load model at startup
sentiment_analyzer = None
executor = ThreadPoolExecutor(max_workers=4)

@app.on_event("startup")
async def startup():
    global sentiment_analyzer
    sentiment_analyzer = pipeline("sentiment-analysis")

class TextInput(BaseModel):
    text: str

class SentimentOutput(BaseModel):
    label: str
    score: float

@app.post("/analyze/sentiment", response_model=SentimentOutput)
async def analyze_sentiment(input_data: TextInput):
    loop = asyncio.get_event_loop()
    
    # Run in thread pool (CPU-intensive)
    result = await loop.run_in_executor(
        executor,
        sentiment_analyzer,
        input_data.text
    )
    
    return result[0]

# Multi-model inference
@app.post("/analyze/full")
async def full_analysis(input_data: TextInput):
    loop = asyncio.get_event_loop()
    
    # Run multiple models concurrently
    sentiment_task = loop.run_in_executor(
        executor, sentiment_analyzer, input_data.text
    )
    toxicity_task = loop.run_in_executor(
        executor, toxicity_analyzer, input_data.text
    )
    
    sentiment, toxicity = await asyncio.gather(
        sentiment_task, toxicity_task
    )
    
    return {
        "sentiment": sentiment[0],
        "toxicity": toxicity[0]
    }
```

---

## Python Best Practices

### Type Hints

```python
from typing import List, Dict, Optional, Union
from datetime import datetime

def process_users(
    users: List[Dict[str, str]],
    active_only: bool = True
) -> List[str]:
    return [u["name"] for u in users if u.get("active", False)]

# Generic types
from typing import TypeVar, Generic

T = TypeVar('T')

class Repository(Generic[T]):
    def get(self, id: int) -> Optional[T]:
        ...
    
    def list(self, limit: int = 100) -> List[T]:
        ...
```

### List Comprehensions

```python
# Instead of loops, use comprehensions
numbers = [1, 2, 3, 4, 5]

# Filter
evens = [n for n in numbers if n % 2 == 0]

# Transform
squared = [n ** 2 for n in numbers]

# Dict comprehension
user_map = {u["id"]: u["name"] for u in users}

# Set comprehension
unique_tags = {tag.lower() for item in items for tag in item.tags}
```

### Context Managers

```python
# Database connection
from contextlib import contextmanager

@contextmanager
def get_db_connection():
    conn = create_connection()
    try:
        yield conn
    finally:
        conn.close()

# Usage
with get_db_connection() as conn:
    result = conn.execute("SELECT * FROM users")
```

---

## Testing FastAPI

### Unit Tests

```python
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_read_main():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Hello World"}

def test_create_user():
    response = client.post(
        "/users",
        json={
            "email": "test@example.com",
            "password": "password123",
            "full_name": "Test User"
        }
    )
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "test@example.com"
    assert "id" in data

def test_invalid_email():
    response = client.post(
        "/users",
        json={
            "email": "invalid-email",
            "password": "password123"
        }
    )
    assert response.status_code == 422  # Validation error
```

### Async Tests

```python
import pytest
from httpx import AsyncClient
from main import app

@pytest.mark.asyncio
async def test_async_endpoint():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.get("/users/1")
    assert response.status_code == 200
```

---

## Interview Questions & Answers

### Q1: "Why FastAPI over Flask or Django?"

**Your Answer:**

> *"FastAPI combines the best of both worlds:*
> 
> **vs Flask:**
> *- **Performance:** 2-3x faster (async/await native)*
> *- **Type safety:** Pydantic validation vs manual validation*
> *- **Auto docs:** OpenAPI/Swagger built-in*
> *- **Modern:** Async-first, not bolted on*
> 
> **vs Django:**
> *- **Lightweight:** No ORM/admin if you don't need it*
> *- **Performance:** Async for high concurrency*
> *- **API-first:** Built for APIs, not full-stack MVC*
> *- **Less boilerplate:** Decorator-based like Flask*
> 
> **When I'd Use Each:**
> *- **FastAPI:** Microservices, ML model serving, high-performance APIs*
> *- **Flask:** Simple apps, when team knows it well*
> *- **Django:** Full-stack admin portals, built-in auth/admin needed*
> 
> **Real Example:**
> *I used FastAPI to build an AI prediction API serving 1000+ req/sec. The async nature let us handle concurrent model inference without blocking. Auto-generated OpenAPI docs made frontend integration seamless."*

---

### Q2: "How do you serve ML models in production?"

**Your Answer:**

> *"Here's my production ML serving pattern:*
> 
> **Architecture:**
> ```
> Load Balancer
>   ↓
> FastAPI (3+ instances)
>   ↓
> ML Model (loaded in memory)
>   ↓
> Redis (prediction cache)
> ```
> 
> **Key Patterns:**
> 
> **1. Load Model at Startup (Not Per Request)**
> ```python
> model = None
> 
> @app.on_event("startup")
> async def load_model():
>     global model
>     model = joblib.load("model.pkl")
> ```
> 
> **2. Thread Pool for CPU Work**
> ```python
> executor = ThreadPoolExecutor(max_workers=4)
> 
> @app.post("/predict")
> async def predict(data: Input):
>     loop = asyncio.get_event_loop()
>     result = await loop.run_in_executor(
>         executor, model.predict, data.features
>     )
>     return {"prediction": result}
> ```
> 
> **3. Caching for Repeated Inputs**
> ```python
> cache_key = hash(tuple(features))
> cached = redis.get(cache_key)
> if cached:
>     return cached
> ```
> 
> **4. Batch Inference for Efficiency**
> ```python
> # Queue requests, predict in batches of 32
> batch = await queue.get_batch(size=32, timeout=0.1)
> predictions = model.predict(batch)
> ```
> 
> **5. Health Checks**
> ```python
> @app.get("/health")
> async def health():
>     # Check model loaded
>     if model is None:
>         raise HTTPException(503, "Model not loaded")
>     
>     # Quick prediction test
>     test_input = np.zeros((1, 10))
>     model.predict(test_input)
>     
>     return {"status": "healthy"}
> ```
> 
> **Monitoring:**
> *- Prediction latency (P50, P95, P99)*
> *- Model version deployed*
> *- Prediction distribution (drift detection)*
> *- Error rate by error type*"*

---

### Q3: "Explain async/await and when you'd use it."

**Your Answer:**

> *"Async/await is for I/O-bound concurrency, not parallelism.*
> 
> **How It Works:**
> *- Single thread, event loop*
> *- While waiting for I/O (DB, API), handle other requests*
> *- NOT for CPU-intensive work (use threads/processes)*
> 
> **Use Cases:**
> 
> **✅ GOOD for Async:**
> *- Database queries*
> *- External API calls*
> *- File I/O*
> *- Network operations*
> 
> ```python
> # 3 API calls in parallel (1 sec total)
> results = await asyncio.gather(
>     api1(), api2(), api3()
> )
> ```
> 
> **❌ BAD for Async:**
> *- ML model inference (CPU-bound)*
> *- Image processing*
> *- Data crunching*
> 
> ```python
> # This BLOCKS the event loop!
> result = model.predict(data)  # 500ms CPU time
> 
> # Do this instead:
> result = await loop.run_in_executor(executor, model.predict, data)
> ```
> 
> **Real Example:**
> *Invoice API needs data from 3 microservices. Synchronous: 300ms (100ms each, sequential). Async: 100ms (all parallel). That's 3x faster!"*

---

## Summary: Your Python/FastAPI Expertise

**When Asked About Python/FastAPI:**

> *"I use Python/FastAPI for modern microservices and AI/ML model serving. FastAPI gives us 2-3x better performance than Flask through async/await, automatic validation via Pydantic, and built-in OpenAPI docs.*
> 
> *For ML serving, I load models at startup, run inference in thread pools to avoid blocking the event loop, and cache predictions in Redis. This architecture handles 1000+ req/sec with P95 latency under 200ms.*
> 
> *The combination of type hints, automatic validation, and async support makes it perfect for building reliable, high-performance APIs that serve both traditional web requests and AI model predictions."*

---

**Python/FastAPI expertise complete!** 🐍⚡
