# ProteIn

A protein tracker whose entire experience lives on a medium home screen widget.
The app itself is a single screen for setting your daily goal (default **165g**);
everything else — logging, progress, undo — happens on the widget.

- Swift + SwiftUI + WidgetKit, iOS 17+
- No third-party dependencies, no backend, no account, no ads, no tracking
- All data lives in App Group `UserDefaults` shared between app and widget

## Project layout

```
ProteIn/
├── ProteIn.xcodeproj
├── ProteIn/                  # App target (onboarding / goal settings screen)
│   ├── ProteInApp.swift
│   ├── GoalView.swift
│   ├── Assets.xcassets
│   └── ProteIn.entitlements
├── ProteInWidget/            # Widget extension target (the core product)
│   ├── ProteInWidgetBundle.swift
│   ├── ProteInWidget.swift
│   ├── Info.plist
│   └── ProteInWidget.entitlements
└── Shared/                   # Compiled into BOTH targets
    ├── ProteinStore.swift    # App Group UserDefaults store + midnight reset
    └── ProteinIntents.swift  # AppIntents driving the widget buttons
```

## Setup (one-time, in Xcode)

1. Open `ProteIn.xcodeproj` in Xcode 15 or newer.
2. Select the **ProteIn** target → Signing & Capabilities → choose your team.
   Do the same for the **ProteInWidget** target.
3. **App Group** (required — this is the bridge between the widget and the app):
   both targets ship with the App Group `group.com.protein.tracker` already in
   their entitlements. Register that group ID on your developer account (Xcode
   usually offers to do this automatically under Signing & Capabilities → App
   Groups). If you use your own group ID instead, change it in exactly three
   places so they stay in sync:
   - `Shared/ProteinStore.swift` → `ProteinStore.appGroupID`
   - `ProteIn/ProteIn.entitlements`
   - `ProteInWidget/ProteInWidget.entitlements`

   If the group IDs don't match, taps on the widget will write to a different
   defaults suite than the app reads, and nothing will appear to update.
4. You may also want to change the bundle identifiers (`com.protein.tracker`
   and `com.protein.tracker.widget`) to match your team's namespace. The widget
   bundle ID must remain prefixed by the app's bundle ID.
5. Build & run on an iOS 17+ device or simulator, then long-press the home
   screen → add the **ProteIn** medium widget.

## Behavior

- **+1 / +5 / +10 buttons** log grams instantly via iOS 17 interactive widget
  buttons (`Button(intent:)` + `AppIntent`). The intent runs in the widget
  process, writes to the shared store, and the widget re-renders immediately.
- **Undo button** removes the most recent entry and shows what it will remove
  (e.g. "Undo 10g").
- **Ring** fills proportionally toward the goal and shifts hue from blue toward
  yellow as you get close, then snaps to green at 100%, when the remaining
  label also flips to **GOAL HIT**.
- **Midnight reset** is automatic and timer-free: entries are stored under a
  per-day stamp, so any read on a new day sees 0. The widget timeline also
  schedules a refresh just after midnight so the displayed number resets even
  if you never tap it.

## Design note: press-and-hold to subtract

The original spec called for press-and-hold on the +N buttons to subtract.
WidgetKit does not support this: interactive widgets only accept
`Button(intent:)` / `Toggle(intent:)` taps, and the system reserves long-press
on a widget for the edit/remove context menu — there is no long-press gesture
API inside a widget, on any iOS version. Per the fallback in the spec, the
widget instead ships a dedicated **undo** button that removes the last logged
entry. Because logging happens in 1/5/10g taps, undo gives the same corrective
power (hold-to-remove-N is equivalent to undoing the tap that added N).

## App Store notes

- Priced as a **paid app at $0.99** (one-time). Pricing is configured in App
  Store Connect (Pricing and Availability → $0.99 tier); no StoreKit code is
  needed because there are no in-app purchases or subscriptions.
- No data collection of any kind — the privacy "nutrition label" in App Store
  Connect can declare "Data Not Collected". There is no network code in the app.
- Before submitting, add a 1024×1024 app icon to
  `ProteIn/Assets.xcassets/AppIcon.appiconset` (the set is present but empty).
