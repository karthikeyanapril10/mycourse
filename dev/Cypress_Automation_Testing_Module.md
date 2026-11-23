# 🧪 Cypress Automation Testing Module

**Reality Check:** At 12+ years, you're expected to write, maintain, and review automation as part of dev work — not hand it off to QA.

---

## 📋 Module Overview

**What You'll Learn:**
- Cypress fundamentals and architecture
- Billtrust's automation patterns (Page Object Model, Test Data API)
- Writing E2E tests for CC (Client Connect) and EIC (eInvoice Connect)
- Custom commands and helper utilities
- Test maintenance and debugging
- Interview prep: Automation questions for 12+ years experience

**Time Investment:** 4-6 weeks to master (20-30 hours)

**Billtrust Automation Stack:**
- **Cypress 13+** (TypeScript)
- **Page Object Model** pattern
- **Test Data API** (AWS-backed service provisioning)
- **Allure Reports** for test reporting
- **cy-grep** for tag-based execution
- **GitHub Actions CI/CD** pipelines

---

## 🎯 Why Automation Matters at 12+ Years

### **What Changes at Senior Level**

| Junior QA (0-3 years) | Senior Dev (12+ years) |
|---|---|
| Write tests from spec | Write tests WHILE coding the feature |
| Hand-written selectors | Maintainable Page Objects with data-test attrs |
| Happy path only | Edge cases + error handling |
| Fix when asked | Own test stability, reduce flakiness |
| Manual reruns | Auto-heal tests, understand CI failures |

### **Interview Reality**

**They WILL ask:**
1. ✅ "How do you handle flaky tests?" (stability, retries, waits)
2. ✅ "Describe your automation architecture" (Page Objects, services)
3. ✅ "How do you handle authentication in Cypress?" (session management, custom commands)
4. ✅ "What's your approach to test data?" (API-driven provisioning vs fixtures)
5. ✅ "How do you debug CI failures?" (screenshots, videos, logs)

---

## 📚 Section 1: Cypress Fundamentals

### **What is Cypress?**

Cypress is a **JavaScript-based E2E testing framework** that runs IN the browser (not WebDriver-based like Selenium).

**Key Differences from Selenium:**

| Feature | Selenium WebDriver | Cypress |
|---|---|---|
| **Architecture** | Runs outside browser, sends commands via HTTP | Runs INSIDE browser, direct access to DOM/Network |
| **Language** | Java, Python, C#, Ruby | JavaScript / TypeScript only |
| **Wait Strategy** | Explicit waits (WebDriverWait) | Auto-retry, built-in waits |
| **Network Stubbing** | Hard (requires proxy) | Built-in (`cy.intercept()`) |
| **Speed** | Slower (HTTP round-trips) | Faster (direct browser access) |
| **Debugging** | Harder (black box) | Easier (Chrome DevTools, time-travel) |

### **Cypress Core Concepts**

#### **1. Command Chaining**

```typescript
// Everything chains!
cy.get('[data-test="username"]')
  .type('admin@example.com')
  .should('have.value', 'admin@example.com')

// BAD: Don't assign to variables (async!)
const button = cy.get('button'); // ❌ This is a Cypress chainable, not the element!

// GOOD: Use aliases or chain directly
cy.get('button').as('submitButton');
cy.get('@submitButton').click();
```

#### **2. Automatic Retries & Waiting**

```typescript
// Cypress auto-retries for 4 seconds (default)
cy.get('.loading-spinner').should('not.exist'); // Waits until spinner disappears
cy.get('.success-message').should('be.visible'); // Waits until visible

// Custom timeout
cy.get('.slow-element', { timeout: 10000 }).should('exist');
```

#### **3. Asynchronous Nature**

```typescript
// ❌ WRONG: Trying to use Cypress commands synchronously
let username;
cy.get('[data-test="username"]').then(($el) => {
  username = $el.text();
});
console.log(username); // ❌ undefined! (Cypress hasn't run yet)

// ✅ CORRECT: Use .then() or aliases
cy.get('[data-test="username"]').then(($el) => {
  const username = $el.text();
  cy.log(`Username is: ${username}`);
});

// ✅ OR use aliases
cy.get('[data-test="username"]').invoke('text').as('username');
cy.get('@username').then((username) => {
  cy.log(`Username is: ${username}`);
});
```

---

## 🏗️ Section 2: Billtrust's Cypress Architecture

### **Repo Structure (inv-invoicing-ui-cc-automation)**

```
inv-invoicing-ui-cc-automation/
├── cypress/
│   ├── e2e/
│   │   └── tests/
│   │       ├── admin/              # Admin portal tests
│   │       ├── enroll/             # Enrollment flow tests
│   │       ├── payment/            # Payment tests
│   │       └── batchUpload/        # Bulk operations
│   ├── pages/                      # Page Object Model
│   │   ├── admin.ts                # Admin page actions
│   │   ├── payment.ts              # Payment page actions
│   │   └── signin.ts               # Sign-in page
│   ├── support/
│   │   ├── commands.ts             # Custom Cypress commands
│   │   ├── helpers/                # Utility functions
│   │   │   ├── dataHelper.ts
│   │   │   ├── dateHelper.ts
│   │   │   └── customerCreationHelpers.ts
│   │   └── services/               # API service wrappers
│   │       ├── testDataService.ts  # Test Data API
│   │       ├── btpayService.ts
│   │       └── eicService.ts
│   ├── fixtures/                   # Static test data
│   └── plugins/                    # Cypress plugins
├── cypress.config.ts               # Main config
└── package.json
```

