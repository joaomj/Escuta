# ESCUTA-008: Apply Escuta Branding

## Problem

The repository and executable still use the Quill product name and identifiers.
The first Escuta release needs one consistent product identity.

## Outcome

Source names, user text, configuration, and installation data use Escuta.
The Git repository keeps Quill as its upstream remote.

## Scope

- Rename the Swift package to `escuta`.
- Rename the executable target to `escuta`.
- Rename source folders and main command types.
- Replace user-visible Quill text with Escuta text.
- Change the bundle identifier to an Escuta identifier.
- Rename Core Audio tap data.
- Rename dispatch queue labels.
- Change the configuration path to `~/.config/escuta/config.json`.
- Rename the login-agent identifier and log file names.
- Update command help and installation output.
- Update the README for Escuta behavior.
- Keep the `upstream` Git remote for Quill.

## Business Rules

- Do not add migration from Quill paths before an Escuta release exists.
- Do not change the upstream remote as part of product renaming.
- Development instructions must continue to use the isolation rules from
  `ESCUTA-001`.

## Acceptance Criteria

- The release executable is named `escuta`.
- The command help uses Escuta names.
- The menu and notifications use Escuta names.
- Permission descriptions use Escuta names.
- New configuration uses the Escuta configuration path.
- New login-agent files use an Escuta identifier.
- Audio device data does not use Quill names.
- The README describes the first-release Escuta flow.
- The upstream Git remote remains configured for Quill.
- Repository searches find no active product identifier that uses Quill.

## Verification

- Build and run the `escuta` executable.
- Run `escuta --help`.
- Inspect the menu, notifications, and permission text.
- Inspect generated login-agent data without installing it during development.
- Search source and documentation for old product identifiers.
- Confirm the local Git remote configuration.

## Dependencies

- `ESCUTA-001`
- `ESCUTA-006`
- `ESCUTA-007`

## Out of Scope

- A signed installer.
- Mac App Store distribution.
- Migration of unreleased Quill configuration.
- Changes to the upstream Quill repository.
