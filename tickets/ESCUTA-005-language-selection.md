# ESCUTA-005: Add Language Selection

## Problem

Escuta must support Portuguese and English.
The user needs automatic detection and an optional language hint.

## Outcome

The user can select `Automatic`, `Portuguese`, or `English`.
Escuta records the selected or detected language for each track.

## Scope

- Add a language value to Escuta configuration.
- Add the same language control to the menu-bar menu.
- Make the menu control write the persistent configuration.
- Support these values:
  - `automatic`
  - `pt`
  - `en`
- Display `pt` as `Portuguese (Brazil)`.
- Pass `pt` to WhisperKit for Portuguese.
- Pass `en` to WhisperKit for English.
- Detect each track language in automatic mode.
- Use the selected hint for both tracks in explicit mode.
- Keep the transcription task in transcription mode.
- Record the language and its source for each track.

## Business Rules

- `Automatic` is the default value.
- The menu and JSON configuration control the same setting.
- An explicit hint applies to the next transcript jobs.
- Escuta must not translate Portuguese speech to English.
- A partial transcript records language data only for completed tracks.

## Acceptance Criteria

- The menu shows the active language setting.
- The user can select `Automatic` from the menu.
- The user can select `Portuguese (Brazil)` from the menu.
- The user can select `English` from the menu.
- The selected value remains after Escuta restarts.
- Automatic mode records a detected language for each completed track.
- Explicit mode records that the language came from a user hint.
- Portuguese output remains Portuguese.
- English output remains English.
- `transcript.json` records per-track language data.

## Verification

- Test configuration read and write for all three values.
- Test invalid configuration input and the default result.
- Transcribe a Portuguese fixture in automatic mode.
- Transcribe an English fixture in automatic mode.
- Transcribe both fixtures with explicit hints.
- Confirm that Portuguese text is not translated.
- Confirm that the menu and configuration show the same value.

## Dependencies

- `ESCUTA-004`

## Out of Scope

- Languages other than Portuguese and English in the user interface.
- A language setting for each session.
- Translation output.
