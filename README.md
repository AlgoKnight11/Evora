# 🌿 EVORA — Greener Choices. Healthier Cities.

> **AI-Powered Civic Intelligence & Ecosystem Preservation Platform for Uttarakhand**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Gemini AI](https://img.shields.io/badge/Gemini%20AI-3.8%20Flash%20%26%20Embeddings-4285F4?logo=google&logoColor=white)](https://ai.google.dev)
[![Cloudinary](https://img.shields.io/badge/Cloudinary-Media%20Storage-3448C5?logo=cloudinary&logoColor=white)](https://cloudinary.com)
[![Architecture](https://img.shields.io/badge/Architecture-Riverpod%202.0-blueviolet)]()
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-black)]()

---

## 📌 About EVORA

**EVORA** is a next-generation civic intelligence and sustainability platform engineered specifically for the fragile Himalayan ecology of Uttarakhand (starting with the Dehradun & Doon Valley pilot).

EVORA transforms everyday citizen observations and grievances—from uncollected roadside waste and blocked stormwater drains to broken streetlights and potholes—into structured, verifiable municipal actions through geofenced community reporting, AI Vision multi-department triage, on-device PII privacy redaction, 500m duplicate detection, and transparent case tracking.

---

## 🚀 Phase 1 Milestone: Foundation, Authentication & Design System

Phase 1 establishes the core architectural foundation, multi-method authentication, Himalayan Modernism design system, legal guardrails, and media storage pipeline.

### 1. Brand Experience & Adaptive System Design
* **Adaptive App Icon:** Native Android Adaptive Icon (`mipmap-anydpi-v26`) featuring the glowing neon EVORA leaf emblem on a deep Mountain Emerald canvas (`#02130C`).
* **Cinematic Splash Screen:** 3.7-second animated intro with breathing mint aura (`#34D399`), glowing logo entrance, and smooth cross-fade route transitions.
* **Onboarding Carousel:** 3-slide visual onboarding introducing AI civic intelligence, the Doon Valley mission, and EcoCoins. Automatically tracks first-time launch via `SharedPreferences` so it appears only once.
* **Himalayan Modernism Design Language:** Material 3 theme incorporating Mountain Emerald (`#006948`), Electric Mint (`#34D399`), Himalayan Terracotta (`#F97316`), and Forest Slate (`#0F172A`).
* **Bilingual Typography:** Plus Jakarta Sans with tailored `+2px` line-height balancing for Hindi Devanagari vowel marks (*matrayen*) and tabular figures (`tnum`) to eliminate live metric jitter.
* **Edge-to-Edge Safe Areas:** Calibrated for modern Android window insets above gesture pills and 3-button navigation bars.

### 2. Multi-Method Authentication & Session Persistence
* **Multi-Auth Support:** Tabbed Email/Password + Phone Number OTP authentication alongside one-tap Google Sign-In.
* **Cross-Provider Account Linking:** Automatically links Email/Password credentials with Google Sign-In accounts sharing the same email via `linkWithCredential`, plus "Forgot Password?" recovery.
* **Persistent Sessions:** Survives app force-close across Email, Google, and Phone OTP sessions (including built-in developer testing mode).
* **SMS Rate Limiting:** Enforces a 60-second client-side cooldown on OTP requests to prevent SMS pumping.
* **Mandatory Legal Consent:** Explicit consent checkbox gating new account creation behind DPDP Act disclosures.

### 3. Media Pipeline & DPDP Privacy Guardrails
* **Zero-Cost Cloudinary Media Storage:** Direct unsigned multipart photo uploads with client-side resolution constraints and EXIF scrubbing.
* **DPDP Act Privacy & Terms:** Built-in Privacy Policy and Terms & Conditions screens disclosing non-continuous GPS polling, coordinate fuzzing, and strict non-monetary disclaimers for EcoCoins.
* **Observability & PII Scrubbing:** In-memory log buffer with Correlation IDs (`#req_xxxx`) and regex scrubbing for OTPs, phone numbers, and emails.

---

## 🌍 Phase 2 Milestone: CivicBook Feed, CivicFlow Grievances & Guest-First Access

Phase 2 delivers the two core citizen civic participation pillars alongside privacy-preserving geolocation and frictionless guest browsing.

### 1. Guest-First Exploration & Lazy Auth Guard (`AuthGuard`)
* **Open Dashboard Entry:** Visitors launch into Onboarding (first run) and land directly on the **Home Dashboard (`/home`)** without mandatory login upfront.
* **Lazy Authentication Gate:** Guests can explore the dashboard and read public CivicBook observations & comments; any interactive mutation (posting, upvoting/downvoting, commenting, escalating, filing a grievance, completing actions, or uploading media) triggers a **Sign In Required** bottom sheet (`AuthGuard.requireLogin`) and returns users directly back to their screen once authenticated.

### 2. Geolocation & Spatial Privacy (`LocationService`)
* **On-Demand GPS Acquisition:** Requests runtime location permission with clean fallback coordinates (`Dehradun Central / Clock Tower`) if GPS is unavailable—zero background tracking.
* **Spatial Privacy Fuzzing:** Truncates coordinates to 3 decimal places (~100m generalization) before publishing community observations.
* **Haversine Distance Calculation:** Computes exact neighborhood distances (`450 m away`, `2.3 km away`) for geofenced feeds.

### 3. CivicBook: Geofenced Community Observation Feed
* **Geofenced Feed Filtering:** Supports **3 km (default)** and **5 km (expanded)** spatial radius toggles plus category filters (*Solid Waste, Roads & Potholes, Water Leakage, Streetlights, Greenery & Trees*).
* **100% Real User Data:** Fetches and renders genuine user posts and discussion comments (`loadComments` / `addComment`) synced between Cloud Firestore (`tenants/{tenantId}/civicBookPosts`) and local device cache—zero static seed posts or sample comments.
* **Community Voting & Escalation Bridge:** Enforces 1-vote-per-user upvote/downvote toggles (`votes/{uid}`) and provides a one-tap **Escalate** action that pre-fills a formal CivicFlow grievance linked via `sourceCivicBookPostId`.
* **Explicit Permission Disclosures:** Presents transparent in-app dialogs before invoking Camera or Photo Gallery pickers.

### 4. CivicFlow: Formal Municipal Grievance Workflow
* **3-Step Grievance Wizard:** Hierarchical municipal department taxonomy (*Solid Waste, Roads & Footpaths, Drainage & Waterlogging, Street Lighting, Water Supply, Public Sanitation*), compressed photo evidence upload, locality/landmark entry, and detailed review.
* **Case Tracking & 10-Stage Timeline:** Generates unique `CF-YYYY-XXXXXX` tracking IDs and displays **All / Active / Resolved** views with an official 10-stage resolution timeline stepper (`Submitted` $\rightarrow$ `Under Triage` $\rightarrow$ `Needs Information` $\rightarrow$ `Verified` $\rightarrow$ `Assigned` $\rightarrow$ `In Progress` $\rightarrow$ `Resolved - Pending Review` $\rightarrow$ `Resolved` $\rightarrow$ `Closed`).
* **Citizen Follow-Up Controls:** Interactive UI to submit requested clarifications on *Needs Information* cases and confirm resolution or request reopening.
* **Anti-Spam Rate Limiting:** Enforces a sliding-window limit of **3 formal submissions per 10 minutes** per citizen with live cooldown countdown feedback.

---

## 🤖 Phase 3 Milestone: AI Vision Triage, Multi-Department Routing, Privacy Shield & 500m Duplicate Detection

Phase 3 embeds multimodal AI intelligence directly into **CivicFlow** and **CivicBook** with privacy-first on-device image redaction and resilient high-concurrency handling.

### 1. Multimodal Vision Classifier & Official Taxonomy (`AiGatewayService` & `CivicTaxonomy`)
* **Structured Vision Triage (`gemini-3.8-flash`):** Analyzes compressed issue photos via the Gemini Interactions API (`store: false` for zero server-side retention) to auto-detect official municipal category, subcategory, severity level, and suggested citizen description—always editable before submission.
* **Resilient Model Fallback Chain:** Automatically promotes across `gemini-3.8-flash` $\rightarrow$ `gemini-3.5-flash-lite` $\rightarrow$ `gemini-3.1-flash-lite` on transient `503` high-demand responses, with exponential backoff on `429`/`5xx`, SHA-256 semantic response caching, and a FIFO concurrency semaphore (`maxConcurrent = 3`).
* **Strict Enum Guardrails:** Clamps all AI outputs through `CivicTaxonomy.normalizeCategory`, `normalizeSubcategory`, and `normalizeDepartment` across EVORA's 6 municipal categories and 8 operational departments.

### 2. Multi-Department Detection & Coordinated Routing
* **Lead & Co-Assigned Departments:** Detects cross-cutting civic hazards (e.g., a blocked stormwater drain damaging an adjoining asphalt road near a streetlight pole) and routes cases to a **Lead Department** alongside **Supporting Co-Assigned Departments**, complete with per-department AI action rationales surfaced in both the filing wizard and `CaseDetailScreen`.

### 3. On-Device EXIF Stripping & PII Privacy Shield (`PiiRedactionService`)
* **Zero-Metadata Pre-Upload Pipeline:** Runs in background Dart isolates (`Isolate.run`) to bake orientation, resize to max `1280px`, and re-encode clean JPEGs so original GPS/EXIF headers never leave the phone.
* **Automated Face & License Plate Pixelation:** Converts Gemini-detected `0..1000` normalized `face` and `license_plate` bounding boxes into irreversible block pixelation directly on-device before preview or cloud upload.

### 4. Geospatial (500m) & Semantic Duplicate Shield (`DuplicateDetectorService` & `DuplicateAlertSheet`)
* **Multimodal Embeddings (`gemini-embedding-2`):** Generates L2-normalized 256-dim multimodal embeddings (text + redacted image) stored alongside grievances and observations.
* **500m Pre-Submission Alert:** Queries active open `civicFlowCases` (excluding `resolved`/`closed`) and nearby `civicBookPosts` within a `500 m` Haversine radius; presents a bottom sheet (`DuplicateAlertSheet`) letting residents **Follow & Support Case (+1)** or **Upvote Existing Post** instead of duplicating tickets, or submit anyway if distinct.

### 5. Native OS Permissions & Edge-to-Edge Modal Polish
* **On-Demand System Permissions (`MainActivity.kt` & `DevicePermissionService`):** Declares Camera, Location (`FINE`/`COARSE`), and Android version-aware Media permissions (`READ_MEDIA_IMAGES`, `READ_MEDIA_VISUAL_USER_SELECTED`, legacy `READ_EXTERNAL_STORAGE` `maxSdkVersion="32"`) in `AndroidManifest.xml`, prompting via the Android OS only when triggered and not yet granted.
* **Navigation Bar Inset Clearance:** Reserves `max(padding.bottom, viewPadding.bottom)` across `DuplicateAlertSheet`, confirmation modals, and `AuthGuard` sheets so action buttons never collide with Android 3-button or gesture navigation bars.

---

## 🌿 Phase 4 Milestone: Citizen Daily Utility — My Neighbourhood, EvoSwitch & Circular Directory

Phase 4 establishes everyday sustainability utility through real-time environmental telemetry, circular facility discovery with direct navigation, and deterministic carbon calculators.

### 1. "My Neighbourhood" Dynamic Environmental Dashboard (`HomeScreen`)
* **Live Environmental Telemetry (`EnvironmentalService`):** Integrates Open-Meteo European Copernicus (CAMS) atmospheric dispersion models to compute live PM2.5, PM10, Indian CPCB sub-index AQI, temperature, and weather conditions.
* **Coordinate-Keyed Caching (`_coordKey`):** Employs isolated in-memory and disk cache partitions keyed by geographic grid coordinates (`${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}`), ensuring seamless, instant telemetry updates when switching between cities (e.g. Dehradun vs Delhi) without cross-contamination.
* **Pull-to-Refresh & Manual Invalidation:** Full dashboard wrapped in a `RefreshIndicator` alongside an in-card refresh trigger for on-demand environmental polling.
* **Strict Stale-Data Guardrail:** Zero-hallucination fallback returning `EnvironmentalData.unavailable()` when feeds are offline and un-cached.
* **Locality & Regional GPS Switcher:** Instant switching between Doon Valley neighborhoods (*Dehradun Central*, *Rajpur Road*, *Dalanwala*, *Paltan Bazaar*, *ISBT/Majra*, *West Doon*) and device **Live GPS** with automatic regional recognition (*Delhi Live GPS*, *Delhi NCR*, *Haridwar/Rishikesh*, *Chandigarh Tri-City*).
* **Today's Eco Action Daily Check-in:** Actionable daily sustainability prompt with per-user SharedPreferences scoping (`evora_eco_action_${uid}_${today}`) and automatic reactive reset on logout or guest mode.
* **Senior-Accessible UI Cleanup:** Purged legacy Phase 1 test containers in favor of large high-contrast touch targets, a 2x2 civic grid, and a nearby recycling hubs carousel.

### 2. Smart Waste & Circular Living Directory (`FacilitiesDirectoryScreen` & `CircularDirectoryService`)
* **8 Verified Municipal Hubs in Dehradun:** Seeded with verified real-world recovery facilities (Kargi Chowk Material Recovery Facility, Nagar Nigam Patel Road E-Waste Hub, Old Rajpur Composting Hub near MDDA Park, Paltan Bazaar Eco Refill, Dalanwala Repair Guild, Pacific Mall E-Waste Takeback, ISBT Majra Scrap Hub, and Shishambara Integrated Solid Waste Management Facility).
* **Multi-Criteria Search & Filtering:** Live substring search across facility names, localities, and accepted materials, with category filters (*All*, *E-Waste*, *Recycling*, *Composting*, *Refill*, *Repair*), distance radius sliders (<3 km, <5 km, <10 km, All), and "Verified Partners Only" toggles.
* **Direct Google Maps Navigation (`ExternalLauncher`):** Implements Android 11+ `<queries>` package visibility compliance with a 3-tier fallback (native Google Navigation turn-by-turn `google.navigation:q=lat,lng&mode=d` $\rightarrow$ native geo intent $\rightarrow$ Google Maps Web).
* **One-Tap Phone Dialer:** Direct calling launcher (`tel:`) pre-populating verified facility contact lines.

### 3. EvoSwitch Sustainable Choice Engine (`EvoSwitchScreen` & `EvoSwitchService`)
* **Deterministic Mathematical Engine:** Pure mathematical models derived from official Indian regulatory standards (CPCB, ARAI, IPCC, BEE India, UPCL domestic power tariffs) avoiding unconstrained LLM hallucinations:
  1. *Travel & Commute:* ARAI emission factors comparing petrol cars (~170g $\text{CO}_2\text{e}$/km) against electric buses (~38g $\text{CO}_2\text{e}$/km), EV scooters (~15g), or active cycling/walking (0g), computing annual $\text{kg CO}_2\text{e}$ avoided, rupees saved, and tree power equivalents over 250 working days.
  2. *Shopping & Packaging:* Single-use PET bottles (25g plastic, 82g $\text{CO}_2\text{e}$, ₹20) and LDPE polybags (8g plastic, 33g $\text{CO}_2\text{e}$, ₹5) averted per year.
  3. *Repair vs. Buy New:* Embodied manufacturing carbon savings from repairing smartphones (~48 kg $\text{CO}_2\text{e}$), home appliances (~34 kg), bicycles (~32 kg), and footwear (~12 kg).
  4. *Organic Waste Diversion:* Diverting kitchen wet waste from anaerobic dumps (0.65 kg $\text{CO}_2\text{e}$/kg methane emission factor) to aerobic compost (0.10 kg $\text{CO}_2\text{e}$/kg).
  5. *Home Energy Habits:* BEE India 6%/°C AC setpoint optimization (24°C vs 18°C) and LED lighting retrofits evaluated against UPCL domestic tariffs (₹7.20/kWh).
* **Verified Methodology Disclosure:** Transparent modal card outlining all emission baseline coefficients, conversion factors, and formulas.

### 4. Android 3-Button Navigation Bar & System Inset Clearance
* **Zero System Nav Collisions:** Dynamic window inset resolution across `DuplicateAlertSheet`, `AuthGuard`, `FacilitiesDirectoryScreen`, and `HomeScreen` with a guaranteed 56.0 dp fallback clearance on devices running Xiaomi MIUI / HyperOS with 3-button navigation bars (Square, Circle, Triangle), ensuring "Submit Anyway" and dialog action buttons never overlap system icons.

---

## 🏗️ Project Architecture

```text
android/app/src/main/
├── AndroidManifest.xml                             # Camera, Location, Media permissions + Google Maps <queries>
└── kotlin/com/evora/app/MainActivity.kt            # Native runtime permission MethodChannel handler
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart                      # Env secrets, Cloudinary/Gemini config & Firestore paths
│   ├── theme/
│   │   ├── evora_colors.dart                       # Himalayan Modernism color tokens
│   │   ├── evora_typography.dart                   # Bilingual typography & tabular metrics
│   │   └── evora_theme.dart                        # Material 3 ThemeData with stadium pill contours
│   └── utils/
│       ├── auth_guard.dart                         # Lazy authentication modal gate with safe bottom insets
│       └── external_launcher.dart                  # Google Maps turn-by-turn navigation & phone dialer intent
├── features/
│   ├── ai_engine/
│   │   ├── models/civic_ai_models.dart             # CivicVisionAnalysis, PII boxes & DuplicateCandidate models
│   │   ├── services/duplicate_detector_service.dart # 500m Haversine + cosine similarity duplicate detector
│   │   └── widgets/duplicate_alert_sheet.dart      # Safe-inset nearby duplicate prompt & +1 support
│   ├── auth/
│   │   ├── models/user_model.dart                  # EvoraUser Firestore schema model
│   │   ├── screens/
│   │   │   ├── login_screen.dart                   # Tabbed Email / Phone OTP / Google Sign-In
│   │   │   └── signup_screen.dart                  # Registration with mandatory legal consent
│   │   └── services/auth_service.dart              # Riverpod AuthNotifier, session persistence & linking
│   ├── civic_book/
│   │   ├── models/civic_book_model.dart            # CivicBookPost & CivicComment models
│   │   ├── screens/
│   │   │   ├── civic_book_feed_screen.dart         # Geofenced 3km/5km feed & category chips
│   │   │   ├── create_civic_book_post_screen.dart  # AI auto-fill, PII blur & 500m duplicate shield
│   │   │   └── post_detail_screen.dart             # Full observation detail, voting & real comments
│   │   └── services/civic_book_service.dart        # Riverpod CivicBookNotifier (Firestore + cache sync)
│   ├── civic_flow/
│   │   ├── models/
│   │   │   ├── civic_flow_model.dart               # CivicFlowCase, multi-dept & 10-stage timeline models
│   │   │   └── civic_taxonomy.dart                 # 6 categories, subcategories & 8 municipal departments
│   │   ├── screens/
│   │   │   ├── civic_flow_cases_screen.dart        # Citizen tracking dashboard (All/Active/Resolved)
│   │   │   ├── civic_flow_wizard_screen.dart       # AI triage, multi-dept routing & 3-step wizard
│   │   │   └── case_detail_screen.dart             # Multi-dept chips, 10-stage stepper & verification
│   │   └── services/civic_flow_service.dart        # Riverpod CivicFlowNotifier & rate limiting
│   ├── evoswitch/
│   │   ├── models/evoswitch_models.dart            # EvoSwitch category schemas, options & calculation results
│   │   ├── screens/evoswitch_screen.dart           # Interactive green calculator & verified methodology modal
│   │   └── services/evoswitch_service.dart         # Deterministic CPCB/ARAI/IPCC/BEE mathematical engine
│   ├── facilities/
│   │   ├── models/circular_facility_model.dart     # CircularFacility schema, categories & verified badges
│   │   ├── screens/facilities_directory_screen.dart # Interactive search, radius filtering & detail sheets
│   │   └── services/circular_directory_service.dart # Seeded Dehradun facilities & proximity sorter
│   ├── legal/
│   │   └── screens/
│   │       ├── privacy_policy_screen.dart          # DPDP Act compliant privacy disclosures
│   │       └── terms_and_conditions_screen.dart    # Civic rules & non-monetary EcoCoin disclaimers
│   ├── neighbourhood/
│   │   └── screens/home_screen.dart                # Senior-friendly dashboard, locality picker & telemetry card
│   ├── onboarding/
│   │   └── screens/onboarding_screen.dart          # 3-slide first-time user introduction
│   └── splash/
│       └── screens/splash_screen.dart              # Animated logo intro & route resolution
├── routes/
│   └── app_router.dart                             # Declarative GoRouter routes & transitions
├── services/
│   ├── ai_gateway_service.dart                     # Gemini 3.8 Flash Vision + fallback, caching & embeddings
│   ├── cloudinary_service.dart                     # Unsigned multipart media upload service
│   ├── device_permission_service.dart              # Native Android Camera & Gallery permission bridge
│   ├── environmental_service.dart                  # Open-Meteo AQI/weather, coordinate-keyed cache & stale guard
│   ├── location_service.dart                       # GPS acquisition, Haversine math & regional locality resolver
│   ├── logging_service.dart                        # Breadcrumbs, Correlation IDs & PII scrubbing
│   └── pii_redaction_service.dart                  # On-device EXIF stripping & face/plate pixelation
└── main.dart                                       # Flutter bootstrap with ProviderScope & error hooks
test/
├── phase2_civic_test.dart                          # Spatial math, real persistence, rate limit & auth guard tests
├── phase3_ai_engine_test.dart                      # AI schema, multi-dept, PII blur, 500m & 50-concurrency tests
├── phase4_daily_utility_test.dart                  # Directory filters, EvoSwitch math, stale guard & eco action tests
└── widget_test.dart                                # App smoke tests
```

---

## 🛠️ Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.24.0 or higher)
* [Dart SDK](https://dart.dev/get-dart) (v3.5.0 or higher)
* Android Studio / Xcode with connected physical device or emulator

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/AlgoKnight11/Evora.git
   cd Evora
   ```

2. **Configure Environment Secrets (`.env` & Firebase):**
   ```bash
   cp .env.example .env
   cp android/app/google-services.json.example android/app/google-services.json
   ```
   * Populate `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET`, `GEMINI_API_KEY`, and Firebase credentials in `.env` and `android/app/google-services.json` (both are gitignored).

3. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

4. **Verify static analysis & unit tests:**
   ```bash
   flutter analyze
   flutter test
   ```

5. **Run the application:**
   ```bash
   flutter run
   ```

---

## 🗺️ High-Level Project Roadmap

| Phase | Milestone | Status |
|:---:|:---|:---:|
| **Phase 1** | Foundation, Auth, Theme, Legal, Media Storage & Splash | Completed |
| **Phase 2** | CivicBook Geofenced Feed, CivicFlow Grievances & Guest-First Access | Completed |
| **Phase 3** | AI Vision Triage, Multi-Dept Routing, PII Blur & 500m Duplicate Shield | Completed |
| **Phase 4** | **My Neighbourhood, EvoSwitch Habits & Circular Living Directory** | **Completed (Current)** |
| **Phase 5** | Eco Missions, Append-Only EcoCoin Ledger & Impact Profile | Up Next |
| **Phase 6** | Eco Buddy Bilingual RAG Assistant | Planned |
| **Phase 7** | Firebase App Check, Certificate Pinning & Release Builds | Planned |

---

## 📄 License & Intellectual Property

Proprietary © 2026 EVORA Project Contributors. All rights reserved.
Unauthorized copying, modification, distribution, or deployment of this software is strictly prohibited.
