import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hot_asset_gen/hot_asset_gen.dart';
import 'package:http/http.dart' as http;
import 'package:ota_protocol/ota_protocol.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'flutter_patch_config.dart';
import 'flutter_patch_sync_result.dart';

/// One-stop client for Meta OTA resource packs + Shorebird code push.
///
/// ```dart
/// runApp(await FlutterPatch.bootstrap(const MyApp(), appPackage: 'my_app'));
/// FlutterPatch.setUniqueId(id); // when you have it
/// await FlutterPatch.sync();    // when you have network
/// ```
///
/// Allowlist: server returns `unique_ids` on check; **this client** decides
/// whether to download (empty list = everyone).
///
/// Prefer [load] / [resolveFile] over `rootBundle` for audio, share images,
/// and similar non-`Image.asset` call sites so hot resources are visible.
class FlutterPatch {
  FlutterPatch._();

  static FlutterPatchConfig? _config;
  static String? _appPackage;
  static String? _releaseVersion;
  static String? _uniqueId;
  static ShorebirdUpdater _updater = ShorebirdUpdater();
  static http.Client _http = http.Client();

  static FlutterPatchConfig get config {
    final c = _config;
    if (c == null) {
      throw StateError('FlutterPatch.bootstrap() / init() must be called first');
    }
    return c;
  }

  static bool get isInitialized => _config != null && HotAssets.isInitialized;

  static String get appPackage {
    final p = _appPackage;
    if (p == null) {
      throw StateError('FlutterPatch.bootstrap() / init() must be called first');
    }
    return p;
  }

  static String? get uniqueId => _uniqueId;

  static String? get releaseVersion => _releaseVersion;

  static int get resourcePackNumber => HotAssets.packNumber;

  static int get resourceTableCount => HotAssets.tableCount;

  /// [HotAssetBundle] installed by [init] / [wrap]. Prefers the local resource
  /// table, otherwise the parent (usually [rootBundle]).
  static AssetBundle get assetBundle => HotAssets.bundle;

  /// Load asset bytes via [assetBundle] — drop-in for `rootBundle.load`.
  static Future<ByteData> load(String key) => HotAssets.bundle.load(key);

  /// On-disk file for a hot-updated asset key, or `null` if not in the table.
  /// Use with `VideoPlayerController.file` / similar file-based APIs.
  static File? resolveFile(String key) => HotAssets.registry.resolveFile(key);

  @visibleForTesting
  static set updater(ShorebirdUpdater value) => _updater = value;

  @visibleForTesting
  static set httpClient(http.Client value) => _http = value;

  static Future<Widget> bootstrap(
    Widget child, {
    required String appPackage,
    FlutterPatchConfig? config,
    String shorebirdYamlAsset = 'shorebird.yaml',
    String channel = 'stable',
  }) async {
    await init(
      appPackage: appPackage,
      config: config,
      shorebirdYamlAsset: shorebirdYamlAsset,
      channel: channel,
    );
    return wrap(child);
  }

  static Future<void> init({
    required String appPackage,
    FlutterPatchConfig? config,
    String shorebirdYamlAsset = 'shorebird.yaml',
    String channel = 'stable',
  }) async {
    _appPackage = appPackage;
    _config = config ??
        await FlutterPatchConfig.fromShorebirdYaml(
          assetPath: shorebirdYamlAsset,
          channel: channel,
        );
    await HotAssets.init(
      appPackage: appPackage,
      appId: _config!.appId,
    );
  }

