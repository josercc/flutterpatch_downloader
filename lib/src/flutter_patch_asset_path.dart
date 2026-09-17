import 'package:flutter/widgets.dart';

import 'flutter_patch.dart';

/// Path helpers for FlutterGen / raw asset keys.
///
/// ```dart
/// Assets.images.game.cottonPower.path.flutterPatchImage(width: 24);
/// Assets.images.game.cottonPower.path.flutterPatchImageProvider;
/// ```
///
/// Note: [AssetGenImage.image] is an **instance** method — Dart extensions
/// cannot override it. Use [flutterPatchImage] / package `.patchImage` instead.
extension FlutterPatchAssetPath on String {
  /// Same as [FlutterPatch.assetImage].
  ImageProvider flutterPatchImageProvider({
    AssetBundle? bundle,
    String? package,
    double? scale,
  }) {
    return FlutterPatch.assetImage(
      this,
      bundle: bundle,
      package: package,
      scale: scale,
    );
  }

  /// Same as [FlutterPatch.image] — hot table first, else package assets.
  ///
  /// Parameter defaults align with FlutterGen [AssetGenImage.image].
  Image flutterPatchImage({
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
    return FlutterPatch.image(
      this,
      key: key,
      bundle: bundle,
      package: package,
      scale: scale,
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
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}
