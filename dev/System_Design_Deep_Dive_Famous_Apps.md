# System Design Deep Dive: 5 Famous Applications

> **Master system design by understanding how the giants built their platforms**

---

## Table of Contents

1. [Email Notification System (Zero to Master)](#1-email-notification-system)
2. [Spotify (Music Streaming)](#2-spotify-music-streaming)
3. [WhatsApp (Messaging)](#3-whatsapp-messaging)
4. [Instagram (Social Media)](#4-instagram-social-media)
5. [URL Shortener (bit.ly)](#5-url-shortener)

---

# 1. Email Notification System (Zero to Master)

## Overview
Design a scalable email notification system that can handle **10 million users** sending **100 million emails/day**.

---

## Functional Requirements

1. **Send transactional emails** (password reset, order confirmation, invoice delivery)
2. **Send marketing emails** (newsletters, promotions, campaigns)
3. **Email templates** (dynamic content, personalization)
4. **Delivery tracking** (sent, delivered, opened, clicked, bounced)
5. **Retry logic** (failed deliveries)
6. **Unsubscribe management**
7. **Priority queues** (critical emails sent first)

---

## Non-Functional Requirements

1. **Throughput:** 100M emails/day = **1,157 emails/sec average**, **5,000 emails/sec peak**
2. **Latency:** Transactional emails sent within **10 seconds**, marketing emails within **1 hour**
3. **Availability:** 99.9% uptime
4. **Scalability:** Handle 10x growth (1 billion emails/day)
5. **Cost-effective:** Minimize infrastructure costs

---

## Capacity Estimation

**Emails per day:** 100M  
**Average email size:** 50 KB (HTML + images base64)  
**Storage per day:** 100M * 50 KB = **5 TB/day**  
**Storage per year:** 5 TB * 365 = **1.8 PB/year** (need retention policy)

**Bandwidth:**
- Outgoing: 1,157 emails/sec * 50 KB = **58 MB/sec** = **464 Mbps**
- Peak: 5,000 emails/sec * 50 KB = **250 MB/sec** = **2 Gbps**

**Database:**
- Users: 10M records * 1 KB = **10 GB**
- Email logs: 100M/day * 500 bytes = **50 GB/day** = **18 TB/year**

---

## API Design

### 1. Send Email
```http
POST /api/v1/emails/send
Content-Type: application/json

{
  "to": ["user@example.com"],
  "cc": ["manager@example.com"],
  "bcc": ["admin@example.com"],
  "subject": "Your invoice is ready",
  "template_id": "invoice_ready_v2",
  "template_data": {
    "user_name": "John Doe",
    "invoice_number": "INV-12345",
    "amount": "$1,250.00"
  },
  "priority": "high",  // high, normal, low
  "scheduled_at": "2026-11-20T10:00:00Z",  // optional
  "attachments": [
    {
      "filename": "invoice.pdf",
      "content_base64": "JVBERi0xLjQK..."
    }
  ]
}

Response:
{
  "email_id": "eml_7x9k2m4p",
  "status": "queued",
  "estimated_delivery": "2026-11-20T09:45:12Z"
}
```

### 2. Get Email Status
```http
GET /api/v1/emails/{email_id}

Response:
{
  "email_id": "eml_7x9k2m4p",
  "status": "delivered",  // queued, sent, delivered, opened, clicked, bounced, failed
  "sent_at": "2026-11-20T09:45:12Z",
  "delivered_at": "2026-11-20T09:45:15Z",
  "opened_at": "2026-11-20T10:12:03Z",
  "clicked_at": null,
  "bounce_reason": null,
  "retry_count": 0
}
```

### 3. Create Template
```http
POST /api/v1/templates
Content-Type: application/json

{
  "name": "invoice_ready_v2",
  "subject": "Your invoice {{invoice_number}} is ready",
  "body_html": "<html>...</html>",
  "body_text": "Plain text version..."
}
```

### 4. Unsubscribe User
```http
POST /api/v1/unsubscribe
{
  "email": "user@example.com",
  "category": "marketing"  // marketing, transactional, all
}
```

---

## Database Schema

### Users Table
```sql
CREATE TABLE users (
  user_id BIGINT PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255),
  unsubscribed_marketing BOOLEAN DEFAULT FALSE,
  unsubscribed_all BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email (email)
);
```

### Email Templates Table
```sql
CREATE TABLE email_templates (
  template_id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  subject VARCHAR(500),
  body_html TEXT,
  body_text TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Email Queue Table (Transient, Redis/RabbitMQ)
```
Key: email_queue:{priority}
Value: {
  "email_id": "eml_7x9k2m4p",
  "to": ["user@example.com"],
  "subject": "...",
  "body_html": "...",
  "priority": "high",
  "retry_count": 0,
  "scheduled_at": "2026-11-20T10:00:00Z"
}
```

### Email Logs Table (Cassandra/MongoDB)
```javascript
{
  "_id": "eml_7x9k2m4p",
  "user_id": 12345,
  "to": ["user@example.com"],
  "subject": "Your invoice is ready",
  "template_id": "invoice_ready_v2",
  "status": "delivered",
  "priority": "high",
  "sent_at": ISODate("2026-11-20T09:45:12Z"),
  "delivered_at": ISODate("2026-11-20T09:45:15Z"),
  "opened_at": ISODate("2026-11-20T10:12:03Z"),
  "clicked_at": null,
  "bounce_reason": null,
  "retry_count": 0,
  "metadata": {
    "campaign_id": "spring_sale_2026",
    "user_segment": "premium"
  }
}
```

---

## High-Level Architecture

```
┌─────────────┐
│   Web App   │
│  Mobile App │
└──────┬──────┘
       │ POST /emails/send
       ▼
┌─────────────────────────┐
│   API Gateway           │
│   (Rate Limiting)       │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│   Email Service         │
│   (Validation, Template │
│    Rendering)           │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐       ┌──────────────┐
│   RabbitMQ              │       │  Redis       │
│   3 Queues:             │◄──────│  (Dedup)     │
│   - high_priority       │       └──────────────┘
│   - normal_priority     │
│   - low_priority        │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│   Email Workers (20+)   │
│   - Fetch from queue    │
│   - Call SendGrid API   │
│   - Log delivery status │
└──────┬──────────────────┘
       │
       ├──────────► SendGrid/AWS SES/Twilio SendGrid
       │
       └──────────► Cassandra (Email Logs)
```

---

## Deep Dive: Components

### 1. **API Gateway**
- **Rate limiting:** 100 emails/sec per user (prevent spam)
- **Authentication:** API key validation
- **Load balancing:** Distribute across Email Service instances

### 2. **Email Service (Stateless)**
- **Validation:**
  - Check email format (regex)
  - Check unsubscribe list (Redis cache)
  - Check spam score (Akismet API)
- **Template rendering:**
  - Fetch template from MySQL
  - Replace `{{variables}}` with user data
  - Generate HTML + plain text versions
- **Deduplication:**
  - Check Redis: `sent:{user_id}:{template_id}:{hash}` (TTL 24h)
  - Prevent sending duplicate emails within 24 hours
- **Queue selection:**
  - `high` priority → `high_priority` queue
  - `normal` priority → `normal_priority` queue
  - `low` priority (marketing) → `low_priority` queue

### 3. **RabbitMQ (Message Queue)**
- **Why RabbitMQ?**
  - At-least-once delivery (workers ack after sending)
  - Priority queues (high-priority emails sent first)
  - Dead Letter Queue (DLQ) for failed emails
- **Configuration:**
  - `prefetch_count=10` (each worker processes 10 emails concurrently)
  - `message_ttl=3600` (1 hour, discard old marketing emails)
  - `max_retries=3` (retry failed emails 3 times)

### 4. **Email Workers (Kubernetes HPA)**
- **Scaling:**
  - Start: 10 workers
  - Auto-scale to 50 workers when queue depth > 10,000
  - Scale down to 10 when queue depth < 1,000
- **Worker logic:**
  ```python
  while True:
      email = rabbitmq.fetch_from_queue(queue='high_priority')
      
      # Call SendGrid API
      response = sendgrid.send(
          to=email['to'],
          subject=email['subject'],
          html=email['body_html']
      )
      
      # Log delivery
      cassandra.insert('email_logs', {
          'email_id': email['email_id'],
          'status': 'sent',
          'sent_at': now(),
          'sendgrid_message_id': response['message_id']
      })
      
      # Ack message
      rabbitmq.ack(email)
  ```

### 5. **SendGrid/AWS SES (Email Provider)**
- **Why external provider?**
  - Deliverability (IP reputation, SPF/DKIM setup)
  - Bounce handling (they track bounces, not us)
  - Cost-effective ($0.10 per 1,000 emails)
- **Webhooks:**
  - SendGrid sends webhooks for: `delivered`, `opened`, `clicked`, `bounced`
  - We update Cassandra via webhook handler

### 6. **Cassandra (Email Logs)**
- **Why Cassandra?**
  - Write-heavy (100M writes/day)
  - Time-series data (query by date range)
  - Horizontal scaling (add nodes easily)
- **Data model:**
  - Partition key: `user_id` (all emails for a user in one partition)
  - Clustering key: `sent_at DESC` (newest first)
  - TTL: 90 days (auto-delete old logs)

---

## Bottlenecks & Solutions

### Bottleneck 1: **SendGrid Rate Limit (5,000 emails/sec)**
**Solution:**
- Use multiple email providers (SendGrid + AWS SES + Mailgun)
- Round-robin distribution
- Fallback if one provider is down

### Bottleneck 2: **Template Rendering is Slow (CPU-intensive)**
**Solution:**
- Pre-render common templates and cache in Redis
- Use template engine with compiled templates (Jinja2)

### Bottleneck 3: **Database Writes are Expensive (100M logs/day)**
**Solution:**
- Batch writes (buffer 1,000 logs, write every 10 seconds)
- Use Cassandra's native batch insert

### Bottleneck 4: **Duplicate Emails Sent (Race Condition)**
**Solution:**
- Redis deduplication: `SET sent:{user}:{template}:{hash} 1 EX 86400 NX`
- `NX` ensures only one worker sets the key

---

## Scaling Strategies

### Stage 1: **MVP (10k emails/day)**
- Single server (Flask + Celery + PostgreSQL)
- SendGrid for delivery
- Cost: $50/month

### Stage 2: **Growth (1M emails/day)**
- Kubernetes (5 worker pods)
- RabbitMQ for queuing
- PostgreSQL for logs (partitioned by month)
- Cost: $500/month

### Stage 3: **Scale (100M emails/day)**
- Kubernetes HPA (10-50 worker pods)
- Cassandra for logs (3-node cluster)
- Redis for caching + dedup
- Multi-provider (SendGrid + AWS SES)
- Cost: $5,000/month

### Stage 4: **Hyper-Scale (1B emails/day)**
- Kafka instead of RabbitMQ (higher throughput)
- Cassandra (10-node cluster)
- Regional deployments (US, EU, Asia)
- Cost: $50,000/month

---

## Interview 2-Minute Answer

**Interviewer:** "Design an email notification system for 100M emails/day."

**Your Answer:**

"I'd design a **queue-based architecture** with three main components:

**1. API Layer:**
- API Gateway validates requests, checks rate limits, and routes to Email Service
- Email Service renders templates, deduplicates (Redis), and pushes to RabbitMQ

**2. Queue Layer (RabbitMQ):**
- **3 priority queues**: high (transactional), normal, low (marketing)
- Workers auto-scale 10-50 pods based on queue depth via Kubernetes HPA
- At-least-once delivery with ack after sending

**3. Email Providers:**
- SendGrid/AWS SES for actual delivery ($0.10 per 1,000 emails)
- Multiple providers for redundancy (round-robin)

**4. Logging (Cassandra):**
- Write-heavy workload (100M logs/day)
- Time-series data (partition by user_id, cluster by sent_at DESC)
- 90-day TTL to auto-delete old logs

**Scaling:**
- **100M emails/day** = 1,157/sec avg, 5,000/sec peak
- 10 workers handle 1,157/sec easily (each worker: 100 emails/sec)
- Auto-scale to 50 workers during peak

**Key Design Choices:**
- RabbitMQ for priority queues (not Kafka, overkill for this throughput)
- Cassandra for logs (not MySQL, write-heavy)
- External providers (not SMTP server, deliverability issues)

**Bottleneck:** SendGrid rate limit (5,000/sec). Solution: Multi-provider.

At Billtrust, we handle similar invoice delivery workflows using RabbitMQ + S3 + email workers, processing 100k invoices/month."

---

# 2. Spotify (Music Streaming)

## Overview
Design Spotify: **400M users**, **100M songs**, **10B streams/month**.

---

## Functional Requirements

1. **User management** (signup, login, profiles)
2. **Music catalog** (100M songs, metadata, albums, artists)
3. **Search** (songs, artists, albums, playlists)
4. **Playlists** (create, edit, follow, collaborative)
5. **Audio streaming** (adaptive bitrate, offline mode)
6. **Recommendations** (personalized playlists, Discover Weekly)
7. **Social features** (follow artists, share songs, collaborative playlists)

---

## Non-Functional Requirements

1. **Latency:** Song starts playing within **200ms** of clicking play
2. **Availability:** 99.99% uptime (4 minutes downtime/month)
3. **Scalability:** Handle 10M concurrent streams
4. **Storage:** 100M songs * 10 MB = **1 PB** of audio files
5. **Bandwidth:** 10M streams * 320 kbps = **3.2 Tbps** = **400 GB/sec**

---

## Capacity Estimation

**Users:** 400M  
**Active users:** 200M (50%)  
**Daily active users (DAU):** 100M (25%)

**Songs:** 100M  
**Average song size:** 10 MB (320 kbps, 4 min)  
**Total storage:** 100M * 10 MB = **1 PB**

**Streams per month:** 10B  
**Streams per day:** 10B / 30 = **333M/day**  
**Concurrent streams:** 333M / 86,400 sec = **3,858/sec** (average)  
**Peak concurrent streams:** 10M (during popular album releases)

**Bandwidth per stream:** 320 kbps = **40 KB/sec**  
**Total bandwidth:** 10M streams * 40 KB/sec = **400 GB/sec** = **3.2 Tbps**

---

## API Design

### 1. Search Songs
```http
GET /api/v1/search?q=Shape+of+You&type=song&limit=20

Response:
{
  "songs": [
    {
      "song_id": "song_7x9k2m",
      "title": "Shape of You",
      "artist": "Ed Sheeran",
      "album": "÷ (Divide)",
      "duration_sec": 233,
      "cover_art_url": "https://cdn.spotify.com/covers/song_7x9k2m.jpg",
      "audio_url": "https://cdn.spotify.com/audio/song_7x9k2m_320kbps.mp3"
    }
  ],
  "total": 1,
  "offset": 0,
  "limit": 20
}
```

### 2. Get Song Stream URL
```http
GET /api/v1/songs/{song_id}/stream?quality=high

Response:
{
  "stream_url": "https://cdn-us-west.spotify.com/audio/song_7x9k2m_320kbps.mp3?token=xyz",
  "expires_in": 3600,
  "bitrates": {
    "low": "96kbps",
    "normal": "160kbps",
    "high": "320kbps"
  }
}
```

### 3. Create Playlist
```http
POST /api/v1/playlists
{
  "name": "Workout Mix",
  "description": "High-energy songs for the gym",
  "public": true,
  "song_ids": ["song_7x9k2m", "song_abc123"]
}

Response:
{
  "playlist_id": "pl_xyz789",
  "name": "Workout Mix",
  "created_at": "2026-11-20T10:00:00Z"
}
```

### 4. Get Recommendations
```http
GET /api/v1/recommendations?user_id=12345

Response:
{
  "playlists": [
    {
      "playlist_id": "discover_weekly_12345",
      "name": "Discover Weekly",
      "songs": [...]
    },
    {
      "playlist_id": "daily_mix_1_12345",
      "name": "Daily Mix 1",
      "songs": [...]
    }
  ]
}
```

---

## Database Schema

### Users Table (PostgreSQL)
```sql
CREATE TABLE users (
  user_id BIGINT PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(50) UNIQUE NOT NULL,
  password_hash VARCHAR(255),
  subscription_type VARCHAR(20),  -- free, premium
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email (email),
  INDEX idx_username (username)
);
```

### Songs Table (PostgreSQL)
```sql
CREATE TABLE songs (
  song_id VARCHAR(50) PRIMARY KEY,
  title VARCHAR(500) NOT NULL,
  artist_id BIGINT,
  album_id BIGINT,
  duration_sec INT,
  release_date DATE,
  genre VARCHAR(100),
  cover_art_url VARCHAR(1000),
  audio_file_path VARCHAR(1000),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_artist (artist_id),
  INDEX idx_album (album_id),
  INDEX idx_title (title)
);
```

### Playlists Table (PostgreSQL)
```sql
CREATE TABLE playlists (
  playlist_id VARCHAR(50) PRIMARY KEY,
  user_id BIGINT,
  name VARCHAR(500),
  description TEXT,
  public BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id)
);

CREATE TABLE playlist_songs (
  playlist_id VARCHAR(50),
  song_id VARCHAR(50),
  position INT,
  added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (playlist_id, song_id),
  INDEX idx_playlist (playlist_id)
);
```

### Listening History (Cassandra)
```javascript
{
  "_id": "listen_xyz123",
  "user_id": 12345,
  "song_id": "song_7x9k2m",
  "played_at": ISODate("2026-11-20T10:12:03Z"),
  "duration_played_sec": 180,  // listened for 3 min out of 4 min song
  "skipped": false,
  "device": "mobile_ios"
}
```

---

## High-Level Architecture

```
┌─────────────┐
│   Mobile    │
│   Web App   │
└──────┬──────┘
       │
       ▼
┌─────────────────────────┐
│   API Gateway           │
│   (Auth, Rate Limiting) │
└──────┬──────────────────┘
       │
       ├──► Search Service (Elasticsearch)
       │
       ├──► Metadata Service (PostgreSQL: songs, artists, albums)
       │
       ├──► Playlist Service (PostgreSQL)
       │
       ├──► Recommendation Service (ML models, Cassandra listening history)
       │
       └──► Stream Service (generates CDN URLs)
                │
                ▼
         ┌──────────────────┐
         │   CDN (Akamai)   │
         │   - Audio files  │
         │   - 1 PB storage │
         └──────────────────┘
```

---

## Deep Dive: Streaming

### Challenge: **10M concurrent streams * 40 KB/sec = 400 GB/sec bandwidth**

### Solution: **Multi-CDN + Adaptive Bitrate**

**1. Audio Storage (S3):**
- Original: 320 kbps FLAC files (master quality)
- Transcoded: 320 kbps MP3, 160 kbps MP3, 96 kbps MP3
- Stored in S3 (US, EU, Asia regions)

**2. CDN (Akamai/CloudFront):**
- Push audio files to CDN edge servers (1,000+ locations worldwide)
- User requests nearest CDN server (latency < 50ms)

**3. Adaptive Bitrate (HLS/DASH):**
- Monitor user's bandwidth
- Start with 96 kbps (loads fast)
- Upgrade to 320 kbps if bandwidth allows
- Downgrade if buffering occurs

**4. Pre-caching Popular Songs:**
- Top 10,000 songs (10% of streams) cached on all CDN nodes
- Long tail (remaining 100M songs) cached on-demand

---

## Deep Dive: Recommendations

### Challenge: **Personalize playlists for 400M users**

### Solution: **Collaborative Filtering + ML**

**1. Listening History (Cassandra):**
- Store every stream: `{user_id, song_id, played_at, duration_played}`
- Query: "What did user 12345 listen to in the last 30 days?"

**2. Collaborative Filtering:**
- Find users similar to you (based on listening overlap)
- Recommend songs they liked but you haven't heard

**3. ML Models (TensorFlow):**
- **Input:** User's listening history (last 1,000 songs)
- **Output:** 100 recommended songs
- **Training:** Nightly batch job (Spark on 10B streams/month data)

**4. Discover Weekly:**
- Generated every Monday
- Pre-computed and stored in Redis (fast access)
- Expires after 7 days

---

## Bottlenecks & Solutions

### Bottleneck 1: **Search is Slow (100M songs)**
**Solution:**
- Elasticsearch cluster (10 nodes)
- Index songs by title, artist, album, genre
- Query time: < 50ms

### Bottleneck 2: **Recommendation Computation is Expensive**
**Solution:**
- Pre-compute recommendations nightly (Spark job)
- Store in Redis (key: `user_id`, value: [song_ids])
- Serve from cache (no real-time computation)

### Bottleneck 3: **CDN Costs ($0.08 per GB transferred)**
**Solution:**
- 10M streams * 10 MB/stream = 100 TB/day = $8,000/day = $240k/month
- Negotiate bulk pricing with CDN provider ($0.02 per GB)

---

## Interview 2-Minute Answer

"Spotify is a **metadata-heavy + CDN-heavy** architecture.

**Core components:**

**1. Metadata (PostgreSQL):**
- Songs, artists, albums, playlists
- 100M songs, indexed by title/artist for search

**2. Search (Elasticsearch):**
- 10-node cluster, 100M songs indexed
- Query time < 50ms

**3. Streaming (Multi-CDN):**
- Audio stored in S3 (1 PB), transcoded to 320/160/96 kbps
- CDN (Akamai) serves from 1,000+ edge servers worldwide
- Adaptive bitrate (start 96 kbps, upgrade to 320 kbps)
- Pre-cache top 10k songs on all nodes

**4. Recommendations (ML):**
- Listening history in Cassandra (10B streams/month)
- Nightly Spark job trains TensorFlow model
- Discover Weekly pre-computed, stored in Redis

**Scaling:**
- **10M concurrent streams:** CDN handles bandwidth (400 GB/sec)
- **Search:** Elasticsearch scales horizontally
- **Metadata:** PostgreSQL read replicas (10 replicas)

**Key design choice:** CDN for streaming (not origin servers). Without CDN, 400 GB/sec bandwidth would cost $1M/month. With CDN: $60k/month."

---

# 3. WhatsApp (Messaging)

## Overview
Design WhatsApp: **2 billion users**, **100 billion messages/day**.

---

## Functional Requirements

1. **1-on-1 messaging** (text, images, videos, voice notes)
2. **Group messaging** (up to 256 members)
3. **Online/offline status** (last seen)
4. **Message delivery receipts** (sent, delivered, read)
5. **End-to-end encryption** (Signal Protocol)
6. **Media sharing** (images, videos, documents)
7. **Voice/video calls**

---

## Non-Functional Requirements

1. **Latency:** Message delivered within **100ms**
2. **Availability:** 99.99% uptime
3. **Consistency:** Eventual consistency OK (messages may arrive out of order)
4. **Scalability:** Handle 2B users, 100B messages/day
5. **Storage:** 100B messages/day * 1 KB = **100 TB/day** = **36 PB/year**

---

## Capacity Estimation

**Users:** 2B  
**Daily active users:** 1B  
**Messages per day:** 100B  
**Messages per second:** 100B / 86,400 = **1.16M messages/sec** (average)  
**Peak:** 5M messages/sec

**Message size:** 1 KB (text + metadata)  
**Storage per day:** 100B * 1 KB = **100 TB/day**  
**Storage per year:** 36 PB (need retention policy)

**Media messages:** 20% of messages  
**Average media size:** 500 KB  
**Media storage per day:** 20B * 500 KB = **10 PB/day**

---

## API Design

### 1. Send Message
```http
POST /api/v1/messages/send
{
  "from_user_id": 12345,
  "to_user_id": 67890,
  "message_type": "text",  // text, image, video, voice
  "content": "Hello!",
  "encrypted_content": "base64_encrypted_payload",
  "timestamp": "2026-11-20T10:00:00Z"
}

Response:
{
  "message_id": "msg_xyz123",
  "status": "sent",
  "timestamp": "2026-11-20T10:00:00.123Z"
}
```

### 2. Receive Messages (WebSocket)
```javascript
// Client maintains persistent WebSocket connection
ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  
  {
    "message_id": "msg_xyz123",
    "from_user_id": 67890,
    "to_user_id": 12345,
    "message_type": "text",
    "encrypted_content": "base64_encrypted_payload",
    "timestamp": "2026-11-20T10:00:01Z"
  }
  
  // Decrypt locally
  const plaintext = decrypt(message.encrypted_content, private_key);
  displayMessage(plaintext);
  
  // Send delivery receipt
  ws.send(JSON.stringify({
    type: "delivery_receipt",
    message_id: message.message_id,
    status: "delivered"
  }));
};
```

### 3. Upload Media
```http
POST /api/v1/media/upload
Content-Type: multipart/form-data

file: image.jpg (5 MB)

Response:
{
  "media_id": "media_abc123",
  "media_url": "https://cdn.whatsapp.com/media/media_abc123.jpg",
  "thumbnail_url": "https://cdn.whatsapp.com/media/media_abc123_thumb.jpg"
}
```

---

## Database Schema

### Users Table (Cassandra)
```javascript
{
  "user_id": 12345,
  "phone_number": "+1234567890",
  "username": "John Doe",
  "profile_pic_url": "https://cdn.whatsapp.com/profiles/12345.jpg",
  "status": "Hey there! I am using WhatsApp",
  "last_seen": ISODate("2026-11-20T10:12:03Z"),
  "online": true,
  "created_at": ISODate("2020-01-15T10:00:00Z")
}
```

### Messages Table (Cassandra)
```javascript
// Partition key: conversation_id (sorted by timestamp)
{
  "message_id": "msg_xyz123",
  "conversation_id": "conv_12345_67890",  // sorted pair: min(user1, user2)_max(user1, user2)
  "from_user_id": 12345,
  "to_user_id": 67890,
  "message_type": "text",
  "encrypted_content": "base64_encrypted_payload",
  "timestamp": ISODate("2026-11-20T10:00:00Z"),
  "status": "delivered",  // sent, delivered, read
  "read_at": ISODate("2026-11-20T10:05:00Z")
}
```

### Group Chats Table (Cassandra)
```javascript
{
  "group_id": "grp_abc123",
  "name": "Family Group",
  "admin_user_ids": [12345],
  "member_user_ids": [12345, 67890, 11111],
  "created_at": ISODate("2025-06-10T10:00:00Z")
}
```

---

## High-Level Architecture

```
┌─────────────┐
│   Mobile    │
│   App       │
└──────┬──────┘
       │ WebSocket (persistent connection)
       ▼
┌─────────────────────────┐
│   API Gateway           │
│   (WebSocket Manager)   │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐       ┌──────────────┐
│   Chat Service          │◄──────│  Redis       │
│   - Route messages      │       │  (Online     │
│   - Delivery receipts   │       │   Users)     │
└──────┬──────────────────┘       └──────────────┘
       │
       ├──► Message Queue (Kafka)
       │
       ▼
┌─────────────────────────┐
│   Message Storage       │
│   (Cassandra)           │
│   - 36 PB/year          │
└─────────────────────────┘
```

---

## Deep Dive: Real-Time Messaging

### Challenge: **1.16M messages/sec, delivered within 100ms**

### Solution: **WebSocket + Kafka + Cassandra**

**1. WebSocket Connection:**
- Each user maintains persistent WebSocket to nearest Chat Server
- 2B users / 100k connections per server = **20,000 Chat Servers**

**2. Message Flow:**
```
User A sends message:
  1. App encrypts message locally (end-to-end encryption)
  2. Sends via WebSocket to Chat Server 1
  3. Chat Server 1 checks Redis: Is User B online?
     - YES: Forward directly to Chat Server 2 (where User B is connected)
     - NO: Push to Kafka (User B will fetch when online)
  4. Chat Server 2 delivers to User B via WebSocket
  5. User B sends "delivered" receipt → Chat Server 2 → Chat Server 1 → User A
  6. Total time: 50-100ms
```

**3. Offline Message Storage (Kafka):**
- If User B is offline, message stays in Kafka queue
- When User B comes online, Chat Server fetches undelivered messages
- Kafka retains messages for 7 days (then deleted)

**4. Persistent Storage (Cassandra):**
- All messages written to Cassandra (asynchronously)
- Partition key: `conversation_id` (all messages for a conversation in one partition)
- Clustering key: `timestamp DESC` (newest first)
- TTL: 90 days (auto-delete old messages)

---

## Deep Dive: End-to-End Encryption

### Challenge: **WhatsApp servers cannot read message content**

### Solution: **Signal Protocol**

**1. Key Exchange (Initial Setup):**
```
User A generates:
  - Identity Key Pair (long-term)
  - Signed Pre-Key (rotated weekly)
  - One-Time Pre-Keys (100 keys, used once)

User A uploads Public Keys to WhatsApp Server

User B wants to message User A:
  1. Fetches User A's public keys from server
  2. Generates session key using Diffie-Hellman
  3. Encrypts message with session key
  4. Sends encrypted message + signature
```

**2. Message Encryption:**
```
Plaintext: "Hello!"
↓
Encrypted with AES-256 (session key)
↓
Encrypted Content: "xK9mP2n..."
↓
Sent to server
```

**3. Server's Role:**
- **Cannot decrypt** (no private keys)
- Only routes encrypted payload
- Metadata visible: sender, receiver, timestamp (but not content)

---

## Bottlenecks & Solutions

### Bottleneck 1: **20k Chat Servers, Each Maintaining 100k WebSocket Connections**
**Solution:**
- Use Erlang (WhatsApp's original choice) or Go (handles 1M connections/server)
- Reduce to 2,000 servers (each handling 1M connections)

### Bottleneck 2: **Finding Which Server a User is Connected To**
**Solution:**
- Redis: `user_id → server_id` mapping
- When User A sends message to User B:
  1. Check Redis: Which server is User B on?
  2. Forward message to that server

### Bottleneck 3: **100 TB/day Cassandra Writes**
**Solution:**
- Cassandra is write-optimized (append-only logs)
- 100-node Cassandra cluster handles 1.16M writes/sec easily

---

## Interview 2-Minute Answer

"WhatsApp is a **WebSocket-based real-time messaging system** with end-to-end encryption.

**Core components:**

**1. WebSocket Servers (2,000 servers):**
- Each server handles 1M persistent connections
- User A sends message → Chat Server 1 checks Redis for User B's server → forwards to Chat Server 2 → User B receives

**2. Redis (Online Users):**
- Stores `user_id → server_id` mapping
- Fast lookup (< 1ms) to route messages

**3. Kafka (Offline Queue):**
- If User B is offline, message stays in Kafka
- When User B comes online, fetch undelivered messages
- Retains messages for 7 days

**4. Cassandra (Persistent Storage):**
- 100B messages/day = 100 TB/day
- Partition key: `conversation_id`, clustering: `timestamp DESC`
- 90-day TTL (auto-delete old messages)

**5. End-to-End Encryption (Signal Protocol):**
- Messages encrypted on sender's device, decrypted on receiver's device
- WhatsApp servers only route encrypted payload (cannot read content)

**Scaling:**
- **1.16M messages/sec:** Kafka handles writes, Cassandra persists
- **2B users:** 2,000 servers * 1M connections each
- **100 TB/day storage:** Cassandra's strength (write-heavy, horizontal scaling)

**Key design choice:** WebSocket (not HTTP polling). Polling would require 2B users polling every second = 2B requests/sec. WebSocket: persistent connection, messages pushed instantly."

---

# 4. Instagram (Social Media)

## Overview
Design Instagram: **1 billion users**, **500M daily active users (DAU)**, **95M photos/day**.

---

## Functional Requirements

1. **User profiles** (signup, login, bio, profile pic)
2. **Photo/video upload** (max 10 photos per post, 60-sec videos)
3. **Feed generation** (chronological + algorithmic)
4. **Follow/unfollow** users
5. **Like/comment** on posts
6. **Stories** (24-hour expiry)
7. **Explore page** (trending posts)
8. **Hashtags & search**

---

## Non-Functional Requirements

1. **Latency:** Feed loads within **500ms**
2. **Availability:** 99.99% uptime
3. **Scalability:** Handle 500M DAU, 95M photos/day
4. **Storage:** 95M photos/day * 2 MB = **190 TB/day** = **70 PB/year**

---

## Capacity Estimation

**Users:** 1B  
**DAU:** 500M  
**Posts per day:** 95M  
**Average photo size:** 2 MB  
**Storage per day:** 95M * 2 MB = **190 TB/day**

**Feed reads:** 500M users * 10 feed loads/day = **5B feed loads/day**  
**Feed reads per second:** 5B / 86,400 = **57,870/sec**

---

## API Design

### 1. Upload Photo
```http
POST /api/v1/posts
Content-Type: multipart/form-data

photos: [image1.jpg, image2.jpg]
caption: "Beautiful sunset 🌅"
hashtags: ["#sunset", "#nature"]

Response:
{
  "post_id": "post_xyz123",
  "photo_urls": [
    "https://cdn.instagram.com/photos/post_xyz123_1.jpg",
    "https://cdn.instagram.com/photos/post_xyz123_2.jpg"
  ],
  "created_at": "2026-11-20T18:30:00Z"
}
```

### 2. Get Feed
```http
GET /api/v1/feed?user_id=12345&offset=0&limit=20

Response:
{
  "posts": [
    {
      "post_id": "post_xyz123",
      "user_id": 67890,
      "username": "john_doe",
      "profile_pic": "https://cdn.instagram.com/profiles/67890.jpg",
      "photo_urls": ["https://cdn.instagram.com/photos/post_xyz123_1.jpg"],
      "caption": "Beautiful sunset 🌅",
      "likes_count": 1234,
      "comments_count": 56,
      "created_at": "2026-11-20T18:30:00Z"
    }
  ],
  "next_offset": 20
}
```

### 3. Like Post
```http
POST /api/v1/posts/{post_id}/like
{
  "user_id": 12345
}

Response:
{
  "liked": true,
  "likes_count": 1235
}
```

### 4. Add Comment
```http
POST /api/v1/posts/{post_id}/comments
{
  "user_id": 12345,
  "text": "Amazing photo!"
}

Response:
{
  "comment_id": "cmt_abc123",
  "created_at": "2026-11-20T18:32:00Z"
}
```

---

## Database Schema

### Users Table (PostgreSQL)
```sql
CREATE TABLE users (
  user_id BIGINT PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255),
  full_name VARCHAR(255),
  bio TEXT,
  profile_pic_url VARCHAR(1000),
  followers_count INT DEFAULT 0,
  following_count INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_username (username)
);
```

### Posts Table (PostgreSQL)
```sql
CREATE TABLE posts (
  post_id VARCHAR(50) PRIMARY KEY,
  user_id BIGINT,
  caption TEXT,
  photo_urls JSON,  -- Array of photo URLs
  likes_count INT DEFAULT 0,
  comments_count INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_created (user_id, created_at DESC)
);
```

### Follows Table (PostgreSQL)
```sql
CREATE TABLE follows (
  follower_user_id BIGINT,
  followee_user_id BIGINT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (follower_user_id, followee_user_id),
  INDEX idx_follower (follower_user_id),
  INDEX idx_followee (followee_user_id)
);
```

### Likes Table (Cassandra)
```javascript
{
  "post_id": "post_xyz123",
  "user_id": 12345,
  "created_at": ISODate("2026-11-20T18:32:00Z")
}
// Partition key: post_id
// Clustering key: user_id
```

### Feed Cache (Redis)
```
Key: feed:12345
Value: ["post_xyz123", "post_abc456", "post_def789", ...]
TTL: 5 minutes
```

---

## High-Level Architecture

```
┌─────────────┐
│   Mobile    │
│   Web App   │
└──────┬──────┘
       │
       ▼
┌─────────────────────────┐
│   API Gateway           │
└──────┬──────────────────┘
       │
       ├──► Photo Upload Service → S3 (70 PB) → CDN
       │
       ├──► Feed Generation Service → Redis (feed cache)
       │
       ├──► Graph Service (follows) → PostgreSQL
       │
       └──► Timeline Service (posts) → PostgreSQL + Cassandra (likes)
```

---

## Deep Dive: Feed Generation

### Challenge: **57,870 feed loads/sec, must load within 500ms**

### Solution: **Fan-Out on Write + Redis Cache**

**Two Approaches:**

### Approach 1: **Fan-Out on Read** (Bad for Instagram)
```
User A requests feed:
  1. Find all users A follows (100 users)
  2. Fetch recent posts from each (100 queries)
  3. Merge and sort by timestamp
  4. Return top 20

Problem: 100 queries per feed load = too slow (> 1 second)
```

### Approach 2: **Fan-Out on Write** (Instagram's Choice)
```
User B posts a photo:
  1. Find all of B's followers (1M followers)
  2. For each follower, add post_id to their feed cache (Redis)
  3. Redis: LPUSH feed:follower_id post_xyz123

User A requests feed:
  1. Redis: LRANGE feed:12345 0 19 (20 posts)
  2. Fetch post metadata (20 queries, can batch)
  3. Total time: < 100ms

Problem: If User B has 1M followers, need 1M Redis writes
Solution: Async workers (Celery) write to Redis in background
```

### Hybrid Approach (For Celebrities):
- **Regular users** (< 10k followers): Fan-out on write
- **Celebrities** (> 10k followers): Fan-out on read (don't cache their feeds)

---

## Deep Dive: Photo Storage

### Challenge: **95M photos/day * 2 MB = 190 TB/day**

### Solution: **S3 + CDN + Image Optimization**

**1. Upload:**
```
User uploads 2 MB photo:
  1. API receives photo
  2. Generate 5 versions:
     - Original: 2 MB
     - Large: 1080px, 500 KB
     - Medium: 640px, 150 KB
     - Small: 320px, 50 KB
     - Thumbnail: 150px, 10 KB
  3. Upload all 5 to S3 (3 MB total per photo)
  4. Return CDN URLs
```

**2. Storage:**
- S3: 95M photos/day * 3 MB = **285 TB/day** = **104 PB/year**
- S3 cost: $0.023 per GB = $2,392/TB = $248k/month

**3. CDN (CloudFront):**
- Push images to CDN (1,000+ edge servers)
- User requests thumbnail → served from nearest CDN (< 50ms)

---

## Bottlenecks & Solutions

### Bottleneck 1: **Feed Generation for Celebrities (10M followers)**
**Solution:**
- Don't fan-out on write for celebrities
- When User A (following a celebrity) requests feed:
  - Fetch A's cached feed (regular users)
  - Fetch celebrity's recent posts (on-demand)
  - Merge and return

### Bottleneck 2: **Likes Counter is a Hot Spot (Viral Post with 10M likes)**
**Solution:**
- Don't increment `likes_count` in real-time
- Write likes to Cassandra (append-only)
- Background job aggregates likes every 10 seconds
- Display approximate count ("10M likes" not "10,234,567 likes")

### Bottleneck 3: **Photo Storage Costs (104 PB/year)**
**Solution:**
- Compress old photos (> 1 year old)
- Move to Glacier (10x cheaper than S3)
- Delete original version (keep only large/medium/small)

---

## Interview 2-Minute Answer

"Instagram is a **fan-out on write** architecture for feed generation.

**Core components:**

**1. Photo Upload:**
- User uploads 2 MB photo → API generates 5 versions (original, large, medium, small, thumbnail)
- Upload to S3 (104 PB/year) → push to CDN (CloudFront)

**2. Feed Generation (Fan-Out on Write):**
- When User B posts, async workers add `post_id` to all followers' feed caches (Redis)
- 1M followers = 1M Redis writes (background job, doesn't block user)
- When User A requests feed: `LRANGE feed:12345 0 19` (20 posts) → < 100ms

**3. Hybrid for Celebrities:**
- Regular users (< 10k followers): Fan-out on write
- Celebrities (> 10k followers): Fan-out on read (fetch on-demand)

**4. Graph Service (Follows):**
- PostgreSQL stores `follows` table
- Indexed by `follower_user_id` and `followee_user_id`

**5. Likes/Comments (Cassandra):**
- Write-heavy (1M likes/sec on viral posts)
- Cassandra: append-only, horizontal scaling

**Scaling:**
- **57,870 feed loads/sec:** Redis handles (each load = 1 LRANGE command)
- **95M photos/day:** S3 + CDN
- **Hot posts (10M likes):** Approximate counts, background aggregation

**Key design choice:** Fan-out on write (not fan-out on read). Pre-compute feeds, serve from cache. Trade-off: Higher write cost (1M Redis writes per celebrity post) but lightning-fast feed loads (< 100ms)."

---

# 5. URL Shortener (bit.ly)

## Overview
Design bit.ly: **Shorten 1 billion URLs**, handle **10 billion clicks/month**.

---

## Functional Requirements

1. **Shorten URL** (long URL → short URL)
2. **Redirect** (short URL → original URL)
3. **Analytics** (click count, geographic distribution, referrers)
4. **Custom short URLs** (optional)
5. **Expiration** (optional, e.g., 30 days)

---

## Non-Functional Requirements

1. **Latency:** Redirect within **50ms**
2. **Availability:** 99.99% uptime
3. **Scalability:** 1B URLs, 10B clicks/month
4. **Short URL length:** 7 characters max (e.g., `bit.ly/abc123`)

---

## Capacity Estimation

**URLs shortened per month:** 100M  
**URLs per second:** 100M / (30 * 86,400) = **38/sec**

**Clicks per month:** 10B  
**Clicks per second:** 10B / (30 * 86,400) = **3,858/sec**

**Read:Write ratio:** 3,858 / 38 = **100:1** (read-heavy)

**Storage:**
- URL table: 1B URLs * 500 bytes = **500 GB**
- Click logs: 10B clicks/month * 200 bytes = **2 TB/month** = **24 TB/year**

---

## API Design

### 1. Shorten URL
```http
POST /api/v1/shorten
{
  "long_url": "https://example.com/very/long/article?id=12345",
  "custom_short_code": "my-article",  // optional
  "expires_in_days": 30  // optional
}

Response:
{
  "short_url": "https://bit.ly/abc123",
  "long_url": "https://example.com/very/long/article?id=12345",
  "created_at": "2026-11-20T10:00:00Z",
  "expires_at": "2026-12-20T10:00:00Z"
}
```

### 2. Redirect
```http
GET /abc123

Response: HTTP 302 Redirect
Location: https://example.com/very/long/article?id=12345
```

### 3. Get Analytics
```http
GET /api/v1/analytics/abc123

Response:
{
  "short_code": "abc123",
  "long_url": "https://example.com/...",
  "total_clicks": 1234567,
  "clicks_by_country": {
    "US": 500000,
    "IN": 300000,
    "UK": 200000
  },
  "clicks_by_referrer": {
    "twitter.com": 400000,
    "facebook.com": 300000,
    "direct": 200000
  },
  "clicks_over_time": [
    {"date": "2026-11-20", "clicks": 10000},
    {"date": "2026-11-21", "clicks": 12000}
  ]
}
```

---

## Database Schema

### URLs Table (PostgreSQL)
```sql
CREATE TABLE urls (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  short_code VARCHAR(10) UNIQUE NOT NULL,
  long_url TEXT NOT NULL,
  user_id BIGINT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP,
  total_clicks BIGINT DEFAULT 0,
  INDEX idx_short_code (short_code)
);
```

### Clicks Table (Cassandra)
```javascript
{
  "click_id": "click_xyz123",
  "short_code": "abc123",
  "clicked_at": ISODate("2026-11-20T10:12:03Z"),
  "ip_address": "203.0.113.42",
  "country": "US",
  "referrer": "https://twitter.com",
  "user_agent": "Mozilla/5.0..."
}
```

---

## High-Level Architecture

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ GET /abc123
       ▼
┌─────────────────────────┐
│   API Gateway           │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐       ┌──────────────┐
│   Redirect Service      │◄──────│  Redis       │
│   (Fetch long_url)      │       │  (Cache)     │
└──────┬──────────────────┘       └──────────────┘
       │
       ├──► PostgreSQL (URLs table)
       │
       └──► Kafka (Click events) → Cassandra (Click logs)
```

---

## Deep Dive: Short Code Generation

### Challenge: **Generate unique 7-character short codes for 1B URLs**

### Options:

### Option 1: **Hash (MD5/SHA256)**
```
long_url = "https://example.com/..."
hash = md5(long_url) = "5d41402abc4b2a76b9719d911017c592"
short_code = hash[:7] = "5d41402"

Problem: Collisions (two URLs hash to same short_code)
Solution: If collision, increment: "5d41402" → "5d41403"
```

### Option 2: **Base62 Encoding (Instagram's Approach)**
```
Database auto-increment ID: 123456789
Convert to Base62: "8M0kX"

Base62 characters: [a-zA-Z0-9] = 62 characters
7 characters = 62^7 = 3.5 trillion unique codes

Formula:
  ID 1 → "b"
  ID 62 → "10"
  ID 123456789 → "8M0kX"
```

**Instagram's Choice:** Base62 encoding (no collisions, deterministic)

---

## Deep Dive: Redirect Performance

### Challenge: **3,858 redirects/sec, must respond within 50ms**

### Solution: **Redis Cache**

**Flow:**
```
User clicks bit.ly/abc123:
  1. Check Redis: GET short_code:abc123
     - HIT: Return long_url (10ms)
     - MISS: Query PostgreSQL → Cache in Redis (TTL 24h) → Return (50ms)
  2. Send 302 Redirect to browser
  3. Async: Kafka.publish({short_code: "abc123", clicked_at: now(), ip: "..."})
```

**Cache hit ratio:** 95% (popular links clicked repeatedly)  
**Redis throughput:** 100k reads/sec per node (3,858/sec is trivial)

---

## Deep Dive: Analytics

### Challenge: **Track 10B clicks/month without slowing down redirects**

### Solution: **Kafka + Cassandra (Async)**

**Flow:**
```
Redirect Service:
  1. Fetch long_url (from Redis/PostgreSQL)
  2. Send 302 Redirect (don't wait for analytics)
  3. Kafka.publish(click_event)  ← Fire-and-forget

Background Workers:
  1. Consume from Kafka
  2. Write to Cassandra (clicks table)
  3. Aggregate every 10 minutes:
     - Total clicks per short_code
     - Clicks by country
     - Clicks by referrer
  4. Update PostgreSQL: urls.total_clicks += N
```

**Why Cassandra?**
- Write-heavy (10B writes/month)
- Time-series data (partition by `short_code`, cluster by `clicked_at`)

---

## Bottlenecks & Solutions

### Bottleneck 1: **Hot Short URLs (Viral Tweet with 10M clicks/hour)**
**Solution:**
- Redis cache handles 100k reads/sec (10M clicks/hour = 2,778/sec → trivial)
- Multiple Redis replicas (read from replicas)

### Bottleneck 2: **Short Code Exhaustion (7 characters)**
**Solution:**
- 62^7 = 3.5 trillion codes
- 1B URLs = 0.03% utilization (not a problem)
- If we ever reach 1 trillion URLs, increase to 8 characters (62^8 = 218 trillion)

### Bottleneck 3: **PostgreSQL Writes (38 URLs/sec)**
**Solution:**
- Batch writes (buffer 100 URLs, write every 3 seconds)
- PostgreSQL easily handles 38/sec

---

## Interview 2-Minute Answer

"URL Shortener is a **read-heavy, cache-first** architecture.

**Core components:**

**1. Short Code Generation (Base62):**
- PostgreSQL auto-increment ID: 123456789
- Convert to Base62: "8M0kX"
- 7 characters = 62^7 = 3.5 trillion unique codes

**2. Redirect Service:**
- User clicks `bit.ly/abc123`
- Check Redis: `GET short_code:abc123`
  - HIT (95%): Return long_url (10ms)
  - MISS (5%): Query PostgreSQL → cache in Redis (TTL 24h) → return (50ms)
- Send 302 Redirect
- Async: Publish click event to Kafka

**3. Analytics (Kafka + Cassandra):**
- Click events published to Kafka (fire-and-forget, doesn't block redirect)
- Background workers consume from Kafka
- Write to Cassandra (10B clicks/month)
- Aggregate every 10 minutes (total clicks, by country, by referrer)

**4. Database:**
- **PostgreSQL:** URLs table (1B rows, 500 GB)
- **Redis:** Cache (95% hit ratio, 10ms latency)
- **Cassandra:** Click logs (10B clicks/month, 24 TB/year)

**Scaling:**
- **3,858 redirects/sec:** Redis cache handles 100k reads/sec
- **10B clicks/month:** Cassandra (write-heavy, horizontal scaling)
- **1B URLs:** 7-char Base62 supports 3.5 trillion (plenty of headroom)

**Key design choice:** Redis cache-first (not database-first). 95% of redirects served from cache (10ms). Without cache, every redirect would hit PostgreSQL (50ms)."

---

# Summary: Key Takeaways

| System | Architecture Pattern | Key Technology Choices | Bottleneck Solved |
|--------|---------------------|------------------------|-------------------|
| **Email Notification** | Queue-based | RabbitMQ (priority queues), Cassandra (logs), SendGrid (delivery) | SendGrid rate limit → Multi-provider |
| **Spotify** | CDN-heavy + ML | Multi-CDN (Akamai), Elasticsearch (search), TensorFlow (recommendations) | Bandwidth (400 GB/sec) → CDN |
| **WhatsApp** | WebSocket + Real-time | WebSocket (persistent connections), Kafka (offline queue), Cassandra (storage) | 1.16M messages/sec → Kafka + Cassandra |
| **Instagram** | Fan-out on write | Redis (feed cache), S3 (photo storage), Cassandra (likes) | 57k feed loads/sec → Redis cache |
| **URL Shortener** | Cache-first | Redis (cache), PostgreSQL (URLs), Cassandra (click logs) | 3.9k redirects/sec → Redis cache |

---

## Interview Prep Checklist

✅ Memorize **2-minute answers** for each system  
✅ Know **capacity estimation** formulas (bandwidth, storage, QPS)  
✅ Understand **when to use** each technology:
- RabbitMQ vs Kafka (task queue vs event stream)
- PostgreSQL vs Cassandra (relational vs write-heavy)
- Redis (cache) vs Memcached (simpler cache)
- CDN (static content) vs origin servers  
✅ Practice drawing **high-level architecture diagrams** on whiteboard  
✅ Know **3 bottlenecks + solutions** for each system  
✅ Be ready to **deep-dive** into any component  

**You're ready for Staff Engineer system design interviews!** 🎯
