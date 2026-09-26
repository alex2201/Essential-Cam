# Essential Cam

Essential Cam is a native iPhone camera app that keeps the interface simple while giving photographers direct control over the settings that matter most.

The project focuses on capturing clean, editing-ready photos with Apple's camera APIs, without adding artificial intelligence or heavy post-processing.

## Features

- Live camera preview with orientation support
- Photo capture and automatic saving to the Photo Library
- Quick preview after each capture
- Physical and virtual lens selection
- Automatic exposure with exposure compensation
- Manual ISO and shutter-speed controls
- Automatic and manual focus
- Automatic and manual white balance, including temperature and tint
- Off, on, and automatic flash modes
- Camera capability detection so controls adapt to the current device
- Accessible labels and selection states for camera controls

## Requirements

- Xcode 26 or later
- iOS 18.6 or later
- An iPhone for camera capture and accurate hardware testing

The app has no third-party dependencies.

## Getting started

1. Clone the repository:

   ```bash
   git clone https://github.com/alex2201/Essential-Cam.git
   cd "Essential Cam"
   ```

2. Open `Essential Cam.xcodeproj` in Xcode.
3. Select the **Essential Cam** scheme and an iPhone as the run destination.
4. Choose your development team under **Signing & Capabilities** if required.
5. Build and run the app.
6. Allow Camera and Photo Library access when prompted.

> The iOS Simulator does not provide the same camera hardware or capabilities as a physical iPhone. Use a real device when testing capture, flash, focus, exposure, white balance, and lens selection.

## Architecture

The codebase separates camera infrastructure, domain models, and SwiftUI presentation:

```text
Essential Cam/
├── Core/           AVFoundation services, device discovery, capture, and persistence
├── Domain/         Camera models and photo-capture use cases
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
