import 'package:flutter/services.dart';

/// Connection settings for the self-hosted Meta OTA control plane.
///
/// Prefer [FlutterPatchConfig.fromShorebirdYaml] so apps only maintain
/// `shorebird.yaml` (same file Shorebird already uses for code push).
///
/// Gray-release identity is **not** part of this config — call
/// [FlutterPatch.setUniqueId] when your app obtains it.
class FlutterPatchConfig {
  const FlutterPatchConfig({
    required this.appId,
    required this.baseUrl,
    this.channel = 'stable',
  });

  /// Shorebird / Meta OTA application id.
  final String appId;

  /// Control-plane origin, e.g. `http://192.168.1.10:8080`.
  final String baseUrl;

  /// Release channel (resources + patch check).
  final String channel;

  FlutterPatchConfig copyWith({
    String? appId,
    String? baseUrl,
    String? channel,
  }) {
    return FlutterPatchConfig(
      appId: appId ?? this.appId,
      baseUrl: baseUrl ?? this.baseUrl,
      channel: channel ?? this.channel,
    );
  }

  /// Load [appId] / [baseUrl] from a Flutter asset (default `shorebird.yaml`).
  static Future<FlutterPatchConfig> fromShorebirdYaml({
    String assetPath = 'shorebird.yaml',
    String channel = 'stable',
    AssetBundle? bundle,
  }) async {
    final text = await (bundle ?? rootBundle).loadString(assetPath);
    return FlutterPatchConfig.parseYaml(text, channel: channel);
  }

  /// Parse Shorebird-style YAML without a full YAML dependency.
  factory FlutterPatchConfig.parseYaml(
    String yaml, {
    String channel = 'stable',
  }) {
    final appId = RegExp(r'app_id:\s*"?([0-9a-fA-F-]+)"?')
            .firstMatch(yaml)
            ?.group(1) ??
        '';
    final baseUrl =
        RegExp(r'base_url:\s*(\S+)').firstMatch(yaml)?.group(1) ?? '';
    if (appId.isEmpty) {
      throw FormatException('shorebird.yaml missing app_id');
    }
    if (baseUrl.isEmpty) {
      throw FormatException('shorebird.yaml missing base_url');
    }
    return FlutterPatchConfig(
      appId: appId,
      baseUrl: baseUrl.replaceAll(RegExp(r'/$'), ''),
      channel: channel,
    );
  }
}
