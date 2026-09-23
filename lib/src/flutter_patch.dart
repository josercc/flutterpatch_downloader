import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hot_asset_gen/hot_asset_gen.dart';
import 'package:http/http.dart' as http;
import 'package:ota_protocol/ota_protocol.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'flutter_patch_asset_image.dart';
import 'flutter_patch_config.dart';
import 'flutter_patch_sync_result.dart';

/// One-stop client for Meta OTA resource packs + Shorebird code push.
///
/// ```dart
/// runApp(await FlutterPatch.bootstrap(const MyApp(), appPackage: 'my_app'));
/// FlutterPatch.setUniqueId(id); // when you have it
/// await FlutterPatch.sync();    // when you have network
///
/// // Non-Image.asset call sites — no hot/miss branching:
/// final bytes = await FlutterPatch.loadBytes(key);
/// final file = await FlutterPatch.file(key);
/// ```
///
/// Whitelist is **server-side** (`whitelist_enabled` + `unique_ids`).
/// [setUniqueId] is sent as check `client_id` so the server can gate downloads.
/// When Meta OTA returns `patch_available: false`, this client skips Shorebird.
///
/// Prefer [load] / [loadBytes] / [file] over `rootBundle` for audio, share
/// images, video file APIs, and similar non-`Image.asset` call sites.
class FlutterPatch {
  FlutterPatch._();

