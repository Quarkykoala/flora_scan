# FloraScan

Production-grade Flutter + Supabase plant intelligence platform with:

- Offline-first scan pipeline
- AI diagnosis + treatment recommendations
- Recovery loop tracking (intervention -> adherence -> outcome)
- Affiliate commerce intent links
- Freemium paywall and premium assistant
- B2B API key authentication path for enterprise ingestion

## Table of Contents

- [1. Product Overview](#1-product-overview)
- [2. System Architecture](#2-system-architecture)
- [3. Core User Flows](#3-core-user-flows)
- [4. Screens and Routes](#4-screens-and-routes)
- [5. Data Model (Golden Record + Recovery Loop)](#5-data-model-golden-record--recovery-loop)
- [6. Edge Functions](#6-edge-functions)
- [7. Monetization and Enterprise Layers](#7-monetization-and-enterprise-layers)
- [8. Local Development Setup](#8-local-development-setup)
- [9. Supabase Setup and Deployment](#9-supabase-setup-and-deployment)
- [10. Testing and Validation](#10-testing-and-validation)
- [11. Project Structure](#11-project-structure)
- [12. Security and Privacy](#12-security-and-privacy)

## 1. Product Overview

FloraScan is designed as a consumer app and a data engine at the same time.

- Consumer value: fast diagnosis, actionable recommendations, assistant chat, polished UX.
- Data value: high-quality longitudinal records for future model training.
- Business value: freemium conversion, affiliate intent monetization, B2B telemetry API path.

### North-Star Loop

```mermaid
flowchart LR
  A[Scan + Telemetry] --> B[AI Diagnosis]
  B --> C[Intervention Recommendations]
  C --> D[Follow-up Mission]
  D --> E[Adherence + Outcome]
  E --> F[Higher-quality Training Data]
  F --> G[Better Recommendations]
  G --> C
```

## 2. System Architecture

```mermaid
flowchart TB
  subgraph Mobile App [Flutter App]
    UI[UI Screens]
    Queue[Offline Queue]
    Sensors[Camera + Sensors + Location]
    UI --> Queue
    Sensors --> Queue
  end

  subgraph Backend [Supabase]
    DB[(Postgres)]
    Storage[(Private Storage)]
    EF[Edge Functions]
    Auth[Auth + RLS]
    Realtime[Realtime/Polling]
    EF --> DB
    EF --> Storage
    Auth --> DB
    DB --> Realtime
  end

  subgraph External [External APIs]
    Gemini[Google Gemini Flash]
    Weather[Open-Meteo]
    Air[Air Quality API]
    Commerce[Affiliate Search Targets]
  end

  Queue --> EF
  UI --> Realtime
  EF --> Gemini
  EF --> Weather
  EF --> Air
  UI --> Commerce
```

## 3. Core User Flows

### 3.1 Zero-Latency Scan Pipeline

```mermaid
sequenceDiagram
  participant U as User
  participant A as Flutter App
  participant Q as Offline Queue
  participant S as Supabase
  participant W as Weather/Air APIs
  participant G as Gemini

  U->>A: Tap Scan
  A->>A: Capture image + sensors + location
  A->>Q: Store PendingScan (idempotent client_scan_id)
  A-->>U: Immediate "Analyzing..." feedback
  A->>S: create-scan (upload + insert scan + enqueue jobs)
  S->>W: enrich-weather / enrich-air
  S->>G: diagnose-ai
  S->>S: write diagnosis + recommendations + missions
  A->>S: poll/realtime for processing_status
  S-->>A: completed
  A-->>U: diagnosis + telemetry + recommended actions
```

### 3.2 Recovery Intelligence Loop

```mermaid
flowchart LR
  R[Recommendation Created] --> M[Follow-up Mission Due]
  M --> A1[User logs adherence]
  A1 --> A2[User logs outcome]
  A2 --> A3[Optional follow-up scan/photo]
  A3 --> O[intervention_outcomes row]
  O --> I[Effectiveness analytics by recommendation_code]
```

## 4. Screens and Routes

Current route map (`go_router`):

| Route | Screen | Purpose |
|---|---|---|
| `/login` | Login | Auth entry (bypassed when `APP_TEST_MODE=true`) |
| `/` | Home | Plant list, premium/free state, weekly snapshot |
| `/scan` | Scan | Camera capture + deep analysis toggle + paywall |
| `/scan-history` | Scan History | Past scans |
| `/plant/add` | Add Plant | Plant registration |
| `/plant/:id` | Plant Detail | Plant profile and timeline |
| `/diagnosis/:scanId` | Diagnosis Result | AI diagnosis, telemetry, recommendations, outcomes |
| `/assistant` | Chat Assistant | Premium-only conversational care assistant |
| `/settings` | Settings | Locale, consent, sync metadata |

Navigation shell tabs: `Plants`, `Scan`, `History`, `Settings`.

## 5. Data Model (Golden Record + Recovery Loop)

Supabase schema lives in [schema.sql](supabase/schema.sql).

```mermaid
erDiagram
  users ||--o{ plants : owns
  users ||--o{ scans : creates
  plants ||--o{ scans : has
  scans ||--o{ scan_jobs : tracks
  scans ||--o{ intervention_recommendations : produces
  intervention_recommendations ||--o{ followup_missions : schedules
  intervention_recommendations ||--o{ intervention_outcomes : measures
  users ||--o{ analytics_events : emits

  users {
    uuid id PK
    text locale_code
    bool research_consent
    bool is_premium
    int free_scans_remaining
  }

  scans {
    uuid id PK
    uuid user_id FK
    uuid plant_id FK
    text client_scan_id UK
    text processing_status
    text diagnosis_code
    float diagnosis_confidence
    jsonb ai_diagnosis_raw
  }

  intervention_recommendations {
    uuid id PK
    uuid scan_id FK
    text recommendation_code
    text followup_status
    text risk_level
  }

  intervention_outcomes {
    uuid id PK
    uuid intervention_id FK
    text adherence_status
    text outcome_status
  }
```

## 6. Edge Functions

Implemented under `supabase/functions`:

- `create-scan`: idempotent scan creation + async job enqueue
- `enrich-weather`: Open-Meteo enrichment + VPD derivation
- `enrich-air`: AQ enrichment
- `diagnose-ai`: Gemini diagnosis + recommendations + commerce links + missions
- `submit-intervention-outcome`: adherence/outcome capture + mission completion
- `care-chat`: contextual assistant responses
- `log-analytics-event`: telemetry event ingestion
- `create-b2b-api-key`: admin-protected B2B key issuance

## 7. Monetization and Enterprise Layers

### 7.1 Freemium Gating

- Basic scan capture and telemetry remain accessible.
- Deep AI analysis and assistant are premium-gated.
- Paywall interactions are tracked in `analytics_events`.

### 7.2 Affiliate Commerce Intent Layer

- `diagnose-ai` returns `treatment_plan.commerce_links`.
- UI renders `Buy Treatment Now` CTA in diagnosis screen.
- Links are sanitized and tracked.

### 7.3 B2B API Key Flow

```mermaid
flowchart TB
  Admin[Admin Backend/Operator] -->|x-admin-token| CreateKey[create-b2b-api-key]
  CreateKey --> Keys[(b2b_api_keys hashed)]
  Client[B2B Client] -->|x-api-key| Funcs[diagnose-ai / enrich-weather]
  Funcs --> Auth{validateAuthOrB2BApiKey}
  Auth -->|valid| Process[Process request]
  Auth -->|invalid| Reject[401]
```

## 8. Local Development Setup

### 8.1 Prerequisites

- Flutter SDK (stable)
- Dart SDK (bundled with Flutter)
- Supabase project
- Optional: Supabase CLI

### 8.2 Install dependencies

```bash
flutter pub get
```

### 8.3 Run app

Production-like auth:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Testing mode (bypass login gate):

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=APP_TEST_MODE=true
```

### 8.4 Optional payment envs

```bash
--dart-define=DODO_CHECKOUT_BASE_URL=https://checkout.dodopayments.com/...
--dart-define=DODO_SUCCESS_URL=https://your-webapp.com/?payment=success
--dart-define=DODO_CANCEL_URL=https://your-webapp.com/?payment=cancel
```

## 9. Supabase Setup and Deployment

### 9.1 Apply schema

Run [schema.sql](supabase/schema.sql) in Supabase SQL editor.

### 9.2 Configure secrets (Edge Functions)

Required secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `GEMINI_API_KEY`
- `B2B_ADMIN_TOKEN` (for key creation endpoint)

### 9.3 Deploy functions

```bash
supabase functions deploy create-scan
supabase functions deploy enrich-weather
supabase functions deploy enrich-air
supabase functions deploy diagnose-ai
supabase functions deploy submit-intervention-outcome
supabase functions deploy care-chat
supabase functions deploy log-analytics-event
supabase functions deploy create-b2b-api-key
```

### 9.4 Issue a B2B API key (example)

```bash
curl -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/create-b2b-api-key" \
  -H "Content-Type: application/json" \
  -H "x-admin-token: YOUR_B2B_ADMIN_TOKEN" \
  -d '{"company_name":"Acme Agri","tier_limit":10000}'
```

## 10. Testing and Validation

Run unit/widget tests:

```bash
flutter test
```

Suggested release checks:

- Scan in offline mode -> reconnect -> verify sync
- Confirm `client_scan_id` idempotency on repeated uploads
- Verify diagnosis, recommendations, missions created
- Submit outcome and confirm mission transitions to `completed`
- Validate premium gates and paywall analytics events
- Validate `x-api-key` path for enterprise endpoints

## 11. Project Structure

```text
lib/
  config/          # app config, theme, router
  l10n/            # localization (.arb + generated delegates)
  models/          # typed data models
  providers/       # Riverpod state providers/notifiers
  screens/         # UI routes
  services/        # pipeline, Supabase, sensors, notifications, payments
  utils/           # image/geohash/telemetry helpers
  widgets/         # reusable UI components

supabase/
  schema.sql
  functions/
    _shared/       # CORS, security, B2B auth, hash helpers
    create-scan/
    enrich-weather/
    enrich-air/
    diagnose-ai/
    care-chat/
    submit-intervention-outcome/
    log-analytics-event/
    create-b2b-api-key/
```

## 12. Security and Privacy

- Private storage bucket for scan images
- RLS across user-owned tables
- EXIF stripping before upload
- Consent-aware geolocation persistence (rounded vs precise)
- Canonical code storage for language-neutral analytics
- Input validation and auth checks in edge functions

---

If you want, the next documentation pass can add:

- Embedded app screenshots/GIF walkthroughs
- API request/response examples per function
- ERD synced to exact schema constraints
