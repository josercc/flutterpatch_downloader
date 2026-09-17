## 0.1.2

- Add `FlutterPatch.image` + `String.flutterPatchImage` / `flutterPatchImageProvider` for path-based (FlutterGen-friendly) hot images — no app-specific widgets required. Supports `package` / `cacheWidth` / `cacheHeight` (aligns with FlutterGen `AssetGenImage.image`).
- Note: Dart cannot override `AssetGenImage.image` via extension; apps should add `.patchImage` on their generated `AssetGenImage` (see package `assets_flutter_patch.dart`).
- Add `FlutterPatchAssetImage` / `FlutterPatchExactAssetImage` / `FlutterPatch.assetImage`: hot table first (no AssetManifest), else package assets.
- Send `setUniqueId` as Meta OTA `patches/check` `client_id` so server-side `whitelist_enabled` can match.
- Skip Shorebird download when Meta OTA returns `patch_available: false` (whitelist deny / no newer patch).
- Add `FlutterPatch.loadBytes` and `FlutterPatch.file`: always return hot-aware bytes / an on-disk `File` with no caller-side hot/miss branching (`file` extracts from the package asset bundle into a local cache when not in the hot table).
- Prefer `loadBytes` / `file` over manual `resolveFile` null checks in README.

## 0.1.1

- Expose `FlutterPatch.load`, `resolveFile`, and `assetBundle` for non-`Image.asset` hot resources (audio, video file APIs, share bitmaps).
- Document resource hot-update scope and image OTA smoke checklist.

## 0.1.0

- Initial release: umbrella client for resource hot-update and Shorebird code push.
