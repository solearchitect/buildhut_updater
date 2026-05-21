// Android in-app update checker and installer for the BuildHut API.
//
// Quick start:
// ```dart
// import 'package:buildhut_updater/buildhut_updater.dart';
//
// final service = BuildHutUpdateService(
//   appId: 'your-app-uuid',
//   currentVersion: '1.0.0',
// );
//
// // Check for updates
// final update = await service.checkForUpdates();
//
// // Or show the full update UI flow
// await showBuildHutUpdateCheck(
//   context: context,
//   updateService: service,
//   currentVersion: '1.0.0',
// );
// ```

export 'src/models/buildhut_app_update.dart';
export 'src/services/buildhut_update_service.dart';
export 'src/widgets/buildhut_update_dialog.dart';
