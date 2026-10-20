# buildhut_updater

Android in-app update checker and APK installer for apps distributed through [BuildHut](https://git.sr.ht/~drzoidberg/Buildhut).

Checks the BuildHut API for new versions, shows an update dialog with a markdown changelog, downloads the APK with a progress bar, requests the required Android permissions at runtime, and triggers the system installer — all in one call or with full control over each step.

## Features

- **Version comparison** — Semantic versioning with optional build numbers (`1.2.3+5`)
- **One-call UI flow** — `showBuildHutUpdateCheck()` handles checking, dialogs, download, and install
- **Silent checks** — Use `checkForUpdates()` without any UI for background polling
- **Markdown changelog** — Renders the update description from BuildHut as markdown
- **Progress reporting** — Real-time download progress and status callbacks
- **Custom HTTP client** — Pass your own `Dio` instance for interceptors, timeouts, etc.
- **Self-contained permissions** — Requests storage and install permissions at runtime when needed

## Android Manifest Setup

Your app **must** declare the install permission in `android/app/src/main/AndroidManifest.xml` for APK installation to work. Add the following inside the `<manifest>` tag:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Required for in-app APK updates -->
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />

    <!-- Required on Android 9 and below for downloading the APK -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

    <application>
        <!-- ... -->
    </application>
</manifest>
```

Additionally, you need to declare a **FileProvider** so the system package installer can access the downloaded APK. Add this inside the `<application>` tag in the same manifest:

```xml
<application>
    <provider
        android:name="androidx.core.content.FileProvider"
        android:authorities="${applicationId}.fileprovider"
        android:exported="false"
        android:grantUriPermissions="true">
        <meta-data
            android:name="android.support.FILE_PROVIDER_PATHS"
            android:resource="@xml/file_paths" />
    </provider>
</application>
```

Then create the file `android/app/src/main/res/xml/file_paths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-path name="external_files" path="." />
    <cache-path name="cache" path="." />
</paths>
```

> **Note:** The library requests `REQUEST_INSTALL_PACKAGES` and storage permissions at runtime during the install flow. If the user denies them, the install is aborted with an exception you can handle.

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  buildhut_updater: ^0.1.0
```

Then run:

```sh
flutter pub get
```

## Quick Start

```dart
import 'package:buildhut_updater/buildhut_updater.dart';
import 'package:package_info_plus/package_info_plus.dart';
```

```dart
// 1. Get your current version
final info = await PackageInfo.fromPlatform();
final currentVersion = '${info.version}+${info.buildNumber}';

// 2. Create the update service
final updateService = BuildHutUpdateService(
  appId: 'your-buildhut-app-id',   // UUID from BuildHut dashboard
  currentVersion: currentVersion,
);

// 3. Show the full update flow (check -> dialog -> download -> install)
await showBuildHutUpdateCheck(
  context: context,
  updateService: updateService,
  currentVersion: currentVersion,
);
```

That's it. `showBuildHutUpdateCheck` will:

1. Show a "Checking for Updates" spinner dialog
2. Query `GET /api/app/{appId}` on the BuildHut API
3. If an update is found, show a dialog with the version number and markdown changelog
4. When the user taps "Update Now", download the APK with a progress bar
5. Request runtime permissions if not already granted
6. Trigger the Android system installer

## API Reference

### `BuildHutUpdateService`

The core service that communicates with the BuildHut API.

```dart
final service = BuildHutUpdateService(
  appId: '51b43a77-352d-4161-b454-554edeeeaf71',
  currentVersion: '1.2.3+5',
  baseUrl: 'https://hut.buildr.fun/api/app',      // optional, this is the default
  os: 'android',                                  // optional OS filter for the lookup
  dio: myCustomDioInstance,                       // optional
);
```

| Parameter          | Type     | Default                              | Description                                 |
| ------------------ | -------- | ------------------------------------ | ------------------------------------------- |
| `appId`            | `String` | required                             | BuildHut application UUID                   |
| `currentVersion`   | `String` | required                             | Current app version for comparison           |
| `baseUrl`          | `String` | `https://hut.buildr.fun/api/app`     | BuildHut API base URL                       |
| `os`               | `String?`| `null`                               | Restrict lookup to one OS (e.g. `android`) — recommended when the app ships multiple formats |
| `dio`              | `Dio?`   | `null`                               | Custom Dio instance for HTTP configuration  |

#### `checkForUpdates()`

```dart
Future<BuildHutAppUpdate?> checkForUpdates()
```

Queries the BuildHut API and returns a `BuildHutAppUpdate` if a newer version exists, or `null` if the app is up to date. A server 404 (no build for the requested OS yet) is also treated as "no update". Throws on network errors.

```dart
final update = await service.checkForUpdates();
if (update != null) {
  print('New version available: ${update.version}');
} else {
  print('Already up to date');
}
```

#### `installUpdate()`

```dart
Future<void> installUpdate(
  BuildHutAppUpdate update, {
  ProgressCallback? onProgress,
  StatusCallback? onStatusChange,
  String apkNamePrefix = 'buildhut_update',
})
```

Downloads the APK and triggers the Android system installer. The callbacks receive:

- `onProgress` — download progress as a `double` from `0.0` to `1.0`
- `onStatusChange` — human-readable status string (e.g. `"Downloading update..."`, `"Installing update..."`)
- `apkNamePrefix` — prefix for the temporary APK filename

```dart
await service.installUpdate(
  update,
  onProgress: (progress) {
    print('Download: ${(progress * 100).toInt()}%');
  },
  onStatusChange: (status) {
    print('Status: $status');
  },
);
```

### `BuildHutAppUpdate`

Data model representing an available update from the BuildHut API.

| Field           | Type             | Description                            |
| --------------- | ---------------- | -------------------------------------- |
| `app`           | `String`         | Application name                       |
| `version`       | `String`         | Version string (e.g. `"1.2.3"`)       |
| `tag`           | `String`         | Version tag                            |
| `description`   | `String?`        | Markdown release notes                 |
| `tags`          | `List<String>?`  | Build tags (e.g. `["stable"]`)        |
| `downloadUrl`   | `String`         | Presigned S3 URL for the APK           |
| `uploadedAt`    | `DateTime`       | Upload timestamp                       |
| `architecture`  | `String?`        | Target architecture (e.g. `"arm64-v8a"`) |

#### `isNewerThan()`

```dart
bool isNewerThan(String currentVersion)
```

Compares against the current version. Supports semver (`1.2.3`), semver with build number (`1.2.3+5`), and partial semver (`1.2`).

```dart
final update = BuildHutAppUpdate.fromJson(json);
if (update.isNewerThan('1.0.0')) {
  // offer update
}
```

### `BuildHutUpdateDialog`

A Material dialog widget that displays the update info, handles the download with a progress bar, and triggers installation.

```dart
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) => BuildHutUpdateDialog(
    update: update,
    updateService: service,
    currentVersion: '1.0.0',
    onUpdateInstalled: () {
      // Called after the install is triggered
    },
  ),
);
```

### `showBuildHutUpdateCheck()`

```dart
Future<void> showBuildHutUpdateCheck({
  required BuildContext context,
  required BuildHutUpdateService updateService,
  required String currentVersion,
  VoidCallback? onUpdateInstalled,
})
```

All-in-one flow: shows a checking spinner, then either the update dialog, an "up to date" dialog, or an error dialog.

## Usage Patterns

### Manual check with custom handling

```dart
final update = await service.checkForUpdates();

if (update == null) {
  // No update available
  return;
}

// Show your own UI, log to analytics, etc.
print('Update ${update.version} available');
print('Download URL: ${update.downloadUrl}');
print('Changelog: ${update.description}');
```

### Background update polling

```dart
Timer.periodic(const Duration(hours: 6), (_) async {
  try {
    final update = await service.checkForUpdates();
    if (update != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update ${update.version} available')),
      );
    }
  } catch (_) {
    // Silently ignore network errors during background checks
  }
});
```

### Custom Dio instance

Pass your own `Dio` with interceptors, timeouts, or custom headers:

```dart
final dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 60),
));
dio.interceptors.add(LogInterceptor());

final service = BuildHutUpdateService(
  appId: 'your-app-id',
  currentVersion: '1.0.0',
  dio: dio,
);
```

### Custom BuildHut endpoint

If you are self-hosting BuildHut:

```dart
final service = BuildHutUpdateService(
  appId: 'your-app-id',
  currentVersion: '1.0.0',
  baseUrl: 'https://your-buildhut-instance.example.com/api/app',
);
```

### Install with progress only (no dialog)

```dart
final update = await service.checkForUpdates();
if (update == null) return;

await service.installUpdate(
  update,
  onProgress: (progress) {
    // Update your own progress indicator
    setState(() => _progress = progress);
  },
  onStatusChange: (status) {
    setState(() => _statusText = status);
  },
  apkNamePrefix: 'my_app',  // temp file will be my_app_1.2.3.apk
);
```

## BuildHut API Compatibility

This library targets the BuildHut `GET /api/app/{appId}` endpoint which returns:

```json
{
  "app": "my-app",
  "version": "1.0.5",
  "architecture": "arm64-v8a",
  "tag": "1.0.5",
  "description": "Bug fixes and performance improvements",
  "tags": ["stable"],
  "downloadUrl": "https://s3.../presigned-url",
  "uploadedAt": "2026-04-01T10:00:00.000Z"
}
```

The `downloadUrl` is a presigned S3 URL served by BuildHut. The APK is downloaded to the app's temporary directory and then passed to the Android package installer.

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:buildhut_updater/buildhut_updater.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final BuildHutUpdateService _service;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = '${info.version}+${info.buildNumber}');

    _service = BuildHutUpdateService(
      appId: '51b43a77-352d-4161-b454-554edeeeaf71',
      currentVersion: _version,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Version: $_version'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => showBuildHutUpdateCheck(
                context: context,
                updateService: _service,
                currentVersion: _version,
              ),
              icon: const Icon(Icons.system_update),
              label: const Text('Check for Updates'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## License

MIT
