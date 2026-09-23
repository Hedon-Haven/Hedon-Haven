import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '/utils/bundled_plugin.dart';

/// Shared isolate entry-point logic for every bundled plugin. Each plugin's
/// own entry-point function just calls this with its own functions map.
/// Mirrors isolate_js_runtime.dart's setup/message-loop shape.
void runBundledPluginIsolate(
    SendPort mainSendPort, BundledPluginIsolate instance) async {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  bool initialized = false;
  Map<String, Future<dynamic> Function(List args)>? handlers;

  await for (final message in receivePort) {
    if (!initialized) {
      final rootToken = message["rootToken"] as RootIsolateToken;
      final SendPort readyPort = message["readyPort"] as SendPort;
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

      instance.attachPorts(
          message["logPort"] as SendPort, message["fetchPort"] as SendPort);
      handlers = instance.buildFunctionsMap();

      initialized = true;
      readyPort.send(true);
      continue;
    }

    if (message["type"] == "dispose") {
      Isolate.current.kill();
      return;
    }

    _handleCall(message, handlers!);
  }
}

void _handleCall(Map<String, dynamic> message,
    Map<String, Future<dynamic> Function(List args)> handlers) async {
  final SendPort replyPort = message["replyPort"] as SendPort;
  try {
    final String functionName = message["function"] as String;
    final List args = message["args"] as List;

    final handler = handlers[functionName];
    if (handler == null) throw Exception("Unknown function: $functionName");

    replyPort.send({"result": jsonEncode(await handler(args))});
  } catch (e, st) {
    replyPort.send({"error": e.toString(), "stackTrace": st.toString()});
  }
}

typedef HttpResponse = ({
  int statusCode,
  Uint8List bodyBytes,
  String body,
  Map<String, String> headers,
});

/// Performs an http request via the main isolate's client. `body` is decoded
/// as text using the response's own Content-Type charset (same logic
/// package:http's Response.body uses); `bodyBytes` is the raw response.
Future<HttpResponse> httpRequestMainIsolate(SendPort fetchPort, String url,
    {Map<String, String>? headers}) async {
  final responsePort = ReceivePort();
  fetchPort.send({
    "responsePort": responsePort.sendPort,
    "url": url,
    "headers": headers,
  });
  final response = await responsePort.first as Map;
  responsePort.close();

  final statusCode = response["statusCode"] as int;
  final bytes = base64Decode(response["body"] as String);
  final respHeaders = Map<String, String>.from(response["headers"] as Map);
  final decoded = http.Response.bytes(bytes, statusCode, headers: respHeaders);

  return (
    statusCode: statusCode,
    bodyBytes: bytes,
    body: decoded.body,
    headers: respHeaders,
  );
}
