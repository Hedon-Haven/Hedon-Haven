import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';

/// Shared isolate entry-point logic for every bundled plugin. Each plugin's
/// own entry-point function just calls this with its own functions map.
/// Mirrors isolate_js_runtime.dart's setup/message-loop shape.
void runBundledPluginIsolate(
  SendPort mainSendPort,
  Map<String, Future<dynamic> Function(List args)> functionsMap, {
  void Function(SendPort logPort, SendPort fetchPort)? onSetup,
}) async {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  bool initialized = false;
  await for (final message in receivePort) {
    if (!initialized) {
      final rootToken = message["rootToken"] as RootIsolateToken;
      final SendPort readyPort = message["readyPort"] as SendPort;
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

      onSetup?.call(
        message["logPort"] as SendPort,
        message["fetchPort"] as SendPort,
      );

      initialized = true;
      readyPort.send(true);
      continue;
    }

    if (message["type"] == "dispose") {
      Isolate.current.kill();
      return;
    }

    _handleCall(message, functionsMap);
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

Future<Uint8List?> requestFetch(
    SendPort fetchPort, String url, Map<String, String>? headers) async {
  final responsePort = ReceivePort();
  fetchPort.send({
    "responsePort": responsePort.sendPort,
    "url": url,
    "headers": headers,
  });
  final response = await responsePort.first as Map;
  responsePort.close();
  return base64Decode(response["body"] as String);
}
