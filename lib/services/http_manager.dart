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

Future<http.Client> getHttpClient(String? proxy) async {
  return RhttpCompatibleClient.create(
    settings: ClientSettings(
      userAgent: httpUserAgent,
      // Don't throw on 4xx or 5xx status codes, the app handles that
      throwOnStatusCode: false,
      proxySettings: (proxy != null && proxy.isNotEmpty)
          ? ProxySettings.proxy("http://192.168.1.11:8080")
          : null,
      tlsSettings: (proxy != null && proxy.isNotEmpty)
          ? const TlsSettings(verifyCertificates: false)
          : null,
      timeoutSettings: const TimeoutSettings(
        connectTimeout: Duration(seconds: 30),
      ),
    ),
    interceptors: [
      SimpleInterceptor(
        beforeRequest: (request) async {
          // Add client hint headers to avoid TLS fingerprinting rejections
          HttpHeaders tempHeaders = request.headers ?? HttpHeaders.rawMap({});
          final originalHeaders = (tempHeaders is HttpHeaderRawMap)
              ? tempHeaders.map
              : <String, String>{};
          // Do not override already existing headers
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
          String? requestId;
          if (response.request.headers is HttpHeaderRawMap) {
            requestId = (response.request.headers as HttpHeaderRawMap)
                .map["x-request-id"];
          }

          logger.t("[HTTP][$requestId] response status: ${response.statusCode};"
              " headers: ${response.headers}");

          return Interceptor.next(response);
        },
      ),
    ],
  );
}
