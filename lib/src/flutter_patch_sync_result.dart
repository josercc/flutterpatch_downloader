import 'package:hot_asset_gen/hot_asset_gen.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Combined outcome of [FlutterPatch.sync].
class FlutterPatchSyncResult {
  const FlutterPatchSyncResult({
    this.resources,
    this.code,
    this.releaseVersion,
    this.targetPatchNumber,
  });

  /// Resource-pack sync result; null if resources were skipped.
  final HotAssetSyncResult? resources;

  /// Code-push outcome; null if code sync was skipped.
  final FlutterPatchCodeResult? code;

  /// Release version used for this sync (`version+build`).
  final String? releaseVersion;

  /// Patch number whose resource table was (or will be) synced.
  final int? targetPatchNumber;

  /// True when a code patch was downloaded and needs a cold start.
  bool get restartRequired => code?.restartRequired ?? false;

  /// True when the local resource table changed this run.
  bool get resourcesUpdated => resources?.updated ?? false;

  /// True when either resources or code need user attention.
  bool get updateAvailable =>
      resourcesUpdated ||
      restartRequired ||
      (code?.downloaded ?? false) ||
      (code?.outdated ?? false);
}

/// Shorebird code-push slice of a sync.
class FlutterPatchCodeResult {
  const FlutterPatchCodeResult({
    required this.status,
    this.currentPatchNumber,
    this.nextPatchNumber,
    this.hasResourceChanges,
    this.downloaded = false,
    this.error,
  });

  final UpdateStatus status;
  final int? currentPatchNumber;

  /// Newest published patch number from preflight (may equal current).
  final int? nextPatchNumber;

  /// From patches/check: whether the target patch has resource changes.
  final bool? hasResourceChanges;

  /// True if [ShorebirdUpdater.update] ran successfully this sync.
  final bool downloaded;

  /// Non-fatal error (e.g. updater unavailable in `flutter run` builds).
  final Object? error;

  /// Patch bytes are staged; restart the process to activate.
  bool get restartRequired =>
      downloaded || status == UpdateStatus.restartRequired;

  /// True when Shorebird reports a newer patch is available to download.
  bool get outdated => status == UpdateStatus.outdated;
}
