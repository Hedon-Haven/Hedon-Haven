import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '/utils/global_vars.dart';
import '/utils/image_url.dart';

/// Shows [errorWidget], or a red error icon if none is given
class _ErrorFallback extends StatelessWidget {
  final Widget? errorWidget;
  final double? width;
  final double? height;

  const _ErrorFallback({this.errorWidget, this.width, this.height});

  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      height: height,
      child: errorWidget ??
          // Scale with the available space, fall back to the default icon size if unbounded
          LayoutBuilder(
              builder: (context, constraints) => Icon(Icons.error,
                  size: constraints.biggest.shortestSide.isFinite
                      ? constraints.biggest.shortestSide / 4
                      : null,
                  color: Theme.of(context).colorScheme.error)));
}

/// Image.network, but null, empty and mock urls show [errorWidget] without making a request
/// [errorWidget] defaults to a red error icon
class SafeNetworkImage extends StatelessWidget {
  final String? url;
  final Map<String, String>? headers;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.errorWidget,
    this.headers,
    this.fit,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return !isLoadableImageUrl(url)
        ? _ErrorFallback(errorWidget: errorWidget, width: width, height: height)
        : Image.network(url!,
            headers: headers,
            fit: fit,
            width: width,
            height: height, errorBuilder: (context, error, stackTrace) {
            logger.e("Failed to load network image $url: $error\n$stackTrace");
            return _ErrorFallback(
                errorWidget: errorWidget, width: width, height: height);
          });
  }
}

/// Image.memory, but empty bytes show [errorWidget] without trying to decode
/// [errorWidget] defaults to a red error icon
class SafeMemoryImage extends StatelessWidget {
  final Uint8List bytes;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const SafeMemoryImage({
    super.key,
    required this.bytes,
    this.errorWidget,
    this.fit,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return bytes.isEmpty
        ? _ErrorFallback(errorWidget: errorWidget, width: width, height: height)
        : Image.memory(bytes, fit: fit, width: width, height: height,
            errorBuilder: (context, error, stackTrace) {
            logger.e("Failed to load memory image: $error\n$stackTrace");
            return _ErrorFallback(
                errorWidget: errorWidget, width: width, height: height);
          });
  }
}

/// Image.file, but a null file shows [errorWidget]
/// Load failures are not logged, as missing files (e.g. uncached icons) are expected
/// [errorWidget] defaults to a red error icon
class SafeFileImage extends StatelessWidget {
  final File? file;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const SafeFileImage({
    super.key,
    required this.file,
    this.errorWidget,
    this.fit,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return file == null
        ? _ErrorFallback(errorWidget: errorWidget, width: width, height: height)
        : Image.file(file!,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) => _ErrorFallback(
                errorWidget: errorWidget, width: width, height: height));
  }
}
