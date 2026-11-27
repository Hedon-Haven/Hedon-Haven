/// False for null, empty and mock urls
bool isLoadableImageUrl(String? url) {
  return url != null && url.isNotEmpty && !url.startsWith("mock");
}
