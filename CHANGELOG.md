# Changelog

All notable changes documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [Unreleased]

### Added
- Extracted from `kolodii-ivan/land-lab@feature/sdlc-kit-replication`.
- Reusable GitHub workflows (`brainstorm.yml`, `implement.yml`, `iterate.yml`) with `on: workflow_call:`.
- `@kolodii-ivan/claude-sdlc-kit` npm CLI: `install`, `update`, `doctor`, `version`.
- Claude Code plugin with `/sdlc-install`, `/sdlc-update`, `/sdlc-doctor`, `/sdlc-version`.
- SHA-tracked manifest at `.claude/.kit-manifest.json` for safe in-place updates.
