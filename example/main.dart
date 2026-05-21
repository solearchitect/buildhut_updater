/// Complete example demonstrating buildhut_updater integration.
///
/// Before running, make sure your app's `AndroidManifest.xml` declares:
/// ```xml
/// <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
/// <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
/// ```
///
/// And that a FileProvider is configured (see README for details).
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:buildhut_updater/buildhut_updater.dart';

void main() {
  runApp(const ExampleApp());
}

/// Root application widget.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BuildHut Updater Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const ExamplePage(),
    );
  }
}

/// Main page demonstrating both the full UI flow and silent update checking.
class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  /// The update service — initialized in [initState] once the app version
  /// is known via [PackageInfo.fromPlatform].
  late final BuildHutUpdateService _updateService;

  /// Current app version string displayed in the UI.
  String _currentVersion = 'loading...';

  /// Whether an update check is currently in progress.
  bool _isChecking = false;

  /// The latest update found by a silent check, if any.
  BuildHutAppUpdate? _lastSilentUpdate;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  /// Reads the current version from the platform and initializes
  /// the [BuildHutUpdateService].
  Future<void> _initService() async {
    final info = await PackageInfo.fromPlatform();
    final version = '${info.version}+${info.buildNumber}';

    setState(() => _currentVersion = version);

    _updateService = BuildHutUpdateService(
      // Replace with your BuildHut app UUID
      appId: 'your-app-id-here',
      currentVersion: version,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('BuildHut Updater')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Current version display
              Icon(
                Icons.android,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'Current version',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                _currentVersion,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // Full UI flow button
              FilledButton.icon(
                onPressed:
                    _isChecking
                        ? null
                        : () async {
                          setState(() => _isChecking = true);
                          await showBuildHutUpdateCheck(
                            context: context,
                            updateService: _updateService,
                            currentVersion: _currentVersion,
                          );
                          if (mounted) setState(() => _isChecking = false);
                        },
                icon:
                    _isChecking
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.system_update),
                label: const Text('Check for Updates'),
              ),
              const SizedBox(height: 12),

              // Silent check button
              OutlinedButton.icon(
                onPressed:
                    _isChecking
                        ? null
                        : _silentCheck,
                icon: const Icon(Icons.refresh),
                label: const Text('Silent Check (no dialog)'),
              ),
              const SizedBox(height: 24),

              // Silent check result
              if (_lastSilentUpdate != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Update available: ${_lastSilentUpdate!.version}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_lastSilentUpdate!.description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _lastSilentUpdate!.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () {
                          // Show the full update dialog for the silently
                          // discovered update.
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (_) => BuildHutUpdateDialog(
                                  update: _lastSilentUpdate!,
                                  updateService: _updateService,
                                  currentVersion: _currentVersion,
                                  onUpdateInstalled: () {
                                    setState(
                                      () => _lastSilentUpdate = null,
                                    );
                                  },
                                ),
                          );
                        },
                        child: const Text('Show Update Dialog'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Performs a silent update check without showing any dialogs.
  ///
  /// Demonstrates how to use [BuildHutUpdateService.checkForUpdates]
  /// directly for background polling or custom UI flows.
  Future<void> _silentCheck() async {
    setState(() => _isChecking = true);

    try {
      final update = await _updateService.checkForUpdates();
      if (!mounted) return;

      setState(() => _lastSilentUpdate = update);

      if (update != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update available: ${update.version}'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App is up to date'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }

    if (mounted) setState(() => _isChecking = false);
  }
}
