# 🩸 ResQ — Donor Mobile Application

**ResQ** is a blood donation management app that connects voluntary blood donors with blood banks and hospitals in real time. Hospitals post urgent blood requests from the ResQ web dashboard. Donors get alerted, check their eligibility, book a donation slot, and carry a digital donor ID card.

The app ranks emergency requests with a **Min-Heap priority queue** and decides donor eligibility with a **decision tree model**.

---

## 🚀 Features

### Onboarding & Account

* **Animated splash + "How ResQ Works" onboarding.** A 4-step walkthrough (Find a Request → Join the Queue → Smart Routing → Save a Life).
* **Registration wizard with health screening.** Guided sign-up with OTP phone verification and medical-history questions.
* **Terms & Conditions.** The agreement checkbox is remembered on the device.
* **Biometric login (Fingerprint / Face ID).** Turning it on checks that the phone has a fingerprint or face enrolled and confirms it with the phone's own prompt. After signing out, one scan signs the donor straight back in.
* **ID verification.** Third-party ID and liveness check (Didit) before a donor can book.

### Dashboard

* **Eligible and deferred dashboards.** Deferred donors see their recovery countdown and referral options.
* **Urgent requests near you.** Open hospital requests ranked by urgency. Includes every broadcast the donor was sent, not only the coordinating chapter's.
* **Your Impact.** Units donated, liters donated, and lives impacted.
* **Live updates.** A WebSocket channel plus a 30-second fallback poll, so new broadcasts and appointment changes appear without restarting the app.

### Appointments

* **Book Appointment.** Three steps (center → date → time) with a progress header, morning and afternoon slots, and a sticky summary with a Confirm button.
* **Appointment tab.** Lists every open request with "Requested by *hospital name*" and its own Reserve button.
* **Active schedule.** View or cancel an upcoming appointment.

### Profile & Digital Health Card

* **Digitalized Health Card.**
  * A physical-ID-style card (front and back) drawn at real ID-1 card proportions (85.6 × 54 mm), with a flip animation.
  * Includes a signature pad, QR check-in code, recent donations, and an MRZ strip.
  * **Download** saves the visible side straight to the phone's gallery.
* **Donation stamps and priority blood access tiers.** Life Starter (1–4), Lifesaving Hero (5–9), Guardian of Life (10+).
* **Lifetime Impact Record** and **Clinical & Donation Records.**
* **QR Digital Pass** for quick hospital check-in.

### Settings

* **Edit personal details.** Name, phone, email, birth date, and emergency contact. Birth date and emergency contact update the health card immediately.
* **Alert & notification preferences.**
  * **Push App Notifications** (shows the phone's permission prompt).
  * SMS alerts and email alerts.
* **Location & emergency radius.** "Use my location" asks for the phone's location permission.
* **Change password, biometric login, sign out, and delete account** (OTP-confirmed).

---

## 🛠️ Tech Stack

| Area | Choice |
| --- | --- |
| Framework | [Flutter](https://flutter.dev/) (Dart 3.7+) |
| Backend | Node.js / Express + PostgreSQL + Redis (the `hospital-web-dashboard` repo), deployed on Render |
| HTTP / realtime | `http` for REST, WebSocket (`/ws`) for live events |
| Secure storage | `flutter_secure_storage`: session token, biometric flag, and on-device preferences (Android Keystore / iOS Keychain) |
| Biometrics | `local_auth` |
| Push notifications | `firebase_messaging` + `flutter_local_notifications` (optional, see below) |
| Location | `geolocator` |
| Gallery save | `gal` |
| Other | `qr_flutter`, `image_picker`, `url_launcher`, `share_plus`, `google_fonts` |

---

## ▶️ Getting Started

### Requirements

* Flutter SDK (stable) with Dart 3.7 or newer
* Android Studio (Android SDK) and/or Xcode (for iOS)
* A real phone or an emulator/simulator

### Run the app

```bash
git clone https://github.com/aliahkono/resq_app.git
cd resq_app
flutter pub get
flutter run
```

By default the app talks to the **deployed backend** (`https://hospital-web-dashboard.onrender.com/api`), so it works right away with the same data as the live admin dashboard.

### Use a local backend instead

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:4000/api
```

* **Android emulator:** run `adb reverse tcp:4000 tcp:4000` first. Re-run it after every emulator restart.
* **iOS simulator:** `127.0.0.1` works directly.
* **Real phone:** use your computer's LAN IP (same Wi-Fi) or an ngrok URL.

The local server and the deployed server use **separate databases**.

### Push notifications (optional)

Push uses Firebase Cloud Messaging, but no Firebase config is committed. Without `android/app/google-services.json` / `ios/Runner/GoogleService-Info.plist`, the app still runs normally with push turned off. The "Push App Notifications" permission prompt still works. To enable push, add your own Firebase config files.

---

## 🔐 Device Permissions

| Permission | Used for | Where it's asked |
| --- | --- | --- |
| Camera / Photos | Profile photo, ID photos for verification | When taking or picking a photo |
| Save to Photos (iOS), storage (Android 9 and below) | Downloading the Digital Health Card | First tap on Download |
| Location (while in use) | "Use my location" for the urgent-alert radius | When the toggle is turned on |
| Notifications | Push App Notifications | When the toggle is turned on |
| Face ID / Biometrics | Biometric login | When biometric login is turned on, and at sign-in |

Declared in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`.

---

## 🗂️ Project Structure

```text
lib/
├── main.dart               # App entry, Firebase/push init (skipped safely if not configured)
├── model/                  # Data models (session, appointment, blood request, broadcast, screening, verification…)
├── services/
│   ├── api_service.dart        # REST client (API_BASE_URL)
│   ├── realtime_service.dart   # WebSocket live events
│   ├── push_service.dart       # FCM + local notifications + OS permission prompt
│   ├── notif_service.dart      # Hospital broadcast notifications (bell)
│   ├── session_storage.dart    # Secure session token + biometric login
│   ├── local_prefs.dart        # Per-donor on-device settings
│   └── eligibility_service.dart
├── utils/
│   ├── algo/               # min_heap.dart (request priority), decision_tree_class.dart (eligibility)
│   ├── constants/          # ResQ theme colors & typography
│   └── helpers/            # Date formatting, eligibility & medical keyword rules, responsive helpers
├── views/
│   ├── splash/             # Animated splash screen
│   ├── onboarding/         # "How ResQ Works" walkthrough
│   ├── auth/               # Landing, login, OTP, registration wizard, terms & conditions
│   ├── home/               # HomeView shell, eligible & deferred dashboards
│   ├── appointment/        # Book appointment, active schedule, no-schedule & deferred views
│   ├── notifications/      # Hospital broadcast list
│   ├── profile/            # Donor profile, Digital Health Card, signature pad, QR pass, verification
│   └── settings/           # Settings & delete-account OTP
└── widgets/                # Shared UI kit (resq_ui.dart), nav bar, notification bell, avatar, donor ID card
```

---

## 📝 Recent Updates (Sept 26–27, 2026)

* Digital Health Card: saves to the gallery; standard ID-card size; fixed stamp label; instant birth date/emergency contact updates
* Terms & Conditions checkbox is saved
* "How ResQ Works" redesign: no circle frame; background wave shown clearly
* "Use my location" asks for location permission
* Profile: Lifesaving Hero no longer overflows at 10+ donations
* Biometric login works end-to-end
* Hospital broadcasts appear on the Dashboard and Appointment tab
* Your Impact redesign (Units / Liters / Lives)
* New Push App Notifications toggle
* Book Appointment screen redesign