---

## 📄 Section 3: Page Object Model (POM)

### **Why Page Objects?**

**Without POM (BAD):**
```typescript
// Test file - tightly coupled to DOM
it('should update user password', () => {
  cy.get("[href='ccAdmin.php']").click(); // ❌ What is this?
  cy.get("[name='NewPassword']").type('newpass123'); // ❌ Brittle selector
  cy.get("input.btncc[value='Update']").click(); // ❌ Hard to maintain
});
```

**With POM (GOOD):**
```typescript
// Test file - readable, maintainable
it('should update user password', () => {
  adminPage.clickAdminButton(); // ✅ Clear intent
  adminPage.enterPassword('newpass123'); // ✅ Encapsulated
  adminPage.clickUpdateButton(); // ✅ Reusable
});
```

### **Billtrust POM Pattern**

**Example: `admin.ts` Page Object**

```typescript
export class AdminPage {
  // Centralized selectors
  elements = {
    adminUrl: "/ccAdmin.php",
    passwordTextBox: () => cy.get("[name='NewPassword']"),
    adminUpdateButton: () => cy.get("input.btncc[value='Update']"),
    successMsg: () => cy.get(".redmed"),
  };

  // Page actions (methods)
  navigateToAdmin() {
    cy.visit(this.elements.adminUrl);
  }

  enterPassword(password: string) {
    this.elements.passwordTextBox().clear().type(password);
  }

  clickUpdateButton() {
    this.elements.adminUpdateButton().click();
  }

  verifySuccessMessage(expectedText: string) {
    this.elements.successMsg().should('contain', expectedText);
  }
}

// Export singleton instance
export const adminPage = new AdminPage();
```

**Using the Page Object in Tests:**

```typescript
import { adminPage } from "@pages/admin";

describe("Admin Password Update", () => {
  it("should update admin password successfully", () => {
    adminPage.navigateToAdmin();
    adminPage.enterPassword('newSecurePass123!');
    adminPage.clickUpdateButton();
    adminPage.verifySuccessMessage('Password updated successfully');
  });
});
```

---

## 🔧 Section 4: Custom Commands

### **What Are Custom Commands?**

Custom commands extend Cypress with reusable actions. Defined in `cypress/support/commands.ts`.

### **Billtrust Examples**

#### **1. Authentication Command**

```typescript
// cypress/support/commands.ts
Cypress.Commands.add("signin", (customerName: string) => {
  signInPage.navigateTo();
  signInPage.enterCompanyName(customerName);
  signInPage.enterUserName(customerName);
  signInPage.enterPassword(Cypress.env("automationAccountPassword"));
  signInPage.clickSignIn();
});

// Usage in test
cy.signin('ACME Corp');
```

#### **2. Customer Settings Update**

```typescript
Cypress.Commands.add("updateCustomerSettings", (customerId: string, settingsToUpdate: any) => {
  cy.fixture("customer.all.settings").then((allSettings: any) => {
    const settingsMap = new Map(Object.entries(settingsToUpdate));
    const updatedSettings = allSettings.settings
      .filter(item => settingsMap.has(item.settingName))
      .map(item => ({
        ...item,
        settingValue: settingsMap.get(item.settingName)
      }));

    const requestBody = { settings: updatedSettings };
    TestDataService.updateCustomerSettingsWithPath(customerId, requestBody);
  });
});

// Usage
cy.updateCustomerSettings(customerId, {
  'AutopayVersion': AutopayVersions.V3,
  'EnableEBill': 'Y'
});
```

#### **3. Data-Test Selector Helpers**

```typescript
Cypress.Commands.add("getDataTest", (dataTestSelector: string) => {
  return cy.get(`[data-test="${dataTestSelector}"]`);
});

// Usage
cy.getDataTest('submit-button').click(); // Cleaner than cy.get('[data-test="submit-button"]')
```

---

## 🌐 Section 5: Test Data API Integration

### **Why Test Data API?**

**Problem:** Creating test customers manually is slow and flaky.

**Solution:** AWS-backed Test Data Service that provisions customers via API.

### **Service Wrapper Pattern**

```typescript
// cypress/support/services/testDataService.ts
class TestDataService {
  static createCustomer(customerData: any) {
    return cy.request({
      method: 'POST',
      url: `${Cypress.env('TESTDATAAPI_BASE_URL')}/customers`,
      headers: {
        'Authorization': `Bearer ${Cypress.env('TESTDATAAPI_AUTH_TOKEN')}`,
        'x-api-key': Cypress.env('TESTDATAAPI_API_KEY')
      },
      body: customerData
    });
  }

  static getCustomerSettingsByCustomerId(customerId: string) {
    return cy.request({
      method: 'GET',
      url: `${Cypress.env('TESTDATAAPI_BASE_URL')}/customers/${customerId}/settings`,
      headers: {
        'Authorization': `Bearer ${Cypress.env('TESTDATAAPI_AUTH_TOKEN')}`
      }
    });
  }
}

export default TestDataService;
```

### **Using Test Data API in Tests**

```typescript
import TestDataService from "@services/testDataService";

describe("Payment Autopay Flow", () => {
  let customerId: string;

  before(() => {
    // Provision customer via API (fast!)
    cy.fixture('customer.autopay').then((customerData) => {
      TestDataService.createCustomer(customerData).then((response) => {
        customerId = response.body.data.customerId;
      });
    });
  });

  it("should enable autopay for customer", () => {
    cy.updateCustomerSettings(customerId, { 'AutopayVersion': 'V3' });
    cy.signin(customerId);
    // ... rest of test
  });
});
```

