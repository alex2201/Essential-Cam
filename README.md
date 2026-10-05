# Essential Cam

Essential Cam is a native iPhone camera app that keeps the interface simple while giving photographers direct control over the settings that matter most.

The project focuses on capturing clean, editing-ready photos with Apple's camera APIs, without adding artificial intelligence or heavy post-processing.

## Features

- Live camera preview with a portrait-only interface
- Photo capture and automatic saving to the Photo Library
- SDR video recording with microphone audio, supported 1080p/4K resolutions and 24/25/30/50/60 fps
- H.264/HEVC video codecs, supported stabilization modes, and continuous light when available
- Independent photo/video settings during a session, with separate locally saved presets and quick-control layouts
- Video thumbnails with a play overlay and in-app playback
- Retry or discard recordings when saving to Photos fails
- Startup storage check with a low-space warning for photos and videos
- Quick preview after each capture
- Physical and virtual lens selection
- Automatic exposure with exposure compensation
- Manual ISO and shutter-speed controls
- Automatic and manual focus
- Automatic and manual white balance, including temperature and tint
- Off, on, and automatic flash modes
- Camera capability detection so controls adapt to the current device
- Accessible labels and selection states for camera controls
- Camera, microphone, and add-only Photo Library permission checks when entering Video mode

## Requirements

- Xcode 26 or later
- iOS 18.0 or later
- An iPhone for camera capture and accurate hardware testing

Firebase Analytics, Crashlytics, and Authentication are integrated through Swift
Package Manager. Feedback is saved to Cloud Firestore through its REST API.

## Getting started

1. Clone the repository:

   ```bash
   git clone https://github.com/alex2201/Essential-Cam.git
   cd "Essential Cam"
   ```

2. Open `Essential Cam.xcodeproj` in Xcode.
3. Select the **Essential Cam** scheme and an iPhone as the run destination.
4. Choose your development team under **Signing & Capabilities** if required.
5. Download the iOS `GoogleService-Info.plist` from each Firebase environment's
   project settings. Save the development configuration as
   `Essential Cam/Firebase/GoogleService-Info-Dev.plist` and the production
   configuration as `Essential Cam/Firebase/GoogleService-Info-Prod.plist`.
   Debug builds use the development file; other build configurations use the
   production file. The build phase copies the selected configuration into the
   app as `GoogleService-Info.plist`. Both local files are ignored by Git and
   required by the build inputs. In CI, supply them securely before building;
   do not commit these files or their API keys.
6. Build and run the app.
7. Allow Camera and Photo Library access when prompted.

### Feedback setup

In **both** Firebase projects, enable **Authentication > Sign-in method >
Anonymous** and create the default Cloud Firestore database. In **Firestore >
Rules**, publish the feedback rules in `Firebase/firestore.rules`. Merge the
`feedbacks` match into existing rules if the database serves other features;
remove any overlapping broad rule that grants public access to feedback.

Settings > Feedback sends one document to `feedbacks` with exactly `message`,
`createdAt` (server timestamp), `appVersion`, and `buildNumber`. Debug uses the
development project and Release uses production. No login screen is required,
and no user ID is stored in feedback documents. Only authenticated creates are
allowed; client reads, updates, and deletes are blocked.

The form rejects blank or oversized messages (5,000 UTF-8 bytes), prevents
simultaneous submissions, and clears the message only after server confirmation.
Failed submissions retain the draft and reuse its document ID on retry, without
overwriting an accepted document or its creation date. The draft is held only
while this screen remains open; leaving it or terminating the app discards it.
Firestore requests time out after 30 seconds and aren't queued for offline
delivery. Authentication may take additional time. App Check enforcement is not
configured by this change; review abuse protection before a public rollout.

At each app launch, Essential Cam checks available local storage before opening
the camera or onboarding. If less than 1 GB is available, an alert shows the
remaining space and warns that photos and videos may fail to save or recording
may stop early. Free up space in **Settings > General > iPhone Storage**, or tap
**Continue** to proceed. If storage cannot be checked, the app shows a separate
notice and still allows continuing. The 1 GB threshold is a preventive warning,
not a guarantee that a photo or recording will fit; media size and recording
duration determine the space needed.

Switching to Video checks camera, microphone, and permission to add media to the
Photo Library, requesting undecided permissions in that order. If access is
denied, open Settings from the alert or return to Photo mode. Permissions are
checked again when the app becomes active in Video mode. Microphone access is
not required for photos.

Video defaults to 1080p/30 fps H.264 in a QuickTime MOV file with SDR color and
microphone audio. Settings is available in both capture modes: exposure, focus,
and white balance have independent values, and the Video section exposes only
supported resolution/frame-rate combinations, codecs, stabilization modes, and
continuous light when available. Configuration happens before recording so the
preview uses the selected format. Changing the camera or applying a preset may
select compatible fallback values and show a notice; the saved preset is unchanged.
Camera, mode, and settings changes remain blocked while recording or saving.

Settings always provides access to both Photo and Video profiles, including their
presets and quick-control layouts. Closing Settings restores the capture mode used
when opening it.

Video's Microphone selector offers Automatic, iPhone Microphone, and external
inputs recognized by iOS. Automatic delegates input and direction selection to the
capture session. While Settings is open and the app is active, available inputs
refresh every second, including while editing a preset. Connecting a microphone
updates the list without changing the selected input. When a selected input
disconnects, the active Video profile returns to the most
recent available microphone selection, or Automatic if none is available. The
saved preset keeps its external input preference. Reconnecting does not override
the fallback selection; select the microphone or preset again to use it. Microphone choices are
session-only unless saved in a preset, and can also be added to quick controls.

Photo and video values are kept separately **in memory for the current session**;
relaunching starts with defaults. Only presets and quick-control selection/order
are persisted locally. Existing presets and quick-control personalization remain
Photo configurations; Video has its own preset list and quick controls. New photo
presets also include output format, resolution, timer, and correction. Presets
exclude camera identifiers and zoom. Editing an applied preset changes the active
values without updating the saved preset; saving/updating a preset is explicit.

The red button becomes a stop button with elapsed time. Leaving the app or a camera
interruption ends the recording. A failed save keeps the file for retry or discard,
including after relaunch. An unfinished or unreadable file requires explicit
discard. Returning while a clip finishes defers camera reconciliation; controls
remain unavailable while the session is interrupted. The gallery shows photos and
videos with in-app playback. HDR, Log, ProRes, and changes during recording are
outside this release.

> The iOS Simulator does not provide the same camera hardware or capabilities as a physical iPhone. Use a real device when testing capture, flash, focus, exposure, white balance, and lens selection.

## Architecture

The codebase separates camera infrastructure, domain models, and SwiftUI presentation:

```text
Essential Cam/
├── Application/    SwiftUI app entry point and application delegate
├── Core/           AVFoundation services, device discovery, capture, and persistence
├── Domain/         Camera models, repository contracts, and use cases
└── Presentation/   SwiftUI views, view models, preview, and camera controls
```

Camera work is isolated behind protocols and coordinated with Swift Concurrency. The presentation layer observes a main-actor view model, while AVFoundation session operations run away from the UI.

## Testing

Run the test suite from Xcode with **Product > Test**, or from the command line with a suitable simulator destination:

```bash
xcodebuild test \
  -project "Essential Cam.xcodeproj" \
  -scheme "Essential Cam" \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Hardware-dependent camera behavior should be verified manually on a physical iPhone.

## Technology

- Swift 6
- SwiftUI
- AVFoundation
- Swift Concurrency
- Swift Testing

## Status

Essential Cam is under active development. APIs, controls, and the user interface may change as the project evolves.