  /// Set gray-release id when the app obtains it. Does not use the network.
  static void setUniqueId(String? uniqueId) {
    if (!isInitialized) {
      throw StateError('FlutterPatch.bootstrap() / init() must be called first');
    }
    final trimmed = uniqueId?.trim();
    _uniqueId = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Empty / null [allowlist] → allowed. Non-empty → [localId] must be listed.
  static bool isAllowlistHit(List<String>? allowlist, [String? localId]) {
    if (allowlist == null || allowlist.isEmpty) return true;
    final id = (localId ?? _uniqueId ?? '').trim();
    if (id.isEmpty) return false;
    return allowlist.contains(id);
  }

  static Widget wrap(Widget child) => HotAssets.wrap(child);

  static Future<String> resolveReleaseVersion() async {
    final info = await PackageInfo.fromPlatform();
    final v = '${info.version}+${info.buildNumber}';
    _releaseVersion = v;
    return v;
  }

  static Future<int?> readCurrentPatch() async {
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (_) {
      return null;
    }
  }

  /// Sync when **you** have network. Uses [setUniqueId] for client-side filter.
  static Future<FlutterPatchSyncResult> sync({
    bool resources = true,
    bool code = true,
    bool downloadCode = true,
    String? releaseVersion,
    String? channel,
    void Function(String)? onLog,
  }) async {
    if (!isInitialized) {
      throw StateError('FlutterPatch.bootstrap() / init() must be called first');
    }

    final version = releaseVersion ?? await resolveReleaseVersion();
    final ch = channel ?? config.channel;

    HotAssetSyncResult? resourceResult;
    if (resources) {
      resourceResult = await HotAssets.sync(
        baseUrl: config.baseUrl,
        appId: config.appId,
        releaseVersion: version,
        channel: ch,
        clientId: 'flutterpatch',
        uniqueId: _uniqueId,
        onLog: onLog,
      );
      onLog?.call(resourceResult.message);
    }

    FlutterPatchCodeResult? codeResult;
    if (code) {
      codeResult = await _syncCode(
        download: downloadCode,
        releaseVersion: version,
        channel: ch,
        onLog: onLog,
      );
    }

    return FlutterPatchSyncResult(
      resources: resourceResult,
      code: codeResult,
      releaseVersion: version,
    );
  }

  static Future<HotAssetSyncResult> syncResources({
    String? releaseVersion,
    String? channel,
    void Function(String)? onLog,
  }) async {
    final result = await sync(
      resources: true,
      code: false,
      releaseVersion: releaseVersion,
      channel: channel,
      onLog: onLog,
    );
    return result.resources!;
  }

  static Future<FlutterPatchCodeResult> syncCode({
    bool download = true,
    void Function(String)? onLog,
  }) async {
    final result = await sync(
      resources: false,
      code: true,
      downloadCode: download,
      onLog: onLog,
    );
    return result.code!;
  }

  static Future<FlutterPatchCodeResult> _syncCode({
    required bool download,
    required String releaseVersion,
    required String channel,
    void Function(String)? onLog,
  }) async {
    // Check first; apply unique_ids filter on the client before Shorebird download.
    final preflight = await _checkPatch(
      releaseVersion: releaseVersion,
      channel: channel,
      onLog: onLog,
    );
    if (preflight != null && preflight.patchAvailable) {
      final ids = preflight.patch?.uniqueIds;
      if (!isAllowlistHit(ids)) {
        onLog?.call('Code patch available but uniqueId miss — skip download');
        final current = await readCurrentPatch();
        return FlutterPatchCodeResult(
          status: UpdateStatus.upToDate,
          currentPatchNumber: current,
          downloaded: false,
        );
      }
    }

    try {
      final status = await _updater.checkForUpdate();
      onLog?.call('Shorebird checkForUpdate → $status');

      var downloaded = false;
      if (download && status == UpdateStatus.outdated) {
        onLog?.call('Shorebird update() downloading patch…');
        await _updater.update();
        downloaded = true;
        onLog?.call('Code patch downloaded — cold-start the app to apply');
      }

      final current = await readCurrentPatch();
      return FlutterPatchCodeResult(
        status: downloaded ? UpdateStatus.restartRequired : status,
        currentPatchNumber: current,
        downloaded: downloaded,
      );
    } catch (e) {
      onLog?.call('Shorebird unavailable (need shorebird release build): $e');
      return FlutterPatchCodeResult(
        status: UpdateStatus.unavailable,
        error: e,
      );
    }
  }

  static Future<PatchCheckResponse?> _checkPatch({
    required String releaseVersion,
    required String channel,
    void Function(String)? onLog,
  }) async {
    final platform =
        Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'unknown');
    final arch =
        (Platform.isAndroid || Platform.isIOS) ? 'aarch64' : 'x86_64';
    final current = await readCurrentPatch();
    final req = PatchCheckRequest(
      appId: config.appId,
      channel: channel,
      releaseVersion: releaseVersion,
      platform: platform,
      arch: arch,
      clientId: 'flutterpatch',
      currentPatchNumber: current,
    );
    try {
      final res = await _http
          .post(
            Uri.parse('${config.baseUrl}/api/v1/patches/check'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(req.toJson()),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        onLog?.call('Code check HTTP ${res.statusCode}');
        return null;
      }
      return PatchCheckResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    } catch (e) {
      onLog?.call('Code check failed: $e');
      return null;
    }
  }
}
