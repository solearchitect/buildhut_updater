import 'dart:io';

import 'package:dio/dio.dart';
import 'package:install_plugin_v3/install_plugin_v3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/buildhut_app_update.dart';

/// Callback for download progress. [progress] ranges from `0.0` to `1.0`.
typedef ProgressCallback = void Function(double progress);

/// Callback for status text changes during the download/install process.
typedef StatusCallback = void Function(String status);

/// Service for checking and installing app updates via the BuildHut API.
///
/// Communicates with `GET /api/app/{appId}` to fetch the latest build info,
/// downloads the APK to a temporary directory, and triggers the Android
/// system package installer.
///
/// ```dart
/// final service = BuildHutUpdateService(
///   appId: 'your-app-id',
///   currentVersion: '1.0.0',
/// );
///
/// final update = await service.checkForUpdates();
/// if (update != null) {
///   await service.installUpdate(
///     update,
///     onProgress: (p) => print('${(p * 100).toInt()}%'),
///     onStatusChange: (s) => print(s),
///   );
/// }
/// ```
class BuildHutUpdateService {
  /// The BuildHut application ID (UUID) used to look up the latest build.
  final String appId;

  /// The current app version string used for comparison (e.g. `"1.2.3+4"`).
  final String currentVersion;

  /// The BuildHut API base URL. Defaults to the production instance.
  final String baseUrl;

  /// Optional OS restriction for the update lookup (e.g. `'android'`).
  /// Sent as `?os=` on the version check; `null` = legacy behaviour
  /// (latest build of any OS).
  final String? os;

  final Dio _dio;

  /// Creates a [BuildHutUpdateService].
  ///
  /// [appId] is the BuildHut application ID (UUID).
  /// [currentVersion] is the current app version string (e.g. `"1.2.3"` or `"1.2.3+4"`).
  /// [baseUrl] defaults to the BuildHut production API at `https://hut.buildr.fun/api/app`.
  /// [os] restricts the update lookup to builds for one OS (recommended:
  /// an Android updater must not be handed the latest Linux tarball when the
  /// app ships multiple formats). Pass `null` to keep the legacy behaviour
  /// (latest build of any OS).
  /// Pass a custom [dio] instance to configure timeouts, interceptors, or base headers.
  BuildHutUpdateService({
    required this.appId,
    required this.currentVersion,
    this.baseUrl = 'https://hut.buildr.fun/api/app',
    this.os,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// Checks for updates via the BuildHut API.
  ///
  /// Queries `GET {baseUrl}/{appId}` (plus `?os=` when the service was
  /// constructed with [os]) and compares the returned version against
  /// [currentVersion].
  ///
  /// Returns a [BuildHutAppUpdate] if a newer version is available,
  /// or `null` if the app is already up to date. A 404 from the server
  /// (no build yet, or no build matching the OS filter) is treated the
  /// same as "no update" instead of throwing.
  ///
  /// Throws a [DioException] on network errors.
  Future<BuildHutAppUpdate?> checkForUpdates() async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '$baseUrl/$appId',
        queryParameters: os != null ? {'os': os} : null,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // App exists but has no build for this OS (or none at all yet) —
        // not an error condition for the updater.
        return null;
      }
      rethrow;
    }

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data;
      final Map<String, dynamic> json =
          data is Map<String, dynamic>
              ? data
              : Map<String, dynamic>.from(data as Map);
      final update = BuildHutAppUpdate.fromJson(json);

      if (update.isNewerThan(currentVersion)) {
        return update;
      }
    }
    return null;
  }

  /// Downloads the APK from [BuildHutAppUpdate.downloadUrl] and triggers
  /// the Android system installer.
  ///
  /// [update] is the update to install, obtained from [checkForUpdates].
  ///
  /// [onProgress] is called with download progress as a `double` from `0.0` to `1.0`.
  /// [onStatusChange] is called with human-readable status text
  ///   (e.g. `"Downloading update..."`, `"Installing update..."`).
  /// [apkNamePrefix] is used as the prefix for the temporary APK file name.
  ///
  /// Requests storage and install permissions at runtime if not yet granted.
  ///
  /// Throws if not running on Android, if permissions are denied,
  /// or if the downloaded file cannot be found.
  Future<void> installUpdate(
    BuildHutAppUpdate update, {
    ProgressCallback? onProgress,
    StatusCallback? onStatusChange,
    String apkNamePrefix = 'buildhut_update',
  }) async {
    onStatusChange?.call('Preparing download...');

    final dir = await getTemporaryDirectory();
    final apkPath = '${dir.path}/${apkNamePrefix}_${update.version}.apk';

    onStatusChange?.call('Requesting permissions...');
    await _requestPermissions();

    onStatusChange?.call('Downloading update...');

    await _dio.download(
      update.downloadUrl,
      apkPath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call(received / total);
        }
      },
    );

    onProgress?.call(1.0);
    onStatusChange?.call('Installing update...');

    if (Platform.isAndroid) {
      final file = File(apkPath);
      if (await file.exists()) {
        await InstallPlugin.install(apkPath);
        onStatusChange?.call('Installation started...');
      } else {
        throw Exception('Downloaded file not found');
      }
    } else {
      throw Exception('Automatic updates are only supported on Android');
    }
  }

  /// Requests the storage and install-packages permissions required to
  /// download and install an APK on Android.
  ///
  /// On Android 10+ this requests [Permission.manageExternalStorage] as a
  /// fallback when [Permission.storage] is not granted. Also requests
  /// [Permission.requestInstallPackages].
  ///
  /// Throws if any required permission is denied.
  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;

    final storageStatus = await Permission.storage.request();
    if (!storageStatus.isGranted) {
      final manageStatus = await Permission.manageExternalStorage.request();
      if (!manageStatus.isGranted) {
        throw Exception('Storage permission is required to download updates');
      }
    }

    final installStatus = await Permission.requestInstallPackages.request();
    if (!installStatus.isGranted) {
      throw Exception('Install permission is required to update the app');
    }
  }
}