---

## 🏷️ Section 6: Test Organization & Tags

### **Test File Structure**

```typescript
import { adminPage } from "@pages/admin";
import data from "@pages/data";

// Describe block with tag
describe("Admin User Management", { tags: "@admin" }, () => {

  // Context for grouping related tests
  context("Password Update Flow", () => {

    // Setup hooks
    before(() => {
      cy.getCustomerCredentials("CP"); // CP = Corporate Primary
    });

    beforeEach(function() {
      cy.signin(this.customerName);
    });

    // Actual test
    it("should update password successfully [BQ-276]", function() {
      adminPage.clickAdminButton();
      adminPage.enterPassword('newPass123!');
      adminPage.clickUpdateButton();
      adminPage.verifySuccessMessage(data.successMessage);
    });
  });
});
```

### **Tag-Based Execution**

```bash
# Run all admin tests
npx cypress run --env grepTags="@admin"

# Run specific test by ID
npx cypress run --env grepTags="@BQ-276"

# Run smoke tests only
npx cypress run --env grepTags="@smoke"
```

---

## 🔄 Section 7: Handling Asynchronous Operations

### **Network Requests with cy.intercept()**

```typescript
// Wait for API call to complete
cy.intercept('POST', '/api/customers').as('createCustomer');
cy.getDataTest('create-customer-btn').click();
cy.wait('@createCustomer').its('response.statusCode').should('eq', 201);

// Stub API response
cy.intercept('GET', '/api/settings', {
  statusCode: 200,
  body: { autopayEnabled: true }
}).as('getSettings');
```

### **Conditional Testing**

```typescript
// Check if element exists, then act
cy.get('body').then(($body) => {
  if ($body.find('.modal-overlay').length > 0) {
    cy.get('.modal-close').click();
  }
});

// Or use Cypress conditional
cy.get('.modal-overlay').then(($modal) => {
  if ($modal.is(':visible')) {
    cy.get('.modal-close').click();
  }
});
```

### **Dynamic Waits**

```typescript
// Wait for a condition
cy.waitUntil(() => 
  cy.get('.status-badge').then($el => $el.text() === 'Complete'),
  { timeout: 10000, interval: 500 }
);
```

---

## 🐛 Section 8: Debugging & Troubleshooting

### **Common Issues & Fixes**

#### **1. Flaky Tests (Element Not Found)**

**❌ Bad:**
```typescript
cy.get('.submit-button').click(); // Fails if button loads slowly
```

**✅ Good:**
```typescript
cy.get('.submit-button', { timeout: 10000 }).should('be.visible').click();
```

#### **2. Stale Element Reference**

**❌ Bad:**
```typescript
cy.get('.item').first().click(); // If DOM updates, this fails
```

**✅ Good:**
```typescript
cy.get('.item').first().click({ force: true }); // Or re-query
cy.get('.item').eq(0).click(); // Re-query each time
```

#### **3. Detached DOM**

**Problem:** Element exists when queried but is removed before action.

**Fix:**
```typescript
// Use { force: true } cautiously (bypasses visibility checks)
cy.get('.overlay-button').click({ force: true });

// Or wait for element to stabilize
cy.get('.loading-spinner').should('not.exist');
cy.get('.overlay-button').click();
```

### **Debugging in VS Code**

```json
// .vscode/launch.json
{
  "type": "node",
  "request": "launch",
  "name": "Debug Cypress",
  "runtimeExecutable": "${workspaceRoot}/node_modules/.bin/cypress",
  "args": ["open", "--e2e", "--browser", "chrome"],
  "console": "integratedTerminal"
}
```

### **Cypress Time-Travel Debugger**

```typescript
cy.get('.button').click(); // Click in test runner, see BEFORE/AFTER snapshots
cy.pause(); // Pause execution, inspect DOM
cy.debug(); // Drop into debugger
```

---

## 📊 Section 9: CI/CD Integration & Code Coverage

### **Overview: Complete Pipeline Strategy**

At Billtrust, our GitHub Actions pipeline runs:
1. ✅ **Unit Tests** (helper functions, utilities)
2. ✅ **Integration Tests** (API service wrappers)
3. ✅ **E2E Tests** (Cypress UI tests)
4. ✅ **Code Coverage** (Istanbul/NYC)
5. ✅ **Coverage Reports** (Codecov, SonarQube)

---

### **1. Code Coverage Setup**

#### **Install Coverage Plugin**

```bash
npm install --save-dev @cypress/code-coverage nyc istanbul-lib-coverage
```

#### **Configure Coverage in `cypress.config.ts`**

```typescript
import { defineConfig } from 'cypress';

export default defineConfig({
  e2e: {
    setupNodeEvents(on, config) {
      // Code coverage plugin
      require('@cypress/code-coverage/task')(on, config);
      
      return config;
    },
  },
});
```

#### **Add Coverage Support File**

```typescript
// cypress/support/e2e.ts
import '@cypress/code-coverage/support';
```

#### **Instrument Your Application Code**

```json
// package.json - add NYC config
{
  "nyc": {
    "report-dir": "coverage",
    "reporter": ["html", "json", "lcov", "text"],
    "exclude": [
      "cypress/**",
      "**/*.spec.ts",
      "**/*.cy.ts"
    ],
    "all": true
  }
}
```

