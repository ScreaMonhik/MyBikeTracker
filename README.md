# Trail Dawn (MyBikeTracker)

Local bicycle GPS tracker for iPhone and iPad. Records outdoor rides, keeps history and a bike garage on-device, and remotes the session from Apple Watch. There is **no account and no cloud**.

| | |
| --- | --- |
| Home-screen / Store display name | **Trail Dawn** |
| App Store title | **Trail Dawn Bike Ride Tracker** |
| Xcode project / module | `MyBikeTracker` |
| Version | **1.0** (build 1) |
| Languages | English, Russian, Ukrainian (follow the device) |
| Platforms | iPhone and iPad (17.6+), watchOS 10.6+, widgets + Live Activity, Control on iOS 18+ |

Full store copy lives in [Store/ASO.md](Store/ASO.md). Legal text lives in [PRIVACY.md](PRIVACY.md) and in Settings.

---

## What it does

### Tabs

| Tab | Role |
| --- | --- |
| **Map** | All saved rides, tap a line for stats / color, long-press for a cycling route |
| **Trip** | Record a ride, live heatmap, address search, share location, pick a bike |
| **History** | Weekly goal, ride list, calendar, day journal, chain-due banner |
| **Settings** | Units, goal, auto-pause, garage, sensors, Health, backup, privacy, diagnostics |

Garage is a screen inside Settings, not its own tab. Deep links (and Live Activity taps) can open a tab:

```
mybiketracker://map
mybiketracker://tracker   (also `trip`)
mybiketracker://history
mybiketracker://settings
```

### Ride tracking

