# flutterpatch

Umbrella client for Meta OTA: **resource hot-update** + **Shorebird code push**.

## Integrate

```dart
runApp(await FlutterPatch.bootstrap(const MyApp(), appPackage: 'my_app'));

FlutterPatch.setUniqueId(id); // when you have it (nullable)
await FlutterPatch.sync();    // when you have network
```

`Image.asset` / FlutterGen `.image()` keep working under `FlutterPatch.wrap`
for keys already in the binary `AssetManifest`. Prefer these **path-based** APIs
(portable; no app-specific `WinnerImage`):

```dart
// FlutterGen — cannot override AssetGenImage.image() (instance method wins).
// Use .patchImage in each package (see assets_flutter_patch.dart), or:
FlutterPatch.image(Assets.images.game.cottonPower.path, width: 24, height: 24);
Assets.images.game.cottonPower.path.flutterPatchImage(width: 24, height: 24);
Assets.images.foo.patchImage(package: 'my_pkg', width: 64); // after importing patch ext

// ImageProvider (ExtendedImage / DecorationImage / …)
FlutterPatch.assetImage(Assets.images.game.cottonPower.path);
Assets.images.game.cottonPower.path.flutterPatchImageProvider;
```

### Non-`Image.asset` call sites

Audio, share bitmaps, video file APIs, etc. that used `rootBundle` or
`VideoPlayerController.asset` should use the unified helpers — **no hot/miss
branching**:

```dart
// bytes (hot table → package asset)
final bytes = await FlutterPatch.loadBytes(key);
// or: await FlutterPatch.load(key) → ByteData

// always a File (hot file, or extracted from the package once)
final file = await FlutterPatch.file(key);
final controller = VideoPlayerController.file(file);

// rare: custom AssetBundle consumers
FlutterPatch.assetBundle;

// advanced: only the hot-updated file, or null
FlutterPatch.resolveFile(key);
```

### uniqueId / 白名单

`setUniqueId`（通常为业务 **用户 uid**）用于客户端灰度；也会作为 check 的 `client_id`（签名 URL / 事件），**服务端不据此拦截下载**。

白名单由**客户端**根据 check 响应里的 `unique_ids` 判定：

| 服务端 `whitelist_enabled` | 响应 `unique_ids` | 客户端结果 |
|----------------------------|-------------------|------------|
| `false` | 省略 | 全员可下 |
| `true` | `[]` | 全员跳过 |
| `true` | 非空 | 仅 `setUniqueId` 命中可下 |

未命中时客户端 **不会** 再走 Shorebird `update()`。

### Network

`bootstrap` 不上网；由业务在合适时机调用 `sync`。

## Resource hot-update scope

| Include | Notes |
|---------|--------|
| `assets/images/**` | Primary; upload **1x + 2.0x + 3.0x** together when variants exist |
| `assets/audios/**` / `assets/videos/**` / Lottie | OK if app uses `FlutterPatch.loadBytes` / `file` |
| **Exclude** `assets/fonts/**` | Registered via `pubspec.yaml` `fonts:` at startup — not via AssetBundle |
| **Exclude** env/config (e.g. `dart_define.json`) | Keep package-bundled only |

**Rules**

1. Only **replace keys already in the binary** `AssetManifest`. Brand-new paths may fail `Image.asset`.
2. Align resource pack `release_version` with the installed app; changing release clears the local table.
3. After `sync` with `resourcesUpdated`, clear/rebuild any preloaded audio/video (images: `imageCache` is cleared inside `HotAssets.sync`). Next `FlutterPatch.file` / `loadBytes` already prefer the new hot bytes.

## Verify image OTA (smoke)

1. Pick an existing FlutterGen path, e.g. `assets/images/home/...png` (include 2x/3x if present).
2. Upload a resource pack for the current `release_version` / `meta_winner_app` package.
3. Cold start → Init `sync` → confirm files under `Documents/meta_ota_resources/` and UI shows the new image.
4. Check `FlutterPatch.resourcePackNumber` / `resourceTableCount`.
