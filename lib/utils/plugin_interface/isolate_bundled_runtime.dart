import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';

import '/utils/bundled_plugin.dart';
import '/utils/exceptions.dart';
import '/utils/universal_formats.dart';

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

    _callFunction(message, handlers!);
  }
}

void _callFunction(Map<String, dynamic> message,
    Map<String, Future<dynamic> Function(List args)> handlers) async {
  final SendPort replyPort = message["replyPort"] as SendPort;
  // Created before the handler runs and sent back on both success and
  // failure, so a call that throws partway through still surfaces whatever
  // was downloaded up to that point.
  final List<NetworkTrace> networkTraces = [];
  try {
    final String functionName = message["function"] as String;
    final List args = message["args"] as List;

    final handler = handlers[functionName];
    if (handler == null) throw Exception("Unknown function: $functionName");

    final result = await runZoned(() => handler(args), zoneValues: {
      BundledPluginIsolate.networkTraceZoneKey: networkTraces,
    });

    replyPort.send({
      "result": _serialize(result),
      "networkTraces": _serialize(networkTraces),
    });
  } catch (e, st) {
    replyPort.send({
      "error": convertExceptionToMap(e),
      "stackTrace": st.toString(),
      "networkTraces": _serialize(networkTraces),
    });
  }
}

/// Recursively converts bundled plugins' Universal* objects (and lists of
/// them) to Maps, so results cross the isolate boundary the same way the JS
/// runtime isolate's JSON-based results do.
dynamic _serialize(dynamic value) {
  if (value is Uint8List) return value;
  if (value is List) return value.map(_serialize).toList();
  if (value == null ||
      value is num ||
      value is String ||
      value is bool ||
      value is Map) {
    return value;
  }
  try {
    return value.toMap();
  } on NoSuchMethodError {
    return value;
  }
}
