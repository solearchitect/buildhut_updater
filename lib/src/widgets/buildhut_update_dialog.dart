import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models/buildhut_app_update.dart';
import '../services/buildhut_update_service.dart';

/// A Material dialog that presents an available update to the user.
///
/// Displays the new version number, the current version, and an optional
/// markdown changelog. Includes a "Update Now" button that downloads the
/// APK with a progress bar, then triggers the Android system installer.
/// The user can dismiss with "Later" at any time before the download starts.
///
/// ```dart
/// showDialog(
///   context: context,
///   barrierDismissible: false,
///   builder: (_) => BuildHutUpdateDialog(
///     update: update,
///     updateService: service,
///     currentVersion: '1.0.0',
///     onUpdateInstalled: () => print('install triggered'),
///   ),
/// );
/// ```
class BuildHutUpdateDialog extends StatefulWidget {
  /// The update to present to the user.
  final BuildHutAppUpdate update;

  /// The service used to download and install the update.
  final BuildHutUpdateService updateService;

  /// The current app version string displayed in the dialog body.
  final String currentVersion;

  /// Optional callback invoked after the APK installation is triggered
  /// (i.e. after the system installer is launched).
  final VoidCallback? onUpdateInstalled;

  /// Creates a [BuildHutUpdateDialog].
  const BuildHutUpdateDialog({
    super.key,
    required this.update,
    required this.updateService,
    required this.currentVersion,
    this.onUpdateInstalled,
  });

  @override
  State<BuildHutUpdateDialog> createState() => _BuildHutUpdateDialogState();
}

class _BuildHutUpdateDialogState extends State<BuildHutUpdateDialog> {
  double _downloadProgress = 0.0;
  String _status = '';
  bool _isDownloading = false;
  bool _downloadComplete = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update_alt, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Update Available'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${widget.update.version} is available',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You are currently on version ${widget.currentVersion}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (widget.update.description != null) ...[
              const SizedBox(height: 16),
              const Text(
                "What's new:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: MarkdownBody(
                  data: widget.update.description!,
                  onTapLink: (text, href, title) {},
                ),
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              Column(
                children: [
                  LinearProgressIndicator(value: _downloadProgress),
                  const SizedBox(height: 8),
                  Text(_status, style: theme.textTheme.bodySmall),
                  if (_downloadProgress > 0)
                    Text(
                      '${(_downloadProgress * 100).toInt()}%',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ],
            if (_downloadComplete) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Download complete! Installing update...'),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDownloading ? null : () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed:
              _isDownloading || _downloadComplete ? null : _startDownload,
          child: const Text('Update Now'),
        ),
      ],
    );
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _status = 'Preparing download...';
    });

    try {
      await widget.updateService.installUpdate(
        widget.update,
        onProgress: (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
        onStatusChange: (status) {
          if (mounted) setState(() => _status = status);
        },
      );

      if (mounted) {
        setState(() => _downloadComplete = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context);
          widget.onUpdateInstalled?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Update Failed'),
            content: Text(
              'Failed to download and install the update:\n\n$error',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}

/// Shows the full update check flow from start to finish.
///
/// This is the simplest way to integrate update checking. It:
/// 1. Shows a "Checking for Updates" spinner dialog.
/// 2. Queries the BuildHut API for the latest build.
/// 3. On success, shows either a [BuildHutUpdateDialog] (update available)
///    or an "Up to Date" dialog (no update).
/// 4. On failure, shows an error dialog with the error message.
///
/// [context] is the build context used to show dialogs.
/// [updateService] is the configured [BuildHutUpdateService] instance.
/// [currentVersion] is the current app version string displayed in dialogs.
/// [onUpdateInstalled] is an optional callback after the APK install is triggered.
///
/// ```dart
/// await showBuildHutUpdateCheck(
///   context: context,
///   updateService: service,
///   currentVersion: '1.0.0',
/// );
/// ```
Future<void> showBuildHutUpdateCheck({
  required BuildContext context,
  required BuildHutUpdateService updateService,
  required String currentVersion,
  VoidCallback? onUpdateInstalled,
}) async {
  // Show checking dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => const AlertDialog(
          title: Text('Checking for Updates'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking for available updates...'),
            ],
          ),
        ),
  );

  try {
    final update = await updateService.checkForUpdates();

    if (!context.mounted) return;
    Navigator.pop(context); // Close checking dialog

    if (!context.mounted) return;
    if (update != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => BuildHutUpdateDialog(
              update: update,
              updateService: updateService,
              currentVersion: currentVersion,
              onUpdateInstalled: onUpdateInstalled,
            ),
      );
    } else {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Up to Date'),
                ],
              ),
              content: Text(
                'You are running the latest version.\nVersion: $currentVersion',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context); // Close checking dialog

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Update Check Failed'),
            content: Text('Failed to check for updates:\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
