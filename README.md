# Essential Cam

Essential Cam is a native iPhone camera app that keeps the interface simple while giving photographers direct control over the settings that matter most.

The project focuses on capturing clean, editing-ready photos with Apple's camera APIs, without adding artificial intelligence or heavy post-processing.

## Features

- Live camera preview with orientation support
- Photo capture and automatic saving to the Photo Library
- Basic 1080p/30 fps SDR video recording with microphone audio
- Video thumbnails with a play overlay and in-app playback
- Retry or discard recordings when saving to Photos fails
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
- iOS 18.6 or later
- An iPhone for camera capture and accurate hardware testing

Firebase Analytics and Crashlytics are integrated through Swift Package Manager.

## Getting started

1. Clone the repository:

   ```bash
   git clone https://github.com/alex2201/Essential-Cam.git
   cd "Essential Cam"
   ```

2. Open `Essential Cam.xcodeproj` in Xcode.
3. Select the **Essential Cam** scheme and an iPhone as the run destination.
4. Choose your development team under **Signing & Capabilities** if required.
5. Download `GoogleService-Info.plist` for the iOS app with bundle identifier
   `com.alexanderlopez.Essential-Cam` from your Firebase project settings and place
   it in `Essential Cam/GoogleService-Info.plist`. This local file is ignored by
   Git and is required for Firebase initialization. In CI, supply it securely
   before building; do not commit the file or its API key.
6. Build and run the app.
7. Allow Camera and Photo Library access when prompted.

Switching to Video checks camera, microphone, and permission to add media to the
Photo Library, requesting undecided permissions in that order. If access is
denied, open Settings from the alert or return to Photo mode. Permissions are
checked again when the app becomes active in Video mode. Microphone access is
not required for photos.

Video mode records H.264 QuickTime clips at 1080p/30 fps with automatic exposure,
focus, and white balance. Choose a camera and zoom before recording; camera,
mode, and settings changes are blocked until the clip finishes saving. The red
button starts recording and becomes a stop button with an elapsed-time display.
Leaving the app or a camera interruption ends the recording. A failed save keeps
the file on this device for retry or discard, including after relaunch. An
unfinished file from a terminated process may need to be discarded. The gallery
shows photos and videos, and the play overlay opens a video player. Resolution,
frame rate, and manual video settings are reserved for a later release.

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
