# PRD: ShareMyRun

## Introduction

ShareMyRun is an iOS app that empowers fitness enthusiasts to create beautiful, customizable images of their workouts for sharing on social media. Unlike Strava and similar apps that lock users into rigid templates with limited stats, ShareMyRun imports workouts from Apple Health and lets users choose exactly which statistics to display, how to style them, and what background to use—whether it's the route map, a photo from their camera roll, or the last image captured.

The MVP focuses on manual sharing with full customization capabilities. The Pro tier architecture will be stubbed out for future implementation of automatic posting after workout completion.

## Goals

- Import GPS-based cardio workouts (running, cycling, swimming, hiking, etc.) from Apple HealthKit
- Allow users to select which statistics appear on their shareable image
- Provide three background options: route map (default), last camera roll image, or user-selected image
- Enable moderate text styling: font, color, size, and positioning
- Generate high-quality images suitable for social media sharing
- Stub Pro tier architecture for future automatic sharing feature
- Achieve 90%+ code coverage through TDD with Swift Testing and XCUITest

## User Stories

### Epic 1: Project Setup & Architecture

#### US-001: Initialize Xcode project with SwiftUI and SwiftData
**Description:** As a developer, I need a properly configured Xcode project so that I have a foundation to build on.

**Acceptance Criteria:**
- [ ] Xcode project created with SwiftUI lifecycle
- [ ] SwiftData configured as persistence layer
- [ ] MVVM folder structure established (Models, Views, ViewModels, Services)
- [ ] Swift Testing target configured for unit tests
- [ ] XCUITest target configured for UI tests
- [ ] Project builds and runs on iOS 17+ simulator
- [ ] Typecheck passes

#### US-002: Set up HealthKit entitlements and permissions
**Description:** As a developer, I need HealthKit properly configured so the app can request workout data access.

**Acceptance Criteria:**
- [ ] HealthKit capability added to project
- [ ] Info.plist contains health share usage description
- [ ] HealthService protocol defined for dependency injection
- [ ] Mock HealthService created for testing
- [ ] Unit tests pass for permission request flow
- [ ] Typecheck passes

#### US-003: Set up Photos framework entitlements
**Description:** As a developer, I need photo library access configured so users can select background images.

**Acceptance Criteria:**
- [ ] Photo Library capability added
- [ ] Info.plist contains photo library usage description
- [ ] PhotoService protocol defined for dependency injection
- [ ] Mock PhotoService created for testing
- [ ] Typecheck passes

---

### Epic 2: Data Models & Persistence

#### US-004: Create Workout data model
**Description:** As a developer, I need a Workout model to store imported workout data locally.

**Acceptance Criteria:**
- [ ] SwiftData `@Model` class for Workout with properties: id, type, startDate, endDate, distance, duration, route (coordinates), calories, avgHeartRate, maxHeartRate, avgPace, elevationGain
- [ ] WorkoutType enum covering: running, cycling, swimming, hiking, walking, other
- [ ] Unit tests verify model initialization and persistence
- [ ] Typecheck passes

#### US-005: Create ShareConfiguration data model
**Description:** As a developer, I need a model to persist user's sharing preferences and styling choices.

**Acceptance Criteria:**
- [ ] SwiftData `@Model` class for ShareConfiguration with: selectedStats, backgroundType, fontName, fontSize, textColor, textPosition
- [ ] BackgroundType enum: routeMap, lastPhoto, selectedPhoto
- [ ] TextPosition enum: topLeft, topRight, bottomLeft, bottomRight, center
- [ ] Relationship to Workout (one config per workout, with defaults)
- [ ] Unit tests verify model persistence
- [ ] Typecheck passes

#### US-006: Create StatisticType enum and display logic
**Description:** As a developer, I need a way to represent available statistics and format them for display.

**Acceptance Criteria:**
- [ ] StatisticType enum: distance, duration, pace, startTime, calories, avgHeartRate, maxHeartRate, elevationGain, effort
- [ ] Each case has displayName and unit properties
- [ ] Formatter functions for each stat type (e.g., pace as "X:XX /mi")
- [ ] Unit tests cover all formatting edge cases
- [ ] Typecheck passes

---

### Epic 3: HealthKit Integration

#### US-007: Fetch workouts from HealthKit
**Description:** As a user, I want to see my recent workouts so I can choose one to share.

**Acceptance Criteria:**
- [ ] HealthService fetches workouts from last 30 days
- [ ] Filters to GPS-based cardio types only (running, cycling, swimming, hiking, walking)
- [ ] Converts HKWorkout to app's Workout model
- [ ] Handles permission denied gracefully with user feedback
- [ ] Unit tests with mock HealthStore verify fetch logic
- [ ] Typecheck passes

