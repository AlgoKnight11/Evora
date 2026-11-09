# 🌿 EVORA — Greener Choices. Healthier Cities.

> **AI-Powered Civic Intelligence & Ecosystem Preservation Platform for Uttarakhand**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Cloudinary](https://img.shields.io/badge/Cloudinary-Media%20Storage-3448C5?logo=cloudinary&logoColor=white)](https://cloudinary.com)
[![Architecture](https://img.shields.io/badge/Architecture-Riverpod%202.0-blueviolet)]()
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-black)]()

---

## 📌 About EVORA

**EVORA** is a next-generation civic intelligence and sustainability platform engineered specifically for the fragile Himalayan ecology of Uttarakhand (starting with the Dehradun & Doon Valley pilot). 

EVORA transforms everyday citizen grievances—from uncollected roadside garbage and open burning to stream pollution—into structured, verifiable municipal actions through AI classification, GPS verification, and gamified community participation.

---

## 🚀 Phase 1 Milestone: Foundation & Architecture

Phase 1 establishes the core architectural foundation, multi-tenant security, visual design language, legal guardrails, and media ingestion pipelines.

### 1. Brand Experience & Adaptive System Design
* **Adaptive App Icon:** Native Android Adaptive Icon (`mipmap-anydpi-v26`) featuring the glowing neon EVORA leaf emblem on a deep Mountain Emerald canvas (`#02130C`), completely filling the icon mask without container wrapping.
* **Cinematic Splash Screen:** 3.7-second animated intro with dynamic breathing mint aura (`#34D399`), glowing vector logo entrance, and smooth cross-fade route transitions.
* **Onboarding Carousel:** 3-slide visual onboarding experience highlighting AI civic intelligence, the Doon Valley mission, and EcoCoins. Automatically tracks first-time launch state via `SharedPreferences` to ensure it only displays once.
* **Himalayan Modernism Design Language:** Material 3 theme incorporating Mountain Emerald (`#006948`), Electric Mint (`#34D399`), and Forest Slate (`#0F172A`).
* **Bilingual Typography:** Plus Jakarta Sans with tailored line-height balancing for upper Hindi Devanagari vowel marks (*matrayen*) and tabular figures to eliminate live metric jitter.
* **Edge-to-Edge Navigation Safe Areas:** Optimized for Android 15/16 edge-to-edge window insets, ensuring all buttons and disclaimers sit safely above system gesture pills and 3-button navigation bars.

### 2. Multi-Method Authentication & User Governance
* **Tabbed Authentication:** Clean switcher supporting both Email/Password and Phone Number OTP authentication.
* **SMS Protection & Rate Limiting:** Enforces a 60-second client-side cooldown on OTP requests to prevent SMS pumping and abuse. Includes built-in developer testing mode for zero-cost rapid local evaluation.
* **Google OAuth Sign-In:** One-tap sign-in integrated via Google Sign-In SDK.
* **Mandatory Legal Consent:** Explicit checkbox gating user registration behind binding acceptance of privacy terms.
* **Reactive State Architecture:** Managed end-to-end via Riverpod `StateNotifierProvider` (`authProvider`).

### 3. Media Pipeline & DPDP Privacy Guardrails
* **Zero-Cost Cloudinary Media Storage:** Direct unsigned multipart image upload service bypassing paid storage buckets.
* **Client-Side EXIF Stripping:** Automatically removes sensitive GPS, device, and timestamp EXIF metadata before uploads to prevent surveillance exposure.
* **DPDP Act Compliant Privacy Policy:** Discloses zero continuous background location tracking, public feed coordinate generalization, and citizen data rights under India's Digital Personal Data Protection Act.
* **Binding Terms & Non-Monetary Disclaimers:** Explicitly defines EcoCoins as non-monetary community incentive points (not cryptocurrency or tradable financial assets).
* **Observability & PII Scrubbing:** In-memory circular log buffer with Correlation IDs (`#req_xxxx`) and regex-based scrubbing of OTPs, phone numbers, and email addresses.

---

## 🏗️ Project Architecture

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart          # Cloudinary config, tenant scope & Firestore paths
│   └── theme/
│       ├── evora_colors.dart           # Himalayan Modernism color tokens
│       ├── evora_typography.dart       # Bilingual typography & tabular metrics
│       └── evora_theme.dart            # Material 3 ThemeData with stadium pill contours
├── features/
│   ├── auth/
│   │   ├── models/
│   │   │   └── user_model.dart         # EvoraUser Firestore schema model
│   │   ├── screens/
│   │   │   ├── login_screen.dart       # Tabbed Email / Phone OTP / Google Sign-In
│   │   │   └── signup_screen.dart      # Registration with mandatory legal consent
│   │   └── services/
│   │       └── auth_service.dart       # Riverpod AuthNotifier session lifecycle
│   ├── legal/
│   │   └── screens/
│   │       ├── privacy_policy_screen.dart      # DPDP Act compliant privacy disclosures
│   │       └── terms_and_conditions_screen.dart # Civic terms & non-monetary disclaimers
│   ├── neighbourhood/
│   │   └── screens/
│   │       └── home_screen.dart        # Neighbourhood feed & live Cloudinary test uploader
│   ├── onboarding/
│   │   └── screens/
│   │       └── onboarding_screen.dart  # 3-slide first-time user introduction
│   └── splash/
│       └── screens/
│           └── splash_screen.dart      # Cinematic animated logo intro with routing logic
├── routes/
│   └── app_router.dart                 # Declarative GoRouter routing with cross-fades
├── services/
│   ├── cloudinary_service.dart         # Direct unsigned multipart photo upload service
│   └── logging_service.dart            # Breadcrumbs, Correlation IDs & PII scrubbing
└── main.dart                           # Flutter bootstrap with ProviderScope & error hooks
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

2. **Configure Environment Secrets (.env):**
   ```bash
   cp .env.example .env
   ```
   * Populate `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET`, `GEMINI_API_KEY`, and `FIREBASE_API_KEY` credentials in `.env`.

3. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

4. **Verify code health & static analysis:**
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
| **Phase 1** | **Foundation, Auth, Theme, Legal, Media Storage & Splash** | **Completed (Current)** |
| **Phase 2** | CivicFlow Grievance Ingestion & AI Triage Pipeline | Planned |
| **Phase 3** | CivicBook Hyperlocal Social Feed & Verification Voting | Planned |
| **Phase 4** | EvoSwitch Habits, Carbon Calculator & EcoCoin Ledger | Planned |
| **Phase 5** | Municipal Worker Dispatch & Offline Geofenced Tasking | Planned |
| **Phase 6** | Eco Buddy Gemini Multimodal Civic AI Assistant | Planned |
| **Phase 7** | Administrative Analytics, Heatmaps & Production Hardening | Planned |

---

## 📄 License & Intellectual Property

Proprietary © 2026 EVORA Project Contributors. All rights reserved.
Unauthorized copying, modification, distribution, or deployment of this software is strictly prohibited.
