import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:buildhut_updater/buildhut_updater.dart';
import 'package:dio/dio.dart' show DioException;

/// End-to-end wire test for the update-check path: a real loopback HTTP
/// server plays the BuildHut `/api/app/{id}` surface so
/// [BuildHutUpdateService] talks to it over actual sockets with default Dio.
void main() {
  final appId = '11111111-2222-3333-4444-555555555555';
  late HttpServer server;
  late String baseUrl;
  final requests = <String>[]; // full request lines, in arrival order

  Future<void> startServer(
    Future<void> Function(HttpRequest req) handler,
  ) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}/api/app';
    server.listen((req) async {
      await utf8.decoder.bind(req).drain<void>();
      requests.add('${req.uri.path}?${req.uri.query}');
      await handler(req);
    });
  }

  setUp(() async {
    requests.clear();
  });

  tearDown(() async {
    await server.close(force: true);
  });

  Future<void> serveLatest({
    required String fileName,
    required String architecture,
  }) {
    // The service appends /{appId} to baseUrl; in production baseUrl IS
    // https://hut.buildr.fun/api/app, so reproduce that shape here.
    return startServer((req) async {
      if (req.uri.path != '/api/app/$appId') {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'app': 'polify',
        'version': '1.0.0',
        'tag': '1.0.0',
        'description': 'latest',
        'tags': <String>[],
        'architecture': architecture,
        'fileName': fileName,
        'downloadUrl': 'https://s3.example.com/$fileName',
        'uploadedAt': '2026-10-20T00:00:00.000Z',
      }));
      await req.response.close();
    });
  }

  test('?os= reaches the socket and the artifact resolves', () async {
    await serveLatest(
      fileName: 'polify-1.0.0-android.apk',
      architecture: 'arm64-v8a',
    );
    final service = BuildHutUpdateService(
      appId: appId,
      currentVersion: '0.9.0',
      baseUrl: baseUrl,
      os: 'android',
    );

    final update = await service.checkForUpdates();

    expect(update, isNotNull);
    expect(update!.version, '1.0.0');
    expect(update.architecture, 'arm64-v8a');
    expect(update.downloadUrl, 'https://s3.example.com/polify-1.0.0-android.apk');
    expect(requests.single, '/api/app/$appId?os=android');
  });

  test('no os parameter keeps legacy behaviour (no query string)', () async {
    await serveLatest(
      fileName: 'polify-1.0.0-linux.tar.gz',
      architecture: 'x86_64',
    );
    final service = BuildHutUpdateService(
      appId: appId,
      currentVersion: '0.9.0',
      baseUrl: baseUrl,
    );

    final update = await service.checkForUpdates();

    expect(update, isNotNull);
    expect(requests.single, '/api/app/$appId?');
  });

  test('404 with os filter = null, not a thrown DioException', () async {
    await startServer((req) async {
      req.response.statusCode = 404;
      req.response.write('No builds found for app "polify" matching os=ios');
      await req.response.close();
    });
    final service = BuildHutUpdateService(
      appId: appId,
      currentVersion: '0.9.0',
      baseUrl: baseUrl,
      os: 'ios',
    );

    final update = await service.checkForUpdates();

    expect(update, isNull);
    expect(requests.single, '/api/app/$appId?os=ios');
  });

  test('still-current version = null without hitting install path', () async {
    await serveLatest(
      fileName: 'polify-1.0.0-android.apk',
      architecture: 'arm64-v8a',
    );
    final service = BuildHutUpdateService(
      appId: appId,
      currentVersion: '1.0.0',
      baseUrl: baseUrl,
      os: 'android',
    );

    final update = await service.checkForUpdates();

    expect(update, isNull);
  });

  test('non-404 errors still throw (500 propagates)', () async {
    await startServer((req) async {
      req.response.statusCode = 500;
      await req.response.close();
    });
    final service = BuildHutUpdateService(
      appId: appId,
      currentVersion: '0.9.0',
      baseUrl: baseUrl,
      os: 'android',
    );

    expect(
      () => service.checkForUpdates(),
      throwsA(isA<DioException>()),
    );
  });
}