#### US-008: Fetch workout route data from HealthKit
**Description:** As a user, I want my workout route included so I can display it as a map background.

**Acceptance Criteria:**
- [ ] Fetches CLLocation array for workout route
- [ ] Handles workouts without route data (treadmill, pool swimming)
- [ ] Stores route coordinates in Workout model
- [ ] Unit tests verify route extraction
- [ ] Typecheck passes

#### US-009: Fetch detailed workout statistics from HealthKit
**Description:** As a user, I want detailed stats like heart rate and elevation so I can display them.

**Acceptance Criteria:**
- [ ] Fetches average and max heart rate for workout duration
- [ ] Fetches elevation gain data
- [ ] Calculates average pace from distance/duration
- [ ] Handles missing data gracefully (shows "N/A" or hides stat)
- [ ] Unit tests verify stat calculations
- [ ] Typecheck passes

---

### Epic 4: Core UI - Workout List

#### US-010: Create workout list view
**Description:** As a user, I want to see a list of my recent workouts so I can select one to customize and share.

**Acceptance Criteria:**
- [ ] SwiftUI List displaying workouts sorted by date (newest first)
- [ ] Each row shows: workout type icon, date, distance, duration
- [ ] Pull-to-refresh triggers HealthKit sync
- [ ] Empty state when no workouts available
- [ ] Loading state while fetching
- [ ] Typecheck passes
- [ ] Verify in simulator

#### US-011: Create workout list ViewModel
**Description:** As a developer, I need a ViewModel to manage workout list state and business logic.

**Acceptance Criteria:**
- [ ] WorkoutListViewModel as @Observable class
- [ ] Publishes workouts array, isLoading, error state
- [ ] fetchWorkouts() method coordinates HealthService calls
- [ ] Handles errors and updates state appropriately
- [ ] Unit tests verify all state transitions
- [ ] Typecheck passes

#### US-012: Implement workout type filtering
**Description:** As a user, I want to filter workouts by type so I can find a specific activity quickly.

**Acceptance Criteria:**
- [ ] Filter chip/segmented control above list
- [ ] Options: All, Running, Cycling, Swimming, Hiking, Other
- [ ] Filter persists during session
- [ ] Empty state message when filter yields no results
- [ ] Unit tests verify filtering logic
- [ ] Typecheck passes
- [ ] Verify in simulator

---

### Epic 5: Core UI - Share Image Editor

#### US-013: Create share editor view skeleton
**Description:** As a user, I want an editor screen where I can customize my workout image.

**Acceptance Criteria:**
- [ ] Navigation from workout list to editor (passing selected workout)
- [ ] Preview area showing the shareable image
- [ ] Bottom sheet or sidebar for customization options
- [ ] Share button in navigation bar
- [ ] Typecheck passes
- [ ] Verify in simulator

#### US-014: Create share editor ViewModel
**Description:** As a developer, I need a ViewModel to manage editor state and image generation.

**Acceptance Criteria:**
- [ ] ShareEditorViewModel as @Observable class
- [ ] Holds current Workout and ShareConfiguration
- [ ] Methods for updating each configuration property
- [ ] Saves configuration to SwiftData on changes
- [ ] Unit tests verify state management
- [ ] Typecheck passes

#### US-015: Implement stat selection interface
**Description:** As a user, I want to choose which statistics appear on my image.

**Acceptance Criteria:**
- [ ] Multi-select list of available StatisticTypes
- [ ] Shows current value for each stat from workout
- [ ] Stats unavailable for this workout are disabled/grayed
- [ ] Selection updates preview in real-time
- [ ] Maximum of 6 stats can be selected (UX constraint)
- [ ] Unit tests verify selection logic
- [ ] Typecheck passes
- [ ] Verify in simulator

#### US-016: Implement background selection interface
**Description:** As a user, I want to choose my image background from three options.

**Acceptance Criteria:**
- [ ] Segmented control or picker: Map, Last Photo, Choose Photo
- [ ] Map option shows route (disabled if no route data)
- [ ] Last Photo automatically loads most recent camera roll image
- [ ] Choose Photo opens PHPickerViewController
- [ ] Selection updates preview in real-time
- [ ] Unit tests verify background switching logic
- [ ] Typecheck passes
- [ ] Verify in simulator

#### US-017: Implement text styling controls
**Description:** As a user, I want to customize how the statistics text looks.

**Acceptance Criteria:**
- [ ] Font picker with 5-8 curated fonts suitable for overlays
- [ ] Font size slider (range: 12-32pt)
- [ ] Color picker for text color
- [ ] Position picker (5 options: corners + center)
- [ ] Changes update preview in real-time
- [ ] Typecheck passes
- [ ] Verify in simulator

