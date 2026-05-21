import 'package:flutter_test/flutter_test.dart';
import 'package:buildhut_updater/buildhut_updater.dart';

void main() {
  group('BuildHutAppUpdate', () {
    test('parses from JSON', () {
      final json = {
        'app': 'test-app',
        'version': '2.0.0',
        'tag': '2.0.0',
        'description': 'Bug fixes',
        'tags': ['stable'],
        'downloadUrl': 'https://example.com/app.apk',
        'uploadedAt': '2026-01-01T00:00:00.000Z',
        'architecture': 'arm64-v8a',
      };

      final update = BuildHutAppUpdate.fromJson(json);

      expect(update.app, 'test-app');
      expect(update.version, '2.0.0');
      expect(update.tag, '2.0.0');
      expect(update.description, 'Bug fixes');
      expect(update.tags, ['stable']);
      expect(update.downloadUrl, 'https://example.com/app.apk');
      expect(update.architecture, 'arm64-v8a');
    });

    test('isNewerThan detects newer version', () {
      final update = _makeUpdate(version: '2.0.0');
      expect(update.isNewerThan('1.0.0'), isTrue);
      expect(update.isNewerThan('2.0.0'), isFalse);
      expect(update.isNewerThan('3.0.0'), isFalse);
    });

    test('isNewerThan handles build numbers', () {
      final update = _makeUpdate(version: '1.0.0+5');
      expect(update.isNewerThan('1.0.0+3'), isTrue);
      expect(update.isNewerThan('1.0.0+5'), isFalse);
      expect(update.isNewerThan('1.0.0+7'), isFalse);
    });

    test('isNewerThan handles mixed version formats', () {
      final update = _makeUpdate(version: '1.2.0');
      expect(update.isNewerThan('1.2.0+99'), isFalse);
      expect(update.isNewerThan('1.1.9+99'), isTrue);
    });

    test('isNewerThan handles partial semver', () {
      final update = _makeUpdate(version: '1.2.3');
      expect(update.isNewerThan('1.2'), isTrue);
      expect(update.isNewerThan('1.2.3'), isFalse);
      expect(update.isNewerThan('2'), isFalse);
    });

    test('toJson round-trips', () {
      final json = {
        'app': 'test-app',
        'version': '2.0.0',
        'tag': '2.0.0',
        'description': null,
        'tags': null,
        'downloadUrl': 'https://example.com/app.apk',
        'uploadedAt': '2026-01-01T00:00:00.000Z',
        'architecture': null,
      };

      final update = BuildHutAppUpdate.fromJson(json);
      final result = update.toJson();

      expect(result['app'], 'test-app');
      expect(result['version'], '2.0.0');
      expect(result['downloadUrl'], 'https://example.com/app.apk');
    });
  });
}

BuildHutAppUpdate _makeUpdate({required String version}) {
  return BuildHutAppUpdate(
    app: 'test',
    version: version,
    tag: version,
    downloadUrl: 'https://example.com/app.apk',
    uploadedAt: DateTime(2026),
  );
}
