import 'package:material_ui/material_ui.dart';

import '/utils/global_vars.dart';

/// False for null, empty and mock urls
bool isLoadableImageUrl(String? url) {
  return url != null && url.isNotEmpty && !url.startsWith("mock");
}

/// Image.network, but null, empty and mock urls show [errorWidget] without making a request
class SafeNetworkImage extends StatelessWidget {
  final String? url;
  final Map<String, String>? headers;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget errorWidget;

  const SafeNetworkImage({
    super.key,
    required this.url,
    required this.errorWidget,
    this.headers,
    this.fit,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return !isLoadableImageUrl(url)
        ? SizedBox(width: width, height: height, child: errorWidget)
        : Image.network(url!,
            headers: headers,
            fit: fit,
            width: width,
            height: height, errorBuilder: (context, error, stackTrace) {
            logger.e("Failed to load network image $url: $error\n$stackTrace");
            return SizedBox(width: width, height: height, child: errorWidget);
          });
  }
}
