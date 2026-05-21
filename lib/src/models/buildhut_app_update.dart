/// Represents an available app update from the BuildHut API.
///
/// Contains all metadata about a build returned by `GET /api/app/{appId}`,
/// including version info, release notes, and the download URL.
class BuildHutAppUpdate {
  /// Application name as registered on BuildHut.
  final String app;

  /// Version string of the available build (e.g. `"1.2.3"`).
  final String version;

  /// Version tag associated with this build (e.g. `"1.2.3"`).
  final String tag;

  /// Optional markdown release notes for this build.
  final String? description;

  /// Optional list of build tags (e.g. `["stable", "production"]`).
  final List<String>? tags;

  /// Presigned S3 URL to download the APK binary.
  final String downloadUrl;

  /// Timestamp when this build was uploaded to BuildHut.
  final DateTime uploadedAt;

  /// Target CPU architecture (e.g. `"arm64-v8a"`, `"x86_64"`).
  final String? architecture;

  /// Creates a [BuildHutAppUpdate] with the given fields.
  BuildHutAppUpdate({
    required this.app,
    required this.version,
    required this.tag,
    this.description,
    this.tags,
    required this.downloadUrl,
    required this.uploadedAt,
    this.architecture,
  });

  /// Creates a [BuildHutAppUpdate] from the JSON response of the BuildHut API.
  ///
  /// The [json] map must contain the keys: `app`, `version`, `tag`,
  /// `downloadUrl`, and `uploadedAt`. Optional keys: `description`,
  /// `tags`, `architecture`.
  factory BuildHutAppUpdate.fromJson(Map<String, dynamic> json) {
    return BuildHutAppUpdate(
      app: json['app'] as String,
      version: json['version'] as String,
      tag: json['tag'] as String,
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      downloadUrl: json['downloadUrl'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      architecture: json['architecture'] as String?,
    );
  }

  /// Whether this version is newer than [currentVersion].
  ///
  /// Supports formats:
  /// - `"1.2.3"` (semver only)
  /// - `"1.2.3+5"` (semver with build number)
  /// - `"1.2"` (partial semver, treated as `"1.2.0"`)
  ///
  /// Compares the semver parts first (major.minor.patch). If equal,
  /// compares the build number suffix.
  bool isNewerThan(String currentVersion) {
    final v1Parts = version.split('+');
    final v2Parts = currentVersion.split('+');

    final v1Semver = v1Parts[0];
    final v2Semver = v2Parts[0];

    final v1Build = v1Parts.length > 1 ? _parseBuildNumber(v1Parts[1]) : 0;
    final v2Build = v2Parts.length > 1 ? _parseBuildNumber(v2Parts[1]) : 0;

    final semverCompare = _compareSemver(v1Semver, v2Semver);
    if (semverCompare != 0) {
      return semverCompare > 0;
    }

    return v1Build > v2Build;
  }

  int _parseBuildNumber(String buildStr) {
    return int.tryParse(buildStr) ?? 0;
  }

  /// Compare two semver version strings (e.g. `"1.2.3"` vs `"1.2.4"`).
  ///
  /// Returns a positive value if [v1] > [v2], zero if equal,
  /// or a negative value if [v1] < [v2].
  int _compareSemver(String v1, String v2) {
    final parts1 = v1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = v2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }

    for (int i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1 - p2;
    }
    return 0;
  }

  /// Serializes this update to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'app': app,
      'version': version,
      'tag': tag,
      'description': description,
      'tags': tags,
      'downloadUrl': downloadUrl,
      'uploadedAt': uploadedAt.toIso8601String(),
      'architecture': architecture,
    };
  }

  @override
  String toString() =>
      'BuildHutAppUpdate(app: $app, version: $version, tag: $tag)';
}
