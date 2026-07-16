# CampusPulse — Firebase Setup

This is the checklist to turn on cross-device data sync + push notifications. All Swift code is already wired and guarded with `#if canImport(FirebaseFirestore)` — once the SDK is present and configured, everything wakes up automatically. No view code needs to change.

## 1 · Create the Firebase project

1. Go to <https://console.firebase.google.com> and create a project named `CampusPulse` (or whatever you like).
2. Add an **iOS app** — bundle id must match the app's `PRODUCT_BUNDLE_IDENTIFIER` (currently `SAO.Campus`).
3. Download `GoogleService-Info.plist`.
4. Drag it into the Xcode project **into the `Campus/` folder** (same folder as `Info.plist`). Make sure the **Campus** target is checked when Xcode asks.

## 2 · Add the Firebase SDK via Swift Package Manager

In Xcode:

1. **File → Add Package Dependencies…**
2. Paste: `https://github.com/firebase/firebase-ios-sdk`
3. Dependency Rule: **Up to Next Major Version — 11.0.0** (or later).
4. Add these products to the **Campus** target:
   - `FirebaseFirestore`
   - `FirebaseMessaging`
   - (Optional) `FirebaseAuth` — only if you later switch on Firebase-backed sign-in

## 3 · Enable services in the Firebase console

- **Firestore Database → Create database → Start in production mode** (rules below).
- **Cloud Messaging → Get started** (no config needed for topic pushes).
- **Project Settings → Cloud Messaging → APNs Authentication Key**: upload the `.p8` key from Apple Developer + your Team ID + Key ID. Without this, iOS pushes cannot be delivered.

Firestore rules — a minimum viable ruleset for the demo (tighten before real deployment):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      // Locked to authenticated users. Swap for granular per-collection
      // rules once you decide whose write is authoritative.
      allow read, write: if request.auth != null;
    }
  }
}
```

If you don't want to require Firebase Auth right now, change the last line to `allow read, write: if true;` **for the demo only** and lock it down before shipping.

## 4 · Xcode capabilities

Select the **Campus** target → **Signing & Capabilities → + Capability**:

- **Push Notifications**
- **Background Modes** → tick **Remote notifications**

The `Info.plist` already registers the `campuspulse://` URL scheme for QR check-ins.

## 5 · Deploy the Cloud Function (assignment push)

```
cd functions
npm install
firebase login       # first time only
firebase use --add   # pick your CampusPulse project
firebase deploy --only functions:notifyOnAssign
```

That's all. On every new document in `assignments/`, the function looks up the event + user, then sends an FCM push to the topic `user_<leaderId>`. The iOS client subscribes to that topic on sign-in (see `CampusApp.resubscribeCurrentUser()`), so the leader gets the notification on their own device even if the admin created the assignment from a different phone.

## 6 · Verify

1. Build & run on **two devices** (or one device + simulator).
2. Sign in as an admin on device A and a leader on device B.
3. Assign the leader from device A. Device B should:
   - See the new assignment appear in `My Events` in real time (Firestore listener).
   - Receive an APNs push a moment later (Cloud Function → FCM → APNs).
4. Have any signed-in student scan the event QR from device C — the leader's live count on device B updates within a second (Firestore listener).

## Data model

Four Firestore top-level collections:

| Collection    | Doc ID                            | Fields                                                                                                     |
|---------------|-----------------------------------|------------------------------------------------------------------------------------------------------------|
| `events`      | `<eventId>` (matches app)         | title, clubId, location, startTime, endTime, technicalNeeds, status, cateringNotes                         |
| `assignments` | `<eventId>::<leaderId>`           | eventId, leaderId, isMain                                                                                  |
| `attendance`  | UUID                              | eventId, studentId, scannedAt                                                                              |
| `debriefs`    | `<eventId>`                       | full debrief payload — every SAO Q1-Q15 field                                                              |

Schemas match `firestorePayload` / `init(firestore:)` extensions in `Campus/FirebaseSync.swift`.

## Rolling back to demo mode

If Firebase is misconfigured, `AppDelegate.application(_:didFinishLaunchingWithOptions:)` will notice the missing `GoogleService-Info.plist` and skip `FirebaseApp.configure()`. `FirebaseSync.isEnabled` stays `false`, no listeners attach, and every remote call is a no-op — the app continues to run with local in-memory data exactly like it did before.
