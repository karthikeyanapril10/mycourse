# Elasticsearch & Search Systems Guide

**For Senior Software Engineer Interviews**

Your competitive advantage: **Enterprise search experience** (10,000+ customers, invoice search, customer lookup, full-text search at scale)

---

## Table of Contents

1. [Search Fundamentals](#search-fundamentals)
2. [Elasticsearch Architecture](#elasticsearch-architecture)
3. [Indexing & Mapping](#indexing--mapping)
4. [Querying & Relevance](#querying--relevance)
5. [Aggregations & Analytics](#aggregations--analytics)
6. [Performance & Scaling](#performance--scaling)
7. [Your real-world use cases](#your-Enterprise SaaS Company-use-cases)
8. [Interview Questions & Answers](#interview-questions--answers)

---

## Search Fundamentals

### Why Not Just Use SQL?

**SQL Limitations for Search:**
```sql
-- Slow on large tables (sequential scan)
SELECT * FROM invoices 
WHERE description LIKE '%payment%'  -- Can't use index

-- No relevance scoring (all matches equal)
-- No typo tolerance
-- No synonym support ('car' doesn't match 'automobile')
```

**Elasticsearch Advantages:**
- **Inverted index:** Fast text search (milliseconds vs seconds)
- **Relevance scoring:** Best matches first (TF-IDF, BM25)
- **Fuzzy matching:** Typo tolerance ('paymnet' → 'payment')
- **Synonyms:** 'car' matches 'automobile', 'vehicle'
- **Full-text:** Search across all fields
- **Aggregations:** Faceted search, analytics

---

### Inverted Index (How Search Works)

**Regular Database Index:**
```
Document ID → Content
1 → "Quick brown fox"
2 → "Brown cow jumps"
3 → "Fox jumps over"
```

**Inverted Index:**
```
Term → Document IDs
'quick' → [1]
'brown' → [1, 2]
'fox' → [1, 3]
'cow' → [2]
'jumps' → [2, 3]
```

**Search "brown fox":**
1. Lookup 'brown' → [1, 2]
2. Lookup 'fox' → [1, 3]
3. Intersection → [1]
4. Return document 1

**Fast:** O(log N) term lookup + set intersection

---

## Elasticsearch Architecture

### Core Concepts

```
Cluster (search-cluster)
  ├── Node 1 (Master + Data)
  ├── Node 2 (Data)
  └── Node 3 (Data)
      ↓
Index (invoices)
  ├── Shard 0 (Primary) → Node 1
  │   └── Replica → Node 2
  ├── Shard 1 (Primary) → Node 2
  │   └── Replica → Node 3
  └── Shard 2 (Primary) → Node 3
      └── Replica → Node 1
```

**Terminology:**

| Elasticsearch | MySQL Equivalent |
|---------------|------------------|
| Index | Database |
| Document | Row |
| Field | Column |
| Mapping | Schema |
| Shard | Partition |

### Sharding & Replication

**Sharding (Horizontal Scaling):**
- Index split into N shards (default: 1)
- Each shard is a Lucene index
- Search runs on all shards in parallel

**Replication (High Availability):**
- Each shard has R replicas (default: 1)
- If node dies, replica promoted to primary
- Reads can hit replicas (load balancing)

**Example:**
```bash
PUT /invoices
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  }
}

# Result:
# 3 primary shards + 3 replica shards = 6 total shards
# Spread across 3 nodes
```

---

## Indexing & Mapping

### Mapping (Schema Definition)

```json
PUT /invoices
{
  "mappings": {
    "properties": {
      "invoice_id": {
        "type": "keyword"  // Exact match (not analyzed)
      },
      "customer_name": {
        "type": "text",    // Full-text search (analyzed)
        "fields": {
          "keyword": {
            "type": "keyword"  // Also store exact for sorting
          }
        }
      },
      "amount": {
        "type": "float"
      },
      "due_date": {
        "type": "date"
      },
      "description": {
        "type": "text",
        "analyzer": "english"  // Stemming, stop words
      },
      "tags": {
        "type": "keyword"  // Array of exact values
      }
    }
  }
}
```

**Field Types:**

| Type | Use Case | Example |
|------|----------|---------|
| `text` | Full-text search | Description, email body |
| `keyword` | Exact match, aggregations | Status, tags, IDs |
| `long`, `float` | Numeric range queries | Amount, quantity |
| `date` | Date range queries | Created_at, due_date |
| `boolean` | True/false | Is_paid, is_active |
| `object` | Nested object | Address {street, city, zip} |
| `geo_point` | Location search | Lat/long coordinates |

### Analyzers (Text Processing)

**Standard Analyzer (Default):**
```
"The QUICK Brown Fox!"
  ↓ Lowercase
"the quick brown fox!"
  ↓ Tokenize
["the", "quick", "brown", "fox"]
  ↓ Remove stop words
["quick", "brown", "fox"]
```

**English Analyzer (Stemming):**
```
"Running quickly with foxes"
  ↓ Lowercase + tokenize
["running", "quickly", "with", "foxes"]
  ↓ Stem
["run", "quick", "with", "fox"]
  ↓ Remove stop words
["run", "quick", "fox"]
```

Now "running" matches "run", "runner", "runs"

**Custom Analyzer:**
```json
PUT /invoices
{
  "settings": {
    "analysis": {
      "analyzer": {
        "invoice_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "asciifolding", "invoice_synonym"]
        }
      },
      "filter": {
        "invoice_synonym": {
          "type": "synonym",
          "synonyms": [
            "bill, invoice",
            "payment, charge, fee"
          ]
        }
      }
    }
  }
}
```

---

## Querying & Relevance

### Basic Queries

**1. Match Query (Full-Text Search)**
```json
GET /invoices/_search
{
  "query": {
    "match": {
      "description": "payment processing"
    }
  }
}

// Finds: "payment", "processing", "payments processed"
// Scored by relevance (BM25)
```

**2. Term Query (Exact Match)**
```json
GET /invoices/_search
{
  "query": {
    "term": {
      "status": "paid"
    }
  }
}

// Finds: Exact "paid" (case-sensitive on keyword fields)
```

**3. Range Query**
```json
GET /invoices/_search
{
  "query": {
    "range": {
      "amount": {
        "gte": 100,
        "lte": 500
      }
    }
  }
}
```

**4. Bool Query (Combine Multiple)**
```json
GET /invoices/_search
{
  "query": {
    "bool": {
      "must": [
        {"match": {"customer_name": "Acme Corp"}}
      ],
      "filter": [
        {"term": {"status": "unpaid"}},
        {"range": {"due_date": {"lt": "now"}}}
      ],
      "must_not": [
        {"term": {"is_disputed": true}}
      ],
      "should": [
        {"term": {"priority": "high"}}
      ]
    }
  }
}

// must: AND (scored)
// filter: AND (not scored, cacheable)
// must_not: NOT
// should: OR (boosts score)
```

### Relevance Scoring (BM25)

**TF-IDF Concept:**
- **Term Frequency (TF):** More occurrences = higher score
- **Inverse Document Frequency (IDF):** Rare terms score higher

```
Score = TF × IDF

Example:
"payment" appears in 1000 invoices → low IDF → low score
"ACH123456" appears in 1 invoice → high IDF → high score
```

**Boosting:**
```json
GET /invoices/_search
{
  "query": {
    "multi_match": {
      "query": "payment",
      "fields": ["description^2", "notes"]
    }
  }
}

// Matches in description score 2x higher than notes
```

**Explain (Debug Scoring):**
```json
GET /invoices/_search
{
  "query": {"match": {"description": "payment"}},
  "explain": true
}

// Returns detailed score calculation
```

---

## Aggregations & Analytics

### Types of Aggregations

**1. Bucket Aggregations (Group By)**
```json
GET /invoices/_search
{
  "size": 0,  // Don't return documents, just aggregations
  "aggs": {
    "by_status": {
      "terms": {
        "field": "status"
      }
    }
  }
}

// Result:
{
  "aggregations": {
    "by_status": {
      "buckets": [
        {"key": "paid", "doc_count": 5000},
        {"key": "unpaid", "doc_count": 1500},
        {"key": "overdue", "doc_count": 300}
      ]
    }
  }
}
```

**2. Metric Aggregations (Calculate Values)**
```json
GET /invoices/_search
{
  "size": 0,
  "aggs": {
    "total_revenue": {
      "sum": {"field": "amount"}
    },
    "avg_invoice": {
      "avg": {"field": "amount"}
    },
    "stats": {
      "stats": {"field": "amount"}  // min, max, avg, sum, count
    }
  }
}
```

**3. Date Histogram (Time-Series)**
```json
GET /invoices/_search
{
  "size": 0,
  "aggs": {
    "sales_over_time": {
      "date_histogram": {
        "field": "created_at",
        "calendar_interval": "month"
      },
      "aggs": {
        "monthly_revenue": {
          "sum": {"field": "amount"}
        }
      }
    }
  }
}

// Result: Revenue per month
```

**4. Nested Aggregations**
```json
GET /invoices/_search
{
  "size": 0,
  "aggs": {
    "by_customer": {
      "terms": {"field": "customer_id"},
      "aggs": {
        "total_spent": {
          "sum": {"field": "amount"}
        }
      }
    }
  }
}

// Top customers by spend
```

---

## Performance & Scaling

### Indexing Performance

**Bulk Indexing:**
```json
POST /_bulk
{"index": {"_index": "invoices", "_id": "1"}}
{"invoice_id": "INV-001", "amount": 150.00}
{"index": {"_index": "invoices", "_id": "2"}}
{"invoice_id": "INV-002", "amount": 200.00}

// 100x faster than individual inserts
```

**Refresh Interval:**
```json
PUT /invoices/_settings
{
  "index": {
    "refresh_interval": "30s"  // Default: 1s
  }
}

// Documents visible after refresh
// Higher interval = faster indexing
```

**Disable Replicas During Bulk Load:**
```json
PUT /invoices/_settings
{"number_of_replicas": 0}

// ... bulk index ...

PUT /invoices/_settings
{"number_of_replicas": 1}
```

### Query Performance

**1. Use Filters (Cacheable)**
```json
// Slow: Scored query
{
  "query": {
    "match": {"status": "paid"}
  }
}

// Fast: Cached filter
{
  "query": {
    "bool": {
      "filter": [
        {"term": {"status": "paid"}}
      ]
    }
  }
}
```

**2. Limit Fields Returned**
```json
GET /invoices/_search
{
  "query": {...},
  "_source": ["invoice_id", "amount"]  // Don't return all fields
}
```

**3. Pagination (Scroll API for Large Results)**
```json
// Bad: Deep pagination (slow)
GET /invoices/_search?from=10000&size=10

// Good: Scroll API
POST /invoices/_search?scroll=1m
{
  "size": 1000,
  "query": {...}
}

// Then: GET /_search/scroll with scroll_id
```

### Scaling Strategies

**1. More Shards (Horizontal)**
```bash
# 1 shard → 3 shards = 3x query parallelism
PUT /invoices/_settings
{"number_of_shards": 3}

# Note: Can't change after index created
# Must reindex into new index
```

**2. More Nodes**
- Add server → ES auto-balances shards
- Linear scaling (3 nodes → 6 nodes = 2x capacity)

**3. Dedicated Master Nodes**
```
Node 1, 2, 3: Master-eligible (cluster coordination)
Node 4, 5, 6: Data nodes (hold shards)
Node 7, 8: Ingest nodes (preprocessing)
```

**4. Hot-Warm Architecture**
```
Hot tier (SSD, recent data): Today's invoices
Warm tier (HDD, old data): Last year's invoices
Cold tier (S3, archive): 5+ years old
```

---

## Your real-world use cases

### 1. Invoice Search

**Requirements:**
- Search 10M+ invoices across 10k customers
- Full-text search: invoice number, customer name, description
- Filter by: status, date range, amount range
- Sort by relevance or date

**Mapping:**
```json
PUT /invoices
{
  "settings": {
    "number_of_shards": 5,
    "number_of_replicas": 1
  },
  "mappings": {
    "properties": {
      "invoice_id": {"type": "keyword"},
      "customer_id": {"type": "keyword"},
      "customer_name": {
        "type": "text",
        "fields": {"keyword": {"type": "keyword"}}
      },
      "description": {
        "type": "text",
        "analyzer": "english"
      },
      "amount": {"type": "float"},
      "status": {"type": "keyword"},
      "due_date": {"type": "date"},
      "created_at": {"type": "date"}
    }
  }
}
```

**Search Query:**
```php
public function searchInvoices($query, $filters) {
    $params = [
        'index' => 'invoices',
        'body' => [
            'query' => [
                'bool' => [
                    'must' => [
                        [
                            'multi_match' => [
                                'query' => $query,
                                'fields' => [
                                    'invoice_id^3',      // Boost exact ID
                                    'customer_name^2',   // Boost customer name
                                    'description'
                                ],
                                'fuzziness' => 'AUTO'   // Typo tolerance
                            ]
                        ]
                    ],
                    'filter' => []
                ]
            ],
            'sort' => [
                '_score' => 'desc',
                'created_at' => 'desc'
            ],
            'size' => 20
        ]
    ];
    
    // Apply filters
    if (isset($filters['customer_id'])) {
        $params['body']['query']['bool']['filter'][] = [
            'term' => ['customer_id' => $filters['customer_id']]
        ];
    }
    
    if (isset($filters['status'])) {
        $params['body']['query']['bool']['filter'][] = [
            'term' => ['status' => $filters['status']]
        ];
    }
    
    if (isset($filters['date_range'])) {
        $params['body']['query']['bool']['filter'][] = [
            'range' => [
                'created_at' => [
                    'gte' => $filters['date_range']['from'],
                    'lte' => $filters['date_range']['to']
                ]
            ]
        ];
    }
    
    return $this->client->search($params);
}
```

### 2. Customer Lookup (Autocomplete)

**Requirement:** Type-ahead search as user types

**Mapping (N-Gram Tokenizer):**
```json
PUT /customers
{
  "settings": {
    "analysis": {
      "tokenizer": {
        "autocomplete_tokenizer": {
          "type": "edge_ngram",
          "min_gram": 2,
          "max_gram": 10,
          "token_chars": ["letter", "digit"]
        }
      },
      "analyzer": {
        "autocomplete": {
          "type": "custom",
          "tokenizer": "autocomplete_tokenizer",
          "filter": ["lowercase"]
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "name": {
        "type": "text",
        "analyzer": "autocomplete",
        "search_analyzer": "standard"
      }
    }
  }
}

// "Acme Corp" indexed as: "ac", "acm", "acme", "acme ", "acme c", ...
// Query "acm" matches "Acme Corp"
```

**Query:**
```json
GET /customers/_search
{
  "query": {
    "match": {
      "name": {
        "query": "acm",
        "operator": "and"
      }
    }
  },
  "size": 10
}
```

### 3. Audit Log Search

**Requirement:** Search millions of audit events

**Data Pipeline:**
```
Application Logs
  ↓ Filebeat
Logstash (parse, enrich)
  ↓
Elasticsearch
  ↓ Kibana
Dashboard + Search
```

**Index Template (Daily Rotation):**
```json
PUT /_index_template/audit_logs
{
  "index_patterns": ["audit-logs-*"],
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1,
      "index.lifecycle.name": "audit_policy"  // Delete after 90 days
    },
    "mappings": {
      "properties": {
        "@timestamp": {"type": "date"},
        "user_id": {"type": "keyword"},
        "action": {"type": "keyword"},
        "resource": {"type": "keyword"},
        "ip_address": {"type": "ip"},
        "details": {"type": "text"}
      }
    }
  }
}

// Creates: audit-logs-2026-11-16, audit-logs-2026-11-17, ...
```

**Search:**
```json
GET /audit-logs-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"match": {"action": "invoice.deleted"}}
      ],
      "filter": [
        {"term": {"user_id": "user_123"}},
        {"range": {"@timestamp": {"gte": "now-7d"}}}
      ]
    }
  }
}
```

---

## Interview Questions & Answers

### Q1: "How does Elasticsearch search so fast compared to SQL LIKE queries?"

**Your Answer:**

> *"Elasticsearch uses an inverted index, which is fundamentally different from how SQL databases work.*
> 
> **SQL LIKE (Sequential Scan):**
> ```sql
> SELECT * FROM invoices WHERE description LIKE '%payment%'
> -- O(N) - must read every row
> -- Can't use B-tree index
> ```
> 
> **Elasticsearch (Inverted Index):**
> ```
> Term 'payment' → [Doc1, Doc5, Doc9]  -- O(log N) lookup
> ```
> 
> **How Inverted Index Works:**
> *1. At index time, text is analyzed:*
>    *- "Payment processing for invoice" → ["payment", "processing", "invoice"]*
> *2. Each term maps to document IDs:*
>    ```
>    'payment' → [1, 5, 9, 12]
>    'processing' → [1, 7, 9]
>    'invoice' → [1, 2, 5, 9, 12]
>    ```
> *3. Search "payment processing":*
>    *- Lookup 'payment' → [1, 5, 9, 12]*
>    *- Lookup 'processing' → [1, 7, 9]*
>    *- Intersection → [1, 9]*
>    *- Return documents 1 and 9*
> 
> **Performance:**
> *- SQL LIKE: 5+ seconds on 10M rows*
> *- Elasticsearch: < 100ms on 10M documents*
> 
> **In a production environment, for invoice search across 10M invoices:**
> *- SQL was too slow (3-5 sec queries)*
> *- Elasticsearch: < 50ms average*
> *- Bonus: Relevance scoring (best matches first), typo tolerance ('paymnet' works)*"*

---

### Q2: "Design a search feature for an e-commerce site with faceted filtering."

**Your Answer:**

> *"Faceted search lets users filter by multiple criteria (category, price, brand, rating). Here's how I'd design it:*
> 
> **Requirements:**
> *- Search products by name/description*
> *- Filter by: category, price range, brand, rating, in-stock*
> *- Show facet counts (e.g., 'Laptops (250)', 'Desktops (150)')*
> *- Fast (< 100ms)*
> 
> **Mapping:**
> ```json
> PUT /products
> {
>   "mappings": {
>     "properties": {
>       "name": {"type": "text"},
>       "description": {"type": "text"},
>       "category": {"type": "keyword"},
>       "brand": {"type": "keyword"},
>       "price": {"type": "float"},
>       "rating": {"type": "float"},
>       "in_stock": {"type": "boolean"}
>     }
>   }
> }
> ```
> 
> **Query:**
> ```json
> GET /products/_search
> {
>   "query": {
>     "bool": {
>       "must": [
>         {"multi_match": {
>           "query": "laptop",
>           "fields": ["name^2", "description"]
>         }}
>       ],
>       "filter": [
>         {"term": {"category": "electronics"}},
>         {"range": {"price": {"gte": 500, "lte": 2000}}},
>         {"term": {"in_stock": true}}
>       ]
>     }
>   },
>   "aggs": {
>     "categories": {
>       "terms": {"field": "category", "size": 20}
>     },
>     "brands": {
>       "terms": {"field": "brand", "size": 20}
>     },
>     "price_ranges": {
>       "range": {
>         "field": "price",
>         "ranges": [
>           {"to": 500},
>           {"from": 500, "to": 1000},
>           {"from": 1000, "to": 2000},
>           {"from": 2000}
>         ]
>       }
>     }
>   },
>   "size": 20
> }
> ```
> 
> **Response:**
> ```json
> {
>   "hits": {
>     "total": 250,
>     "hits": [/* product results */]
>   },
>   "aggregations": {
>     "categories": {
>       "buckets": [
>         {"key": "electronics", "doc_count": 250},
>         {"key": "accessories", "doc_count": 120}
>       ]
>     },
>     "brands": {
>       "buckets": [
>         {"key": "Dell", "doc_count": 80},
>         {"key": "HP", "doc_count": 70},
>         {"key": "Lenovo", "doc_count": 60}
>       ]
>     },
>     "price_ranges": {
>       "buckets": [
>         {"to": 500, "doc_count": 50},
>         {"from": 500, "to": 1000, "doc_count": 120},
>         {"from": 1000, "to": 2000, "doc_count": 80}
>       ]
>     }
>   }
> }
> ```
> 
> **UI Implementation:**
> *- Checkboxes for categories, brands (with counts)*
> *- Slider for price range*
> *- Star rating filter*
> *- Each click refires query with updated filters*
> 
> **Performance:**
> *- Aggregations run on filtered results (fast)*
> *- Use filter context (cacheable, no scoring)*
> *- Expected: < 50ms for 100k products*"*

---

### Q3: "How would you implement autocomplete/type-ahead search?"

**Your Answer:**

> *"Autocomplete needs to match partial input as user types. I'd use edge n-grams:*
> 
> **Example: User types 'Acme' progressively**
> *- 'A' → matches 'Acme Corp', 'Apple Inc'*
> *- 'Ac' → matches 'Acme Corp'*
> *- 'Acm' → matches 'Acme Corp'*
> *- 'Acme' → matches 'Acme Corp'*
> 
> **Edge N-Gram Analyzer:**
> ```json
> PUT /customers
> {
>   "settings": {
>     "analysis": {
>       "tokenizer": {
>         "autocomplete_tokenizer": {
>           "type": "edge_ngram",
>           "min_gram": 2,
>           "max_gram": 10
>         }
>       },
>       "analyzer": {
>         "autocomplete": {
>           "tokenizer": "autocomplete_tokenizer",
>           "filter": ["lowercase"]
>         }
>       }
>     }
>   },
>   "mappings": {
>     "properties": {
>       "name": {
>         "type": "text",
>         "analyzer": "autocomplete",
>         "search_analyzer": "standard"
>       }
>     }
>   }
> }
> ```
> 
> **How It Works:**
> *- Index time: "Acme Corp" → ["ac", "acm", "acme", "acme ", "acme c", "acme co", ...]*
> *- Search time: "acm" → standard analyzer (no n-grams)*
> *- Match: "acm" exists in n-grams*
> 
> **Query:**
> ```json
> GET /customers/_search
> {
>   "query": {
>     "match": {
>       "name": {
>         "query": "acm",
>         "operator": "and"
>       }
>     }
>   },
>   "size": 10
> }
> ```
> 
> **Alternative: Completion Suggester (Faster for Pure Autocomplete)**
> ```json
> PUT /customers
> {
>   "mappings": {
>     "properties": {
>       "name_suggest": {
>         "type": "completion"
>       }
>     }
>   }
> }
> 
> GET /customers/_search
> {
>   "suggest": {
>     "customer-suggest": {
>       "prefix": "acm",
>       "completion": {
>         "field": "name_suggest",
>         "size": 10
>       }
>     }
>   }
> }
> ```
> 
> **Performance:**
> *- Edge n-grams: < 10ms*
> *- Completion suggester: < 5ms (optimized for autocomplete)*
> 
> **real-world use case:**
> *- Customer name autocomplete in invoice creation form*
> *- 10k customers, instant suggestions*
> *- Typo tolerance with fuzzy matching*"*

---

## Summary: Your Search Expertise

**When Asked About Search:**

> *"In a production environment, I'd implement Elasticsearch for invoice search across 10M+ invoices. We'd use an inverted index for sub-100ms queries, compared to SQL LIKE's 3-5 seconds.*
> 
> *The mapping would include full-text fields for customer name and description with English analyzer for stemming, keyword fields for status and exact invoice IDs, and date/numeric fields for range filtering.*
> 
> *For relevance, I'd boost invoice ID matches 3x and customer name 2x. We'd support fuzzy matching for typos and use bool queries combining full-text search with cached filters for status and date range.*
> 
> *For scaling, we'd shard across 5 nodes with 1 replica per shard for high availability. Bulk indexing via nightly sync from MySQL, with 30-second refresh interval.*
> 
> *This gives us Google-like search for invoices with faceted filtering, autocomplete, and audit log search."*

---

**Search systems expertise complete!** 🔍

Continuing with remaining guides...
