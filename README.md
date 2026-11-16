# EVORA | Integrated Citizen, Admin & Worker Platform

> **Greener Choices. Healthier Cities.**  
> An integrated civic intelligence and sustainability platform connecting residents, municipal authorities, and field execution teams through a shared operational system.

---

## 🏛️ Platform Architecture & Repository Structure

This repository is organized as a unified multi-portal workspace:

```text
Evora/
├── Evora-Citizen/       # Citizen Mobile App (iOS / Android) & Responsive Web (Flutter)
├── Evora-Worker/        # Field Worker Portal (Mobile-first PWA / Task Execution) [Upcoming]
├── Evora-Admin/         # Municipal Operations Console & Command Centre [Upcoming]
├── firestore.rules      # Production Multi-Tenant Cloud Firestore Security Rules
├── storage.rules        # Cloud Storage for Firebase Access Rules
└── README.md            # Monorepo Workspace Guide
```

---

## 📱 Portals Overview

### 1. Citizen Portal (`/Evora-Citizen`)
* **Technology:** Flutter (iOS, Android, Responsive Web)
* **Core Capabilities:**
  * **My Neighbourhood:** Locality-aware civic dashboard and nearby circular facilities.
  * **EvoSwitch:** Sustainable choice and alternative decision engine.
  * **Smart Waste & Circular Living:** Directory and verified collection streams.
  * **CivicBook:** Geofenced community feed (3 km / 5 km radius) with privacy fuzzing.
  * **CivicFlow:** Formal grievance submission, live tracking, and evidence lifecycle.
  * **Eco Buddy:** AI assistant grounded in municipal policy and service data.
  * **Profile & Impact:** Traceable CO2e avoidance, water saved, trees maintained, and Eco Coin ledger.

### 2. Field Worker Portal (`/Evora-Worker`) *(Phase IV)*
* **Target:** Mobile-first responsive PWA with offline-first synchronization.
* **Core Capabilities:**
  * Assigned task inbox & team pool claim workflows.
  * Offline task caching with encrypted IndexedDB / OPFS media staging.
  * Before/after evidence upload, checklist completion, and customer acknowledgement.
  * Dedicated safety incident reporting and supervisor escalation.

### 3. Municipal Admin Portal (`/Evora-Admin`) *(Phase III)*
* **Target:** Desktop-first operations console.
* **Core Capabilities:**
  * City Overview command centre and real-time SLA metrics.
  * CivicFlow triage, assignment, and escalation workbench.
  * Workforce administration and supervisor review queues.
  * Geospatial ward mapping and CivicBook moderation.

---

## 🚀 Getting Started with the Citizen App

To run the Citizen app locally:

```bash
# 1. Navigate to the Citizen app directory
cd Evora-Citizen

# 2. Install Flutter packages
flutter pub get

# 3. Run unit, integration, and security tests
flutter test

# 4. Launch the application (Chrome, Android emulator, or iOS simulator)
flutter run -d chrome
```

---

## 🔒 Security & Data Governance

* **Zero-Trust Multi-Tenancy:** All records are partitioned under `tenants/{tenantId}/`.
* **Privacy by Design:** Citizen contact details and exact GPS coordinates are masked from public feeds.
* **Immutable Audit Trail:** All state transitions generate append-only events.
