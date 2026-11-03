# 🎓 Learn Sphere

<p align="center">
  <b>A Cross-Platform Smart Learning Management & Digital Wellbeing Platform</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android%20|%20iOS%20|%20Web%20|%20Desktop-blue?style=for-the-badge" alt="Platform" />
  <img src="https://img.shields.io/badge/Frontend-Flutter%203.x-02569B?style=for-the-badge&logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge&logo=fastapi" alt="FastAPI" />
  <img src="https://img.shields.io/badge/Python-3.9+-3776AB?style=for-the-badge&logo=python" alt="Python" />
  <img src="https://img.shields.io/badge/Language-Dart%20|%20Python%20|%20Kotlin-orange?style=for-the-badge" alt="Languages" />
</p>

---

## 📖 About Learn Sphere

**Learn Sphere** is an ecosystem that bridges **online education** and **digital wellbeing**. While online learners need access to digital devices for coursework, research, and coding, distractions from social media and entertainment apps often derail productive study sessions.

Learn Sphere solves this by pairing a complete **Course & Learning Classroom** with an **Intelligent Screen Time & App Limit Manager**:
- Tracks real-time app usage across devices via native system APIs.
- Automatically calculates study streaks and productive vs. distracting screen time ratios.
- Enforces strict app timers with gentle warning notifications and full-screen blocking overlays when daily quotas are exceeded.
- Synchronizes analytics seamlessly across mobile devices and web dashboards.

---

## 🏛️ System Architecture