---

### Epic 6: Image Generation

#### US-018: Create route map renderer
**Description:** As a developer, I need to render the workout route as a styled map image.

**Acceptance Criteria:**
- [ ] Uses MapKit to render route polyline
- [ ] Map styled appropriately (minimal labels, route prominent)
- [ ] Renders to UIImage at share-ready resolution (1080x1080 or 1080x1920)
- [ ] Handles workouts with no route gracefully
- [ ] Unit tests verify image generation doesn't crash
- [ ] Typecheck passes

#### US-019: Create statistics overlay renderer
**Description:** As a developer, I need to render selected statistics as text overlay on the image.

**Acceptance Criteria:**
- [ ] Renders selected stats with configured font, size, color
- [ ] Positions text according to TextPosition setting
- [ ] Adds subtle text shadow/outline for readability on any background
- [ ] Handles variable number of stats (1-6)
- [ ] Unit tests verify text rendering logic
- [ ] Typecheck passes

#### US-020: Create composite image generator
**Description:** As a developer, I need to combine background and overlay into final shareable image.

**Acceptance Criteria:**
- [ ] ImageGenerator service combines background + stats overlay
- [ ] Supports all three background types
- [ ] Outputs UIImage ready for sharing
- [ ] Generates both square (1080x1080) and story (1080x1920) formats
- [ ] Unit tests verify composition logic
- [ ] Typecheck passes

---

### Epic 7: Sharing

#### US-021: Implement share sheet integration
**Description:** As a user, I want to share my customized image to any app via the system share sheet.

**Acceptance Criteria:**
- [ ] Share button triggers UIActivityViewController
- [ ] Passes generated UIImage
- [ ] Includes optional text caption with workout summary
- [ ] Handles share completion/cancellation
- [ ] Typecheck passes
- [ ] Verify in simulator

#### US-022: Save image to camera roll option
**Description:** As a user, I want to save my image to my camera roll as an alternative to sharing.

**Acceptance Criteria:**
- [ ] "Save to Photos" button in share options
- [ ] Requests photo library add permission if needed
- [ ] Shows success/failure feedback
- [ ] Typecheck passes
- [ ] Verify in simulator

---

### Epic 8: Pro Tier Architecture (Stubbed)

#### US-023: Create subscription/Pro tier data model
**Description:** As a developer, I need a model to track Pro subscription status for future use.

**Acceptance Criteria:**
- [ ] UserSubscription SwiftData model with: isPro, expirationDate
- [ ] SubscriptionService protocol with mock implementation
- [ ] isPro check returns false in MVP (hardcoded)
- [ ] Unit tests verify subscription logic
- [ ] Typecheck passes

#### US-024: Create automatic sharing preferences model (stubbed)
**Description:** As a developer, I need a stubbed data model for automatic sharing configuration.

**Acceptance Criteria:**
- [ ] AutoShareConfig model with: isEnabled, destinations, defaultTemplate
- [ ] UI shows "Pro Feature - Coming Soon" when accessed
- [ ] Architecture allows easy implementation later
- [ ] Typecheck passes
- [ ] Verify in simulator (shows Pro placeholder)

#### US-025: Add Pro feature gate UI
**Description:** As a user, I want to see what Pro features will offer so I know what to expect.

**Acceptance Criteria:**
- [ ] Settings screen with Pro section
- [ ] Shows locked automatic sharing option
- [ ] "Upgrade to Pro" button (non-functional in MVP)
- [ ] Clear messaging about upcoming features
- [ ] Typecheck passes
- [ ] Verify in simulator

---

### Epic 9: Polish & Edge Cases

#### US-026: Implement onboarding flow
**Description:** As a new user, I want a brief onboarding so I understand how to use the app.

**Acceptance Criteria:**
- [ ] 3-screen onboarding: Welcome, HealthKit permission, Get Started
- [ ] Only shows on first launch
- [ ] Can be skipped
- [ ] Stores completion in UserDefaults
- [ ] Typecheck passes
- [ ] Verify in simulator

#### US-027: Handle HealthKit permission denied state
**Description:** As a user who denied permissions, I want clear guidance on how to enable them.

**Acceptance Criteria:**
- [ ] Empty state explains why workouts aren't showing
- [ ] "Open Settings" button deep-links to app settings
- [ ] Re-checks permission when app returns to foreground
- [ ] Typecheck passes
- [ ] Verify in simulator

#### US-028: Implement error handling and user feedback
**Description:** As a user, I want clear feedback when something goes wrong.

