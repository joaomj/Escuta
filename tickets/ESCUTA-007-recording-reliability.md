# ESCUTA-007: Verify Recording Reliability

## Problem

Meeting audio is the source data for all later work.
Write errors, route changes, or process stops must not cause silent data loss.

## Outcome

Escuta preserves each readable track and reports recording problems in the
session folder and menu.

## Scope

- Keep separate `mic.caf` and `system.caf` files.
- Keep streaming writes to crash-tolerant CAF files.
- Save recorder write failures in session state and logs.
- Check audio readability when recording stops.
- Check audio frame count when recording stops.
- Keep a readable track when the other track fails.
- Connect recorder failures to the partial-transcript rule in `ESCUTA-003`.
- Add a real-device test checklist.
- Test recording while WhisperKit uses memory and compute resources.
- Test microphone and output route changes.

## Business Rules

- Escuta must not delete readable audio after a recorder failure.
- A track failure must be visible to the user.
- A session with one readable track can continue to transcription.
- The transcript must identify the missing track.

## Acceptance Criteria

- A normal meeting creates separate microphone and system-audio files.
- Both files remain readable after a clean stop.
- Readable audio remains after forced process termination.
- A track write failure appears in the session log.
- A track write failure appears in session metadata.
- One failed track does not remove the other track.
- A new recording can run while WhisperKit transcribes an older session.
- The menu shows recording state and elapsed time.
- The recording controls remain responsive during transcription.

## Verification

- Record with the built-in microphone and speakers.
- Record with a headset.
- Record audio from at least two meeting applications.
- Change the default microphone during a test session.
- Change the default output during a test session.
- Force termination during recording.
- Force one track to fail and inspect the other track.
- Start a recording while a long transcript job runs.
- Run a meeting-length recording and inspect both tracks.

## Dependencies

- `ESCUTA-003`
- `ESCUTA-004`
- `ESCUTA-006`

## Out of Scope

- Automatic meeting-application control.
- Per-process system-audio selection.
- Video capture.
- A guarantee against macOS audio framework defects.
