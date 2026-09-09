# flutterpatch

Umbrella client for Meta OTA: **resource hot-update** + **Shorebird code push**.

## Integrate

```dart
runApp(await FlutterPatch.bootstrap(const MyApp(), appPackage: 'my_app'));

FlutterPatch.setUniqueId(id); // when you have it (nullable)
await FlutterPatch.sync();    // when you have network
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
