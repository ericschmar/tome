# Plan: Fix CloudKit Sync Visibility and Diagnose macOS Export Failure

## Context

Beth has ~300 books on macOS and 0 on iOS. CloudKit database is confirmed empty on both dev and production. The diagnostics reveal:

- **Same User Record ID on both devices** — same iCloud account, not the issue
- **macOS**: "Last Sync: 57 seconds ago" but **zero CloudKit events** in the log
- **iOS**: Successful Export/Import events, but no data (nothing to export)

The "Last Sync" timestamp on macOS comes from `NSPersistentStoreRemoteChange` (fires on any local store write, including our migration), NOT from an actual CloudKit sync event. So macOS has never successfully pushed data to CloudKit.

**Root cause**: `CloudSyncMonitor.shared` is lazily initialized — only when `SettingsView` opens. `NSPersistentCloudKitContainer` fires Setup/Export events at app startup, before the monitor is listening. We've been blind to all macOS sync activity. The earlier CKError 2 (partialFailure) we observed was almost certainly the reason exports never succeeded, and we never saw a successful export because the monitor wasn't running.

Our cover data fix (`@Attribute(.externalStorage)` + migration) should unblock the exports, but we need the monitor running at startup to confirm it.

## Changes

### 1. Initialize `CloudSyncMonitor` at app startup
**File:** `Tome/tomeApp.swift`

Add `CloudSyncMonitor.shared` as a stored property on `tomeApp` so it initializes before any view appears and starts observing CloudKit events immediately:

```swift
// Add alongside navigationState
private let syncMonitor = CloudSyncMonitor.shared
```

### 2. Add local book count to diagnostics
**File:** `Tome/Views/SettingsView.swift`

Add `@Query private var allBooks: [Book]` to `SettingsView` and surface it in `diagnosticsRows`:

```swift
diagnosticsRow(label: "Local Books", value: "\(allBooks.count)")
```

This immediately confirms whether the migration ran (coverImageData cleared) and whether local data exists to be synced — without needing to dig through logs.

## Files to Modify
- `Tome/tomeApp.swift` — add `private let syncMonitor = CloudSyncMonitor.shared`
- `Tome/Views/SettingsView.swift` — add `@Query` for book count, add row to `diagnosticsRows`

## Verification
1. Build and run on Beth's macOS
2. Open Settings → Diagnostics immediately on first launch
3. **Local Books** should show ~300
4. Within ~30 seconds, CloudKit events should appear (Setup ✓ → Export ✓)
5. Check CloudKit Console — records should now be visible in the production private database
6. Open iOS app — books should sync down via Import events
