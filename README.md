# MyBikeTracker

iOS app for recording bicycle rides: GPS track, stats, history, and a garage for your bikes. Includes an Apple Watch companion, Home Screen widgets, and a Live Activity on the Lock Screen and Dynamic Island.

## Features

### Ride tracking
- Start, pause, and stop a ride from the **Trip** tab
- Live time, speed, distance, and elevation gain
- Background GPS only while a ride is recording (`fitness` activity; Always is requested at ride start)
- Configurable auto-pause when you slow down
- GPS gaps are split instead of drawing a straight “teleport” line; road fills are added when the network is back
- Optional [Mapbox Map Matching](https://docs.mapbox.com/api/navigation/map-matching/) to snap the finished track to cycling roads
- Confirmation screen before a ride is saved, plus Discard and a short-ride warning
- Live ride is checkpointed to the App Group so a crash can restore it
- Share your current location during an active ride

### Map
- All completed rides on one map
- Default line color in Settings, or a custom color per ride (tap a line on the map, or open the ride in History)
- Long-press the map to build a turn-by-turn route
- Address search from the Trip tab

### History
- Ride list with weekly goal vs last week
- Calendar of ride days
- Per-day journal: note and photo
- Ride detail: map, stats, elevation profile, line color
- JSON backup / import of rides, bikes, and journal (GPS export is confirmed first)

### Garage
- Multiple bikes, odometer, chain-service interval
- Pick a bike before starting a ride
- Chain-due reminder on the History tab

### Sensors and shortcuts
- Bluetooth heart-rate monitors (standard HR service)
- Bluetooth cadence / speed sensors (CSC), with wheel circumference in Settings
- Save finished rides to Apple Health (cycling workout, calories, optional heart rate, route)

### Widgets and Watch
- Small widget: yearly distance
- Medium widget: yearly distance plus a month calendar of ride days
- Live Activity / Dynamic Island while a ride is running
- watchOS app: start / pause / stop and live time, speed, and distance (iPhone app must be reachable)

### Settings
- Metric or imperial units
- Weekly distance goal
- Auto-pause speed and delay
- Any color for the live track and for the default history lines
- HealthKit on/off

UI language follows the device: **English**, **Russian**, and **Ukrainian**.

## Targets

| Target | Bundle ID | Role |
| --- | --- | --- |
| **MyBikeTracker** | `dimsun.MyBikeTracker` | iPhone / iPad app |
| **BikeTrackerWidgetExtension** | `dimsun.MyBikeTracker.BikeTrackerWidget` | Widgets + Live Activity |
| **BikeTrackerWatch** | `dimsun.MyBikeTracker.watchkitapp` | watchOS companion |

Shared App Group: `group.com.sunko.mybiketracker`.

## Requirements

- Xcode 16 or later (the project is built against the current iOS SDK; Liquid Glass is used on iOS 26+ and falls back to material chrome on earlier versions)
- iOS **17.6+** for the app
- watchOS **10.6+** for the Watch app
- Apple Developer team and a physical device for GPS, Bluetooth, and HealthKit
- The same App Group enabled on the app and the widget extension

## Getting started

1. Clone the repo and open `MyBikeTracker.xcodeproj`.
2. Select your development team on all three targets.
3. Confirm the App Group `group.com.sunko.mybiketracker` is enabled (or change the ID in Signing & Capabilities **and** in `MyBikeTracker/Models/AppGroupConfig.swift`).
4. Create `MyBikeTracker/Secrets.xcconfig` (gitignored). The Debug/Release project configs already include it:

   ```xcconfig
   // Optional. Leave empty to skip Mapbox matching; GPS tracks still save.
   MAPBOX_ACCESS_TOKEN = pk.your_token_here
   ```

5. Build and run the **MyBikeTracker** scheme.

Without a Mapbox token the app still records and stores rides. Matching simply does not run.

DEBUG builds add a **Developer** section in Settings: simulated moving/paused rides and sample rides for History and Calendar.

## Permissions

The app asks for:

- Location (When In Use first; Always only during an active ride)
- Bluetooth — heart-rate and cycling sensors, after you open Sensors or start a ride with a known device
- HealthKit — write cycling workouts, calories, optional heart rate, and routes (no Health read)
- Camera / Photo Library — day-journal photos

## Project layout

```
MyBikeTracker/                 iOS app
  Models/                      SwiftData: Ride, Bike, DayJournal
  ViewModels/                  MapViewModel, RidesViewModel
  Views/                       tabs, settings, garage, calendar
  Services/                    location, HealthKit, Mapbox, BLE, widgets
  Extensions/                  units, colors, elevation, preferences
BikeTrackerWidget/             Home Screen widgets + Live Activity
BikeTrackerWatch/              watchOS UI + WatchConnectivity session
```

Rides, bikes, and journal entries are stored locally with **SwiftData**. Widget summaries are copied into the App Group `UserDefaults`.

## Ride data

A saved ride includes start/end time, duration, distance, average/max speed, elevation, optional bike, raw GPS, optional matched geometry, heart rate / cadence averages when a sensor was connected, and an optional custom line color. Backup uses JSON (`AppBackupDTO`) and skips rows whose UUID is already present. Legacy ride-only files still import.

Privacy policy: [PRIVACY.md](PRIVACY.md). Store listing copy: [Store/ASO.md](Store/ASO.md).

## License

No license file is included. Treat the repository as private source unless the owner adds one.
