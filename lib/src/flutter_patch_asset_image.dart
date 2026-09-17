import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'flutter_patch.dart';

/// [AssetImage] that prefers Meta OTA local files when hot assets are active.
///
/// Resolution order:
/// 1. Hot assets **not** initialized → same as [AssetImage] (package assets)
/// 2. Initialized + key in the resource table → load via [FlutterPatch.assetBundle]
///    (local file; **no** [AssetManifest] requirement — supports brand-new keys)
/// 3. Initialized but key missing → fall back to [AssetImage] / package assets
class FlutterPatchAssetImage extends AssetImage {
  const FlutterPatchAssetImage(
    super.assetName, {
    super.bundle,
    super.package,
  });

  /// Whether Meta OTA hot-asset table is ready.
  static bool get supportsHotAssets => FlutterPatch.isInitialized;

  String? _resolveHotKey() {
    if (!supportsHotAssets) return null;
    for (final key in <String>{keyName, assetName}) {
      if (FlutterPatch.resolveFile(key) != null) return key;
    }
    return null;
  }

  @override
  Future<AssetBundleImageKey> obtainKey(ImageConfiguration configuration) {
    final hotKey = _resolveHotKey();
    if (hotKey != null) {
      // Bypass AssetManifest so newly added OTA paths still load.
      return SynchronousFuture<AssetBundleImageKey>(
        AssetBundleImageKey(
          bundle: FlutterPatch.assetBundle,
          name: hotKey,
          scale: 1.0,
        ),
      );
    }
    return super.obtainKey(configuration);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is FlutterPatchAssetImage &&
        other.assetName == assetName &&
        other.bundle == bundle &&
        other.package == package;
  }

  @override
  int get hashCode => Object.hash(assetName, bundle, package);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'FlutterPatchAssetImage')}(bundle: $bundle, name: "$assetName")';
}

/// Scale-aware variant; same hot-table preference as [FlutterPatchAssetImage].
class FlutterPatchExactAssetImage extends ExactAssetImage {
  const FlutterPatchExactAssetImage(
    super.assetName, {
    super.bundle,
    super.package,
    super.scale,
  });

  String? _resolveHotKey() {
    if (!FlutterPatch.isInitialized) return null;
    for (final key in <String>{keyName, assetName}) {
      if (FlutterPatch.resolveFile(key) != null) return key;
    }
    return null;
  }

  @override
  Future<AssetBundleImageKey> obtainKey(ImageConfiguration configuration) {
    final hotKey = _resolveHotKey();
    if (hotKey != null) {
      return SynchronousFuture<AssetBundleImageKey>(
        AssetBundleImageKey(
          bundle: FlutterPatch.assetBundle,
          name: hotKey,
          scale: scale,
        ),
      );
    }
    return super.obtainKey(configuration);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is FlutterPatchExactAssetImage &&
        other.assetName == assetName &&
        other.bundle == bundle &&
        other.package == package &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(assetName, bundle, package, scale);
}