---

### **2. Unit Testing Pattern**

**Test Helper Functions Independently**

```typescript
// cypress/support/helpers/dataHelper.spec.ts
import { dataHelper } from './dataHelper';

describe('Data Helper Utils', () => {
  describe('formatCurrency', () => {
    it('should format USD correctly', () => {
      expect(dataHelper.formatCurrency(1234.56, 'USD')).to.equal('$1,234.56');
    });

    it('should handle negative amounts', () => {
      expect(dataHelper.formatCurrency(-500, 'USD')).to.equal('-$500.00');
    });

    it('should round to 2 decimals', () => {
      expect(dataHelper.formatCurrency(10.999, 'USD')).to.equal('$11.00');
    });
  });

  describe('parseDate', () => {
    it('should parse MM/DD/YYYY format', () => {
      const result = dataHelper.parseDate('12/25/2024');
      expect(result.getFullYear()).to.equal(2024);
      expect(result.getMonth()).to.equal(11); // 0-indexed
      expect(result.getDate()).to.equal(25);
    });

    it('should handle invalid dates', () => {
      expect(() => dataHelper.parseDate('invalid')).to.throw();
    });
  });
});
```

**Run Unit Tests Separately**

```bash
# Run only unit tests
npx mocha 'cypress/support/**/*.spec.ts'

# Or use Vitest for faster unit testing
npx vitest run
```

---

### **3. Integration Testing Pattern**

**Test API Service Wrappers**

```typescript
// cypress/e2e/integration/testDataService.integration.cy.ts
import TestDataService from "@services/testDataService";

describe("Test Data Service Integration", () => {
  
  it("should create and retrieve customer", () => {
    let customerId: string;

    // Create customer
    cy.fixture('customer.minimal').then((customerData) => {
      TestDataService.createCustomer(customerData).then((response) => {
        expect(response.status).to.eq(201);
        expect(response.body.data).to.have.property('customerId');
        customerId = response.body.data.customerId;
      });
    });

    // Retrieve customer
    cy.then(() => {
      TestDataService.getCustomerById(customerId).then((response) => {
        expect(response.status).to.eq(200);
        expect(response.body.data.customerId).to.eq(customerId);
      });
    });

    // Cleanup
    cy.then(() => {
      TestDataService.deleteCustomer(customerId);
    });
  });

  it("should update customer settings", () => {
    cy.fixture('customer.minimal').then((customerData) => {
      TestDataService.createCustomer(customerData).then((createResponse) => {
        const customerId = createResponse.body.data.customerId;

        // Update settings
        const settingsToUpdate = { 'AutopayVersion': 'V3' };
        TestDataService.updateCustomerSettingsWithPath(customerId, settingsToUpdate)
          .then((updateResponse) => {
            expect(updateResponse.status).to.eq(200);
            
            // Verify update
            return TestDataService.getCustomerSettingsByCustomerId(customerId);
          })
          .then((getResponse) => {
            const autopayVersionSetting = getResponse.body.data.settings
              .find(s => s.settingName === 'AutopayVersion');
            expect(autopayVersionSetting.settingValue).to.eq('V3');
          });

        // Cleanup
        cy.then(() => TestDataService.deleteCustomer(customerId));
      });
    });
  });
});
```

---

### **4. Complete GitHub Actions Workflow**

