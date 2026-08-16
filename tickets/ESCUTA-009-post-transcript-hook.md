# ESCUTA-009: Make the Post-Transcript Hook Safe

## Problem

The current hook uses a shell command string.
Command interpretation can give unexpected results for arguments and file paths.
Hook failure is not separate from transcript status.

## Outcome

Escuta runs an optional executable after transcript completion.
It records hook results without blocking transcript delivery.

## Scope

- Add `post_transcript_command` to configuration.
- Store an executable path and an argument list.
- Pass the session-folder path as one final argument.
- Start the executable without `/bin/sh -c`.
- Run the hook only after both transcript files exist.
- Run the hook after a valid partial transcript.
- Do not block later transcript jobs while the hook runs.
- Save hook standard error and exit status in the session folder.
- Report hook launch failure in the session folder.
- Keep transcript state as completed when the hook fails.

## Business Rules

- The hook is optional.
- The hook receives the session folder, not transcript text.
- The hook can use local or cloud services.
- Escuta does not include meeting analysis in the first release.
- Hook failure does not remove or change transcript files.

## Acceptance Criteria

- No hook runs when the setting is absent.
- The configured executable receives the session folder as one argument.
- A path that contains spaces remains one argument.
- The hook starts only after `transcript.json` and `transcript.md` exist.
- A hook launch error appears in the hook log.
- A nonzero exit status appears in the hook log.
- Hook failure does not mark transcription as failed.
- Hook execution does not block the transcript queue.
- A valid partial transcript can start the hook.

## Verification

- Run a successful local test executable.
- Use a session path that contains spaces.
- Run an executable that writes to standard error.
- Run an executable that returns a nonzero exit status.
- Configure a missing executable path.
- Queue another transcript while the hook runs.
- Confirm transcript files remain unchanged after hook failure.

## Dependencies

- `ESCUTA-003`
- `ESCUTA-008`

## Out of Scope

- Built-in meeting summaries.
- Cloud-service configuration.
- Hook retries.
- Shell syntax in the command setting.
