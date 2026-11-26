import 'dart:io' show HttpClient, HttpOverrides, SecurityContext;
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:rhttp/rhttp.dart';

import '/utils/global_vars.dart';

final _rand = Random();

String findFastestProxy() {
  throw UnimplementedError();
}

String findRandomProxy() {
  throw UnimplementedError();
}

ClientSettings _getClientSettings(String? proxy) {
  final useProxy = proxy != null && proxy.isNotEmpty;
  return ClientSettings(
    // setting user agent here doesn't work for some reason
    // -> set in the default client hint headers instead
    // Don't throw on 4xx or 5xx status codes, the app handles that
    throwOnStatusCode: false,
    proxySettings:
        useProxy ? ProxySettings.proxy("http://127.0.0.1:8080") : null,
    tlsSettings: useProxy ? const TlsSettings(verifyCertificates: false) : null,
    timeoutSettings: const TimeoutSettings(
      connectTimeout: Duration(seconds: 30),
    ),
  );
}

final _requestInterceptor = SimpleInterceptor(
  beforeRequest: (request) async {
    // Add client hint headers to avoid TLS fingerprinting rejections
    HttpHeaders tempHeaders = request.headers ?? HttpHeaders.rawMap({});
    final originalHeaders =
        _headersToMap(tempHeaders).map((k, v) => MapEntry(k.toLowerCase(), v));
    // Do not override already existing headers (header names are case-insensitive)
    for (final entry in defaultHttpHeaders.entries) {
      if (!originalHeaders.containsKey(entry.key)) {
        tempHeaders =
            tempHeaders.copyWithRaw(name: entry.key, value: entry.value);
      }
    }

    // Add a short unique request ID to the request to print it in the afterResponse
    // This helps correctly match requests and responses in logs
    final requestId = _rand.nextInt(1 << 32).toString();
    tempHeaders =
        tempHeaders.copyWithRaw(name: "x-request-id", value: requestId);

    request = request.copyWith(headers: tempHeaders);

    logger.t("[HTTP][$requestId] type: ${request.method.value};"
        " URI: ${request.url};"
        " headers: ${request.headers}");

    return Interceptor.next(request);
  },
  afterResponse: (response) async {
    final requestId = _headersToMap(response.request.headers)["x-request-id"];

    logger.t("[HTTP][$requestId] response status: ${response.statusCode};"
        " headers: ${response.headers}");

    return Interceptor.next(response);
  },
);

Future<http.Client> getHttpClient(String? proxy) =>
    RhttpCompatibleClient.create(
        settings: _getClientSettings(proxy),
        interceptors: [_requestInterceptor]);

/// Makes every dart:io HttpClient (e.g. Image.network) use rhttp
void overrideDartIoHttpClient(String? proxy) {
  HttpOverrides.global = _RhttpOverrides(IoCompatibleClient.createSync(
    settings: _getClientSettings(proxy),
    interceptors: [_requestInterceptor],
  ));
}

class _RhttpOverrides extends HttpOverrides {
  final HttpClient _client;

  _RhttpOverrides(this._client);

  @override
  HttpClient createHttpClient(SecurityContext? context) => _client;
}

// rhttp passes headers as different types (dart:io requests use a list)
// -> normalize to a lowercase name -> value map
Map<String, String> _headersToMap(HttpHeaders? headers) {
  switch (headers) {
    case null:
      return {};
    case HttpHeaderMap(:final map):
      return {
        for (final entry in map.entries) entry.key.httpName: entry.value,
      };
    case HttpHeaderRawMap(:final map):
      return {
        for (final entry in map.entries) entry.key.toLowerCase(): entry.value,
      };
    case HttpHeaderList(:final list):
      return {
        for (final entry in list) entry.$1.toLowerCase(): entry.$2,
      };
  }
}