```yaml
name: Cypress E2E Tests with Coverage

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  # Job 1: Unit Tests
  unit-tests:
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: 22
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run unit tests
        run: npm run test:unit

      - name: Upload unit test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: unit-test-results
          path: test-results/

  # Job 2: Integration Tests
  integration-tests:
    runs-on: ubuntu-22.04
    env:
      TEST_ENVIRONMENT: dev
      TESTDATAAPI_API_KEY: ${{ secrets.TESTDATAAPI_API_KEY }}
      TESTDATAAPI_AUTH_TOKEN: ${{ secrets.TESTDATAAPI_AUTH_TOKEN }}
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: 22
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run integration tests
        run: npm run test:integration

      - name: Upload integration test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: integration-test-results
          path: cypress/results/

  # Job 3: E2E Tests with Coverage
  e2e-tests:
    runs-on: ubuntu-22.04
    strategy:
      fail-fast: false
      matrix:
        containers: [1, 2, 3, 4] # Parallel execution
    env:
      TEST_ENVIRONMENT: dev
      TESTDATAAPI_API_KEY: ${{ secrets.TESTDATAAPI_API_KEY }}
      TESTDATAAPI_AUTH_TOKEN: ${{ secrets.TESTDATAAPI_AUTH_TOKEN }}
      BT_AUTOMATION_USER_USERNAME: ${{ secrets.BT_AUTOMATION_USER_USERNAME }}
      BT_AUTOMATION_USER_PASSWORD: ${{ secrets.BT_AUTOMATION_USER_PASSWORD }}
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: 22
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run Cypress E2E tests
        uses: cypress-io/github-action@v5
        with:
          record: true
          parallel: true
          group: 'E2E Tests - Chrome'
          browser: chrome
          start: npm run start:ci # Start app server if needed
          wait-on: 'http://localhost:3000'
          config-file: cypress.config.ts
        env:
          CYPRESS_RECORD_KEY: ${{ secrets.CYPRESS_RECORD_KEY }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Generate coverage report
        run: npx nyc report --reporter=lcov

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
          flags: e2e-tests
          name: cypress-coverage

      - name: Upload Cypress screenshots
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: cypress-screenshots-${{ matrix.containers }}
          path: cypress/screenshots/

      - name: Upload Cypress videos
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: cypress-videos-${{ matrix.containers }}
          path: cypress/videos/

      - name: Upload Allure results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: allure-results-${{ matrix.containers }}
          path: cypress/allure-results/

  # Job 4: Merge Coverage Reports
  coverage-report:
    needs: [unit-tests, integration-tests, e2e-tests]
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Download all coverage artifacts
        uses: actions/download-artifact@v3

      - name: Merge coverage reports
        run: |
          npx nyc merge coverage-* .nyc_output/merged-coverage.json
          npx nyc report --reporter=html --reporter=text --reporter=lcov

      - name: Upload merged coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
          flags: merged
          name: merged-coverage

      - name: Comment PR with coverage
        if: github.event_name == 'pull_request'
        uses: romeovs/lcov-reporter-action@v0.3.1
        with:
          lcov-file: ./coverage/lcov.info
          github-token: ${{ secrets.GITHUB_TOKEN }}

  # Job 5: Allure Report Generation
  allure-report:
    needs: e2e-tests
    runs-on: ubuntu-22.04
    if: always()
    steps:
      - name: Download Allure results
        uses: actions/download-artifact@v3
        with:
          path: allure-results

      - name: Get Allure history
        uses: actions/checkout@v3
        if: always()
        continue-on-error: true
        with:
          ref: gh-pages
          path: gh-pages

      - name: Allure Report
        uses: simple-elf/allure-report-action@master
        if: always()
        with:
          allure_results: allure-results
          allure_history: allure-history
          keep_reports: 20

      - name: Deploy Allure report to GitHub Pages
        if: always()
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_branch: gh-pages
          publish_dir: allure-history

  # Job 6: SonarQube Analysis
  sonarqube:
    needs: coverage-report
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Download coverage
        uses: actions/download-artifact@v3

      - name: SonarQube Scan
        uses: sonarsource/sonarqube-scan-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
        with:
          args: >
            -Dsonar.projectKey=inv-invoicing-ui-cc-automation
            -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
            -Dsonar.coverage.exclusions=**/*.spec.ts,**/*.cy.ts
```

---

### **5. Package.json Scripts**

```json
{
  "scripts": {
    "test:unit": "vitest run --coverage",
    "test:integration": "cypress run --spec 'cypress/e2e/integration/**/*.cy.ts'",
    "test:e2e": "cypress run --spec 'cypress/e2e/tests/**/*.cy.ts'",
    "test:all": "npm run test:unit && npm run test:integration && npm run test:e2e",
    "coverage:merge": "nyc merge coverage .nyc_output/out.json",
    "coverage:report": "nyc report --reporter=html --reporter=text",
    "allure:generate": "allure generate cypress/allure-results --clean -o allure-report",
    "allure:open": "allure open allure-report",
    "cypress:open": "cypress open",
    "cypress:run": "cypress run",
    "cypress:run:chrome": "cypress run --browser chrome",
    "cypress:run:tags": "cypress run --env grepTags=",
    "start:ci": "NODE_ENV=test npm run start"
  }
}
```

---

### **6. Coverage Badges**

#### **Add Badge to README.md**

```markdown
# Invoicing UI CC Automation

![Coverage](https://codecov.io/gh/BilltrustGH/inv-invoicing-ui-cc-automation/branch/main/graph/badge.svg)
![Tests](https://github.com/BilltrustGH/inv-invoicing-ui-cc-automation/workflows/Cypress%20E2E%20Tests/badge.svg)
![Allure Report](https://img.shields.io/badge/Allure-Report-blue)

## Coverage by Type

| Type | Coverage |
|---|---|
| **Unit Tests** | 85% |
| **Integration Tests** | 72% |
| **E2E Tests** | 65% |
| **Overall** | 74% |
```

---

### **7. Local Coverage Commands**

```bash
# Run E2E tests with coverage
npx cypress run --env coverage=true

# Generate HTML coverage report
npx nyc report --reporter=html

# Open coverage report in browser
open coverage/index.html

# Check coverage thresholds
npx nyc check-coverage --lines 80 --functions 80 --branches 75

# Generate coverage for specific spec
npx cypress run --spec 'cypress/e2e/tests/payment/payment.cy.ts' --env coverage=true
```

---

### **8. Coverage Configuration - nyc.config.js**

```javascript
module.exports = {
  all: true,
  include: [
    'cypress/pages/**/*.ts',
    'cypress/support/helpers/**/*.ts',
    'cypress/support/services/**/*.ts'
  ],
  exclude: [
    '**/*.spec.ts',
    '**/*.cy.ts',
    'cypress/plugins/**',
    'cypress/fixtures/**'
  ],
  reporter: ['html', 'json', 'lcov', 'text', 'text-summary'],
  'report-dir': 'coverage',
  checkCoverage: true,
  lines: 80,
  functions: 80,
  branches: 75,
  statements: 80
};
```

---

### **9. Interview Questions: Coverage & CI/CD**

#### **Q: How do you measure code coverage in Cypress?**

**Answer:**
"We use `@cypress/code-coverage` plugin with Istanbul/NYC:
1. **Instrument code** at build time
2. **Collect coverage** during Cypress test execution
3. **Generate reports** in multiple formats (HTML, LCOV, JSON)
4. **Upload to Codecov** for trending
5. **Enforce thresholds** via nyc check-coverage (80% minimum)"

