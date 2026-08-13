# ESCUTA-006: Add Setup and Status Controls

## Problem

The current menu does not show model download consent or detailed progress.
The user must know whether Escuta is ready before a meeting.

## Outcome

The menu shows permission, model, queue, and transcript status.
Escuta asks before the first model download.

## Scope

- Show microphone permission status.
- Show system-audio permission guidance.
- Show whether the selected model is local.
- Add a model download action.
- Show model name, approximate size, and destination before download.
- Add `Download` and `Not now` actions.
- Show model download progress.
- Show model load status.
- Show the active session and track during transcription.
- Show transcription progress when WhisperKit supplies progress data.
- Show the number of queued sessions.
- Keep recording controls available during transcription.
- Notify the user when a transcript is ready.
- Notify the user when transcription fails.
- Add actions to open the latest transcript and retry a failed job.

## Business Rules

- Escuta must not start a model download before user consent.
- `Not now` keeps the session pending.
- Recording remains available when the model is not local.
- macOS has no reliable status query for system-audio permission.
- The menu must explain this system limit.

## Acceptance Criteria

- The menu shows microphone permission as allowed, not requested, or denied.
- The menu gives a corrective action when microphone permission is denied.
- The menu explains how system-audio permission is requested.
- The menu shows whether the production model is local.
- The first download requires user confirmation.
- A declined download does not remove or fail pending work.
- Download progress updates in the menu.
- Transcription status shows the session, track, and queue count.
- The user can start a recording while transcription runs.
- A ready notification identifies the session.
- A failure notification identifies the session log.

## Verification

- Run with no local model.
- Accept the model download.
- Cancel or decline the model download.
- Restart Escuta with the model present.
- Run with microphone permission denied.
- Run before system-audio permission is granted.
- Queue more than one session.
- Record while a queue job runs.
- Verify ready and failure notifications.

## Dependencies

- `ESCUTA-003`
- `ESCUTA-004`
- `ESCUTA-005`

## Out of Scope

- A full application window.
- Live captions.
- Automatic system-audio permission detection when macOS does not supply it.
