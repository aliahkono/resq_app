# 🩸 ResQ — Donor Mobile Application

**ResQ** is a centralized blood donation management mobile platform designed to bridge the gap between voluntary blood donors and blood banks/hospitals in real time. The app dynamically prioritizes emergency blood requests using a **Min-Heap priority queue algorithm** and manages donor eligibility through a **decision tree model**.

---

## 🚀 Features

* **Animated 5-Phase Brand Onboarding:** Smooth entry animation showcasing ResQ branding before navigating to authentication.
* **Smart Donor Screening:** Instant eligibility assessment based on age, weight, and health parameters.
* **Priority Request Feed:** Emergency blood requests ranked dynamically by urgency and proximity.
* **Seamless Appointment Booking:** Dedicated workflows for eligible donors to reserve donation slots and deferred donors to track recovery count downs.
* **QR Digital Pass:** Quick QR code verification for instant hospital check-in.

---

## 🛠️ Tech Stack & Architecture

* **Framework:** [Flutter](https://flutter.dev/) (Dart)
* **Design Pattern:** Clean Architecture with Feature-based Directory Structure (`views/`, `model/`, `utils/`)
* **State Management:** Local persistence with `SharedPreferences`
* **Backend Integration Target:** Express / Node.js with PostgreSQL & Redis (Dockerized)

---

## 🗂️ Project Structure

```text
lib/
├── controller/         # Logic & state management controllers
├── model/              # Data models (DonorProfileModel, BloodReqModel, AppSessModel, etc.)
├── utils/
│   ├── algo/          # Min-Heap priority queue & decision tree classification algorithms
│   ├── constants/     # ResQ Theme colors, typography, & styling
│   └── helpers/       # Date formatting & eligibility logic helpers
└── views/
    ├── appointment/   # Slot booking, deferral roadmaps, & empty state views
    ├── auth/          # OTP verification & registration wizard
    ├── home/          # Active (eligible) & deferred (ineligible) donor dashboards
    ├── onboarding/    # Interactive onboarding walkthrough
    ├── profile/       # Impact statistics & QR check-in pass modal
    ├── settings/      # App preferences & notification controls
    └── splash/        # 5-phase animated SplashScreen