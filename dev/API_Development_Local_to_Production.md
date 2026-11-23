# API Development: Local to Production

> **Complete journey of building and deploying a REST API with Docker**

---

## Table of Contents

1. [Overview: The Complete Journey](#overview)
2. [Stage 1: Local Development](#stage-1-local-development)
3. [Stage 2: Testing (Unit → Integration → E2E)](#stage-2-testing)
4. [Stage 3: CI/CD Pipeline](#stage-3-cicd-pipeline)
5. [Stage 4: Staging Deployment](#stage-4-staging-deployment)
6. [Stage 5: Production Deployment](#stage-5-production-deployment)
7. [Stage 6: Monitoring & Rollback](#stage-6-monitoring--rollback)
8. [Interview Talking Points](#interview-talking-points)

---

# Overview

## The Complete Journey

```
Local Dev (Docker Compose)
  ↓
Unit Tests (Jest/pytest)
  ↓
Integration Tests (Testcontainers + Real DB)
  ↓
E2E Tests (Cypress against test environment)
  ↓
CI/CD Pipeline (GitHub Actions: lint → test → build → scan)
  ↓
Staging Deployment (ECS/EKS, staging.example.com)
  ↓
Smoke Tests (Automated + Manual QA)
  ↓
Production Deployment (Blue-Green or Canary)
  ↓
Monitoring (Datadog, Rollback if needed)
```

---

# Stage 1: Local Development

## Goal
Run the entire application stack on your laptop: API, database, Redis, and any background workers.

---

## Project Structure

```
my-api/
├── src/
│   ├── app.js                 # Express app
│   ├── routes/
│   │   ├── users.js
│   │   └── posts.js
│   ├── models/
│   │   ├── User.js
│   │   └── Post.js
│   ├── services/
│   │   └── emailService.js
│   └── utils/
│       └── logger.js
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── package.json
└── README.md
```

---

## Docker Compose Setup

### `docker-compose.yml`
```yaml
version: '3.8'

services:
  # API Server
  api:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: development
      DB_HOST: postgres
      DB_PORT: 5432
      DB_NAME: myapp_dev
      DB_USER: postgres
      DB_PASSWORD: postgres
      REDIS_HOST: redis
      REDIS_PORT: 6379
    volumes:
      - ./src:/app/src       # Hot reload: changes reflected instantly
      - ./node_modules:/app/node_modules
    depends_on:
      - postgres
      - redis
    command: npm run dev      # Uses nodemon for hot reload

  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp_dev
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql  # Run schema on startup

  # Redis Cache
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  # Background Worker (Optional)
  worker:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      NODE_ENV: development
      DB_HOST: postgres
      REDIS_HOST: redis
    volumes:
      - ./src:/app/src
    depends_on:
      - postgres
      - redis
    command: npm run worker

volumes:
  postgres_data:
  redis_data:
```

---

## Dockerfile

```dockerfile
# Stage 1: Base image
FROM node:18-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Development (with devDependencies)
FROM node:18-alpine AS development
WORKDIR /app
COPY package*.json ./
RUN npm ci  # Install all dependencies (including devDependencies)
COPY . .
CMD ["npm", "run", "dev"]

# Stage 3: Production (optimized)
FROM base AS production
COPY . .
CMD ["node", "src/app.js"]
```

---

## Running Locally

### 1. **Start all services:**
```bash
docker-compose up -d
```

**What happens:**
1. Docker Compose reads `docker-compose.yml`
2. Builds `api` image (if not cached)
3. Pulls `postgres:15-alpine` and `redis:7-alpine` images
4. Creates network `my-api_default` (all services can talk to each other)
5. Starts 3 containers:
   - `api` → runs on `localhost:3000`
   - `postgres` → runs on `localhost:5432`
   - `redis` → runs on `localhost:6379`
6. Runs `init.sql` to create database schema

### 2. **Check logs:**
```bash
docker-compose logs -f api

# Output:
# api_1 | > my-api@1.0.0 dev
# api_1 | > nodemon src/app.js
# api_1 | 
# api_1 | [nodemon] 2.0.20
# api_1 | [nodemon] watching: *.*
# api_1 | Server listening on port 3000
# api_1 | Connected to PostgreSQL
# api_1 | Connected to Redis
```

### 3. **Test API:**
```bash
curl http://localhost:3000/api/users

# Response:
{
  "users": [
    {"id": 1, "name": "John Doe", "email": "john@example.com"}
  ]
}
```

### 4. **Hot Reload (Make a code change):**
```bash
# Edit src/routes/users.js
# Add a console.log("Fetching users...")

# Check logs:
docker-compose logs -f api

# Output:
# api_1 | [nodemon] restarting due to changes...
# api_1 | [nodemon] starting `node src/app.js`
# api_1 | Server listening on port 3000
# api_1 | Fetching users...
```

**Changes reflected instantly** without rebuilding the image!

---

## What Happens Under the Hood

### Docker Networks
```bash
docker network ls

# Output:
# NETWORK ID     NAME                MODE
# abc123         my-api_default      bridge
```

All services (`api`, `postgres`, `redis`) are on the same network.  
Inside the `api` container, you can reach:
- PostgreSQL: `postgres:5432` (not `localhost:5432`)
- Redis: `redis:6379` (not `localhost:6379`)

### Volumes
```bash
docker volume ls

# Output:
# VOLUME NAME
# my-api_postgres_data
# my-api_redis_data
```

**Purpose:**
- Data persists even if containers are stopped/removed
- Delete container → data still exists
- Delete volume → data is lost

---

## Common Issues & Fixes

### Issue 1: **Port already in use**
```
Error: bind: address already in use
```

**Fix:**
```bash
# Check what's using port 3000
lsof -i :3000

# Kill the process
kill -9 <PID>

# Or change port in docker-compose.yml
ports:
  - "3001:3000"  # Host port 3001 → Container port 3000
```

### Issue 2: **Database connection refused**
```
Error: connect ECONNREFUSED postgres:5432
```

**Fix:**
- Check `depends_on` in docker-compose.yml
- PostgreSQL might not be ready yet (race condition)
- Add retry logic in app.js:
```javascript
const connectDB = async (retries = 5) => {
  while (retries > 0) {
    try {
      await db.connect();
      console.log('Connected to PostgreSQL');
      return;
    } catch (err) {
      console.log(`DB connection failed. Retrying... (${retries} left)`);
      retries--;
      await new Promise(resolve => setTimeout(resolve, 2000));  // Wait 2 seconds
    }
  }
  throw new Error('Could not connect to PostgreSQL');
};
```

### Issue 3: **Changes not reflected (hot reload not working)**
```
# Changes made but container still serves old code
```

**Fix:**
- Check volumes in docker-compose.yml:
```yaml
volumes:
  - ./src:/app/src  # Must mount source directory
```
- Restart containers:
```bash
docker-compose restart api
```

---

# Stage 2: Testing

## Overview

Three types of tests, run in order:

1. **Unit Tests** (fast, isolated)
2. **Integration Tests** (medium, real database)
3. **E2E Tests** (slow, full stack)

---

## 2.1 Unit Tests

### Goal
Test individual functions in isolation (no database, no external services).

### Example: Testing a Service Function

**File:** `src/services/userService.js`
```javascript
const bcrypt = require('bcrypt');

class UserService {
  async hashPassword(password) {
    return bcrypt.hash(password, 10);
  }

  async validatePassword(password, hash) {
    return bcrypt.compare(password, hash);
  }

  formatUser(user) {
    return {
      id: user.id,
      name: user.name,
      email: user.email,
      // Don't expose password_hash
    };
  }
}

module.exports = new UserService();
```

**Test:** `tests/unit/userService.test.js`
```javascript
const userService = require('../../src/services/userService');

describe('UserService', () => {
  describe('hashPassword', () => {
    it('should hash a password', async () => {
      const password = 'mySecretPassword';
      const hash = await userService.hashPassword(password);
      
      expect(hash).toBeTruthy();
      expect(hash).not.toBe(password);  // Not plaintext
      expect(hash.length).toBeGreaterThan(50);  // bcrypt hashes are long
    });
  });

  describe('validatePassword', () => {
    it('should return true for correct password', async () => {
      const password = 'mySecretPassword';
      const hash = await userService.hashPassword(password);
      
      const isValid = await userService.validatePassword(password, hash);
      expect(isValid).toBe(true);
    });

    it('should return false for incorrect password', async () => {
      const password = 'mySecretPassword';
      const hash = await userService.hashPassword(password);
      
      const isValid = await userService.validatePassword('wrongPassword', hash);
      expect(isValid).toBe(false);
    });
  });

  describe('formatUser', () => {
    it('should not expose password_hash', () => {
      const user = {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        password_hash: 'hashed_password_here'
      };
      
      const formatted = userService.formatUser(user);
      
      expect(formatted).toEqual({
        id: 1,
        name: 'John Doe',
        email: 'john@example.com'
      });
      expect(formatted.password_hash).toBeUndefined();
    });
  });
});
```

**Run:**
```bash
npm test

# Output:
# PASS  tests/unit/userService.test.js
#   UserService
#     hashPassword
#       ✓ should hash a password (45ms)
#     validatePassword
#       ✓ should return true for correct password (40ms)
#       ✓ should return false for incorrect password (38ms)
#     formatUser
#       ✓ should not expose password_hash (2ms)
# 
# Test Suites: 1 passed, 1 total
# Tests:       4 passed, 4 total
# Time:        1.234s
```

---

## 2.2 Integration Tests

### Goal
Test API endpoints with a **real database** (not mocked).

### Setup: Testcontainers

**What is Testcontainers?**
- Spins up a real PostgreSQL container for tests
- Each test suite gets a fresh database
- Container is destroyed after tests finish

**File:** `tests/integration/users.test.js`
```javascript
const request = require('supertest');
const { GenericContainer } = require('testcontainers');
const app = require('../../src/app');
const db = require('../../src/db');

describe('Users API (Integration)', () => {
  let postgresContainer;
  let dbClient;

  // Before all tests: Start PostgreSQL container
  beforeAll(async () => {
    postgresContainer = await new GenericContainer('postgres:15-alpine')
      .withEnvironment({
        POSTGRES_USER: 'test',
        POSTGRES_PASSWORD: 'test',
        POSTGRES_DB: 'test_db'
      })
      .withExposedPorts(5432)
      .start();

    const host = postgresContainer.getHost();
    const port = postgresContainer.getMappedPort(5432);

    // Connect to test database
    dbClient = await db.connect({
      host,
      port,
      user: 'test',
      password: 'test',
      database: 'test_db'
    });

    // Run schema migration
    await dbClient.query(`
      CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
  });

  // After all tests: Stop container
  afterAll(async () => {
    await dbClient.end();
    await postgresContainer.stop();
  });

  // Before each test: Clear data
  beforeEach(async () => {
    await dbClient.query('TRUNCATE TABLE users CASCADE');
  });

  describe('POST /api/users', () => {
    it('should create a new user', async () => {
      const response = await request(app)
        .post('/api/users')
        .send({
          name: 'John Doe',
          email: 'john@example.com',
          password: 'password123'
        })
        .expect(201);

      expect(response.body).toMatchObject({
        id: expect.any(Number),
        name: 'John Doe',
        email: 'john@example.com'
      });
      expect(response.body.password_hash).toBeUndefined();  // Not exposed

      // Verify in database
      const result = await dbClient.query('SELECT * FROM users WHERE email = $1', ['john@example.com']);
      expect(result.rows.length).toBe(1);
      expect(result.rows[0].name).toBe('John Doe');
    });

    it('should return 400 for duplicate email', async () => {
      // Create first user
      await request(app)
        .post('/api/users')
        .send({
          name: 'John Doe',
          email: 'john@example.com',
          password: 'password123'
        })
        .expect(201);

      // Try to create duplicate
      const response = await request(app)
        .post('/api/users')
        .send({
          name: 'Jane Doe',
          email: 'john@example.com',  // Duplicate email
          password: 'password123'
        })
        .expect(400);

      expect(response.body.error).toContain('already exists');
    });
  });

  describe('GET /api/users/:id', () => {
    it('should return user by id', async () => {
      // Create user
      const createResponse = await request(app)
        .post('/api/users')
        .send({
          name: 'John Doe',
          email: 'john@example.com',
          password: 'password123'
        });

      const userId = createResponse.body.id;

      // Fetch user
      const response = await request(app)
        .get(`/api/users/${userId}`)
        .expect(200);

      expect(response.body).toMatchObject({
        id: userId,
        name: 'John Doe',
        email: 'john@example.com'
      });
    });

    it('should return 404 for non-existent user', async () => {
      const response = await request(app)
        .get('/api/users/999999')
        .expect(404);

      expect(response.body.error).toContain('not found');
    });
  });
});
```

**Run:**
```bash
npm run test:integration

# Output:
# Starting PostgreSQL container...
# Container started: postgres:15-alpine (port 32768)
# Running schema migrations...
# 
# PASS  tests/integration/users.test.js
#   Users API (Integration)
#     POST /api/users
#       ✓ should create a new user (234ms)
#       ✓ should return 400 for duplicate email (189ms)
#     GET /api/users/:id
#       ✓ should return user by id (145ms)
#       ✓ should return 404 for non-existent user (98ms)
# 
# Stopping PostgreSQL container...
# 
# Test Suites: 1 passed, 1 total
# Tests:       4 passed, 4 total
# Time:        12.456s
```

**What happened:**
1. Testcontainers pulled `postgres:15-alpine` image
2. Started container on random port (32768)
3. Connected to it, ran schema migration
4. Ran 4 tests
5. Stopped and removed container

---

## 2.3 End-to-End (E2E) Tests

### Goal
Test the **entire application flow** from frontend → API → database → response.

### Setup: Cypress

**File:** `cypress/e2e/user-registration.cy.js`
```javascript
describe('User Registration Flow', () => {
  beforeEach(() => {
    // Reset database before each test
    cy.task('db:reset');
    
    // Visit homepage
    cy.visit('http://localhost:3000');
  });

  it('should register a new user', () => {
    // Click "Sign Up" button
    cy.contains('Sign Up').click();
    
    // Fill form
    cy.get('[data-testid="name-input"]').type('John Doe');
    cy.get('[data-testid="email-input"]').type('john@example.com');
    cy.get('[data-testid="password-input"]').type('password123');
    cy.get('[data-testid="confirm-password-input"]').type('password123');
    
    // Submit form
    cy.get('[data-testid="submit-button"]').click();
    
    // Assert: Redirected to dashboard
    cy.url().should('include', '/dashboard');
    cy.contains('Welcome, John Doe');
    
    // Assert: User exists in database
    cy.task('db:query', 'SELECT * FROM users WHERE email = $1', ['john@example.com'])
      .then((result) => {
        expect(result.rows.length).to.equal(1);
        expect(result.rows[0].name).to.equal('John Doe');
      });
  });

  it('should show error for duplicate email', () => {
    // Pre-seed user
    cy.task('db:seed', {
      table: 'users',
      data: { name: 'Existing User', email: 'john@example.com', password_hash: 'hashed' }
    });
    
    // Try to register with duplicate email
    cy.contains('Sign Up').click();
    cy.get('[data-testid="email-input"]').type('john@example.com');
    cy.get('[data-testid="password-input"]').type('password123');
    cy.get('[data-testid="submit-button"]').click();
    
    // Assert: Error message shown
    cy.contains('Email already exists').should('be.visible');
  });
});
```

**Run:**
```bash
npx cypress run

# Output:
# Starting Cypress...
# 
# Running: user-registration.cy.js (1 of 1)
#   User Registration Flow
#     ✓ should register a new user (1234ms)
#     ✓ should show error for duplicate email (567ms)
# 
# Tests:  2 passed, 2 total
# Time:   3.456s
```

---

## Testing Summary

| Test Type | Speed | Database | Scope | When to Run |
|-----------|-------|----------|-------|-------------|
| **Unit** | Fast (< 1s) | Mocked | Individual functions | Every code change (pre-commit) |
| **Integration** | Medium (10-30s) | Real (Testcontainers) | API endpoints | Before PR merge |
| **E2E** | Slow (1-5 min) | Real (test environment) | Full user flows | Nightly or pre-deployment |

---

# Stage 3: CI/CD Pipeline

## Goal
Automatically run tests, build Docker image, scan for vulnerabilities, and deploy on every git push.

---

## GitHub Actions Workflow

**File:** `.github/workflows/ci-cd.yml`
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # Job 1: Lint & Code Quality
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run ESLint
        run: npm run lint
      
      - name: Check code formatting (Prettier)
        run: npm run format:check

  # Job 2: Unit Tests
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run unit tests
        run: npm run test:unit
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info

  # Job 3: Integration Tests
  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test_db
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run integration tests
        run: npm run test:integration
        env:
          DB_HOST: localhost
          DB_PORT: 5432
          DB_USER: test
          DB_PASSWORD: test
          DB_NAME: test_db

  # Job 4: Build Docker Image
  build:
    runs-on: ubuntu-latest
    needs: [lint, unit-tests, integration-tests]  # Only run if tests pass
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
      
      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: |
            myapp/api:${{ github.sha }}
            myapp/api:latest
          cache-from: type=registry,ref=myapp/api:buildcache
          cache-to: type=registry,ref=myapp/api:buildcache,mode=max

  # Job 5: Security Scan (Checkmarx)
  security-scan:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Checkmarx Scan
        run: |
          docker run --rm \
            -v $(pwd):/app \
            checkmarx/cx-cli:latest scan \
            --project-name my-api \
            --source-location /app \
            --severity-threshold HIGH
      
      - name: Upload scan results
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: checkmarx-results
          path: ./checkmarx-results.xml

  # Job 6: Deploy to Staging
  deploy-staging:
    runs-on: ubuntu-latest
    needs: [build, security-scan]
    if: github.ref == 'refs/heads/develop'  # Only deploy develop branch
    steps:
      - name: Deploy to ECS (Staging)
        run: |
          aws ecs update-service \
            --cluster my-api-staging \
            --service my-api-service \
            --force-new-deployment \
            --region us-east-1
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      
      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster my-api-staging \
            --services my-api-service
      
      - name: Run smoke tests
        run: |
          curl https://staging.myapp.com/health | grep '"status":"healthy"'
```

---

## What Happens on Git Push

```bash
git add .
git commit -m "feat: add user registration endpoint"
git push origin develop
```

**GitHub Actions workflow triggers:**

**Minute 0-1:** Lint + Unit Tests + Integration Tests (parallel)  
**Minute 1-3:** Build Docker image (only if tests pass)  
**Minute 3-5:** Security scan (Checkmarx)  
**Minute 5-7:** Deploy to staging (ECS)  
**Minute 7-8:** Smoke tests (curl /health endpoint)

**If any step fails → entire pipeline stops.**

---

## Pipeline Stages Explained

### Stage 1: **Lint (ESLint + Prettier)**
**What it does:**
- Checks code style (indentation, semicolons, quotes)
- Catches common bugs (unused variables, unreachable code)

**Example failure:**
```bash
# Error:
src/routes/users.js:45:7
  error  'userId' is assigned a value but never used  no-unused-vars

✖ 1 problem (1 error, 0 warnings)
```

---

### Stage 2: **Unit Tests**
**What it does:**
- Runs all `tests/unit/**/*.test.js` files
- Generates code coverage report (uploaded to Codecov)

**Example output:**
```bash
Test Suites: 10 passed, 10 total
Tests:       87 passed, 87 total
Coverage:    85.3% statements
             78.1% branches
             91.2% functions
             84.9% lines
```

---

### Stage 3: **Integration Tests**
**What it does:**
- Spins up PostgreSQL service container
- Runs all `tests/integration/**/*.test.js` files
- Tests API endpoints against real database

**Example output:**
```bash
Starting PostgreSQL service...
PostgreSQL healthy on localhost:5432
Running integration tests...
Test Suites: 5 passed, 5 total
Tests:       34 passed, 34 total
```

---

### Stage 4: **Build Docker Image**
**What it does:**
- Builds Docker image from `Dockerfile`
- Tags with git commit SHA (e.g., `myapp/api:a1b2c3d`)
- Pushes to Docker Hub

**Example output:**
```bash
Building image myapp/api:a1b2c3d...
Step 1/8 : FROM node:18-alpine
Step 2/8 : WORKDIR /app
Step 3/8 : COPY package*.json ./
Step 4/8 : RUN npm ci --only=production
Step 5/8 : COPY . .
Step 6/8 : CMD ["node", "src/app.js"]
Successfully built abc123def456
Successfully tagged myapp/api:a1b2c3d
Pushing to Docker Hub...
✓ Push complete (1.2 GB)
```

---

### Stage 5: **Security Scan (Checkmarx)**
**What it does:**
- Scans code for vulnerabilities (SQL injection, XSS, hardcoded secrets)
- Fails pipeline if HIGH/CRITICAL findings

**Example failure:**
```bash
Checkmarx Scan Results:
  CRITICAL: SQL Injection in src/routes/users.js:78
  HIGH: Hardcoded password in src/config.js:12

✖ Pipeline failed due to security findings
```

---

### Stage 6: **Deploy to Staging**
**What it does:**
- Updates ECS service to use new Docker image
- Waits for deployment to stabilize (health checks pass)
- Runs smoke test (curl /health endpoint)

**Example output:**
```bash
Updating ECS service my-api-staging...
Deployment started: ecs-svc-123456
Waiting for tasks to reach RUNNING state...
Task arn:aws:ecs:us-east-1:123:task/abc123 is RUNNING
Health check passed: 3/3 targets healthy
Running smoke test...
✓ https://staging.myapp.com/health → 200 OK
```

---

# Stage 4: Staging Deployment

## Goal
Deploy to a **production-like environment** for manual QA testing.

---

## Staging Environment

```
staging.myapp.com
  ↓
AWS ECS (Elastic Container Service)
  ↓
3 ECS Tasks (containers running myapp/api:a1b2c3d)
  ↓
RDS PostgreSQL (db-staging.xxx.rds.amazonaws.com)
  ↓
ElastiCache Redis (redis-staging.xxx.cache.amazonaws.com)
```

---

## ECS Task Definition

**File:** `ecs-task-definition.json`
```json
{
  "family": "my-api-staging",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "myapp/api:a1b2c3d",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "NODE_ENV", "value": "staging"},
        {"name": "DB_HOST", "value": "db-staging.xxx.rds.amazonaws.com"},
        {"name": "DB_PORT", "value": "5432"},
        {"name": "DB_NAME", "value": "myapp_staging"},
        {"name": "REDIS_HOST", "value": "redis-staging.xxx.cache.amazonaws.com"}
      ],
      "secrets": [
        {"name": "DB_PASSWORD", "valueFrom": "arn:aws:ssm:us-east-1:123:parameter/staging/db-password"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/my-api-staging",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "api"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

---

## Deployment Process

### 1. **ECS updates task definition:**
```bash
aws ecs register-task-definition --cli-input-json file://ecs-task-definition.json
```

**Output:**
```json
{
  "taskDefinition": {
    "taskDefinitionArn": "arn:aws:ecs:us-east-1:123:task-definition/my-api-staging:42",
    "revision": 42
  }
}
```

### 2. **ECS updates service:**
```bash
aws ecs update-service \
  --cluster my-api-staging \
  --service my-api-service \
  --task-definition my-api-staging:42 \
  --force-new-deployment
```

**What happens:**
1. ECS starts 3 new tasks (containers) with revision 42
2. Waits for health checks to pass (3/3 healthy)
3. Stops old tasks (containers) with revision 41
4. Deployment complete (rolling update, zero downtime)

---

## Smoke Tests (Automated)

**File:** `scripts/smoke-test.sh`
```bash
#!/bin/bash

BASE_URL="https://staging.myapp.com"

echo "Running smoke tests..."

# Test 1: Health endpoint
echo "1. Testing /health..."
curl -f $BASE_URL/health | grep '"status":"healthy"' || exit 1

# Test 2: Create user
echo "2. Testing POST /api/users..."
curl -f -X POST $BASE_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","password":"test123"}' \
  | grep '"id"' || exit 1

# Test 3: Fetch user
echo "3. Testing GET /api/users/:id..."
curl -f $BASE_URL/api/users/1 | grep '"email":"test@example.com"' || exit 1

echo "✓ All smoke tests passed"
```

**Run:**
```bash
./scripts/smoke-test.sh

# Output:
# Running smoke tests...
# 1. Testing /health...
# {"status":"healthy"}
# 2. Testing POST /api/users...
# {"id":1,"name":"Test User","email":"test@example.com"}
# 3. Testing GET /api/users/:id...
# {"id":1,"name":"Test User","email":"test@example.com"}
# ✓ All smoke tests passed
```

---

## Manual QA Testing

**QA Checklist:**
- [ ] Can create new user
- [ ] Can login with correct password
- [ ] Cannot login with wrong password
- [ ] Can update user profile
- [ ] Can delete user
- [ ] API returns 404 for non-existent resources
- [ ] API returns 400 for invalid input
- [ ] API returns 500 errors with proper error messages

---

# Stage 5: Production Deployment

## Goal
Deploy to production with **zero downtime** and **rollback capability**.

---

## Deployment Strategies

### Option 1: **Blue-Green Deployment**

**How it works:**
```
Current state:
  BLUE environment (live, serving traffic)
  GREEN environment (idle)

Deployment:
  1. Deploy new version to GREEN environment
  2. Run smoke tests on GREEN
  3. Switch load balancer to GREEN (instant cutover)
  4. Monitor for 10 minutes
  5. If OK: Keep GREEN, shut down BLUE
     If ERROR: Switch back to BLUE (instant rollback)
```

**Example:**
```bash
# Step 1: Deploy to GREEN
aws ecs update-service \
  --cluster my-api-prod \
  --service my-api-green \
  --task-definition my-api-prod:43

# Step 2: Wait for healthy
aws ecs wait services-stable \
  --cluster my-api-prod \
  --services my-api-green

# Step 3: Switch load balancer
aws elbv2 modify-listener \
  --listener-arn arn:aws:elasticloadbalancing:us-east-1:123:listener/app/my-api-lb/abc/def \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:123:targetgroup/my-api-green

# Step 4: Monitor for 10 minutes
sleep 600

# Step 5: Shut down BLUE
aws ecs update-service \
  --cluster my-api-prod \
  --service my-api-blue \
  --desired-count 0
```

---

### Option 2: **Canary Deployment** (Instagram's Approach)

**How it works:**
```
Phase 1: 5% traffic to new version, 95% to old version (10 min)
Phase 2: 25% traffic to new version, 75% to old version (10 min)
Phase 3: 50% traffic to new version, 50% to old version (10 min)
Phase 4: 100% traffic to new version

If errors spike at any phase → rollback instantly
```

**Example (AWS App Mesh):**
```yaml
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualService
metadata:
  name: my-api
spec:
  routes:
    - name: canary-route
      http:
        match:
          prefix: /
        action:
          weightedTargets:
            - virtualNodeRef:
                name: my-api-v1
              weight: 95  # Old version
            - virtualNodeRef:
                name: my-api-v2
              weight: 5   # New version (canary)
```

**Gradually shift weights:**
```bash
# Phase 1: 5% canary
kubectl apply -f canary-5.yaml
sleep 600  # Monitor for 10 min

# Phase 2: 25% canary
kubectl apply -f canary-25.yaml
sleep 600

# Phase 3: 50% canary
kubectl apply -f canary-50.yaml
sleep 600

# Phase 4: 100% canary
kubectl apply -f canary-100.yaml
```

---

## Production Deployment Checklist

**Before deployment:**
- [ ] All tests pass (unit, integration, E2E)
- [ ] Security scan clean (no HIGH/CRITICAL findings)
- [ ] Staging deployment successful
- [ ] Manual QA sign-off
- [ ] Database migrations tested (if any)
- [ ] Rollback plan documented
- [ ] On-call engineer notified

**During deployment:**
- [ ] Monitor error rate (Datadog dashboard)
- [ ] Monitor latency (p50, p95, p99)
- [ ] Check logs for new errors
- [ ] Verify health checks pass

**After deployment:**
- [ ] Smoke tests pass
- [ ] Manual verification (critical flows)
- [ ] Monitor for 1 hour
- [ ] Update release notes
- [ ] Notify stakeholders

---

# Stage 6: Monitoring & Rollback

## Goal
Detect issues quickly and rollback if needed.

---

## Monitoring Dashboard (Datadog)

**Key Metrics:**

1. **Request Rate** (requests/sec)
   - Baseline: 1,000/sec
   - Alert if drops below 500/sec (50% drop)

2. **Error Rate** (5xx errors / total requests)
   - Baseline: 0.1%
   - Alert if exceeds 1%

3. **Latency** (p95, p99)
   - Baseline: p95 = 200ms, p99 = 500ms
   - Alert if p95 > 500ms or p99 > 1000ms

4. **Database Connections**
   - Baseline: 50 connections
   - Alert if exceeds 100 connections (pool exhaustion)

5. **Memory Usage**
   - Baseline: 400 MB
   - Alert if exceeds 800 MB (potential memory leak)

---

## Alerting Rules

**PagerDuty alert triggers when:**
```yaml
alerts:
  - name: High Error Rate
    condition: error_rate > 1% for 5 minutes
    severity: CRITICAL
    action: Page on-call engineer

  - name: High Latency
    condition: p95_latency > 500ms for 10 minutes
    severity: WARNING
    action: Slack notification

  - name: Service Down
    condition: health_check_failures > 3 in 2 minutes
    severity: CRITICAL
    action: Page on-call engineer + auto-rollback
```

---

## Rollback Process

### Manual Rollback (Blue-Green)

**Scenario:** New version deployed to production, error rate spiked to 5%

**Action:**
```bash
# 1. Switch load balancer back to BLUE (old version)
aws elbv2 modify-listener \
  --listener-arn arn:aws:elasticloadbalancing:us-east-1:123:listener/app/my-api-lb/abc/def \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:123:targetgroup/my-api-blue

# 2. Verify error rate drops
# Check Datadog: error_rate should drop from 5% → 0.1% within 1 minute

# 3. Post-mortem
# Investigate why new version had high error rate
# Fix bug, deploy to staging, re-test, deploy to prod again
```

**Rollback time:** < 1 minute (instant cutover)

---

### Auto-Rollback (CI/CD)

**GitHub Actions workflow:**
```yaml
jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to production
        run: ./deploy-prod.sh
      
      - name: Wait 5 minutes
        run: sleep 300
      
      - name: Check error rate
        run: |
          ERROR_RATE=$(curl -s https://api.datadoghq.com/api/v1/query?query=error_rate | jq '.series[0].pointlist[-1][1]')
          if (( $(echo "$ERROR_RATE > 1.0" | bc -l) )); then
            echo "ERROR: Error rate is $ERROR_RATE% (threshold: 1%)"
            echo "Initiating auto-rollback..."
            ./rollback.sh
            exit 1
          fi
          echo "✓ Error rate is $ERROR_RATE% (healthy)"
```

---

## Logs (CloudWatch Logs)

**Viewing logs:**
```bash
aws logs tail /ecs/my-api-prod --follow

# Output:
# 2026-11-20T10:00:01 [INFO] Server started on port 3000
# 2026-11-20T10:00:05 [INFO] GET /api/users/123 200 45ms
# 2026-11-20T10:00:12 [ERROR] POST /api/users 500 123ms
#   Error: Duplicate key violation
#   at UserService.createUser (src/services/userService.js:45)
# 2026-11-20T10:00:15 [INFO] GET /health 200 2ms
```

---

# Interview Talking Points

## 2-Minute Answer: "Walk me through deploying an API from local to production"

**Your Answer:**

"I'll walk through the **6-stage journey** from local dev to production:

**Stage 1: Local Development (Docker Compose)**
- Run entire stack on laptop: API, PostgreSQL, Redis in Docker Compose
- Hot reload via volume mounts: code changes reflected instantly
- Benefit: Consistent environment (dev = prod)

**Stage 2: Testing (3 layers)**
- **Unit tests** (Jest): Fast, isolated function tests
- **Integration tests** (Testcontainers): Spin up real PostgreSQL, test API endpoints
- **E2E tests** (Cypress): Full user flows, run against test environment

**Stage 3: CI/CD Pipeline (GitHub Actions)**
- 6-job workflow: Lint → Unit → Integration → Build Docker image → Security scan (Checkmarx) → Deploy
- If any step fails → pipeline stops
- Build time: 5-7 minutes

**Stage 4: Staging Deployment (AWS ECS)**
- Deploy to production-like environment (staging.myapp.com)
- Automated smoke tests: health check, create user, fetch user
- Manual QA: Test critical flows

**Stage 5: Production Deployment (Blue-Green)**
- Deploy new version to GREEN environment
- Run smoke tests
- Switch load balancer (instant cutover)
- Monitor for 10 minutes, rollback if errors spike

**Stage 6: Monitoring (Datadog + PagerDuty)**
- Track error rate, latency, database connections
- Alert if error rate > 1% → auto-rollback
- Rollback time: < 1 minute

**At Billtrust**, we use similar workflows: Docker for local dev, GitHub Actions for CI/CD, ECS for deployment. I've deployed 50+ production changes with zero rollback incidents using this approach."

---

## Common Interview Questions

### Q1: "Why use Docker Compose for local development?"

**Answer:**
"Three reasons:

1. **Consistent environment:** Dev = Staging = Prod (same PostgreSQL version, same Node version)
2. **Easy onboarding:** New developer runs `docker-compose up`, entire stack ready in 2 minutes
3. **Isolation:** Multiple projects don't conflict (each has its own PostgreSQL on different port)"

---

### Q2: "What's the difference between blue-green and canary deployment?"

**Answer:**
"**Blue-Green:**
- Two environments (BLUE = old, GREEN = new)
- Deploy to GREEN, test, then instant cutover (100% → 0%)
- Benefit: Instant rollback
- Used when: Confidence in new version is high

**Canary:**
- Gradual rollout: 5% → 25% → 50% → 100%
- Monitor at each phase, rollback if errors spike
- Benefit: Limits blast radius (only 5% users affected if bug)
- Used when: Risky changes, want to test with small traffic first

At Billtrust, we use **blue-green** for most changes, **canary** for major version upgrades."

---

### Q3: "How do you handle database migrations in production?"

**Answer:**
"Two-phase deployment:

**Phase 1: Additive change (safe):**
1. Add new column (nullable)
2. Deploy code that writes to both old + new column
3. Backfill data for new column
4. Deploy code that reads from new column

**Phase 2: Cleanup (after verification):**
5. Remove code that writes to old column
6. Drop old column

**Key:** Never drop column in same deployment as code change. Always give yourself a rollback window.

At Billtrust, I've executed 200+ production DDL/DML changes with 100% success rate using this pattern."

---

## Summary

| Stage | Purpose | Time | Rollback Time |
|-------|---------|------|---------------|
| **Local Dev** | Fast iteration | Instant (hot reload) | N/A |
| **Testing** | Catch bugs early | 1-5 min | N/A |
| **CI/CD** | Automate everything | 5-7 min | N/A |
| **Staging** | Manual QA | 10-30 min | N/A |
| **Production** | Serve users | 10-30 min | < 1 min (blue-green) |
| **Monitoring** | Detect issues | Continuous | Auto-rollback if error rate > 1% |

**You're ready to explain the full API lifecycle in interviews!** 🎯
