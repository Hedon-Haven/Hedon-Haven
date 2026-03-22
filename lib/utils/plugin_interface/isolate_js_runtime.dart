import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';

late JavascriptRuntime _runtime;
bool _initialized = false;

void initPluginIsolate(SendPort mainSendPort) async {
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

void _setup(Map<String, dynamic> message) {
  final rootToken = message["rootToken"] as RootIsolateToken;
  final SendPort logPort = message["logPort"] as SendPort;
  final SendPort fetchPort = message["fetchPort"] as SendPort;
  final SendPort readyPort = message["readyPort"] as SendPort;
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

  _runtime = getJavascriptRuntime(xhr: false);
  final jsCode =
      File("${message["pluginPath"] as String}/bundle.js").readAsStringSync();
  _runtime.evaluate(jsCode);

  _runtime.onMessage(
      "consoleLog",
      (dynamic args) => logPort.send({
            "level": args["level"],
            "message": args["message"],
          }));

  _runtime.onMessage("httpRequest", (dynamic args) {
    final responsePort = ReceivePort();
    fetchPort.send({
      "responsePort": responsePort.sendPort,
      "url": args["url"],
      "headers": args["headers"]
    });
    return responsePort.first.then((response) {
      responsePort.close();
      return jsonEncode(response as Map);
    });
  });

  _initialized = true;
  readyPort.send(true);
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
    // Make sure to not await dart future's before sending back to main isolate
    var raw = finalResult.rawResult;
    if (raw is Future) {
      raw = await raw;
    }

    if (finalResult.isError) {
      throw Exception("JS error: ${finalResult.rawResult}");
    }
    replyPort.send({"result": jsonEncode(raw)});
  } catch (e, st) {
    replyPort.send({"error": e.toString(), "stackTrace": st.toString()});
  }
}
