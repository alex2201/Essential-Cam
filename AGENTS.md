# Essential Cam — Agent Instructions

## Project context

- Native iPhone camera app using Swift 6, SwiftUI, AVFoundation, and Swift Concurrency. Read `README.md` for product context and setup.
- Preserve the simple camera interface and editing-ready capture intent. Do not introduce third-party dependencies, AI processing, or additional image processing unless required by the task. You can suggest if you think it suits well for the task.
- App deployment target: iOS 18.0. Guard newer APIs with availability checks and provide appropriate fallbacks. Always report APIs availability issues. Read the project settings before choosing a test destination; the current test targets require iOS 26.5.

## Change scope

- Inspect the working tree before editing. Preserve unrelated changes and keep the diff focused on the requested task.
- Follow the surrounding Swift conventions. Reuse existing services, protocols, and controls before adding abstractions.
- Keep signing, bundle identifiers, deployment targets, and project-wide build settings unchanged unless the task requires changing them.
- Suggest to update `README.md` when features, requirements, or setup change before commiting. Keep this file focused on actionable project rules.

## Architecture

- `Domain/`: models, use cases, and repository contracts. Keep new domain logic independent of SwiftUI and concrete hardware or persistence implementations.
- `Core/`: AVFoundation, Photo Library access, device discovery, capture services, and persistence implementations.
- `Presentation/`: SwiftUI views, view models, and presentation controllers. Keep hardware operations and persistence logic in their existing services.
- Use dependency injection at existing protocol boundaries so domain workflows can be tested without camera hardware.
- Prefer lightweight `struct` use cases and create them at the point of use, such as inside a `.task` or when handling a user action. Do not retain use cases in stored properties, `@State`, or the environment by default. Retain an instance only when its lifecycle, ongoing work, or substantial reuse requires it, and explain that need.

## Camera and concurrency rules

- Keep observable UI state on `@MainActor`. Preserve `CameraSession`'s actor isolation and dedicated serial executor for session and device operations.
- Run blocking capture-session start/stop and configuration work off the main actor. Do not mutate the session from views or add detached tasks that bypass its isolation.
- Pair `beginConfiguration()` with `commitConfiguration()` and successful device configuration locks with unlocks, using `defer` where appropriate. Keep session configuration transactions synchronous; do not suspend inside them.
- Preserve cancellation and operation guards during capture, camera switching, lifecycle changes, and delayed control updates. Handle interruption and background/foreground transitions without leaving controls or session state stuck.
- Detect capabilities on the active camera and clamp settings to supported ranges. Refresh capabilities after lens or format changes; do not assume all devices support the same flash, RAW, resolution, focus, or exposure options.
- Do not add `@unchecked Sendable`, `nonisolated(unsafe)`, or concurrency-warning suppression without explaining the isolation guarantee. Do not weaken Swift concurrency checking to make a build pass.

## Photo safety and persistence

- Preserve the pending-photo capture/save/retry/discard workflow. A failed Photo Library save must retain the photo for recovery; a successful save must not be retried merely because pending-file cleanup failed.
- Keep persisted settings and presets compatible with previously saved data. Supply decoding defaults or a deliberate migration when changing stored models.
- Handle denied or limited permissions and storage failures explicitly. Keep privacy usage descriptions aligned with the APIs used, including microphone access if audio recording is added.
- Avoid logging photo contents or private library metadata. Use the existing OSLog conventions for diagnostic events.

## UI rules

- Preserve accessible labels, values, and selection states for camera controls. Verify changed layouts with larger text and supported orientations.
- Reflect active hardware capabilities and capture state in enabled/disabled controls. Surface recoverable failures with a clear retry or discard path when applicable.

## Validation

- For changed domain logic, persistence, or capture workflows, add or update focused Swift Testing tests in `Essential CamTests`. Use isolated temporary files and UserDefaults suites. Test failure paths and regressions, not just successful execution.
- Use XCTest/XCUIAutomation in `Essential CamUITests` for meaningful UI assertions. Existing launch/performance tests alone do not establish camera behavior.
- Discover available destinations rather than assuming a simulator name:

  ```sh
  xcodebuild -showdestinations -project "Essential Cam.xcodeproj" -scheme "Essential Cam"
  ```

- Run relevant tests on an available compatible destination, replacing `SIMULATOR_UDID` with its actual identifier:

  ```sh
  xcodebuild test -project "Essential Cam.xcodeproj" -scheme "Essential Cam" \
    -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
    -only-testing:Essential\ CamTests
  ```

- After implementing any user-visible behavior change, build, install, and launch Essential Cam on the physical test device **iPhone Alex 14 Pro Max** (`00008120-0018499C1444C01E`) before reporting completion. A successful compile alone is not sufficient validation.
- Example device workflow from the repository root:

  ```sh
  xcodebuild build -project "Essential Cam.xcodeproj" -scheme "Essential Cam" \
    -configuration Debug -destination 'id=00008120-0018499C1444C01E' \
    -derivedDataPath /tmp/essential-cam-validation
  xcrun devicectl device install app --device 00008120-0018499C1444C01E \
    "/tmp/essential-cam-validation/Build/Products/Debug-iphoneos/Essential Cam.app"
  xcrun devicectl device process launch --device 00008120-0018499C1444C01E \
    com.alexanderlopez.Essential-Cam
  ```

- Run each device step only after the preceding step succeeds. Exercise the changed behavior on hardware when accessible: preview, capture/save, changed controls, orientation, or lifecycle recovery as relevant. Launch success alone does not establish that these interactions work.
- If the device is unavailable, installation or launch fails, or manual verification cannot be performed, report the exact limitation. Distinguish build, tests, installation, launch, and behavior checks in the completion report.
- Documentation-only changes do not require a device build/install/launch.

## Code Review Rules

- Prioritize main-thread blocking, actor-isolation violations, unbalanced configuration transactions, unsupported hardware settings, photo loss or duplicate saves, persistence compatibility, and lifecycle races.
- Flag missing validation for changed behavior. Tie each finding to a concrete trigger and user impact.
