# flutterpatch

Umbrella client for Meta OTA: **resource hot-update** + **Shorebird code push**.

## Integrate

```dart
runApp(await FlutterPatch.bootstrap(const MyApp(), appPackage: 'my_app'));

FlutterPatch.setUniqueId(id); // when you have it (nullable)
await FlutterPatch.sync();    // when you have network
```

`Image.asset` / FlutterGen `.image()` keep working unchanged under `FlutterPatch.wrap`
(`DefaultAssetBundle` → hot table → `rootBundle`).

### Non-`Image.asset` call sites

Audio, share bitmaps, video file APIs, etc. that used `rootBundle` or
`VideoPlayerController.asset` must go through FlutterPatch:

```dart
// instead of rootBundle.load(key)
final bytes = await FlutterPatch.load(key);

// instead of VideoPlayerController.asset(key) when a hot file may exist
final file = FlutterPatch.resolveFile(key);
final controller = file != null
    ? VideoPlayerController.file(file)
    : VideoPlayerController.asset(key);

// rare: custom AssetBundle consumers
FlutterPatch.assetBundle;
```

### uniqueId（客户端判断）

请求协议不变。check 响应里的 `unique_ids` 由客户端过滤：

| 响应 `unique_ids` | `setUniqueId` | 是否下载 |
|-------------------|---------------|----------|
| 空 / 无 | 任意 | 是 |
| 非空 | 空 / 未命中 | 否 |
| 非空 | 命中 | 是 |

### Network

`bootstrap` 不上网；由业务在合适时机调用 `sync`。

## Resource hot-update scope

| Include | Notes |
|---------|--------|
| `assets/images/**` | Primary; upload **1x + 2.0x + 3.0x** together when variants exist |
| `assets/audios/**` / `assets/videos/**` / Lottie | OK if app uses `FlutterPatch.load` / `resolveFile` |
| **Exclude** `assets/fonts/**` | Registered via `pubspec.yaml` `fonts:` at startup — not via AssetBundle |
| **Exclude** env/config (e.g. `dart_define.json`) | Keep package-bundled only |

**Rules**

1. Only **replace keys already in the binary** `AssetManifest`. Brand-new paths may fail `Image.asset`.
2. Align resource pack `release_version` with the installed app; changing release clears the local table.
3. After `sync` with `resourcesUpdated`, clear/rebuild any preloaded audio/video (images: `imageCache` is cleared inside `HotAssets.sync`).

## Verify image OTA (smoke)

1. Pick an existing FlutterGen path, e.g. `assets/images/home/...png` (include 2x/3x if present).
2. Upload a resource pack for the current `release_version` / `meta_winner_app` package.
3. Cold start → Init `sync` → confirm files under `Documents/meta_ota_resources/` and UI shows the new image.
4. Check `FlutterPatch.resourcePackNumber` / `resourceTableCount`.
