import 'package:hot_asset_gen/hot_asset_gen.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Combined outcome of [FlutterPatch.sync].
class FlutterPatchSyncResult {
  const FlutterPatchSyncResult({
    this.resources,
    this.code,
    this.releaseVersion,
  });

  /// Resource-pack sync result; null if resources were skipped.
  final HotAssetSyncResult? resources;

  /// Code-push outcome; null if code sync was skipped.
  final FlutterPatchCodeResult? code;

  /// Release version used for this sync (`version+build`).
  final String? releaseVersion;

  /// True when a code patch was downloaded and needs a cold start.
  bool get restartRequired => code?.restartRequired ?? false;

  /// True when the local resource table changed this run.
  bool get resourcesUpdated => resources?.updated ?? false;
}

/// Shorebird code-push slice of a sync.
class FlutterPatchCodeResult {
  const FlutterPatchCodeResult({
    required this.status,
    this.currentPatchNumber,
    this.downloaded = false,
    this.error,
  });

  final UpdateStatus status;
  final int? currentPatchNumber;

  /// True if [ShorebirdUpdater.update] ran successfully this sync.
  final bool downloaded;

  /// Non-fatal error (e.g. updater unavailable in `flutter run` builds).
  final Object? error;

  /// Patch bytes are staged; restart the process to activate.
  bool get restartRequired =>
      downloaded || status == UpdateStatus.restartRequired;
}
