# ESCUTA-001: Isolate Swift Development Files

## Problem

Swift Package Manager can use shared cache, configuration, and security folders.
Project development must not install Swift dependencies or services on the Mac.

## Outcome

All Swift package files for development stay in an ignored project folder.
A developer can remove these files by deleting that folder.

## Scope

- Add one project command for package resolution, builds, and tests.
- Put the Swift package cache under `.build`.
- Put Swift package configuration under `.build`.
- Put Swift package security data under `.build`.
- Put build output under `.build`.
- Use only versions in `Package.resolved` during normal builds and tests.
- Disable keychain and netrc credential searches for project commands.
- Document the isolated commands and cleanup procedure.
- Add all local development paths to `.gitignore`.

## Implementation Notes

Use these Swift options in the project command:

```text
--cache-path
--config-path
--security-path
--scratch-path
--disable-keychain
--disable-netrc
--only-use-versions-from-resolved-file
```

The command must keep the Swift process sandbox enabled.
Development instructions must not use `sudo`, `/usr/local/bin`, or a login agent.

## Acceptance Criteria

- A developer can resolve packages with the project command.
- A developer can build Escuta with the project command.
- A developer can run tests with the project command.
- Swift package files stay under `.build` during these operations.
- The operations do not install an executable outside the repository.
- The operations do not add a login item or launch agent.
- Deleting `.build` removes the project dependency copies and build output.
- A build fails if `Package.resolved` does not match `Package.swift`.

## Verification

- Run package resolution from a clean `.build` folder.
- Run the debug build.
- Run the release build.
- Run the test command.
- Inspect created files and confirm that they stay under `.build`.
- Confirm that no project command uses elevated privileges.

## Dependencies

None.

## Out of Scope

- Product file isolation after Escuta is installed.
- A macOS application sandbox.
- A release installer.