  static const _bundleCacheDirName = '.bundle_cache';

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
    final pkg = _appPackage;
    if (pkg == null) {
      throw StateError('FlutterPatch.bootstrap() / init() must be called first');
    }
    return pkg;
  }

  static String? get uniqueId => _uniqueId;

  static String? get releaseVersion => _releaseVersion;

  static int get resourcePackNumber => HotAssets.packNumber;

  static int get resourceTableCount => HotAssets.tableCount;

  static int? get resourcePatchNumber => HotAssets.patchNumber;

  static String? get resourceConfigFingerprint => HotAssets.configFingerprint;

  /// [HotAssetBundle] installed by [init] / [wrap]. Prefers the local resource
  /// table, otherwise the parent (usually [rootBundle]).
  static AssetBundle get assetBundle => HotAssets.bundle;

  /// Load asset bytes via [assetBundle] — drop-in for `rootBundle.load`.
  ///
  /// Always succeeds for packaged keys: hot table first, then the APK/IPA
  /// asset bundle. No caller-side hot/miss check.
  static Future<ByteData> load(String key) => HotAssets.bundle.load(key);

  /// Same as [load], as [Uint8List]. Prefer this for audio / share / custom IO.
  static Future<Uint8List> loadBytes(String key) async {
    final data = await load(key);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// Always returns an on-disk [File] for [key] — no null / branching.
  ///
  /// 1. Hot resource table hit → that file  
  /// 2. Otherwise extract from [assetBundle] into a local cache once  
  ///
  /// Use with `VideoPlayerController.file` / players that need a path.
  static Future<File> file(String key) async {
    if (!isInitialized) {
      throw StateError('FlutterPatch.bootstrap() / init() must be called first');
    }

    final hot = HotAssets.registry.resolveFile(key);
    if (hot != null) return hot;

    final bytes = await loadBytes(key);
    final out = _bundleCacheFile(key);
    out.parent.createSync(recursive: true);
    if (!out.existsSync() || out.lengthSync() != bytes.length) {
      await out.writeAsBytes(bytes, flush: true);
    }
    return out;
  }

  /// Hot-updated on-disk file only, or `null` if not in the table.
  ///
  /// Prefer [file] unless you explicitly need “hot only”.
  static File? resolveFile(String key) => HotAssets.registry.resolveFile(key);

  /// Hot-aware [ImageProvider]: local OTA file first, else package [AssetImage].
  ///
  /// Drop-in for `AssetImage` / `Image.asset` call sites that must show
  /// brand-new hot keys not present in the binary [AssetManifest].
  ///
  /// FlutterGen: `FlutterPatch.assetImage(Assets.images.foo.path)`.
  static ImageProvider assetImage(
    String assetName, {
    AssetBundle? bundle,
    String? package,
    double? scale,
  }) {
    if (scale != null) {
      return FlutterPatchExactAssetImage(
        assetName,
        bundle: bundle,
        package: package,
        scale: scale,
      );
    }
    return FlutterPatchAssetImage(
      assetName,
      bundle: bundle,
      package: package,
    );
  }

  /// Hot-aware [Image] from an asset path — portable across apps (no WinnerImage).
  ///
  /// FlutterGen（无法用扩展覆盖已有的 [AssetGenImage.image]，请用 `.patchImage` /
  /// `.path.flutterPatchImage`）:
  /// ```dart
  /// Assets.images.foo.patchImage(package: 'my_pkg', width: 24);
  /// FlutterPatch.image(Assets.images.foo.path, package: 'my_pkg', width: 24);
  /// ```
  static Image image(
    String assetName, {
    Key? key,
    AssetBundle? bundle,
    String? package,
    double? scale,
    double? width,
    double? height,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Color? color,
    BlendMode? colorBlendMode,
    FilterQuality filterQuality = FilterQuality.medium,
    bool gaplessPlayback = true,
    bool excludeFromSemantics = false,
    String? semanticLabel,
    bool matchTextDirection = false,
    bool isAntiAlias = false,
    Animation<double>? opacity,
    Rect? centerSlice,
    int? cacheWidth,
    int? cacheHeight,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    ImageLoadingBuilder? loadingBuilder,
  }) {
    ImageProvider provider = assetImage(
      assetName,
      bundle: bundle,
      package: package,
      scale: scale,
    );
    if (cacheWidth != null || cacheHeight != null) {
      provider = ResizeImage(
        provider,
        width: cacheWidth,
        height: cacheHeight,
      );
    }
    return Image(
      image: provider,
      key: key,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      color: color,
      colorBlendMode: colorBlendMode,
      filterQuality: filterQuality,
      gaplessPlayback: gaplessPlayback,
      excludeFromSemantics: excludeFromSemantics,
      semanticLabel: semanticLabel,
      matchTextDirection: matchTextDirection,
      isAntiAlias: isAntiAlias,
      opacity: opacity,
      centerSlice: centerSlice,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }

  static File _bundleCacheFile(String key) {
    final digest = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    final ext = p.extension(key);
    return File(
      p.join(HotAssets.registry.rootDir, _bundleCacheDirName, '$digest$ext'),
    );
  }

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
    // Resolve release version before loading the local table so a newer
    // binary (e.g. 1.0.0+2) does not reuse a stale 1.0.0+1 config.
    final version = await resolveReleaseVersion();
    await HotAssets.init(
      appPackage: appPackage,
      appId: _config!.appId,
      releaseVersion: version,
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

  /// Defense-in-depth after server whitelist. Empty / null [allowlist] → allowed.
  /// Non-empty → [localId] (or [uniqueId]) must be listed.
  static bool isAllowlistHit(List<String>? allowlist, [String? localId]) {
    if (allowlist == null || allowlist.isEmpty) return true;
    final id = (localId ?? _uniqueId ?? '').trim();
    if (id.isEmpty) return false;
    return allowlist.contains(id);
  }

  /// Gray-release id for Meta OTA check `client_id` (may be empty if unset).
  static String get _checkClientId => (_uniqueId ?? '').trim();

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

  /// Sync when **you** have network. Sends [uniqueId] as check `client_id`.
  ///
  /// Order: locate target Dart patch number → sync that patch's resource table
  /// → download code patch (if any).
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
    final checkClientId = _checkClientId;

    final preflight = await _checkPatch(
      releaseVersion: version,
      channel: ch,
      onLog: onLog,
    );

    final currentPatch = await readCurrentPatch();
    // Prefer the upcoming patch number when a newer patch is available so
    // resources for that patch download together with the code update.
    int? targetPatchNumber = currentPatch;
    if (preflight != null &&
        preflight.patchAvailable &&
        preflight.patch != null) {
      targetPatchNumber = preflight.patch!.number;
    }

    HotAssetSyncResult? resourceResult;
    if (resources) {
      resourceResult = await HotAssets.sync(
        baseUrl: config.baseUrl,
        appId: config.appId,
        releaseVersion: version,
        channel: ch,
        clientId: checkClientId.isEmpty ? 'flutterpatch' : checkClientId,
        uniqueId: _uniqueId,
        patchNumber: targetPatchNumber,
        platform: _platformName,
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
        preflight: preflight,
        onLog: onLog,
      );
    }

    return FlutterPatchSyncResult(
      resources: resourceResult,
      code: codeResult,
      releaseVersion: version,
      targetPatchNumber: targetPatchNumber,
    );
  }

  static String get _platformName =>
      Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'unknown');

  static Future<HotAssetSyncResult> syncResources({
    String? releaseVersion,
    String? channel,
    int? patchNumber,
    void Function(String)? onLog,
  }) async {
    final version = releaseVersion ?? await resolveReleaseVersion();
    final ch = channel ?? config.channel;
    final checkClientId = _checkClientId;
    final pn = patchNumber ?? await readCurrentPatch();
    return HotAssets.sync(
      baseUrl: config.baseUrl,
      appId: config.appId,
      releaseVersion: version,
      channel: ch,
      clientId: checkClientId.isEmpty ? 'flutterpatch' : checkClientId,
      uniqueId: _uniqueId,
      patchNumber: pn,
      platform: _platformName,
      onLog: onLog,
    );
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
    PatchCheckResponse? preflight,
    void Function(String)? onLog,
  }) async {
    // Meta OTA preflight (server whitelist). Gate Shorebird on patch_available.
    final check = preflight ??
        await _checkPatch(
          releaseVersion: releaseVersion,
          channel: channel,
          onLog: onLog,
        );
    if (check != null && !check.patchAvailable) {
      onLog?.call(
        'Code patch not available from Meta OTA '
        '(whitelist / no newer patch) — skip Shorebird download',
      );
      final current = await readCurrentPatch();
      return FlutterPatchCodeResult(
        status: UpdateStatus.upToDate,
        currentPatchNumber: current,
        downloaded: false,
        nextPatchNumber: check.patch?.number,
        hasResourceChanges: check.patch?.hasResourceChanges,
      );
    }
    if (check != null && check.patchAvailable) {
      final ids = check.patch?.uniqueIds;
      if (!isAllowlistHit(ids)) {
        onLog?.call('Code patch available but uniqueId miss — skip download');
        final current = await readCurrentPatch();
        return FlutterPatchCodeResult(
          status: UpdateStatus.upToDate,
          currentPatchNumber: current,
          downloaded: false,
          nextPatchNumber: check.patch?.number,
          hasResourceChanges: check.patch?.hasResourceChanges,
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
        nextPatchNumber: check?.patch?.number,
        hasResourceChanges: check?.patch?.hasResourceChanges,
      );
    } catch (e) {
      onLog?.call('Shorebird unavailable (need shorebird release build): $e');
      return FlutterPatchCodeResult(
        status: UpdateStatus.unavailable,
        error: e,
        nextPatchNumber: check?.patch?.number,
        hasResourceChanges: check?.patch?.hasResourceChanges,
      );
    }
  }

  static Future<PatchCheckResponse?> _checkPatch({
    required String releaseVersion,
    required String channel,
    void Function(String)? onLog,
  }) async {
    final platform = _platformName;
    final arch =
        (Platform.isAndroid || Platform.isIOS) ? 'aarch64' : 'x86_64';
    final current = await readCurrentPatch();
    // Server whitelist matches this against patches.unique_ids.
    final clientId = _checkClientId;
    final req = PatchCheckRequest(
      appId: config.appId,
      channel: channel,
      releaseVersion: releaseVersion,
      platform: platform,
      arch: arch,
      clientId: clientId,
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