- Start / pause / stop from Trip or Watch. The Lock Screen / Dynamic Island Live Activity shows live stats and opens Trip
- Live time, speed, distance, elevation; live line is a **speed heatmap** (teal → amber → ember), not a single color
- Background GPS only while recording (`CLActivityType.fitness`). **When In Use** first; **Always** is requested at ride start and background updates turn off when the ride ends
- Auto-pause when speed stays below a threshold (default **1 km/h** for **5 s**; both are adjustable)
- GPS gaps are split (no straight “teleport” line). A road fill is requested when the network returns (Apple Directions, cycling / walking / auto fallback). Huge blackouts are not filled
- Optional [Mapbox Map Matching](https://docs.mapbox.com/api/navigation/map-matching/) snaps the finished track to cycling roads (chunks of 96 points, 2-point overlap). Without a token, GPS still saves
- End-ride confirmation: **Save**, **Discard**, or cancel. Rides under **80 m and 45 s** are flagged as accidental
- Crash-safe checkpoint in the App Group every **8 GPS points or 12 s**. Relaunch restores track, timer, pause, sensors averages, selected bike, and Live Activity
- Share current coordinates during an active ride (system share sheet + maps URL)

### Map

- Saved rides on one MapKit map (capped at **40** lines plus the selected ride)
- Newest ride — or any ride you tap — is a heatmap; older lines use the Settings default color or a per-ride custom color
- Long-press (~0.5 s) builds a turn-by-turn **cycling** route (`MKDirections`)
- Address search on the Trip tab
- Tap a line for a popup: stats, heatmap share, edit line color

### History and journal

- Ride list with this week vs last week and a weekly distance goal (default **50 km**, 5–500)
- Calendar of ride days
- Per-day journal: note + camera or photo-library image
- Ride detail: map (heatmap when GPS speeds exist), stats, elevation profile, heart rate / cadence when a sensor was connected, bike name, line color

### Garage

- Several bikes: name, odometer, chain interval (default **400 km**)
- Selected bike is offered on Trip before start; finishing a ride adds distance to that odometer
- Per-bike heatmap thresholds (default slow **< 12 km/h**, medium **< 28 km/h**)
- Chain-due reminder on History; reset chain wear from the bike row

### Sensors, Health, shortcuts

- Bluetooth Heart Rate (`180D`) and Cycling Speed and Cadence (`1816`)
- Wheel circumference in Settings (default **2105 mm**, 1500–2400)
- BLE stack starts only when you open Sensors, reconnect a known device, or start a ride that has one saved
- Optional Apple Health **write**: outdoor cycling workout, distance, estimated calories, heart rate sample, GPS route. **No Health read**. Calories use MET from speed (70 kg assumed); if average HR ≥ 90, Keytel is used when it is higher
- App Store review prompt after the **third saved ride of at least 2 km**, then at most once every **120 days** — not on first launch

### Widgets, Live Activity, Watch

| Surface | What it shows |
| --- | --- |
| Small widget | Yearly distance (km or mi from Settings) |
| Medium widget | Yearly distance + this month’s ride-day calendar |
| Live Activity / Dynamic Island | Elapsed time, speed, distance, paused state. Tap opens `mybiketracker://tracker` |
| Control (iOS 18+) | **Start Ride** — opens the app (`openAppWhenRun`; no tab deep link) |
| Apple Watch | Start / pause / resume / stop, live time, speed, distance, iPhone units. Stop asks to **save or discard**. iPhone must be reachable (`WatchConnectivity` + `RideRemoteProtocol`) |

Widget summaries are copies in App Group `UserDefaults` (`widget_rides`), refreshed when the ride list changes. Timeline rebuilds at local midnight.

### Settings and diagnostics

- Metric or imperial (Watch and widgets follow the iPhone)
- Weekly goal, auto-pause speed / delay
- Default color for older history lines
- HealthKit on/off (default on)
- JSON backup / import (export warns that the file contains precise GPS)
- Privacy Policy (in-app + [GitHub copy](https://github.com/ScreaMonhik/MyBikeTracker/blob/main/PRIVACY.md))
- On-device product events + last MetricKit crash summary. **Nothing is sent off-device**

DEBUG builds add **Developer**: simulated moving / paused rides, stop simulation but keep the ride, seed History / Calendar samples.

---

## How data is stored

- **SwiftData** on device: `Ride`, `Bike`, `DayJournal`. Journal photos are JPEGs in `Application Support/DayPhotos/`
- If the store fails to open, files are copied to `Application Support/StoreBackups/` (not deleted). The app retries the store, then falls back to an in-memory session and shows a banner
- **App Group** `group.com.sunko.mybiketracker`: widget JSON + `live_ride_checkpoint.json`
- Do **not** change bundle IDs (`dimsun.*`) or the App Group on an already-installed copy — widgets and checkpoints would detach

A saved ride stores start/end, duration, distance, average/max speed, elevation, optional bike, raw GPS, optional matched geometry, HR / cadence averages, optional `#RRGGBB` line color.

Backup file: `mybiketracker_backup_*.json` (`AppBackupDTO` — rides, bikes including pace thresholds, journals + photo JPEG). Import skips UUIDs already present. Legacy ride-only JSON still imports and advances the bike odometer.

---

## Targets and identifiers

| Target | Bundle ID | Role |
| --- | --- | --- |
| **MyBikeTracker** | `dimsun.MyBikeTracker` | iPhone / iPad app |
| **BikeTrackerWidgetExtension** | `dimsun.MyBikeTracker.BikeTrackerWidget` | Widgets + Live Activity + Control |
| **BikeTrackerWatch** | `dimsun.MyBikeTracker.watchkitapp` | watchOS companion |
| **MyBikeTrackerTests** | `dimsun.MyBikeTrackerTests` | Hosted XCTest |

| | |
| --- | --- |
| App Group | `group.com.sunko.mybiketracker` |
| URL scheme | `mybiketracker` |
| Encryption flag | `ITSAppUsesNonExemptEncryption` = **NO** |
| Icon | Layered `AppIcon.icon` (light, dark, tinted) |
| Scheme | **MyBikeTracker** (tests attached) |

Shared files that must stay in **app + widget**: `AppGroupConfig.swift`, `RideWidgetEntry.swift`, `BikeTrackerAttributes.swift`.

---

## Requirements

- Xcode 16+ (project last touched with the current iOS / watchOS SDKs; Liquid Glass on iOS 26+, material chrome before that)
- iOS **17.6+** for the app and widgets
- watchOS **10.6+**
- Paid Apple Developer team and a **physical device** for GPS, Bluetooth, HealthKit, Always location, and Watch
- The same App Group on the app and the widget extension

---

## Getting started

1. Clone the repo and open `MyBikeTracker.xcodeproj`.
2. Set your development team on the three shipping targets (app, widget, Watch).
3. Confirm App Group `group.com.sunko.mybiketracker` — or change it in Signing & Capabilities **and** in `MyBikeTracker/Models/AppGroupConfig.swift`.
4. Create `MyBikeTracker/Secrets.xcconfig` (gitignored). Debug/Release already include it:

   ```xcconfig
   // Optional. Leave empty to skip Mapbox matching; GPS tracks still save.
   MAPBOX_ACCESS_TOKEN = pk.your_token_here
   ```

5. Run the **MyBikeTracker** scheme.

Without a Mapbox token the app records and stores rides; matching is skipped.

```bash
# Unit tests (host: the iOS app)
xcodebuild test -scheme MyBikeTracker -destination 'platform=iOS Simulator,name=iPhone 17'
```

Tests cover GPS gap / teleport split, checkpoint JSON, backup UUID + odometer, accidental-ride threshold, calories vs HR, yearly miles, weekly-goal unit round-trip, pace bands, heatmap selection, chain wear, and the calendar grid.

---

## Permissions

Asked only when needed:

| Permission | When | Why |
| --- | --- | --- |
| Location When In Use | Map / Trip | Show you and record while the app is open |
| Location Always | Ride start | Background track while the phone is locked; turned off after stop |
| Bluetooth | Sensors or known device / ride start | HR and CSC sensors |
| HealthKit write | Ride save if the toggle is on | Workout, calories, optional HR, route — no read |
| Camera / Photo Library | Day journal | Optional photo on a calendar day |

Each shipping target has `PrivacyInfo.xcprivacy`: no tracking, precise location + Health for app functionality only, UserDefaults (`CA92.1`) and file timestamps (`C617.1`).

App Privacy questionnaire (Store Connect): precise location (on-device + optional Mapbox HTTPS), HealthKit write, no tracking.

---

## App Store listing (indexed fields)

Do not repeat words across name, subtitle, and keywords.

| Field | Value |
| --- | --- |
| Name (30) | `Trail Dawn Bike Ride Tracker` |
| Subtitle (30) | `GPS, Health & Weekly Goal` |
| Keywords (100) | `cycle,odometer,cadence,heartrate,map,history,garage,chain,widget,watch,island,export,journal,commute` |
| Promotional text | Local GPS rides, Apple Watch remote, widgets, and a garage — no account and no cloud. |
| Privacy policy URL | https://github.com/ScreaMonhik/MyBikeTracker/blob/main/PRIVACY.md |

Do not add `bike`, `ride`, `tracker`, `gps`, `health`, `weekly`, or `goal` to keywords — they are already in the name or subtitle.

Host a static copy of `PRIVACY.md` if App Review wants a page that is not a GitHub blob. Screenshots / preview are **not** in this repo: capture 6.9″ iPhone and 13″ iPad after a real ride (live tracker, history goal, all-rides map, garage, widget).

---

## Project layout

```
MyBikeTracker/                 iOS app
  MyBikeTrackerApp.swift       SwiftData container, analytics launch
  ContentView.swift            tabs + deep links + end-ride cover
  Models/                      Ride, Bike, DayJournal, backup / widget / Watch DTOs
  ViewModels/                  MapViewModel, RidesViewModel
  Views/                       tabs, garage, calendar, settings, permissions
  Views/Components/            heatmap legend, journal, map chrome, ride rows
  DesignSystem/                Brand tokens, type, Liquid Glass fallback
  Services/                    location, Health, Mapbox, BLE, checkpoint, widgets, analytics
  Extensions/                  units, colors, elevation, preferences
  AppIcon.icon/                layered icon
  Localizable.xcstrings        en / ru / uk
  PrivacyInfo.xcprivacy
  Secrets.xcconfig             gitignored Mapbox token (create locally)
BikeTrackerWidget/             small + medium widgets, Live Activity, Control
BikeTrackerWatch/              Watch UI + WatchConnectivity session
MyBikeTrackerTests/            XCTest
Store/ASO.md                   listing copy
Design/BrandBook.md            visual tokens
PRIVACY.md                     public policy
```

UI tokens: parchment canvas, trail teal, ember. Metrics use SF Rounded. Reduce Motion replaces live pulse with a fade. See [Design/BrandBook.md](Design/BrandBook.md).

---

## License

No license file is included. Treat the repository as private source unless the owner adds one.
