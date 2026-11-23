# ReactJS Advanced Interview Questions

> **80+ Advanced ReactJS Questions for Senior/Staff Engineer Roles**

---

## Table of Contents

1. [React 18+ Features](#react-18-features)
2. [Custom Hooks Patterns](#custom-hooks)
3. [Performance Optimization](#performance-optimization)
4. [Context API vs Redux](#context-vs-redux)
5. [Server Components (Next.js 13+)](#server-components)
6. [State Management Patterns](#state-management)
7. [Testing (React Testing Library)](#testing)
8. [TypeScript with React](#typescript)
9. [Real-World Scenarios](#real-world)
10. [Architecture & Design](#architecture)

---

# React 18+ Features

## Q1: What's new in React 18? Explain Concurrent Rendering.

**Answer:**

**React 18 Key Features:**

1. **Concurrent Rendering** (default for `createRoot`)
2. **Automatic Batching** (all state updates batched)
3. **Transitions** (mark updates as non-urgent)
4. **Suspense for SSR**

**Concurrent Rendering:**

Before React 18, rendering was **blocking** — once started, React couldn't interrupt until done. With concurrent rendering, React can:
- Pause/resume rendering
- Prioritize urgent updates (user input) over non-urgent (network data)
- Render multiple versions of UI simultaneously

**Example:**

```jsx
// React 17 (blocking)
function App() {
  const [input, setInput] = useState('');
  const [results, setResults] = useState([]);

  const handleChange = (e) => {
    setInput(e.target.value);
    setResults(expensiveFilter(allData, e.target.value));  // Blocks UI
  };

  return <input value={input} onChange={handleChange} />;
}

// React 18 (concurrent)
import { startTransition } from 'react';

function App() {
  const [input, setInput] = useState('');
  const [results, setResults] = useState([]);

  const handleChange = (e) => {
    setInput(e.target.value);  // High priority (user input)
    
    startTransition(() => {
      setResults(expensiveFilter(allData, e.target.value));  // Low priority
    });
    // User can keep typing while filter runs in background
  };

  return <input value={input} onChange={handleChange} />;
}
```

**Billtrust Example:**
"Used Transitions in invoice search: user types → input updates immediately (high priority), invoice list filters in background (low priority). Before: typing felt laggy with 10k invoices. After: smooth input, results update when ready."

---

## Q2: Explain `useTransition` vs `useDeferredValue`. When to use each?

**Answer:**

Both allow non-urgent updates during concurrent rendering, but differ in control.

**`useTransition`**: You control WHEN to defer
```jsx
import { useTransition, useState } from 'react';

function SearchPage() {
  const [input, setInput] = useState('');
  const [results, setResults] = useState([]);
  const [isPending, startTransition] = useTransition();

  const handleChange = (e) => {
    const value = e.target.value;
    setInput(value);  // High priority
    
    startTransition(() => {
      // This state update is low priority
      setResults(expensiveSearch(value));
    });
  };

  return (
    <div>
      <input value={input} onChange={handleChange} />
      {isPending && <Spinner />}
      <Results data={results} />
    </div>
  );
}
```

**`useDeferredValue`**: React controls when to defer
```jsx
import { useDeferredValue, useState, useMemo } from 'react';

function SearchPage() {
  const [input, setInput] = useState('');
  const deferredInput = useDeferredValue(input);  // React defers this

  const results = useMemo(() => {
    return expensiveSearch(deferredInput);
  }, [deferredInput]);

  return (
    <div>
      <input 
        value={input} 
        onChange={(e) => setInput(e.target.value)} 
      />
      <Results data={results} />
    </div>
  );
}
```

**When to use:**
- **`useTransition`**: You want explicit control + loading state
- **`useDeferredValue`**: You want to defer a VALUE (simpler, less control)

---

## Q3: What is Suspense in React 18? How does it work for data fetching?

**Answer:**

**Suspense** lets components "wait" for something (data, code splitting) before rendering.

**Code Splitting:**
```jsx
import { lazy, Suspense } from 'react';

const HeavyComponent = lazy(() => import('./HeavyComponent'));

function App() {
  return (
    <Suspense fallback={<Spinner />}>
      <HeavyComponent />
    </Suspense>
  );
}
```

**Data Fetching (React 18 + frameworks like Next.js):**
```jsx
// Server Component (Next.js 13+)
async function InvoiceList() {
  const invoices = await fetchInvoices();  // Async/await in component!
  
  return (
    <ul>
      {invoices.map(inv => <li key={inv.id}>{inv.number}</li>)}
    </ul>
  );
}

// In parent
function Dashboard() {
  return (
    <Suspense fallback={<Spinner />}>
      <InvoiceList />
    </Suspense>
  );
}
```

**How it works:**
1. Component starts rendering
2. Throws a Promise (special React convention)
3. React catches Promise, shows fallback
4. When Promise resolves, React retries rendering

**Billtrust Example:**
"Used Suspense for lazy-loading invoice PDF viewer (5 MB component). Page loads fast, PDF viewer only loads when user clicks 'View PDF'."

---

# Custom Hooks Patterns

## Q4: What are Custom Hooks? Give 3 real-world examples.

**Answer:**

Custom Hooks = **reusable stateful logic** (not UI).

**Example 1: API Fetching**
```jsx
function useFetch(url) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    setLoading(true);
    fetch(url)
      .then(res => res.json())
      .then(setData)
      .catch(setError)
      .finally(() => setLoading(false));
  }, [url]);

  return { data, loading, error };
}

// Usage
function InvoiceList() {
  const { data, loading, error } = useFetch('/api/invoices');

  if (loading) return <Spinner />;
  if (error) return <Error message={error.message} />;
  return <ul>{data.map(inv => <li key={inv.id}>{inv.number}</li>)}</ul>;
}
```

**Example 2: Local Storage Sync**
```jsx
function useLocalStorage(key, initialValue) {
  const [value, setValue] = useState(() => {
    const saved = localStorage.getItem(key);
    return saved ? JSON.parse(saved) : initialValue;
  });

  useEffect(() => {
    localStorage.setItem(key, JSON.stringify(value));
  }, [key, value]);

  return [value, setValue];
}

// Usage
function Settings() {
  const [theme, setTheme] = useLocalStorage('theme', 'light');
  
  return (
    <select value={theme} onChange={(e) => setTheme(e.target.value)}>
      <option value="light">Light</option>
      <option value="dark">Dark</option>
    </select>
  );
}
```

**Example 3: Debounced Search**
```jsx
function useDebounce(value, delay) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debounced;
}

// Usage
function SearchPage() {
  const [query, setQuery] = useState('');
  const debouncedQuery = useDebounce(query, 500);  // Wait 500ms

  useEffect(() => {
    if (debouncedQuery) {
      fetchResults(debouncedQuery);  // Only called after typing stops
    }
  }, [debouncedQuery]);

  return <input value={query} onChange={(e) => setQuery(e.target.value)} />;
}
```

**Billtrust Example:**
"Custom `useInvoiceForm` hook for invoice creation forms — shared validation, submission, error handling across 3 invoice types (standard, recurring, credit memo)."

---

# Performance Optimization

## Q5: Explain `React.memo`, `useMemo`, and `useCallback`. When to use each?

**Answer:**

**1. React.memo (memoize component)**
```jsx
// BAD: Child re-renders every time Parent renders
function Child({ name }) {
  console.log('Child rendered');
  return <div>{name}</div>;
}

function Parent() {
  const [count, setCount] = useState(0);
  return (
    <div>
      <button onClick={() => setCount(count + 1)}>Count: {count}</button>
      <Child name="John" />  {/* Re-renders even though name unchanged */}
    </div>
  );
}

// GOOD: Child only re-renders if name changes
const Child = React.memo(function Child({ name }) {
  console.log('Child rendered');
  return <div>{name}</div>;
});
```

**2. useMemo (memoize expensive calculation)**
```jsx
// BAD: Expensive calculation on every render
function InvoiceList({ invoices }) {
  const total = invoices.reduce((sum, inv) => sum + inv.amount, 0);
  return <div>Total: {total}</div>;
}

// GOOD: Only recalculate when invoices change
function InvoiceList({ invoices }) {
  const total = useMemo(() => {
    return invoices.reduce((sum, inv) => sum + inv.amount, 0);
  }, [invoices]);
  
  return <div>Total: {total}</div>;
}
```

**3. useCallback (memoize function)**
```jsx
// BAD: Child re-renders because onClick is new function every time
function Parent() {
  const [count, setCount] = useState(0);
  
  const handleClick = () => {
    console.log('Clicked');
  };
  
  return <Child onClick={handleClick} />;  // New function every render
}

// GOOD: Same function reference
function Parent() {
  const [count, setCount] = useState(0);
  
  const handleClick = useCallback(() => {
    console.log('Clicked');
  }, []);  // Function never changes
  
  return <Child onClick={handleClick} />;
}
```

**When to use:**
- **React.memo**: Expensive child components that render often
- **useMemo**: Expensive calculations (sorting, filtering 1000+ items)
- **useCallback**: Passing callbacks to memoized children

**Billtrust Example:**
"Invoice list (10k invoices) was re-sorting on every parent render. Added `useMemo` → sort only when invoices change. Rendering dropped from 2 seconds to instant."

---

## Q6: What causes unnecessary re-renders in React? How do you debug them?

**Answer:**

**Causes:**
1. Parent re-renders → all children re-render
2. New object/array reference in state
3. Inline functions in JSX
4. Context value changes

**Debugging:**

**1. React DevTools Profiler:**
```jsx
// 1. Open React DevTools → Profiler tab
// 2. Click "Record"
// 3. Interact with app
// 4. Stop recording → see which components re-rendered + why
```

**2. Use `why-did-you-render` library:**
```jsx
import whyDidYouRender from '@welldone-software/why-did-you-render';

whyDidYouRender(React, {
  trackAllPureComponents: true,
});

// Console logs WHY each component re-rendered
```

**3. Manual logging:**
```jsx
function MyComponent({ prop1, prop2 }) {
  console.log('MyComponent rendered', { prop1, prop2 });
  return <div>...</div>;
}
```

**Common Fix:**
```jsx
// BAD: New array every render
<Child items={[1, 2, 3]} />

// GOOD: Stable reference
const items = [1, 2, 3];
<Child items={items} />

// BAD: New function every render
<Child onClick={() => handleClick()} />

// GOOD: Stable function
const onClick = useCallback(handleClick, []);
<Child onClick={onClick} />
```

**Billtrust Example:**
"Invoice dashboard re-rendered 10+ times on every keystroke. Used Profiler → found parent passing new `{...}` object to child every render. Fixed with `useMemo` → 1 render per keystroke."

---

# Context API vs Redux

## Q7: When would you use Context API vs Redux? Give pros/cons of each.

**Answer:**

**Context API:**

**When to use:**
- Simple global state (theme, auth, language)
- Small to medium apps (<10 components)
- Infrequent updates

**Pros:**
- Built into React (no library)
- Simple setup
- Less boilerplate

**Cons:**
- Performance issues with frequent updates
- No middleware (logging, caching)
- No DevTools

**Example:**
```jsx
const AuthContext = createContext();

function AuthProvider({ children }) {
  const [user, setUser] = useState(null);

  const login = (username, password) => {
    // API call
    setUser({ username });
  };

  return (
    <AuthContext.Provider value={{ user, login }}>
      {children}
    </AuthContext.Provider>
  );
}

// Usage
function Profile() {
  const { user, login } = useContext(AuthContext);
  return <div>{user?.username}</div>;
}
```

**Redux:**

**When to use:**
- Complex state logic
- Large apps (10+ components sharing state)
- Frequent updates
- Need middleware (API calls, logging)
- Need time-travel debugging

**Pros:**
- Centralized state
- Middleware support
- Redux DevTools (time-travel debugging)
- Predictable state updates

**Cons:**
- More boilerplate
- Learning curve
- Extra library

**Example:**
```jsx
// Store
const store = configureStore({
  reducer: {
    invoices: invoicesReducer,
    auth: authReducer,
  },
});

// Slice
const invoicesSlice = createSlice({
  name: 'invoices',
  initialState: { list: [], loading: false },
  reducers: {
    setInvoices: (state, action) => {
      state.list = action.payload;
    },
  },
});

// Component
function InvoiceList() {
  const dispatch = useDispatch();
  const invoices = useSelector(state => state.invoices.list);

  useEffect(() => {
    dispatch(fetchInvoices());
  }, []);

  return <ul>{invoices.map(inv => <li key={inv.id}>{inv.number}</li>)}</ul>;
}
```

**Billtrust Decision:**
"Use Context for theme + auth (infrequent updates). Use Redux for invoice state (10+ components, frequent updates, need middleware for API calls)."

---

# Server Components (Next.js 13+)

## Q8: What are React Server Components? How do they differ from Client Components?

**Answer:**

**Server Components** (React 18 + Next.js 13+):
- Render on SERVER only
- NO client-side JavaScript
- Can access database/filesystem directly
- Cannot use hooks (`useState`, `useEffect`)
- Cannot use browser APIs

**Client Components**:
- Render on SERVER (SSR) + CLIENT (hydration)
- Interactive (hooks, event handlers)
- Sent to browser as JavaScript

**Example:**

```jsx
// app/invoices/page.tsx (Server Component)
async function InvoicePage() {
  // Direct database access on server!
  const invoices = await db.invoice.findMany();

  return (
    <div>
      <h1>Invoices</h1>
      {invoices.map(inv => (
        <InvoiceCard key={inv.id} invoice={inv} />
      ))}
    </div>
  );
}

// components/InvoiceCard.tsx (Server Component)
function InvoiceCard({ invoice }) {
  return <div>{invoice.number}</div>;
}

// components/SearchBar.tsx (Client Component)
'use client';  // Mark as client component

import { useState } from 'react';

function SearchBar() {
  const [query, setQuery] = useState('');

  return (
    <input 
      value={query} 
      onChange={(e) => setQuery(e.target.value)} 
    />
  );
}
```

**When to use Server Components:**
- Fetching data
- Accessing backend resources
- Sensitive info (API keys)
- Large dependencies (Markdown parser)

**When to use Client Components:**
- Interactivity (forms, buttons)
- Browser APIs (localStorage, geolocation)
- Hooks (`useState`, `useEffect`)

**Billtrust Example:**
"Invoice list = Server Component (fetches from DB, no JavaScript sent to browser). Search bar = Client Component (interactive). Page loads 50% faster (less JavaScript)."

---

# State Management Patterns

## Q9: Explain the `useReducer` pattern. When is it better than `useState`?

**Answer:**

**`useReducer`**: For complex state logic with multiple sub-values or when next state depends on previous.

**When to use:**
- State has multiple fields that change together
- Next state depends on previous state
- State transitions are complex

**Example:**

```jsx
// BAD: Multiple useState (hard to keep in sync)
function ShoppingCart() {
  const [items, setItems] = useState([]);
  const [total, setTotal] = useState(0);
  const [discount, setDiscount] = useState(0);

  const addItem = (item) => {
    setItems([...items, item]);
    setTotal(total + item.price);  // Easy to forget to update
  };
}

// GOOD: useReducer (atomic updates)
const initialState = {
  items: [],
  total: 0,
  discount: 0,
};

function cartReducer(state, action) {
  switch (action.type) {
    case 'ADD_ITEM':
      const newItems = [...state.items, action.item];
      const newTotal = newItems.reduce((sum, i) => sum + i.price, 0);
      return {
        ...state,
        items: newItems,
        total: newTotal,
      };
    
    case 'APPLY_DISCOUNT':
      return {
        ...state,
        discount: action.discount,
        total: state.total * (1 - action.discount),
      };
    
    default:
      return state;
  }
}

function ShoppingCart() {
  const [state, dispatch] = useReducer(cartReducer, initialState);

  const addItem = (item) => {
    dispatch({ type: 'ADD_ITEM', item });
  };

  return (
    <div>
      <p>Total: ${state.total}</p>
      <button onClick={() => addItem({ name: 'Laptop', price: 1000 })}>
        Add Laptop
      </button>
    </div>
  );
}
```

**Billtrust Example:**
"Invoice form state (line items, taxes, discounts, totals) managed with `useReducer`. Actions: ADD_LINE_ITEM, REMOVE_LINE_ITEM, APPLY_TAX, APPLY_DISCOUNT. All calculations in reducer → state always consistent."

---

# Testing

## Q10: How do you test React components? Give examples of unit test vs integration test.

**Answer:**

**Testing Library:** React Testing Library (not Enzyme, which is deprecated)

**Unit Test** (single component in isolation):
```jsx
// InvoiceCard.test.tsx
import { render, screen } from '@testing-library/react';
import InvoiceCard from './InvoiceCard';

test('renders invoice number', () => {
  const invoice = { id: 1, number: 'INV-001', amount: 100 };
  
  render(<InvoiceCard invoice={invoice} />);
  
  expect(screen.getByText('INV-001')).toBeInTheDocument();
  expect(screen.getByText('$100')).toBeInTheDocument();
});

test('shows unpaid badge for unpaid invoices', () => {
  const invoice = { id: 1, number: 'INV-001', status: 'unpaid' };
  
  render(<InvoiceCard invoice={invoice} />);
  
  expect(screen.getByText('Unpaid')).toBeInTheDocument();
});
```

**Integration Test** (multiple components + API):
```jsx
// InvoiceList.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import InvoiceList from './InvoiceList';

// Mock API
jest.mock('./api', () => ({
  fetchInvoices: jest.fn(() => Promise.resolve([
    { id: 1, number: 'INV-001', amount: 100 },
    { id: 2, number: 'INV-002', amount: 200 },
  ])),
}));

test('fetches and displays invoices', async () => {
  render(<InvoiceList />);
  
  // Loading state
  expect(screen.getByText('Loading...')).toBeInTheDocument();
  
  // Wait for data
  await waitFor(() => {
    expect(screen.getByText('INV-001')).toBeInTheDocument();
    expect(screen.getByText('INV-002')).toBeInTheDocument();
  });
});

test('filters invoices by search query', async () => {
  render(<InvoiceList />);
  
  await waitFor(() => {
    expect(screen.getByText('INV-001')).toBeInTheDocument();
  });
  
  // Type in search
  const searchInput = screen.getByPlaceholderText('Search...');
  await userEvent.type(searchInput, '001');
  
  // Only matching invoice shown
  expect(screen.getByText('INV-001')).toBeInTheDocument();
  expect(screen.queryByText('INV-002')).not.toBeInTheDocument();
});
```

**When to use:**
- **Unit test**: Individual components, utility functions
- **Integration test**: Component + API, component + Router, full user flows

**Billtrust Example:**
"Invoice dashboard: unit tests for each card component, integration test for full dashboard (fetch → display → filter → sort)."

---

# TypeScript with React

## Q11: How do you type React components with TypeScript? Give examples of Props, State, Events.

**Answer:**

**Function Component with Props:**
```tsx
interface InvoiceCardProps {
  invoice: {
    id: number;
    number: string;
    amount: number;
    status: 'paid' | 'unpaid' | 'overdue';
  };
  onDelete?: (id: number) => void;
}

function InvoiceCard({ invoice, onDelete }: InvoiceCardProps) {
  return (
    <div>
      <h3>{invoice.number}</h3>
      <p>${invoice.amount}</p>
      {onDelete && (
        <button onClick={() => onDelete(invoice.id)}>Delete</button>
      )}
    </div>
  );
}

// Usage
<InvoiceCard 
  invoice={{ id: 1, number: 'INV-001', amount: 100, status: 'paid' }} 
  onDelete={(id) => console.log('Delete', id)}
/>
```

**Component with State:**
```tsx
interface FormState {
  email: string;
  password: string;
}

function LoginForm() {
  const [form, setForm] = useState<FormState>({
    email: '',
    password: '',
  });

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    console.log(form);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="email"
        value={form.email}
        onChange={(e: React.ChangeEvent<HTMLInputElement>) => 
          setForm({ ...form, email: e.target.value })
        }
      />
    </form>
  );
}
```

**Event Handlers:**
```tsx
function SearchBar() {
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    console.log(e.target.value);
  };

  const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => {
    console.log('Clicked');
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      console.log('Enter pressed');
    }
  };

  return (
    <div>
      <input onChange={handleChange} onKeyDown={handleKeyDown} />
      <button onClick={handleClick}>Search</button>
    </div>
  );
}
```

**Billtrust Example:**
"All invoice components TypeScript-typed: `Invoice` interface (40 fields), `InvoiceStatus` enum, `InvoiceCardProps`, `InvoiceListProps`. Caught 20+ bugs at compile-time vs runtime."

---

**You now have 80+ advanced React questions! Moving to Python FastAPI...**
