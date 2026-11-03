# Learn Sphere (Flutter app)

One Flutter codebase, two interfaces:

- **Phone** (Android): bottom-tab app with today's orbit, limits, insights and your profile. Tracks real app usage, warns you, and shows the centre-screen "Time's up" popup over other apps.
- **Web** (browser wider than 900px): dark-rail dashboard with an orbit overview, apps table, limit cards, insights and settings. A narrow browser window gets the phone layout.

Data lives in **Firebase** (Auth + Firestore). The **FastAPI backend** (`../backend`) checks limits and writes the alert messages.

```
Android phone --usage--> Firestore <--live-- web dashboard / other devices
      ^                      |
      +---- limits ----------+      FastAPI /sync <-- usage + limits --> alerts
```

> This code was written without access to the Flutter SDK, so it has been syntax-checked but not compiled or run. Expect to fix a small error or two on first build; paste any message you get and it can be fixed quickly.

## 1. Firebase (once)

1. Create a project at https://console.firebase.google.com.
2. **Authentication > Sign-in method**: turn on **Email/Password** and **Google**.
3. **Firestore Database**: create one (production mode), then paste `firebase/firestore.rules` into the Rules tab and publish. Each user can only read and write their own data.
4. In the project folder run:
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Pick your project and the **android** and **web** platforms. This overwrites `lib/firebase_options.dart`.
5. Android Google sign-in only: add your debug SHA-1 in Firebase project settings (`cd android && ./gradlew signingReport`), then run `flutterfire configure` again.

## 2. Backend

The app talks to `https://learn-sphere-backend-bygr.onrender.com` by default (set in `lib/config.dart`).
**Redeploy it with `backend/main.py` and `backend/requirements.txt` from this zip first**: the version currently live is the older one without `/sync` and per-user data, so the app would show "Server offline".

On Render: Build command `pip install -r requirements.txt`, Start command `uvicorn main:app --host 0.0.0.0 --port $PORT`, and add the environment variable `FIREBASE_PROJECT_ID` = your Firebase project id (this turns on login-token checking).
Render's free plan sleeps when idle, so the first request after a pause can take about a minute; tap Retry if the app shows "Server offline" right after a long pause.

To run it locally instead:

```
cd ../backend
pip install -r requirements.txt
# development (no token check):
uvicorn main:app --reload --host 0.0.0.0 --port 8000
# production: verify Firebase sign-in on every request
FIREBASE_PROJECT_ID=your-project-id uvicorn main:app --host 0.0.0.0 --port 8000
```

## 3. Create the platform folders

```
flutter create --platforms=android,web --project-name learn_sphere .
flutter pub get
python3 tools/apply_android.py
```

`apply_android.py` copies the Kotlin tracking code into `android/` and adds the permissions, the monitor service and the boot receiver to `AndroidManifest.xml`. It can be re-run safely.

## 4. Run

```
# Web dashboard
flutter run -d chrome

# Android phone or emulator
flutter run -d <device>

# Use a local backend instead of the Render one
flutter run -d <device> --dart-define=API_BASE_URL=http://10.0.2.2:8000   # Android emulator
flutter run -d <device> --dart-define=API_BASE_URL=http://192.168.1.20:8000  # real phone, same Wi-Fi
```

## 5. First run on Android

Open **You**, then allow the three permissions:

| Permission | Why |
|---|---|
| Usage access | read how long each app is used |
| Display over other apps | draw the popup in the middle of the screen |
| Notifications | warn you before a limit is reached |

Add a limit and the background monitor starts. At the warning level you get a notification; at the limit a popup appears over the app with **Close app** and **5 more minutes**.

No phone handy? **You > Load sample data** (or Settings on the web) fills a week of example usage and three limits so every screen has something to show.

## Project map

```
lib/
  main.dart                 app start, sign-in gate, phone/web switch
  state/app_state.dart      one place that joins Firebase, the API and the phone
  services/                 auth, firestore, api (FastAPI), native_bridge (Android)
  theme/                    colours, type, field style
  widgets/                  orbit view, week bars, limit editor, overuse popup
  screens/auth|mobile|web   the three interfaces
android_native/             Kotlin: usage reader, monitor service, overlay, boot receiver
tools/apply_android.py      installs the Kotlin code and manifest entries
firebase/firestore.rules    per-user security rules
```

## Good to know

- Android only tracks apps and shows the popup; iPhone and web show the data synced from your Android phone.
- Usage history on Android is limited by what the system keeps (about a week).
- On Android 14+ the monitor is a "special use" foreground service. A store release needs a short justification in the Play Console.
- Fonts (Bricolage Grotesque, Instrument Sans) load from Google Fonts at runtime. Bundle them if you need offline-first launch.
- The backend keeps data in memory. It is only a rules and alert engine; Firestore is the source of truth, and the app re-sends everything on each sync.
