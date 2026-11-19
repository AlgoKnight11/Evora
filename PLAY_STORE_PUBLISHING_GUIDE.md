# EVORA — Google Play Store Publishing Guide & Readiness Dossier

This document provides everything needed to publish **EVORA** (`com.evora.app`) to the **Google Play Store**. All technical prerequisites, release signing, ProGuard optimization, and bundle compilation have been verified and configured.

---

## 1. Ready-to-Upload Binary & Asset Files

| Artifact | File Path | Purpose |
| :--- | :--- | :--- |
| **Android App Bundle (.aab)** | [`Evora-Citizen/build/app/outputs/bundle/release/app-release.aab`](file:///d:/Evora/Evora-Citizen/build/app/outputs/bundle/release/app-release.aab) | **The primary binary to upload** to Google Play Console (58.4 MB, signed with production key, minified & obfuscated). |
| **De-obfuscation Mapping** | [`Evora-Citizen/build/app/outputs/mapping/release/mapping.txt`](file:///d:/Evora/Evora-Citizen/build/app/outputs/mapping/release/mapping.txt) | Upload under **App bundle explorer $\rightarrow$ ReTrace mapping file** so crash stack traces in Android Vitals are human-readable. |
| **Native Debug Symbols** | [`Evora-Citizen/build/app/outputs/symbols/`](file:///d:/Evora/Evora-Citizen/build/app/outputs/symbols/) | ZIP and upload under **App bundle explorer $\rightarrow$ Native debug symbols** for native C/C++ engine crash analysis. |
| **512x512 High-Res App Icon** | [`play_store_assets/icon_512.png`](file:///d:/Evora/play_store_assets/icon_512.png) | Upload under **Main store listing $\rightarrow$ App icon** (512x512 px 32-bit PNG with alpha). |

---

## 2. Release Keystore & App Signing Credentials

The application is configured to sign release builds using a dedicated production upload keystore.

* **Keystore Location:** `Evora-Citizen/android/app/upload-keystore.jks` *(Ignored by Git for security)*
* **Key Configuration:** `Evora-Citizen/android/key.properties` *(Ignored by Git for security)*
* **Key Alias:** `upload`
* **Keystore Password:** `evora_upload_2026`
* **Key Password:** `evora_upload_2026`
* **Certificate Distinguishing Name:** `CN=EVORA Release, OU=Mobile, O=EVORA Civic Tech, L=Dehradun, ST=Uttarakhand, C=IN`

### Fingerprints for Firebase Console:
Make sure to add this release SHA-256 fingerprint in your [Firebase Console Settings](https://console.firebase.google.com/project/evora-tech/settings/general) under `com.evora.app` so Google Sign-In and Play Integrity recognize release builds:
* **Release SHA-256:**
  ```
  D0:F6:31:0E:90:27:6E:9E:BD:9F:A3:57:41:52:8B:42:80:D6:94:E7:E9:74:04:33:41:26:E3:C1:BF:02:AF:F4
  ```
* **Release SHA-1:**
  ```
  33:DE:C1:BD:32:59:9A:DD:00:04:1F:8D:08:44:17:3D:18:3E:68:B3
  ```

---

## 3. Store Listing Copy (Ready to Copy-Paste)

### App Name (30 characters max)
```
EVORA
```

### Short Description (80 characters max)
```
AI-Powered Civic Intelligence and Citizen Sustainability Platform.
```

### Full Description (up to 4,000 characters)
```
EVORA is an integrated civic intelligence and sustainability platform connecting residents, municipal authorities, and field execution teams through a shared operational ecosystem.

KEY CAPABILITIES:

1. CivicFlow — AI-Powered Grievance Triage:
• Capture municipal infrastructure hazards (garbage dumps, potholes, open manholes, broken streetlights, waterlogging).
• Automated multi-department routing directs issues to the right municipal ward instantly.
• Real-time timeline tracking from ground inspection to verified resolution.

2. Privacy by Design:
• On-device and server-side PII redaction automatically masks citizen faces and vehicle license plates before community feed publication.

3. CivicBook — Geofenced Community Feed:
• Explore verified civic updates within your locality with privacy fuzzing.
• Upvote critical neighborhood issues and comment on community actions.

4. EvoSwitch & Circular Directory:
• Discover verified recycling drop-off centers, e-waste collectors, and compost hubs near you.
• Calculate your measurable plastic waste avoidance and water savings.

5. Sustainable Missions & EcoCoin Rewards:
• Participate in municipal environmental campaigns and tree-planting drives.
• Earn cryptographically verifiable EcoCoins for positive civic action.

PRIVACY & DATA GOVERNANCE:
EVORA complies strictly with the Digital Personal Data Protection (DPDP) Act. All data is encrypted in transit using strict TLS 1.3. Location data is used strictly in the foreground for incident geo-tagging and nearby facility discovery.

Greener Choices. Healthier Cities.
```

---

## 4. Google Play Console Setup: Step-by-Step

### Step 1: Create Your App in Play Console
1. Open the [Google Play Console](https://play.google.com/console).
2. Click **Create app**.
3. Fill in basic details:
   - **App name:** `EVORA`
   - **Default language:** `English (United States)` or `English (India)`
   - **App or game:** `App`
   - **Free or paid:** `Free`
4. Accept the declarations and click **Create app**.

---

### Step 2: Complete the "App Content" Declarations

Navigate to **Policy and programs $\rightarrow$ App content** in the left sidebar and complete the required questionnaires:

#### A. Privacy Policy
* Provide your publicly accessible Privacy Policy URL.
*(Tip: You can host `Evora-Citizen/lib/features/legal/screens/privacy_policy_screen.dart` content on GitHub Pages, Firebase Hosting, or your organization website).*

#### B. App Access
* Select: **"All or some functionality in my app is restricted"** (since phone OTP or Google login is supported).
* Add instructions for reviewers:
  - **Account name:** `Test Citizen`
  - **Email / Username:** `citizen@evora.app`
  - **Password / Access:** Provide test OTP `123456` or note that guest browsing is available without sign-in.

#### C. Ads
* Select: **"No, my app does not contain ads"**.

#### D. Content Rating
* Complete the questionnaire. For Utility/Civic apps:
  - Violence: None
  - Sexual content: None
  - Language: None
  - Controlled substances: None
  - Miscellaneous: Shares user-provided location to tag civic issues.
  - Result: Will receive an **Everyone** / **PEGI 3** rating.

#### E. Target Audience
* Select: **13-15, 16-17, 18 and over**.
* Under *"Could your store listing appeal to children unintentionally?"*, select **No**.

#### F. Data Safety Section (Accurate Answers)
* **Does your app collect or share user data?** $\rightarrow$ **Yes**.
* **Is all of the user data collected by your app encrypted in transit?** $\rightarrow$ **Yes** (TLS 1.3 enforced).
* **Do you provide a way for users to request that their data be deleted?** $\rightarrow$ **Yes**.
* **Data Types Collected:**
  1. **Location:** *Approximate location* and *Precise location* $\rightarrow$ Collected (App functionality, account management). Not shared with third parties.
  2. **Personal Info:** *Name*, *Email address*, *Phone number* $\rightarrow$ Collected for user account authentication.
  3. **Photos and Videos:** *Photos* $\rightarrow$ User-uploaded grievance photos and mission proof.
  4. **App info and performance:** *Crash logs*, *Diagnostics* $\rightarrow$ App functionality and analytics.

#### G. Government Apps
* Unless publishing under an official government agency developer account with official authorization letters, select:
  - **"No, this app is not developed by or on behalf of a government entity"**.
  - *(EVORA is classified as a civic technology / citizen utility platform).*

#### H. Financial Features
* Select: **"My app doesn't provide any financial features"**.
  - *(EcoCoins are strictly in-app recognition points with zero monetary or crypto value, as disclosed in the app).*

---

### Step 3: Main Store Listing (Graphics & Metadata)
1. Go to **Grow $\rightarrow$ Store presence $\rightarrow$ Main store listing**.
2. Paste the **App name**, **Short description**, and **Full description** from Section 3 above.
3. **App icon:** Upload [`play_store_assets/icon_512.png`](file:///d:/Evora/play_store_assets/icon_512.png).
4. **Feature graphic:** Upload a $1024\times 500$ PNG graphic highlighting EVORA.
5. **Phone Screenshots:** Upload 2 to 8 phone screenshots showing the main screens (Home Dashboard, CivicFlow Wizard, Circular Directory, Eco Buddy).

---

### Step 4: Upload the Release App Bundle
1. In the Play Console menu, go to **Release $\rightarrow$ Testing $\rightarrow$ Internal testing** (recommended for your first upload) or **Production**.
2. Click **Create new release**.
3. Under **App bundles**, upload:
   [`Evora-Citizen/build/app/outputs/bundle/release/app-release.aab`](file:///d:/Evora/Evora-Citizen/build/app/outputs/bundle/release/app-release.aab)
4. Under **Release name**, verify it auto-populates as `1.0.0 (1)`.
5. Enter **Release notes**:
   ```
   Initial production release of EVORA — AI-powered civic intelligence, incident reporting, smart circular directory, and citizen sustainability rewards.
   ```
6. Click **Next** $\rightarrow$ **Save**.

---

### Step 5: Upload De-obfuscation Files (Android Vitals)
1. After uploading the `.aab`, click on the App Bundle details.
2. Go to **App bundle explorer**.
3. Under the **Downloads** or **Files** tab, find **ReTrace mapping file** and upload:
   [`Evora-Citizen/build/app/outputs/mapping/release/mapping.txt`](file:///d:/Evora/Evora-Citizen/build/app/outputs/mapping/release/mapping.txt)
4. Click **Save**.

---

## 5. Future Releases: How to Increment & Rebuild

Whenever you prepare a new update for the Play Store:
1. Increment the version in [`Evora-Citizen/pubspec.yaml`](file:///d:/Evora/Evora-Citizen/pubspec.yaml):
   ```yaml
   version: 1.0.1+2   # (versionName + versionCode)
   ```
2. Recompile the production App Bundle:
   ```bash
   cd Evora-Citizen
   flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
   ```
3. Upload the resulting `app-release.aab` to Play Console.
