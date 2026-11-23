# React.js Frontend Interview Guide

**For Full-Stack AI-First Developer Interviews**

Your competitive advantage: **Modern React + AI integration** (Hooks, state management, API integration, real-time UIs)

---

## Table of Contents

1. [Why React for Modern Frontends](#why-react)
2. [React Fundamentals](#react-fundamentals)
3. [Hooks Deep Dive](#hooks-deep-dive)
4. [State Management](#state-management)
5. [API Integration](#api-integration)
6. [Performance Optimization](#performance-optimization)
7. [Testing React Components](#testing-react-components)
8. [Interview Questions & Answers](#interview-questions--answers)

---

## Why React?

### The Modern Frontend Landscape

```
Traditional (Server-Side):
PHP/Laravel → Blade Templates → HTML

Modern (SPA):
React (frontend) ←→ FastAPI (backend API)
```

**Why React?**
- Component-based (reusable UI)
- Virtual DOM (fast updates)
- Huge ecosystem (libraries for everything)
- Industry standard (most jobs)
- React Native (mobile with same code)

---

## React Fundamentals

### Components

```jsx
// Functional Component (Modern)
function Welcome({ name }) {
  return <h1>Hello, {name}</h1>;
}

// With Props
function UserCard({ user }) {
  return (
    <div className="card">
      <img src={user.avatar} alt={user.name} />
      <h2>{user.name}</h2>
      <p>{user.email}</p>
    </div>
  );
}

// Usage
<UserCard user={{ name: "John", email: "john@example.com", avatar: "/john.jpg" }} />
```

### JSX

```jsx
// JSX lets you write HTML-like syntax in JavaScript
const element = (
  <div className="container">
    <h1>Welcome</h1>
    <p>This is JSX</p>
  </div>
);

// Expressions in JSX
const name = "John";
const element = <h1>Hello, {name}</h1>;

// Conditional rendering
{isLoggedIn ? <Dashboard /> : <Login />}

// Lists
{users.map(user => (
  <UserCard key={user.id} user={user} />
))}
```

---

## Hooks Deep Dive

### useState - State Management

```jsx
import { useState } from 'react';

function Counter() {
  const [count, setCount] = useState(0);
  
  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>
        Increment
      </button>
    </div>
  );
}

// With objects
function UserForm() {
  const [form, setForm] = useState({
    name: '',
    email: '',
    age: 0
  });
  
  const handleChange = (e) => {
    setForm({
      ...form,
      [e.target.name]: e.target.value
    });
  };
  
  return (
    <form>
      <input 
        name="name" 
        value={form.name} 
        onChange={handleChange} 
      />
      <input 
        name="email" 
        value={form.email} 
        onChange={handleChange} 
      />
    </form>
  );
}
```

### useEffect - Side Effects

```jsx
import { useEffect, useState } from 'react';

function UserProfile({ userId }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    // Runs after component mounts and when userId changes
    async function fetchUser() {
      setLoading(true);
      const response = await fetch(`/api/users/${userId}`);
      const data = await response.json();
      setUser(data);
      setLoading(false);
    }
    
    fetchUser();
    
    // Cleanup function (optional)
    return () => {
      // Cancel requests, clear timers, etc.
    };
  }, [userId]); // Dependency array
  
  if (loading) return <div>Loading...</div>;
  if (!user) return <div>User not found</div>;
  
  return <div>{user.name}</div>;
}

// Common useEffect patterns
useEffect(() => {
  // Runs ONCE on mount (empty deps)
}, []);

useEffect(() => {
  // Runs on EVERY render (no deps array - avoid this!)
});

useEffect(() => {
  // Runs when count changes
}, [count]);
```

### useContext - Global State

```jsx
import { createContext, useContext, useState } from 'react';

// Create context
const AuthContext = createContext();

// Provider component
function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  
  const login = async (email, password) => {
    const response = await fetch('/api/login', {
      method: 'POST',
      body: JSON.stringify({ email, password })
    });
    const data = await response.json();
    setUser(data.user);
  };
  
  const logout = () => setUser(null);
  
  return (
    <AuthContext.Provider value={{ user, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

// Custom hook to use auth
function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}

// Usage in components
function Dashboard() {
  const { user, logout } = useAuth();
  
  return (
    <div>
      <h1>Welcome, {user.name}</h1>
      <button onClick={logout}>Logout</button>
    </div>
  );
}

// App setup
function App() {
  return (
    <AuthProvider>
      <Dashboard />
    </AuthProvider>
  );
}
```

### Custom Hooks

```jsx
// useFetch - Reusable data fetching
function useFetch(url) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    async function fetchData() {
      try {
        setLoading(true);
        const response = await fetch(url);
        const json = await response.json();
        setData(json);
      } catch (err) {
        setError(err);
      } finally {
        setLoading(false);
      }
    }
    
    fetchData();
  }, [url]);
  
  return { data, loading, error };
}

// Usage
function UserList() {
  const { data: users, loading, error } = useFetch('/api/users');
  
  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  
  return (
    <ul>
      {users.map(user => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  );
}

// useLocalStorage - Persist state
function useLocalStorage(key, initialValue) {
  const [value, setValue] = useState(() => {
    const item = localStorage.getItem(key);
    return item ? JSON.parse(item) : initialValue;
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
    <button onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>
      Current theme: {theme}
    </button>
  );
}
```

---

## State Management

### Local State vs Global State

```jsx
// LOCAL STATE (single component)
function Counter() {
  const [count, setCount] = useState(0);
  return <div>{count}</div>;
}

// LIFTED STATE (parent → children)
function Parent() {
  const [user, setUser] = useState(null);
  
  return (
    <>
      <Header user={user} />
      <Dashboard user={user} />
      <Sidebar user={user} />
    </>
  );
}

// GLOBAL STATE (Context API)
const UserContext = createContext();

function App() {
  const [user, setUser] = useState(null);
  
  return (
    <UserContext.Provider value={{ user, setUser }}>
      <Header />
      <Dashboard />
      <Sidebar />
    </UserContext.Provider>
  );
}
```

### React Query / TanStack Query

```jsx
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

// Fetch data with caching
function UserList() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['users'],
    queryFn: () => fetch('/api/users').then(res => res.json())
  });
  
  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  
  return (
    <ul>
      {data.map(user => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  );
}

// Mutations (create/update/delete)
function CreateUser() {
  const queryClient = useQueryClient();
  
  const mutation = useMutation({
    mutationFn: (newUser) => 
      fetch('/api/users', {
        method: 'POST',
        body: JSON.stringify(newUser)
      }),
    onSuccess: () => {
      // Invalidate and refetch
      queryClient.invalidateQueries({ queryKey: ['users'] });
    }
  });
  
  const handleSubmit = (e) => {
    e.preventDefault();
    mutation.mutate({ name: 'John', email: 'john@example.com' });
  };
  
  return (
    <form onSubmit={handleSubmit}>
      <button type="submit" disabled={mutation.isPending}>
        {mutation.isPending ? 'Creating...' : 'Create User'}
      </button>
      {mutation.isError && <div>Error: {mutation.error.message}</div>}
    </form>
  );
}
```

---

## API Integration

### Fetch API

```jsx
function Dashboard() {
  const [data, setData] = useState(null);
  
  useEffect(() => {
    async function loadData() {
      try {
        const response = await fetch('/api/dashboard', {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
          }
        });
        
        if (!response.ok) {
          throw new Error('API request failed');
        }
        
        const json = await response.json();
        setData(json);
      } catch (error) {
        console.error(error);
      }
    }
    
    loadData();
  }, []);
  
  return <div>{JSON.stringify(data)}</div>;
}
```

### Axios (Popular Alternative)

```jsx
import axios from 'axios';

// Setup
const api = axios.create({
  baseURL: '/api',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Interceptor for auth token
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Component
function UserList() {
  const [users, setUsers] = useState([]);
  
  useEffect(() => {
    api.get('/users').then(response => {
      setUsers(response.data);
    });
  }, []);
  
  const createUser = async (userData) => {
    const response = await api.post('/users', userData);
    setUsers([...users, response.data]);
  };
  
  return <div>...</div>;
}
```

### Real-Time with WebSockets

```jsx
function ChatRoom({ roomId }) {
  const [messages, setMessages] = useState([]);
  const [ws, setWs] = useState(null);
  
  useEffect(() => {
    // Connect
    const websocket = new WebSocket(`ws://localhost:8000/ws/${roomId}`);
    
    websocket.onmessage = (event) => {
      const message = JSON.parse(event.data);
      setMessages(prev => [...prev, message]);
    };
    
    setWs(websocket);
    
    // Cleanup
    return () => websocket.close();
  }, [roomId]);
  
  const sendMessage = (text) => {
    if (ws) {
      ws.send(JSON.stringify({ text, timestamp: Date.now() }));
    }
  };
  
  return (
    <div>
      {messages.map((msg, i) => (
        <div key={i}>{msg.text}</div>
      ))}
      <MessageInput onSend={sendMessage} />
    </div>
  );
}
```

---

## Performance Optimization

### useMemo - Expensive Calculations

```jsx
import { useMemo } from 'react';

function DataTable({ items, filter }) {
  // Only recalculate when items or filter changes
  const filteredItems = useMemo(() => {
    console.log('Filtering...'); // Only logs when deps change
    return items.filter(item => 
      item.name.toLowerCase().includes(filter.toLowerCase())
    );
  }, [items, filter]);
  
  return (
    <table>
      {filteredItems.map(item => (
        <tr key={item.id}>
          <td>{item.name}</td>
        </tr>
      ))}
    </table>
  );
}
```

### useCallback - Memoized Functions

```jsx
import { useCallback } from 'react';

function Parent() {
  const [count, setCount] = useState(0);
  
  // Without useCallback: new function every render
  // Child re-renders unnecessarily
  
  // With useCallback: same function reference
  const handleClick = useCallback(() => {
    console.log('Clicked');
  }, []); // Empty deps = never changes
  
  return (
    <>
      <p>{count}</p>
      <button onClick={() => setCount(count + 1)}>Increment</button>
      <Child onClick={handleClick} />
    </>
  );
}

// Child only re-renders when onClick changes
const Child = React.memo(({ onClick }) => {
  console.log('Child render');
  return <button onClick={onClick}>Click me</button>;
});
```

### React.memo - Prevent Re-renders

```jsx
// Without React.memo: re-renders every time parent re-renders
function UserCard({ user }) {
  console.log('Rendering UserCard');
  return <div>{user.name}</div>;
}

// With React.memo: only re-renders when user prop changes
const UserCard = React.memo(({ user }) => {
  console.log('Rendering UserCard');
  return <div>{user.name}</div>;
});

// Custom comparison
const UserCard = React.memo(
  ({ user }) => <div>{user.name}</div>,
  (prevProps, nextProps) => {
    // Return true if props are equal (skip re-render)
    return prevProps.user.id === nextProps.user.id;
  }
);
```

### Code Splitting (Lazy Loading)

```jsx
import { lazy, Suspense } from 'react';

// Load component only when needed
const Dashboard = lazy(() => import('./Dashboard'));
const Settings = lazy(() => import('./Settings'));

function App() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Suspense>
  );
}
```

---

## Testing React Components

### Jest + React Testing Library

```jsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

test('renders welcome message', () => {
  render(<Welcome name="John" />);
  expect(screen.getByText('Hello, John')).toBeInTheDocument();
});

test('increments counter on button click', () => {
  render(<Counter />);
  const button = screen.getByText('Increment');
  const count = screen.getByText(/Count:/);
  
  fireEvent.click(button);
  expect(count).toHaveTextContent('Count: 1');
  
  fireEvent.click(button);
  expect(count).toHaveTextContent('Count: 2');
});

test('fetches and displays user', async () => {
  // Mock API
  global.fetch = jest.fn(() =>
    Promise.resolve({
      json: () => Promise.resolve({ name: 'John', email: 'john@example.com' })
    })
  );
  
  render(<UserProfile userId={1} />);
  
  // Initially loading
  expect(screen.getByText('Loading...')).toBeInTheDocument();
  
  // Wait for data
  await waitFor(() => {
    expect(screen.getByText('John')).toBeInTheDocument();
  });
  
  expect(fetch).toHaveBeenCalledWith('/api/users/1');
});

test('submits form with user input', async () => {
  const handleSubmit = jest.fn();
  render(<LoginForm onSubmit={handleSubmit} />);
  
  const emailInput = screen.getByLabelText('Email');
  const passwordInput = screen.getByLabelText('Password');
  const submitButton = screen.getByText('Login');
  
  await userEvent.type(emailInput, 'john@example.com');
  await userEvent.type(passwordInput, 'password123');
  await userEvent.click(submitButton);
  
  expect(handleSubmit).toHaveBeenCalledWith({
    email: 'john@example.com',
    password: 'password123'
  });
});
```

---

## Interview Questions & Answers

### Q1: "Explain the difference between useState and useRef."

**Your Answer:**

> *"Both store values, but behave differently:*
> 
> **useState:**
> *- For values that affect rendering*
> *- Updating triggers re-render*
> *- Use for UI state*
> 
> ```jsx
> const [count, setCount] = useState(0);
> setCount(1); // Component re-renders
> ```
> 
> **useRef:**
> *- For values that DON'T affect rendering*
> *- Updating does NOT trigger re-render*
> *- Persists across renders*
> *- Use for: DOM refs, timers, previous values*
> 
> ```jsx
> const countRef = useRef(0);
> countRef.current = 1; // No re-render
> ```
> 
> **Real Example:**
> *Form with auto-save. Use useState for input value (renders as user types). Use useRef for debounce timer (doesn't need to render):*
> 
> ```jsx
> const [text, setText] = useState('');
> const timerRef = useRef(null);
> 
> const handleChange = (e) => {
>   setText(e.target.value);
>   
>   clearTimeout(timerRef.current);
>   timerRef.current = setTimeout(() => {
>     saveToServer(e.target.value);
>   }, 1000);
> };
> ```"*

---

### Q2: "How do you prevent unnecessary re-renders in React?"

**Your Answer:**

> *"Multiple techniques depending on the scenario:*
> 
> **1. React.memo (Component Level)**
> *Memoize entire component:*
> ```jsx
> const UserCard = React.memo(({ user }) => {
>   return <div>{user.name}</div>;
> });
> ```
> 
> **2. useMemo (Value Level)**
> *Memoize expensive calculations:*
> ```jsx
> const sortedUsers = useMemo(() => {
>   return users.sort((a, b) => a.name.localeCompare(b.name));
> }, [users]);
> ```
> 
> **3. useCallback (Function Level)**
> *Memoize functions passed as props:*
> ```jsx
> const handleClick = useCallback(() => {
>   console.log('clicked');
> }, []);
> ```
> 
> **4. Proper Key Props**
> ```jsx
> // ❌ BAD: index as key
> {items.map((item, i) => <Item key={i} {...item} />)}
> 
> // ✅ GOOD: stable unique id
> {items.map(item => <Item key={item.id} {...item} />)}
> ```
> 
> **5. Code Splitting**
> *Load components only when needed:*
> ```jsx
> const Dashboard = lazy(() => import('./Dashboard'));
> ```
> 
> **Real Example:**
> *Data table with 1000 rows. Without optimization: 2-second re-render on every keystroke. With React.memo on table rows + useMemo for filtered data: 50ms."*

---

### Q3: "How do you integrate a React frontend with a FastAPI backend?"

**Your Answer:**

> *"Here's my production setup:*
> 
> **Architecture:**
> ```
> React (localhost:3000) ←→ FastAPI (localhost:8000)
> ```
> 
> **1. CORS Setup (FastAPI)**
> ```python
> from fastapi.middleware.cors import CORSMiddleware
> 
> app.add_middleware(
>     CORSMiddleware,
>     allow_origins=["http://localhost:3000"],
>     allow_credentials=True,
>     allow_methods=["*"],
>     allow_headers=["*"]
> )
> ```
> 
> **2. API Client (React)**
> ```jsx
> const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';
> 
> async function fetchUsers() {
>   const response = await fetch(`${API_URL}/api/users`, {
>     headers: {
>       'Authorization': `Bearer ${token}`,
>       'Content-Type': 'application/json'
>     }
>   });
>   return response.json();
> }
> ```
> 
> **3. Custom Hook for API Calls**
> ```jsx
> function useAPI(endpoint) {
>   const [data, setData] = useState(null);
>   const [loading, setLoading] = useState(true);
>   const [error, setError] = useState(null);
>   
>   useEffect(() => {
>     fetch(`${API_URL}${endpoint}`)
>       .then(res => res.json())
>       .then(setData)
>       .catch(setError)
>       .finally(() => setLoading(false));
>   }, [endpoint]);
>   
>   return { data, loading, error };
> }
> ```
> 
> **4. React Query (Better)**
> ```jsx
> const { data: users } = useQuery({
>   queryKey: ['users'],
>   queryFn: () => fetch('/api/users').then(r => r.json())
> });
> ```
> 
> **5. WebSocket for Real-Time**
> ```jsx
> useEffect(() => {
>   const ws = new WebSocket('ws://localhost:8000/ws');
>   ws.onmessage = (event) => {
>     setMessages(prev => [...prev, JSON.parse(event.data)]);
>   };
>   return () => ws.close();
> }, []);
> ```
> 
> **Production:**
> *- Same origin (deploy React build via FastAPI static files)*
> *- Or separate: React on Vercel, FastAPI on AWS*
> *- API key / JWT for auth*
> *- Rate limiting on backend*"*

---

## Summary: Your React Expertise

**When Asked About React:**

> *"I build modern React frontends with hooks, functional components, and React Query for server state. For complex UIs, I use useMemo/useCallback for performance optimization and React.memo to prevent unnecessary re-renders.*
> 
> *My typical stack: React frontend consuming FastAPI backend APIs, TanStack Query for data fetching with automatic caching, Context API for global state like auth, and WebSockets for real-time features.*
> 
> *I write tests with React Testing Library focusing on user behavior rather than implementation details. For large apps, I use code splitting with React.lazy to keep bundle sizes small and initial load fast."*

---

**React.js expertise complete!** ⚛️