Learn Sphere is built using a decoupled client-server architecture:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        LEARN SPHERE FRONTEND                           │
│                         (Flutter Multiplatform)                        │
├───────────────────────────────────┬────────────────────────────────────┤
│           Mobile Client           │             Web Client             │
│   (Android & iOS Shell / Tabs)    │     (Responsive Desktop Shell)     │
│  - Home Dashboard & Circular Dial │  - Executive Overview & Metrics    │
│  - App Limits & Duration Sliders  │  - Monitored Apps Grid             │
│  - Weekly Insights & Analytics    │  - Curriculum & Limit Editor       │
│  - User Profile & Downtime Modes  │  - Platform Settings               │
└─────────────────┬─────────────────┴──────────────────┬─────────────────┘
                  │                                    │
                  ▼                                    ▼
       ┌───────────────────────┐            ┌───────────────────────┐
       │     Native Bridge     │            │      Local State      │
       │  (Android Kotlin / JNI│            │   (Orbit / Reactive)  │
       │ - UsageStatsManager   │            │ - SQLite Offline Cache│
       │ - System Alert Window │            │ - SharedPreferences   │
       │ - Foreground Service  │            │ - Secure Token Storage│
       └──────────┬────────────┘            └───────────┬───────────┘
                  │                                     │
                  └──────────────────┬──────────────────┘
                                     │
                             RESTful API (JSON)
                                     │
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        LEARN SPHERE BACKEND                            │
│                         (FastAPI / Python)                             │
├────────────────────────────────────────────────────────────────────────┤
│  - REST Endpoints (/usage, /limits, /alerts, /health)                  │
│  - Real-Time Limit Evaluation Engine (OK / Warning / Exceeded)         │
│  - Concurrency Lock & Thread-Safe In-Memory / Persistent Storage       │
│  - Batch Syncing Pipeline for Background Device Telemetry             │
│  - CORS Middleware & Interactive Swagger/OpenAPI Documentation         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## ⚙️ How It Works (End-to-End Workflow)

```
 [1. App Used on Phone] ──> [2. Native Bridge Reads Usage] ──> [3. Background Sync to FastAPI]
           │                                                                  │
           ▼                                                                  ▼
 [6. Exceeded Overlay Blocker] <── [5. Threshold Evaluated] <── [4. Limit Comparison]
   (Centre-screen popup &           (Status: OK / Warning           (Used Seconds vs.
    touch-blocking window)           at 80% / Exceeded at 100%)      Daily Limit Minutes)
```

1. **Telemetry Capture**: On mobile, the Android native bridge interacts with `UsageStatsManager` to track foreground window transitions and active screen time seconds.
2. **Batch Syncing**: The mobile client bundles application telemetry and syncs with the FastAPI backend via `PUT /usage/sync` or real-time `POST /usage/log`.
3. **Status Evaluation**: The backend compares accumulated daily usage against configured limits for each package:
   - **`ok`**: Usage is below the user's warning threshold.
   - **`warning`**: Usage crosses the threshold (default: 80%). A system notification banner displays remaining minutes.
   - **`exceeded`**: Usage reaches 100% of the daily quota.
4. **Enforcement & Intervention**: When an app is exceeded, the mobile shell triggers a `SYSTEM_ALERT_WINDOW` overlay. The full-screen modal intercepts user input, presents the time spent, and offers options to either exit the app or return to study mode in Learn Sphere.
5. **Analytics & Reflection**: Usage metrics are processed into daily totals, weekly trend charts, peak hourly heatmaps, and category ratios (Productive vs. Entertainment).

---

## 🌟 Key Features

### 1. 📱 Home Dashboard & Real-Time Screen Time
- **Circular Progress Dial**: Visualizes today's aggregate screen time with hour and minute formatting.
- **Top Apps Feed**: Lists applications ranked in descending order of screen time with color-coded progress bars.
- **Learning Streak Counter**: Tracks consecutive days of productive study with an animated streak flame.
- **Focus Mode**: Quick-action Pomodoro timer to silence non-essential apps during deep study blocks.

### 2. ⏱️ App Limits & Custom Timers
- **Granular Daily Quotas**: Set usage limits in minutes or hours for individual apps or entire categories (e.g., Social Media).
- **Customizable Warning Threshold**: Choose when to receive advance warning alerts (e.g., at 75%, 80%, or 90% of the limit).
- **Grace Periods & Snooze**: Option to grant a one-time 5-minute extension for critical tasks.
- **Pause & Resume**: Temporarily suspend enforcement for a specific app without deleting the configured timer.

### 3. 🛡️ System Overlays & Distraction Blocker
- **Full-Screen Intervention**: Displays a centre-of-screen modal ("Time's up!") directly over blocked applications.
- **Touch Interception**: Consumes underlying touch gestures to prevent mindless scrolling.
- **System Shade Alerts**: Sends persistent notifications with actionable deep links back to the Learn Sphere dashboard.

### 4. 📊 Analytics, Trends & Insights
- **Weekly Bar Chart**: Interactive Mon–Sun bar graph with tap tooltips displaying daily screen time.
- **Category Donut Chart**: Breakdown of time spent across Education, Productivity, Social Media, and Games.
- **Week-over-Week Metrics**: Shows percentage trends compared to the previous week to encourage habit reduction.
- **Hourly Heatmap**: 24-hour visual distribution highlighting peak phone usage hours.

### 5. 🌙 Bedtime & Wellbeing Modes
- **Downtime Schedule**: Set custom bedtime hours (e.g., 10:00 PM to 7:00 AM) to automatically restrict entertainment apps.
- **Quiet Hours**: Suppresses audible alert chimes during scheduled study hours and meetings.
- **Follow System Theme**: Seamless dark and light mode adaptation matching system display preferences.

---

## 📁 Directory Structure

```text
├── learn_sphere/                       # Flutter Application (Mobile, Web, Desktop)
│   ├── android/                        # Android Native Project (Kotlin, Gradle, Manifest)
│   ├── ios/                            # iOS Native Project (Swift, Runner, Xcode)
│   ├── web/                            # Web Bootstrap (index.html, Manifest, Icons)
│   ├── lib/                            # Dart Source Code
│   │   ├── main.dart                   # Application Entry Point & Route Definitions
│   │   ├── config.dart                 # API Host & Environment Settings
│   │   ├── models/                     # Data Models (AppUsage, AppLimit, User)
│   │   ├── screens/                    # User Interface Screens
│   │   │   ├── auth/                   # Login, Registration & Password Recovery
│   │   │   ├── mobile/                 # Mobile Shell, Home, Limits, Insights, Profile
│   │   │   └── web/                    # Desktop & Tablet Responsive Web Shell
│   │   ├── services/                   # Service Layer
│   │   │   ├── api_service.dart        # Backend HTTP Client
│   │   │   ├── auth_service.dart       # Session & Token Management
│   │   │   └── native_bridge.dart      # Platform Channels for Android Usage & Overlays
│   │   ├── state/                      # Global Reactive State Management
│   │   ├── theme/                      # Design System Tokens, Colors & Typography
│   │   └── widgets/                    # Reusable UI Components & Dialogs
│   └── pubspec.yaml                    # Flutter Package Dependencies
│
└── Learn-Sphere-Backend-main/          # FastAPI Backend Server
    ├── main.py                         # Application Core, Endpoints & Data Models
    └── requirements.txt                # Python Server Dependencies
```

---

## 🛠️ Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Mobile & Web UI** | [Flutter](https://flutter.dev/) (Dart 3.x) | Cross-platform frontend compiled to native Android, iOS, and Web |
| **Backend API** | [FastAPI](https://fastapi.tiangolo.com/) (Python 3.9+) | High-performance asynchronous REST API framework |
| **API Server** | [Uvicorn](https://www.uvicorn.org/) | Lightning-fast ASGI web server implementation |
| **Data Validation** | [Pydantic v2](https://docs.pydantic.dev/) | Strict data parsing, type validation, and schema definitions |
| **Native Integration** | Android Kotlin & Platform Channels | Access to `UsageStatsManager` and `SYSTEM_ALERT_WINDOW` |
| **Local Storage** | SQLite (`sqflite`) & SharedPreferences | Offline caching of usage telemetry and user preferences |
| **API Documentation** | OpenAPI 3.0 / Swagger UI | Interactive API documentation available at `/docs` |

---

## 🚀 Getting Started

### 1. Run the Backend API Server

Open a terminal and navigate to the backend directory:

```powershell
cd "Learn-Sphere-Backend-main"

# Install backend dependencies
pip install -r requirements.txt

# Start the FastAPI server with live reloading
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Once started:
- API Root: `http://localhost:8000`
- Interactive Swagger Documentation: `http://localhost:8000/docs`
- Health Check: `http://localhost:8000/health`

---

### 2. Run the Flutter Application

In a separate terminal, navigate to the `learn_sphere` directory:

```powershell
cd "learn_sphere"

# Fetch Flutter dependencies
flutter pub get

# Run on Chrome (Web)
flutter run -d chrome

# Or run on a connected Android device / emulator
flutter run -d android
```

---

## 🔌 API Endpoints Reference

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/` | Returns service name and documentation link |
| `GET` | `/health` | Server health check probe |
| `POST` | `/usage/log` | Logs seconds of usage for a specific app package |
| `PUT` | `/usage/sync` | Bulk syncs daily usage totals across multiple apps |
| `GET` | `/usage/today` | Retrieves per-app usage breakdown for today |
| `GET` | `/usage/history` | Fetches historical daily screen time summaries |
| `DELETE` | `/usage` | Flushes all recorded usage data |
| `PUT` | `/limits/{package_name}` | Creates or updates daily time limit for an app |
| `GET` | `/limits` | Lists all configured limits with current statuses |
| `GET` | `/limits/{package_name}/status` | Checks real-time limit status for a specific app |
| `DELETE` | `/limits/{package_name}` | Removes limit configuration for an app |
| `GET` | `/alerts` | Returns all apps currently in `warning` or `exceeded` state |

---

## 🔒 Security & Privacy

- **On-Device Processing**: Screen time analysis is computed using local system timestamps without collecting personal user keystrokes or screen contents.
- **Configurable Whitelisting**: System utilities, phone dialer, and emergency services are permanently exempt from blocking overlays.
- **Zero Third-Party Ad Trackers**: No third-party ad SDKs or user tracking telemetry are embedded.

---

## 📄 License

This project is licensed under the MIT License — see the repository for details.