**Acceptance Criteria:**
- [ ] Toast/alert for transient errors
- [ ] Retry options where appropriate
- [ ] No silent failures - all errors surface to user
- [ ] Typecheck passes

#### US-029: Add accessibility support
**Description:** As a user with accessibility needs, I want to use the app with VoiceOver and Dynamic Type.

**Acceptance Criteria:**
- [ ] All interactive elements have accessibility labels
- [ ] Images have accessibility descriptions
- [ ] Supports Dynamic Type for text scaling
- [ ] Color contrast meets WCAG AA standards
- [ ] VoiceOver navigation works logically
- [ ] Typecheck passes
- [ ] Verify with Accessibility Inspector

---

## Functional Requirements

- **FR-1:** App shall request HealthKit read permission for workouts, heart rate, and route data on first launch
- **FR-2:** App shall request photo library read permission when user selects photo background
- **FR-3:** App shall fetch and display GPS-based cardio workouts from the last 30 days
- **FR-4:** App shall support workout types: running, cycling, swimming, hiking, walking
- **FR-5:** App shall allow selection of 1-6 statistics to display on shareable image
- **FR-6:** Available statistics shall include: distance, duration, pace, start time, calories, avg heart rate, max heart rate, elevation gain
- **FR-7:** App shall offer three background options: route map, last camera roll image, user-selected image
- **FR-8:** App shall provide text customization: font (5-8 options), size (12-32pt), color, position (5 positions)
- **FR-9:** App shall generate shareable images at 1080x1080 (square) and 1080x1920 (story) resolutions
- **FR-10:** App shall present system share sheet for image sharing
- **FR-11:** App shall allow saving generated image to camera roll
- **FR-12:** App shall persist user's last-used styling configuration as defaults
- **FR-13:** App shall display appropriate empty states and error messages
- **FR-14:** App shall stub Pro tier UI showing "Coming Soon" for automatic sharing

## Non-Goals

- No user accounts or authentication in MVP
- No in-app social feed or community features
- No backend server infrastructure
- No automatic sharing implementation (stubbed only)
- No StoreKit/subscription purchase flow (stubbed only)
- No Apple Watch companion app
- No widgets or Live Activities
- No workout recording (import only from Health)
- No video generation (static images only)
- No integration with third-party services (Strava API, etc.)

## Design Considerations

- **Visual Style:** Clean, modern iOS aesthetic following Human Interface Guidelines
- **Color Scheme:** Support both light and dark mode
- **Preview Accuracy:** Editor preview must match final exported image exactly
- **Responsive Layout:** Support all iPhone screen sizes (iPhone SE through Pro Max)
- **Gesture Support:** Pinch-to-zoom on preview, swipe navigation where appropriate

### Key Screens
1. **Workout List** - Primary navigation, filterable list
2. **Share Editor** - Image preview with customization controls
3. **Settings** - App preferences, Pro section, about
4. **Onboarding** - 3-screen first-launch flow

## Technical Considerations

- **Minimum iOS Version:** iOS 17.0 (required for SwiftData, modern SwiftUI features)
- **Architecture:** MVVM with protocol-based dependency injection for testability
- **Persistence:** SwiftData for workouts and configurations
- **Testing Strategy:**
  - TDD approach: write tests before implementation
  - Swift Testing framework for unit tests
  - XCUITest for critical user flows
  - Mock services for HealthKit and Photos
- **HealthKit Queries:** Use HKAnchoredObjectQuery for efficient incremental fetches
- **Image Generation:** Core Graphics for compositing, MapKit snapshots for routes
- **Memory Management:** Careful handling of large images to avoid memory pressure
- **Background Processing:** None required for MVP (no automatic sharing)

### Dependencies
- HealthKit framework
- PhotosUI framework
- MapKit framework
- Core Graphics framework

## Success Metrics

- App successfully imports workouts from HealthKit for 95%+ of supported workout types
- Image generation completes in under 2 seconds on iPhone 12 or newer
- Share flow completes in 3 taps or fewer from workout selection
- 90%+ unit test code coverage on ViewModels and Services
- Zero crashes in critical paths (import, customize, share)
- App size under 20MB

## Open Questions

1. Should we support landscape orientation for the editor screen? - No
2. What specific fonts should be included in the font picker? - Use best judgement
3. Should there be preset "themes" that combine font/color/position for quick styling? - Yes
4. Should generated images include a subtle ShareMyRun watermark? - Yes (Pro to remove)
5. What analytics/telemetry should be included for understanding user behavior? - We'll determine later. For now just count of images shared. TelemetryDeck will be used.
6. Should workout data be cached locally for offline access to previously imported workouts? - Yes. Settings like presets for layouts can be synced via iCloud.
