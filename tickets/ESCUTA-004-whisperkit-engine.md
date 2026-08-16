# ESCUTA-004: Add the WhisperKit Engine

## Problem

The current FluidAudio engine supports English only.
Escuta requires local Portuguese and English transcription.

## Outcome

Escuta uses WhisperKit and the selected multilingual production model.
All speech processing stays on the Mac.

## Scope

- Remove the FluidAudio dependency.
- Add the `WhisperKit` product from `argmax-oss-swift`.
- Pin the package version in `Package.resolved`.
- Implement the transcription-engine interface with WhisperKit.
- Use `large-v3-v20240930_626MB` as the production model.
- Use explicit model and tokenizer cache folders.
- Load long audio with WhisperKit incremental loading.
- Transcribe microphone and system-audio files separately.
- Convert WhisperKit segments to Escuta timed segments.
- Report model download and transcription progress.
- Record engine name, engine version, and model name.
- Release model objects when the queue is empty.
- Do not require a Hugging Face credential.

## Implementation Notes

Initialize WhisperKit with automatic download disabled.
Use the model-download flow from `ESCUTA-006` before model loading.

Call `unloadModels()` when queue work ends.
Release the WhisperKit instance after model unloading.

Keep a small development model option for automated checks.
Do not change the production model default.

## Acceptance Criteria

- The package builds without FluidAudio.
- The package includes WhisperKit from `argmax-oss-swift`.
- Escuta selects `large-v3-v20240930_626MB` by default.
- Escuta transcribes both supported audio tracks separately.
- Transcript segments keep WhisperKit start and end timestamps.
- Long audio does not require loading the complete file into memory.
- `transcript.json` records engine and model details.
- Queue completion releases WhisperKit model memory.
- Model download works without a Hugging Face token.
- No transcription audio goes to a cloud speech service.

## Verification

- Build with the isolated command from `ESCUTA-001`.
- Transcribe a short English fixture.
- Transcribe a short Portuguese fixture.
- Transcribe a long generated fixture with incremental loading.
- Confirm segment timestamps in JSON.
- Confirm that the queue releases the engine after its last job.
- Confirm that package configuration contains no FluidAudio dependency.

## Dependencies

- `ESCUTA-002`
- `ESCUTA-003`

## Out of Scope

- SpeakerKit.
- Remote-speaker identification.
- Cloud transcription.
- Meeting analysis.
