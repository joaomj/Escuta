# ESCUTA-010: Validate the First Release

## Problem

Unit tests cannot prove permission prompts, Core Audio capture, Core ML memory,
or transcript quality on the target Mac.

## Outcome

Automated and real-device checks show that Escuta meets the first-release
acceptance criteria.

## Scope

- Add one documented release-validation procedure.
- Run all automated tests with isolated Swift commands.
- Build debug and release products.
- Validate Portuguese and English fixtures.
- Validate transcript JSON and Markdown files.
- Validate queue restart and failure recovery.
- Validate real meeting audio on Apple silicon.
- Validate first model download and later offline use.
- Validate model release when the queue is empty.
- Record all skipped checks and verification gaps.

## Automated Checks

- Build with versions from `Package.resolved`.
- Run all core tests.
- Test queue recovery after process interruption.
- Test failed-job isolation.
- Test duplicate queue scans.
- Test full and partial transcripts.
- Test Portuguese and English language behavior.
- Test transcript schema and Markdown output.
- Confirm that Python and Docker are not required.
- Confirm that a Hugging Face credential is not required.

## Real-Device Checks

1. Start Escuta on macOS 15 or later.
2. Complete the microphone permission flow.
3. Complete the system-audio permission flow.
4. Confirm the first model download.
5. Record a Portuguese meeting sample.
6. Record an English meeting sample.
7. Read both Markdown transcripts.
8. Inspect timestamps and speaker labels.
9. Start a new recording during transcription.
10. Stop Escuta during transcription and start it again.
11. Stop Escuta during recording and start it again.
12. Test one microphone track failure.
13. Test one system-audio track failure.
14. Run Escuta offline with the cached model.
15. Confirm that model memory decreases when the queue becomes empty.
16. Confirm the transcript-ready notification.
17. Confirm the optional post-transcript hook.

## Acceptance Criteria

- A user records a meeting from the menu bar on macOS 15 or later.
- Escuta keeps separate microphone and system-audio files.
- A Portuguese meeting produces a readable Portuguese transcript locally.
- An English meeting produces a readable English transcript locally.
- Transcript segments include timestamps and `me` or `them` labels.
- Each completed session has JSON and Markdown transcript files.
- A recording can run while an older session is transcribed.
- An interrupted job continues after Escuta starts again.
- A completed track checkpoint is reused after an interruption.
- A one-track session produces a marked partial transcript.
- A failed job does not block later jobs.
- The first model download requires user consent.
- Later transcription works offline with the cached model.
- Escuta does not require Python, Docker, or a Hugging Face credential.
- Escuta releases model resources when the queue is empty.

## Evidence

Record these items for each validation run:

- macOS version.
- Mac model and Apple chip.
- Escuta revision.
- WhisperKit version.
- Whisper model name.
- Commands and results.
- Test session folders.
- Failed or skipped checks.
- Known release risks.

## Dependencies

- `ESCUTA-001` through `ESCUTA-009`

## Out of Scope

- Windows or Linux validation.
- Transcript quality targets for unsupported languages.
- SpeakerKit validation.
- Meeting analysis validation.
- Cloud storage validation.