---

#### **Q: How do you handle flaky tests in CI?**

**Answer:**
"Multi-layered approach:
1. **Retries:** Configure 2 retries in CI (`retries: { runMode: 2 }`)
2. **Proper waits:** Use `.should()` assertions instead of hard waits
3. **Network stubbing:** Use `cy.intercept()` to control timing
4. **Quarantine:** Tag flaky tests with `@flaky`, run separately
5. **Dashboard:** Use Cypress Dashboard to track flakiness over time"

**Code:**
```typescript
// cypress.config.ts
export default defineConfig({
  retries: {
    runMode: 2,    // CI gets 2 retries
    openMode: 0    // Local dev gets 0 retries (fail fast)
  }
});
```

---

#### **Q: How do you parallelize Cypress tests in GitHub Actions?**

**Answer:**
"Use matrix strategy with Cypress Dashboard:
1. **Matrix containers:** Split tests across 4 containers
2. **Load balancing:** Cypress Dashboard distributes specs automatically
3. **Record results:** `record: true` sends results to Dashboard
4. **Merge coverage:** Combine coverage from all containers in final job"

---

### **10. Best Practices**

✅ **DO:**
- Run unit tests first (fastest feedback)
- Run integration tests before E2E (cheaper to run)
- Collect coverage from ALL test types (unit + integration + E2E)
- Cache npm dependencies (`cache: 'npm'`)
- Use `fail-fast: false` to see all failures
- Upload artifacts on failure (screenshots, videos)
- Set coverage thresholds (80% lines, 75% branches)

❌ **DON'T:**
- Run E2E tests on every commit (too slow, use tags)
- Ignore flaky tests (fix or quarantine them)
- Merge without coverage check
- Skip integration tests (API layer is critical)
- Run all tests in one job (parallelization is key)

---

## 📝 Section 10: Writing Tests - Real Examples

### **Example 1: Admin AP Network Test**

```typescript
import { adminPage } from "@pages/admin";
import data from "@pages/data";

describe("AP Network Settings", { tags: "@admin" }, () => {

  before(function() {
    cy.getCustomerCredentials("CP"); // Corporate Primary
  });

  beforeEach(function() {
    cy.signin(this.customerName);
  });

  it("should edit AP Network settings and verify validation [BQ-276]", function() {
    // Navigate to Admin
    adminPage.clickAdminButton();

    // Navigate to AP Network
    adminPage.clickOnApNetwork();
    adminPage.verifyLineOfBusinessName(data.lineOfBusiness);

    // Edit settings
    adminPage.clickOnEditApNetworkSettings();
    adminPage.clickOnRequestEnrollment();

    // Verify validation pop-up
    adminPage.verifyPendingValidation();
    adminPage.verifyPopUpContent(data.pendingValidation);
    adminPage.clickOnOkButton();

    // Verify status updated
    adminPage.verifyPendingValidationStatus(data.status);

    // Sign out
    adminPage.clickSignOutButton();
  });
});
```

### **Example 2: Payment Flow with API Setup**

```typescript
import { paymentPage } from "@pages/payment";
import TestDataService from "@services/testDataService";

describe("CC Payment Flow", { tags: "@payment" }, () => {
  let customerId: string;

  before(() => {
    // Provision customer with CC risk via API
    cy.fixture('customer.payment').then((customerData) => {
      TestDataService.createCustomer(customerData).then((response) => {
        customerId = response.body.data.customerId;

        // Create CC risk profile
        cy.createCCRisk(customerId, 'ccRisk.fixture');
      });
    });
  });

  it("should process CC payment successfully", function() {
    cy.signin(customerId);

    // Navigate to payment
    paymentPage.navigateToPaymentPage();
    paymentPage.selectDocument(0); // First document

    // Enter payment details
    paymentPage.enterPaymentAmount('100.00');
    paymentPage.selectPaymentMethod('Credit Card');
    paymentPage.enterCardDetails({
      cardNumber: '4111111111111111',
      expiry: '12/25',
      cvv: '123'
    });

    // Submit payment
    cy.intercept('POST', '/api/payments').as('paymentSubmit');
    paymentPage.clickSubmitPayment();
    cy.wait('@paymentSubmit').its('response.statusCode').should('eq', 200);

    // Verify success
    paymentPage.verifySuccessMessage('Payment processed successfully');
  });
});
```

---

## 🎯 Section 11: Best Practices

### **1. Selector Priority**

```typescript
// ✅ BEST: data-test attributes (semantic, stable)
cy.get('[data-test="submit-button"]');

// ✅ GOOD: data-msgid (Billtrust i18n)
cy.get('[data-msgid="payment.submit"]');

// ⚠️ OK: ID (if stable)
cy.get('#submit-btn');

// ❌ AVOID: Classes (change with styling)
cy.get('.btn.btn-primary.submit');

// ❌ NEVER: Text content (breaks with i18n)
cy.contains('Submit'); // ❌ Breaks in Spanish!
```

### **2. Test Independence**

```typescript
// ❌ BAD: Tests depend on each other
it('creates user', () => {
  cy.createUser('test@example.com'); // State leaks to next test
});

it('logs in as user', () => {
  cy.login('test@example.com'); // ❌ Depends on previous test!
});

// ✅ GOOD: Each test is isolated
describe("User Flow", () => {
  beforeEach(() => {
    cy.createUser('test@example.com'); // Fresh state every test
  });

  it('logs in as user', () => {
    cy.login('test@example.com'); // ✅ Independent
  });
});
```

