# ESCUTA-002: Add the Escuta Core Module

## Problem

Queue, transcript, configuration, and AppKit code are in one executable target.
The repository has no test target.

## Outcome

Pure Escuta behavior has a testable Swift module.
System integration code stays in a small executable target.

## Scope

- Add an `EscutaCore` library target.
- Add an `EscutaCoreTests` test target.
- Use Swift Testing for new tests.
- Move session metadata to typed `Codable` values.
- Move transcript data types to `EscutaCore`.
- Move transcript merge behavior to `EscutaCore`.
- Move Markdown rendering to `EscutaCore`.
- Define a transcript schema version.
- Keep AppKit, Core Audio, notifications, and WhisperKit outside the core module.
- Keep one transcription-engine interface for external speech engines.

## Implementation Notes

Use the public core interfaces as the main test seam.
Tests must inspect output files and returned values.
Tests must not inspect private state or private call order.

Keep the engine interface small. It must provide timed segments, language data,
engine data, progress, and model release behavior.

## Acceptance Criteria

- `Package.swift` defines the core library and its test target.
- The executable imports `EscutaCore` for session and transcript behavior.
- Session metadata uses typed encoding and decoding.
- `transcript.json` contains a schema version.
- Transcript merging sorts segments by the shared session timestamp.
- Microphone segments use the `me` label.
- System-audio segments use the `them` label.
- Markdown output contains readable timestamps and speaker labels.
- Core tests run without microphone or system-audio permission.

## Verification

- Test transcript ordering with overlapping track segments.
- Test microphone and system start offsets.
- Test an empty track.
- Test a missing track.
- Test JSON encoding and decoding.
- Test Markdown output for sessions longer than one hour.
- Run all tests with the isolated command from `ESCUTA-001`.

## Dependencies

- `ESCUTA-001`

## Out of Scope

- WhisperKit integration.
- Menu-bar changes.
- Audio capture changes.
