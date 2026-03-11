# CloudKit Sync Not Working for TestFlight Tester

## Context

CloudKit sync works on the developer's personal builds (via Xcode) but not for the first tester on TestFlight. The container name is fine — all users share the same container identifier (`iCloud.com.ericschmar.tome`) but each user has their own private partition. That's correct and expected.

The root cause is a **CloudKit environment mismatch**:

- **Xcode builds** → connect to the **Development** CloudKit environment
- **TestFlight builds** → connect to the **Production** CloudKit environment

The schema (record types, indexes for Book and Tag) currently only exists in the Development environment. The Production environment is essentially empty, so SwiftData on the tester's device has no valid schema to sync against, causing sync to silently fail or do nothing.

The `aps-environment: development` in `tome.entitlements` is not the issue — Xcode automatically overrides this to `production` when archiving for TestFlight/App Store.

## Fix: Deploy Schema to Production in CloudKit Dashboard

No code changes are needed. This is a one-time CloudKit Dashboard operation.

### Steps

1. Go to [CloudKit Console](https://icloud.developer.apple.com/dashboard)
2. Select the **iCloud.com.ericschmar.tome** container
3. Navigate to **Schema** → **Record Types** in the Development environment
4. Verify the schema looks correct (should see record types for Book and Tag, likely prefixed with `CD_` since SwiftData generates them)
5. Click **Deploy Schema Changes to Production** (button in the top area of the Schema section)
6. Confirm the deployment

## Data Added Before Schema Deployment

Both Mac and iOS were TestFlight builds → both use the Production CloudKit environment → the local data on Mac is the right data.

However, sync attempts that happened before the schema was deployed likely failed silently. NSPersistentCloudKitContainer queues these and retries, but it may need some time or a nudge.

### What to try (in order)

1. **Wait and leave apps open** — Open the Mac app and leave it active for 5–10 minutes. CloudKit processes retries in the background and may catch up on its own.

2. **Force quit and reopen both apps** — This restarts the NSPersistentCloudKitContainer sync cycle and will re-attempt any pending uploads.

3. **Check CloudKit Console** — Go to [CloudKit Console](https://icloud.developer.apple.com/dashboard) → select the container → **Data** → **Private Database** and check if any records show up in the Production environment under the tester's account (you'd need to use the "Query" tool with a test account).

4. **If still stuck — add a new book on Mac** — A new write will force a fresh sync attempt, which often unsticks queued records. If the newly added book appears on iOS but old ones don't, it means the old records may be permanently stuck in a failed state and may not retry without app reinstall.

5. **Nuclear option: reinstall the app** — If old records don't sync after 15–20 minutes, the tester can delete and reinstall the app on both devices. On first launch, SwiftData will push all local data to CloudKit fresh. **Warn the tester**: if they do this on the device with the data (Mac), the data will be re-uploaded. If they delete from the device without the data (iOS) first, they just lose the empty state and re-download from cloud once Mac syncs.

### Verification

After deploying:
1. Have the tester open the app on their device (no reinstall needed)
2. Add a book on one of your devices and check if it appears on the other within ~30 seconds
3. Have the tester add a book and verify it syncs to their other devices

### Notes

- The tester syncs within their **own** iCloud account (private database). They won't see your books and you won't see theirs — that's correct.
- Once schema is in production, all current and future TestFlight/App Store users will sync correctly.
- You only need to redeploy if you add new fields/models to Book or Tag.