### **3. Avoid Hardcoded Waits**

```typescript
// ❌ BAD
cy.wait(5000); // Flaky! What if it loads in 2s? Or 6s?

// ✅ GOOD
cy.get('.loading-spinner').should('not.exist');
cy.get('.data-loaded').should('be.visible');
```

### **4. Use Aliases for Reusability**

```typescript
// Store frequently accessed elements
cy.get('[data-test="user-profile"]').as('profile');
cy.get('@profile').find('.name').should('contain', 'John Doe');
cy.get('@profile').find('.email').should('contain', 'john@example.com');
```

### **5. Clean Test Data**

```typescript
afterEach(() => {
  // Clean up created test data
  cy.deleteTestCustomer(customerId);
});

// Or use API to clean up
after(() => {
  TestDataService.deleteCustomer(customerId);
});
```

---

## 🎓 Section 12: Interview Prep

### **Top 10 Cypress Interview Questions (12+ Years)**

#### **1. How do you handle flaky tests in Cypress?**

**Answer:**
1. **Root cause analysis:** Check screenshots/videos from CI
2. **Proper waits:** Use `.should()` assertions instead of `cy.wait(5000)`
3. **Network stubbing:** Use `cy.intercept()` to control API responses
4. **Retry logic:** Configure retries in `cypress.config.ts`
5. **Idempotent tests:** Ensure tests can run multiple times

**Code example:**
```typescript
// ❌ Flaky
cy.get('.modal').click();

// ✅ Stable
cy.get('.modal', { timeout: 10000 })
  .should('be.visible')
  .and('not.be.disabled')
  .click();
```

---

#### **2. Explain your Page Object Model implementation**

**Answer:**
"At Billtrust, we use a class-based POM pattern with centralized selectors and action methods. Each page object exports a singleton instance for reuse across tests. Selectors are functions (not static strings) to ensure fresh queries every time."

**Example:**
```typescript
export class PaymentPage {
  elements = {
    amountInput: () => cy.get('[data-test="payment-amount"]'),
    submitButton: () => cy.get('[data-test="submit-payment"]')
  };

  enterAmount(amount: string) {
    this.elements.amountInput().clear().type(amount);
  }

  submit() {
    this.elements.submitButton().click();
  }
}

export const paymentPage = new PaymentPage();
```

---

#### **3. How do you manage test data in Cypress?**

**Answer:**
"We use a hybrid approach:
1. **API-driven provisioning** via Test Data Service for dynamic customers
2. **Fixtures** for static reference data (settings, templates)
3. **Custom commands** to abstract data setup complexity
4. **Cleanup hooks** to delete test data after tests"

**Example:**
```typescript
before(() => {
  TestDataService.createCustomer(customerData).then((response) => {
    customerId = response.body.data.customerId;
  });
});

after(() => {
  TestDataService.deleteCustomer(customerId);
});
```

---

#### **4. How do you handle authentication in Cypress?**

**Answer:**
"We preserve authentication state using Cypress session management:
1. Custom `cy.signin()` command
2. Store session via `cy.session()` to avoid re-login every test
3. Use `cy.getCookie()` to verify authentication
4. For API tests, use auth tokens directly"

**Example:**
```typescript
Cypress.Commands.add("signin", (customerName: string) => {
  cy.session(customerName, () => {
    cy.visit('/login');
    cy.get('[name="username"]').type(customerName);
    cy.get('[name="password"]').type(Cypress.env('password'));
    cy.get('[type="submit"]').click();
    cy.url().should('include', '/dashboard');
  });
});
```

---

#### **5. What's your approach to debugging CI failures?**

**Answer:**
1. **Artifacts:** Check screenshots/videos from CI
2. **Logs:** Use `cy.log()` and Cypress terminal reporter
3. **Network tab:** Check `cy.intercept()` logs for API failures
4. **Reproduce locally:** Run same test with same environment vars
5. **Allure reports:** Detailed step-by-step breakdown

**Command:**
```bash
# Run same test locally as CI
TEST_ENVIRONMENT=dev npm run cypress:run -- --spec cypress/e2e/tests/payment/payment.cy.ts
```

---

#### **6. How do you structure Cypress tests for maintainability?**

**Answer:**
1. **Page Objects:** Encapsulate selectors and actions
2. **Custom Commands:** Reusable actions (signin, createCustomer)
3. **Service Wrappers:** Abstract API calls (Test Data Service)
4. **Helpers:** Utility functions (date parsing, validation)
5. **Clear naming:** Test names describe WHAT is tested, not HOW

---

#### **7. How do you test file uploads/downloads in Cypress?**

**Answer:**

**Upload:**
```typescript
cy.get('input[type="file"]').selectFile('cypress/fixtures/roster.csv');
```

**Download:**
```typescript
cy.get('[data-test="download-report"]').click();
cy.readFile('cypress/downloads/report.csv').should('exist');
```

---

#### **8. What's your strategy for testing responsive designs?**

**Answer:**
```typescript
describe("Responsive Layout", () => {
  const viewports = [
    { device: 'mobile', width: 375, height: 667 },
    { device: 'tablet', width: 768, height: 1024 },
    { device: 'desktop', width: 1920, height: 1080 }
  ];

  viewports.forEach(({ device, width, height }) => {
    it(`renders correctly on ${device}`, () => {
      cy.viewport(width, height);
      cy.visit('/dashboard');
      cy.get('[data-test="sidebar"]').should('be.visible');
    });
  });
});
```

