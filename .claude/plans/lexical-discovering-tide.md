# CloudKit Sync Debugging Plan

## Context

Books added on Mac are not appearing in real-time on iPhone. The iPhone receives no `NSPersistentStoreRemoteChange` notifications while the app is running. However, rebuilding/restarting the iPhone app shows the updated data — meaning **CloudKit DID sync the data**, but the running app is never notified.

The root cause: there is no `AppDelegate` implementing `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`. CloudKit uses silent APNs pushes to signal data changes. Without this handler, iOS has no confirmation the app processed the notification and increasingly deprioritizes future pushes. `NSPersistentCloudKitContainer` (SwiftData's underlying engine) never gets triggered to pull from CloudKit, so `NSPersistentStoreRemoteChange` is never posted.

---

## Step 1 — Add `AppDelegate` to `tomeApp.swift` (Primary Fix)

**File:** `Tome/tomeApp.swift`

Before the `@main struct tomeApp` declaration, add:

```swift
#if os(iOS)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("[CloudKit DEBUG] Remote notification received")
        if let ckFields = userInfo["ck"] as? [String: Any] {
            print("[CloudKit DEBUG] CloudKit payload: \(ckFields)")
        }
        // Must call within 30 seconds — tells iOS the app is a reliable push recipient
        completionHandler(.newData)
        print("[CloudKit DEBUG] fetchCompletionHandler called with .newData")
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[CloudKit DEBUG] APNs token: \(token)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[CloudKit DEBUG] Failed to register for APNs: \(error)")
    }
}
#endif
```

Inside `tomeApp` struct, add the adaptor property:

```swift
@main
struct tomeApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    // ... rest unchanged
```

---

## Step 2 — Add `eventChangedNotification` Observer to `CloudSyncMonitor` (Diagnostics + Better Signal)

**File:** `Tome/Views/CloudSyncMonitor.swift`

`NSPersistentCloudKitContainer.eventChangedNotification` fires at the CloudKit layer for every import/export/setup event — before `NSPersistentStoreRemoteChange`. Observing it reveals whether CloudKit is processing changes at all.

In `setupNotificationObservers()`, add after the existing observers:

```swift
print("[CloudKit DEBUG] CloudSyncMonitor: observers registered")

NotificationCenter.default.publisher(
    for: NSPersistentCloudKitContainer.eventChangedNotification
)
.receive(on: DispatchQueue.main)
.sink { [weak self] notification in
    self?.handleCloudKitEvent(notification)
}
.store(in: &cancellables)
```

Add the handler method:

```swift
private func handleCloudKitEvent(_ notification: Notification) {
    guard let event = notification.userInfo?[
        NSPersistentCloudKitContainer.eventNotificationUserInfoKey
    ] as? NSPersistentCloudKitContainer.Event else {
        print("[CloudKit DEBUG] eventChangedNotification: missing event object")
        return
    }

    let typeName: String
    switch event.type {
    case .setup:   typeName = "setup"
    case .import:  typeName = "import"
    case .export:  typeName = "export"
    @unknown default: typeName = "unknown"
    }

    if event.endDate == nil {
        print("[CloudKit DEBUG] CloudKit \(typeName) STARTED")
        isSyncing = true
    } else {
        print("[CloudKit DEBUG] CloudKit \(typeName) FINISHED — succeeded=\(event.succeeded)")
        if let error = event.error {
            print("[CloudKit DEBUG]   ERROR: \(error)")
            lastError = error
        }
        if event.succeeded && event.type == .import {
            lastSyncDate = event.endDate
        }
        isSyncing = false
        syncProgress = 1.0
    }
}
```

Also enhance `handleRemoteChange` logging:

```swift
private func handleRemoteChange(_ notification: Notification) {
    print("[CloudKit DEBUG] NSPersistentStoreRemoteChange fired — local store updated from CloudKit")
    if let storeURL = notification.userInfo?[NSPersistentStoreURLKey] as? URL {
        print("[CloudKit DEBUG]   Store: \(storeURL.lastPathComponent)")
    }
    // ... rest of existing code unchanged
```

---

## What to Watch in Xcode Console (iPhone)

After adding a book on Mac, you should see this sequence on iPhone:

```
[CloudKit DEBUG] Remote notification received
[CloudKit DEBUG] CloudKit payload: {...}
[CloudKit DEBUG] fetchCompletionHandler called with .newData
[CloudKit DEBUG] CloudKit import STARTED
[CloudKit DEBUG] CloudKit import FINISHED — succeeded=true
[CloudKit DEBUG] NSPersistentStoreRemoteChange fired — local store updated from CloudKit
```

**Diagnosis by what you see:**
- No "Remote notification received" → APNs push not arriving (check network, APNs registration)
- Push arrives but no import event → NSPersistentCloudKitContainer not processing it
- Import fires but no `NSPersistentStoreRemoteChange` → store options issue (very unlikely with SwiftData)

---

## Files Modified
- `Tome/tomeApp.swift` — Add `AppDelegate` class + `@UIApplicationDelegateAdaptor`
- `Tome/Views/CloudSyncMonitor.swift` — Add `eventChangedNotification` observer + enhanced logging

## No Changes Needed
- `Info.plist` — `UIBackgroundModes: remote-notification` already present ✓
- `tome.entitlements` — `aps-environment: development`, correct container ID ✓
- `ModelContainer` setup — correctly configured with `.private()` CloudKit ✓
