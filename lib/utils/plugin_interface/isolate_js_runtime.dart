import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:path/path.dart' as p;

import '/utils/universal_formats.dart';

late JavascriptRuntime _runtime;
bool _initialized = false;

void initJSRuntimeIsolate(SendPort mainSendPort) async {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  await for (final message in receivePort) {
    if (!_initialized) {
      _setup(message);
      continue;
    }

    if (message["type"] == "dispose") {
      _runtime.dispose();
      Isolate.current.kill();
      return;
    }

    _callFunction(message);
  }
}

void _setup(Map<String, dynamic> initMessage) async {
  final rootToken = initMessage["rootToken"] as RootIsolateToken;
  final SendPort logPort = initMessage["logPort"] as SendPort;
  final SendPort fetchPort = initMessage["fetchPort"] as SendPort;
  final SendPort readyPort = initMessage["readyPort"] as SendPort;
  final String cachePath = initMessage["cachePath"] as String;
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

  // Start javascript runtime and load plugin code
  _runtime = getJavascriptRuntime(xhr: false);
  final jsCode = File("${initMessage["pluginPath"] as String}/bundle.js")
      .readAsStringSync();
  _runtime.evaluate(jsCode);

  // Register "external" functions
  _runtime.onMessage("consoleLog", (args) => _consoleLog(logPort, args));
  _runtime.onMessage("httpRequest",
      (args) async => jsonEncode(await _httpRequest(fetchPort, args)));
  _runtime.onMessage("readCacheFile",
      (msg) async => jsonEncode(_readCacheFile(logPort, cachePath, msg)));
  _runtime.onMessage("writeCacheFile",
      (msg) async => jsonEncode(_writeCacheFile(logPort, cachePath, msg)));

  _initialized = true;
  readyPort.send(true);
}

void _consoleLog(SendPort logPort, dynamic args) {
  logPort.send({
    "level": args["level"],
    "message": args["message"],
  });
}

Future<HttpResponse> _httpRequest(SendPort fetchPort, dynamic args) async {
  final responsePort = ReceivePort();
  fetchPort.send({
    "responsePort": responsePort.sendPort,
    "url": args["url"],
    "headers": args["headers"]
  });
  final response = await responsePort.first as Map<String, dynamic>;
  responsePort.close();
  return HttpResponse.fromMap(response);
}

Map<String, dynamic> _readCacheFile(
    SendPort logPort, String cachePath, dynamic message) {
  final resolved = p.normalize(p.join(cachePath, message["filePath"]));
  if (!resolved.startsWith(cachePath + p.separator)) {
    logPort.send({
      "level": "warning",
      "message": "Failed to read cache file due to invalid path: $resolved",
    });
    return {
      "status": "failure",
      "message": "Invalid path: $resolved",
    };
  }
  try {
    final file = File(resolved);
    return {"status": "success", "message": file.readAsBytesSync().toList()};
  } catch (e, st) {
    logPort.send({
      "level": "error",
      "message": "Failed to read cache file: $e\n$st",
    });
    return {
      "status": "failure",
      "message": "Unknown error: $e",
    };
  }
}

Map<String, dynamic> _writeCacheFile(
    SendPort logPort, String cachePath, Map<String, dynamic> message) {
  final resolved = p.normalize(p.join(cachePath, message["filePath"]));
  if (!resolved.startsWith(cachePath + p.separator)) {
    logPort.send({
      "level": "warning",
      "message": "Failed to write cache file due to invalid path: $resolved",
    });
    return {
      "status": "failure",
      "message": "Invalid path: $resolved",
    };
  }
  try {
    final file = File(resolved);
    file.createSync(recursive: true);
    file.writeAsBytesSync(message["fileContents"]);
  } catch (e, st) {
    logPort.send({
      "level": "error",
      "message": "Failed due to unknown error: $e\n$st",
    });
    return {
      "status": "failure",
      "message": "Unknown error: $e",
    };
  }
  return {
    "status": "success",
    "message": "Contents written to $resolved",
  };
}

void _callFunction(Map<String, dynamic> message) async {
  final SendPort replyPort = message["replyPort"] as SendPort;
  try {
    final String functionName = message["function"] as String;
    final encodedArgs =
        (message["args"] as List).map((a) => jsonEncode(a)).join(", ");

    JsEvalResult jsResult =
        await _runtime.evaluateAsync("$functionName($encodedArgs)");
    _runtime.executePendingJob();

    JsEvalResult finalResult = await _runtime.handlePromise(jsResult);
    // Make sure to await futures before sending back to main isolate
    var raw = finalResult.rawResult;
    if (raw is Future) {
      raw = await raw;
    }

    if (finalResult.isError) {
      throw Exception("JS error: ${finalResult.rawResult}");
    }
    replyPort.send({"result": raw});
  } catch (e, st) {
    replyPort.send({"error": e.toString(), "stackTrace": st.toString()});
  }
}