---

#### **9. How do you handle iframes in Cypress?**

**Answer:**
```typescript
cy.get('iframe[id="payment-frame"]')
  .its('0.contentDocument.body')
  .should('not.be.empty')
  .then(cy.wrap)
  .find('[data-test="card-number"]')
  .type('4111111111111111');
```

---

#### **10. Explain Cypress' automatic retry mechanism**

**Answer:**
"Cypress automatically retries queries and assertions until they pass or timeout (default 4s). Only the LAST command in a chain is retried."

**Example:**
```typescript
// ✅ RETRIES: .should() is last command
cy.get('.button').should('be.visible');

// ❌ DOES NOT RETRY: .click() is last
cy.get('.button').click(); // Fails immediately if not found
```

---

## 🚀 Section 13: Practical Exercise

### **Exercise: Write a Complete E2E Test**

**Scenario:** Test the "Enroll Payment" flow in Client Connect

**Requirements:**
1. Create a customer via Test Data API
2. Sign in as the customer
3. Navigate to Enroll → Payment
4. Enter payment details
5. Submit enrollment
6. Verify success message
7. Clean up test data

**Solution:**

```typescript
import { adminPage } from "@pages/admin";
import { enrollPage } from "@pages/enroll";
import TestDataService from "@services/testDataService";

describe("Enroll Payment Flow", { tags: ["@enroll", "@payment"] }, () => {
  let customerId: string;

  before(() => {
    // Provision customer
    cy.fixture('customer.enroll').then((customerData) => {
      TestDataService.createCustomer(customerData).then((response) => {
        customerId = response.body.data.customerId;
        cy.wrap(customerId).as('customerId');
      });
    });
  });

  beforeEach(function() {
    // Sign in
    cy.signin(this.customerId);
  });

  it("should enroll payment method successfully [BQ-999]", function() {
    // Navigate to Enroll
    adminPage.clickAdminButton();
    enrollPage.clickEnrollTab();

    // Enter payment details
    enrollPage.selectAccount('Account #1');
    enrollPage.selectPaymentMethod('Bank Account');
    enrollPage.enterBankDetails({
      accountNumber: '123456789',
      routingNumber: '021000021',
      accountType: 'Checking'
    });

    // Submit
    cy.intercept('POST', '/api/enroll/payment').as('enrollPayment');
    enrollPage.clickSubmitButton();
    cy.wait('@enrollPayment').its('response.statusCode').should('eq', 201);

    // Verify
    enrollPage.verifySuccessMessage('Payment method enrolled successfully');
  });

  after(function() {
    // Clean up
    TestDataService.deleteCustomer(this.customerId);
  });
});
```

---

## 📚 Section 14: Additional Resources

### **Official Docs**
- [Cypress Docs](https://docs.cypress.io)
- [Cypress Best Practices](https://docs.cypress.io/guides/references/best-practices)
- [Cypress TypeScript](https://docs.cypress.io/guides/tooling/typescript-support)

### **Billtrust Internal**
- [Cypress Training Videos](https://billtrust0-my.sharepoint.com/:l:/r/personal/jrealini_billtrust_com/Lists/EIC%20Cypress%20Demo)
- Automation Repos:
  - `inv-invoicing-ui-cc-automation` (Client Connect)
  - `inv-invoicing-ui-eic-automation` (eInvoice Connect)
  - `inv-bnp-csr-automation` (CSR - Protractor)

### **Cheat Sheet Commands**

```bash
# Run all tests
npm run cypress:open

# Run headless
npm run cypress:run

# Run with tags
npx cypress run --env grepTags="@admin"

# Run specific spec
npx cypress run --spec "cypress/e2e/tests/admin/apNetwork.cy.ts"

# Generate Allure report
npm run allure:generate
npm run allure:open

# Debug mode
npx cypress open --browser chrome
```

---

## ✅ Checklist: Am I Ready?

**Fundamentals:**
- [ ] Can explain Cypress vs Selenium differences
- [ ] Can write Page Objects with TypeScript
- [ ] Understand async/await and Cypress command chaining
- [ ] Know how to use `cy.intercept()` for API testing
- [ ] Can write custom commands
- [ ] Understand Test Data API integration
- [ ] Can debug flaky tests
- [ ] Know tag-based test execution
- [ ] Can handle authentication with `cy.session()`

**CI/CD & Coverage:**
- [ ] Understand GitHub Actions workflows with matrix strategy
- [ ] Can set up code coverage with `@cypress/code-coverage`
- [ ] Know how to write unit tests for helpers/utilities
- [ ] Can write integration tests for API service wrappers
- [ ] Understand coverage thresholds and enforcement
- [ ] Can merge coverage reports from parallel runs
- [ ] Know how to debug CI failures (artifacts, logs, screenshots)
- [ ] Understand Allure report generation and deployment
- [ ] Can configure SonarQube integration for quality gates

---

## 🎯 Next Steps

1. **Clone a repo:** `inv-invoicing-ui-cc-automation`
2. **Run existing tests:** `npm run cypress:open`
3. **Pick a Jira ticket:** Write automation for a recent fix
4. **Code review:** Review automation PRs with the checklist mindset
5. **Practice interview questions:** Explain your approach out loud

**Goal:** Write 3-5 automation specs covering edge cases for your next feature ticket.

---

**Last Updated:** November 17, 2026  
**Next Module:** System Design & Architecture (Payment Gateway End-to-End Flow)
