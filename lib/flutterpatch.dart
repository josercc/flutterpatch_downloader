/// Meta OTA client: resource hot-update + Shorebird code push.
///
/// ```dart
/// runApp(await FlutterPatch.bootstrap(const MyApp(), appPackage: 'my_app'));
/// FlutterPatch.setUniqueId(id); // when you have it
/// await FlutterPatch.sync();    // when you have network
/// // Response unique_ids are filtered on the client — no request API change.
/// ```
library;

export 'package:hot_asset_gen/hot_asset_gen.dart';
export 'package:shorebird_code_push/shorebird_code_push.dart'
    show
        Patch,
        ReadPatchException,
        ShorebirdUpdater,
        UpdateException,
        UpdateFailureReason,
        UpdateStatus,
        UpdateTrack;

export 'src/flutter_patch.dart';
export 'src/flutter_patch_config.dart';
export 'src/flutter_patch_sync_result.dart';
