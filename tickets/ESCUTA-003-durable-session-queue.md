# ESCUTA-003: Add a Durable Session Queue

## Problem

The current queue finds only sessions with `meta.json` and no transcript.
An interrupted recording can have readable audio but no queue record.
Failed jobs can start again after every application start.

## Outcome

Escuta records each session state in its session folder.
Escuta continues safe work after an application restart.

## Scope

- Add these session states:
  - `recording`
  - `pending`
  - `transcribing`
  - `completed`
  - `failed`
- Write initial session metadata before audio capture starts.
- Update session metadata with atomic file writes.
- Recover interrupted recording sessions at application start.
- Check each audio track before queue processing.
- Process transcription jobs one at a time.
- Permit recording while queue processing continues.
- Save a checkpoint after each completed track.
- Reuse a completed track checkpoint after an interruption.
- Restart only the incomplete track after an interruption.
- Store a permanent failure state in the session folder.
- Continue with later jobs after one job fails.
- Add a manual retry operation for failed jobs.
- Prevent duplicate queue entries.

## Business Rules

- A session can produce a transcript when one track is readable.
- A partial transcript must identify the missing or failed track.
- A partial transcript must show a warning in JSON and Markdown.
- The menu and log must show the partial result.
- A hook can run only after the final transcript files exist.
- A hook failure does not change a completed transcript to failed.

## Implementation Notes

Use the session folder as the durable queue record.
Do not add a database for the first release.

A completed track checkpoint must include enough data to rebuild the merged
transcript. It must also identify the audio file and engine settings that made
the checkpoint.

## Acceptance Criteria

- Escuta finds an interrupted recording after the next start.
- Escuta queues readable audio from the interrupted recording.
- Escuta does not lose a readable track when the other track fails.
- Escuta does not transcribe a completed track again after a safe checkpoint.
- Escuta processes the oldest pending session first.
- Escuta processes only one transcript job at a time.
- A new recording can start while a transcript job runs.
- A failed job does not block a later job.
- A failed job stays failed until the user requests a retry.
- Repeated queue scans do not add duplicate work.
- `transcript.json` and `transcript.md` appear only as complete files.

## Verification

- Stop the process during recording and restart Escuta.
- Stop the process after the microphone checkpoint and restart Escuta.
- Stop the process while the second track runs and restart Escuta.
- Queue two jobs and force the first job to fail.
- Scan the same recordings folder more than once.
- Test a session with only `mic.caf`.
- Test a session with only `system.caf`.
- Test unreadable and zero-frame audio files.

## Dependencies

- `ESCUTA-002`

## Out of Scope

- Resume inside a partly transcribed audio track.
- Parallel transcription jobs.
- A database-backed queue.
