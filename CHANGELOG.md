# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-21

### Added

- `BuildHutUpdateService` for checking and installing app updates via the BuildHut API
  - `checkForUpdates()` queries `GET /api/app/{appId}` and compares versions
  - `installUpdate()` downloads the APK with progress callbacks and triggers the Android system installer
  - Configurable base URL for self-hosted BuildHut instances
  - Optional custom `Dio` instance for HTTP configuration
- `BuildHutAppUpdate` model with `fromJson`, `toJson`, and `isNewerThan()` version comparison
  - Supports semver (`1.2.3`), semver with build numbers (`1.2.3+5`), and partial semver (`1.2`)
- `BuildHutUpdateDialog` Material widget showing update info, markdown changelog, and download progress
- `showBuildHutUpdateCheck()` all-in-one function for the complete update check flow
- Runtime permission handling for storage and install packages on Android
- Unit tests for `BuildHutAppUpdate` model (6 tests)
- Example app demonstrating both full UI flow and silent update checking
