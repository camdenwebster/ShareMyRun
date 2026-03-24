# Auto-Share Feature Spec

## Goal
Generate a workout share image automatically when a workout is completed, then either:
- queue it for later use, or
- hand it to Shortcuts so a follow-up action can send a message.

## Current Scope (Implemented)
- `AutoShareConfig` stores:
  - enabled flag
  - delivery mode (`queue_only`, `shortcut_message`)
  - lookback window (minutes)
  - image format (`square`, `story`)
  - persisted queue (`jobs`)
- `AutoShareCoordinator` handles:
  - queueing eligible workouts after sync
  - generating images for pending jobs
  - tracking job state (`pending`, `ready`, `failed`, `delivered`)
- `WorkoutListViewModel.fetchWorkouts()` now triggers auto-share queue/processing after sync.
- `GenerateLatestWorkoutShareIntent` (App Intent) now:
  - syncs workouts from HealthKit
  - prefers queued ready images when available
  - falls back to generating from the most recent workout in the lookback window
  - returns a PNG `IntentFile` for downstream Shortcut actions
- Settings UI now includes an **Auto-Share (Beta)** section to configure behavior and inspect queue counts.

## Shortcut Automation Setup
Recommended personal automation:
1. Trigger: `Workout Ends`
2. Action: `Generate Latest Workout Share` (ShareMyRun)
3. Action: `Send Message` (use the image output from step 2)

## Queue Processing Rules
- Only workouts inside the configured lookback window are auto-queued.
- One job per workout HealthKit ID (deduplicated).
- Jobs are processed in creation order.
- If generation fails, job is marked `failed` with the last error message.

## Constraints
- iOS does not allow fully silent message sending without a Shortcut/user flow, so message delivery is designed around App Intent + Shortcuts.
- Auto-generated jobs fall back away from `selectedPhoto` background to route map or last photo, so background image generation can run without interactive photo picking.

## Next Iterations
- add retry policy for failed jobs
- add queue detail screen (history and manual retry)
- add explicit caption output intent for richer messaging shortcuts
- add background task scheduling so pending queue can process even when main UI is not opened
