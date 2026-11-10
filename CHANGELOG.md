# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-11-10

### Added

- `arch` option on [BuildHutUpdateService]: restricts the update lookup to one
  CPU artifact (`?arch=arm64-v8a` etc.). When null on Android, the device's
  primary ABI is auto-detected (device_info_plus `supportedAbis`) so a Pixel
  gets the arm64 APK instead of whichever split uploaded last.
- Graceful fallback: an arch-filtered 404 retries once without the arch
  (still os-filtered) — arm64 devices can still install an armeabi-v7a APK,
  but never silently miss an update.

### Fixed

- Polify phones were handed a Linux tarball as an "APK" (`There's a problem
  with the app file`) because the shipped client sent no `os` filter; the
  unfiltered latest-build endpoint returns whichever artifact uploaded last.

## [0.2.0] - 2026-10-20

### Changed

- **Breaking:** default `baseUrl` moved from the retired `buildhut.fly.dev`
  edge to the self-hosted production instance `https://hut.buildr.fun/api/app`.
  Pass a custom `baseUrl` if you host your own instance (unchanged).
- `BuildHutUpdateService` now accepts an `os` parameter (e.g. `'android'`)
  that adds `?os=` to the version check, so multi-format apps (APK + Linux
  tarball) resolve the latest build for the requesting platform instead of
  whatever format happened to be uploaded last.

### Fixed

- `checkForUpdates()` treats a server 404 (app has no build for the requested
  OS yet) as "no update" instead of throwing a `DioException`.

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
