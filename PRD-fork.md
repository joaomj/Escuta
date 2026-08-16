# Escuta Product Requirements

## Product Summary

Escuta is a lightweight macOS tool that records meetings and creates local
transcripts. It is for a person who takes part in the recorded meeting.

The user starts and stops a recording from the menu bar. Escuta records the
microphone and system audio as separate tracks. After the meeting, it creates
a readable transcript with timestamps and basic speaker labels.

Escuta is a fork of [quill](https://github.com/digimata/quill). It keeps the
small menu-bar interface and reliable recording flow from quill. It adds
multilingual transcription, with pt-BR as the primary use case.

## Problem

Meeting platforms can provide transcripts, but access and quality differ.
Some platforms require a paid plan. Some meetings do not permit platform
recording. A user can also attend meetings on different platforms.

The user needs one tool that works with any meeting platform on a Mac. The
tool must require little setup and little attention during a meeting.

## Product Goal

Let the user get an accurate meeting transcript with two menu-bar actions:

1. Start recording.
2. Stop recording.

The tool does the remaining work automatically on the Mac.

## Target User

The first target user is the project owner:

- Takes part in online meetings on a Mac.
- Uses a microphone or headset.
- Speaks Portuguese or English.
- Reviews past meetings for decisions, facts, and follow-up work.
- Wants one recording flow for all meeting platforms.
- Prefers local processing and direct file access.

## Product Principles

### Easy to use

The user must not configure a recording for each meeting platform. Start and
stop must remain available from the macOS menu bar.

### Lightweight

Escuta must remain a small native macOS tool. It must not require Docker,
Python, a web server, or a browser interface for its core flow.

Large speech models can use disk space and memory during transcription.
Escuta must release model memory when the work queue is empty.

### Local by default

Recording and transcription must run on the Mac. Audio must not leave the Mac
during the core flow.

### Reliable

Escuta must preserve audio if recording or transcription stops unexpectedly.
Pending transcription work must continue after the next start.

### Open files

Each session must use common files that the user can inspect and process with
other tools. JSON is the source transcript. Markdown is the reading format.

## First Release

### Recording

- Record microphone audio and system audio at the same time.
- Keep the two audio tracks separate.
- Start and stop from the menu bar.
- Show the recording state and elapsed time.
- Save each meeting in a dated session folder.
- Keep readable audio when the process stops unexpectedly.

### Transcription

- Use WhisperKit from
  [argmax-oss-swift](https://github.com/argmaxinc/argmax-oss-swift).
- Run transcription on Apple silicon with Core ML.
- Support pt-BR and English.
- Detect the spoken language when the user does not set one.
- Let the user set an optional language hint.
- Use `large-v3-v20240930_626MB` as the initial production model.
- Download the model automatically on first use.
- Cache the model for later meetings.
- Transcribe microphone and system tracks separately.
- Merge both tracks by timestamp.
- Label microphone speech as `me`.
- Label system speech as `them`.
- Create `transcript.json` and `transcript.md`.
- Keep model and engine details in `transcript.json`.

### Work Queue

- Start a new recording while an older meeting is transcribed.
- Process transcript jobs one at a time.
- Continue unfinished jobs after Escuta starts again.
- Record transcription failures in the session folder.
- Continue with later jobs when one job fails.

### Setup and Status

- Support macOS 15 or later.
- Check microphone and system-audio permissions.
- Show whether the selected model is available locally.
- Tell the user before the first model download.
- Show transcription progress in the menu-bar menu.
- Notify the user when the transcript is ready.

### Extension Hook

- Run an optional command after the transcript is ready.
- Give the session-folder path to that command.
- Keep this hook as the first integration point for meeting analysis.

## Later Releases

### Per-Person Speaker Labels

Evaluate SpeakerKit from `argmax-oss-swift`. SpeakerKit runs Pyannote models
locally with Core ML.

The first experiment must apply SpeakerKit only to the system-audio track.
Escuta already knows that microphone speech is the user. The experiment must
determine if SpeakerKit can reliably divide `them` into remote speakers.

This work is not part of the first release. The project owner will test it
separately before product integration.

### Meeting Analysis

Add an optional study layer after the transcript is ready. Possible outputs
include:

- A short summary.
- Decisions.
- Follow-up actions.
- Important topics.
- Questions for later review.

The first version can use the existing post-transcript hook. Analysis must not
block transcript creation. If analysis uses a cloud service, Escuta must tell
the user that transcript text leaves the Mac.

### Transcript Review

Evaluate a small review interface only if Markdown files are not sufficient.
Do not add a full application window without evidence that users need it.

## Not in Scope

The first release does not include:

- Windows or Linux support.
- Video-file import.
- Live captions during a meeting.
- Real-time speaker labels.
- Automatic meeting-platform control.
- Cloud storage or account synchronization.
- A web interface.
- Built-in meeting analysis.
- Per-person labels for remote speakers.

## User Flow

1. The user starts Escuta.
2. Escuta stays in the macOS menu bar.
3. The user selects **Start recording** before or during a meeting.
4. Escuta records microphone and system audio.
5. The user selects **Stop recording** after the meeting.
6. Escuta adds the session to the transcript queue.
7. WhisperKit creates a local transcript.
8. Escuta notifies the user when the transcript is ready.
9. The user opens the session folder and reads `transcript.md`.
10. Escuta runs the optional post-transcript command.

## First-Release Acceptance Criteria

- A user can record a meeting from the menu bar on macOS 15 or later.
- The meeting audio remains available as separate microphone and system files.
- A pt-BR meeting produces a readable Portuguese transcript without a cloud
  speech service.
- An English meeting produces a readable English transcript.
- The transcript includes timestamps and `me` or `them` labels.
- The transcript is available as JSON and Markdown.
- The user can record another meeting while transcription runs.
- An interrupted transcript job continues after the next application start.
- The application does not require a HuggingFace credential.
- The application does not require Python or Docker for recording and
  transcription.

## Success Signals

The first release succeeds when:

- The normal meeting flow needs only start and stop actions.
- The user can use the tool across different meeting platforms.
- pt-BR transcripts are useful for meeting review.
- Recording failures do not cause silent audio loss.
- The tool remains in regular use without setup work before each meeting.

## Fork Policy

Escuta keeps `digimata/quill` as the upstream repository. The fork must merge
useful recorder fixes from upstream when they do not conflict with this
product direction.

Escuta can change product names, defaults, transcription engines, and later
study features. Changes that also serve the small quill product can be offered
to upstream separately.
