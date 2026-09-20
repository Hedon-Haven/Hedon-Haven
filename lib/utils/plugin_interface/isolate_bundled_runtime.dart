import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

typedef HttpResponse = ({
  int statusCode,
  Uint8List bodyBytes,
  String body,
  Map<String, String> headers,
});

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

    final result = await handler(args);

    // jsonEncode can't handle int map keys -> stringify only the known int-keyed fields
    if (result is Map && result.containsKey("m3u8Uris")) {
      result["m3u8Uris"] = (result["m3u8Uris"] as Map)
          .map((key, value) => MapEntry(key.toString(), value));
    }
    if (result is Map && result.containsKey("chapters")) {
      result["chapters"] = (result["chapters"] as Map)
          .map((key, value) => MapEntry(key.toString(), value));
    }
    // jsonEncode can't handle Records -> convert actors to plain maps
    if (result is Map && result["actors"] != null) {
      result["actors"] = (result["actors"] as List).map((actor) {
        final record = actor as ({String name, String authorID, String avatar});
        return {
          "name": record.name,
          "authorID": record.authorID,
          "avatar": record.avatar
        };
      }).toList();
    }

    replyPort.send({"result": jsonEncode(result)});
  } catch (e, st) {
    replyPort.send({"error": e.toString(), "stackTrace": st.toString()});
  }
}

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

/// Base class for bundled plugin isolate implementations.
abstract class BundledPluginIsolate {
  late final SendPort _logPort;
  late final SendPort _fetchPort;

  /// Wires up isolate communication ports. Called once during setup.
  void attachPorts(SendPort logPort, SendPort fetchPort) {
    _logPort = logPort;
    _fetchPort = fetchPort;
  }

  void logTrace(String message) => _log("trace", message);

  void logDebug(String message) => _log("debug", message);

  void logInfo(String message) => _log("info", message);

  void logWarning(String message) => _log("warning", message);

  void logError(String message) => _log("error", message);

  void logFatal(String message) => _log("fatal", message);

  void _log(String level, String message) =>
      _logPort.send({"level": level, "message": message});

  /// Perform an http request via the main isolate's client.
  Future<HttpResponse> httpRequest(String url,
          {Map<String, String>? headers}) =>
      httpRequestMainIsolate(_fetchPort, url, headers: headers);

  // Regular functions from PluginIsolate with serializable values
  Future<void> init();

  Future<bool> runFunctionalityTest() async => true;

  Future<Map<String, dynamic>> parseExternalLink(String uriAsString);

  Future<List<Map<String, dynamic>>> getHomePage(int page);

  Future<Uint8List> downloadThumbnail(String uri, Map<String, String>? headers);

  Future<List<String>> getSearchSuggestions(String searchString);

  Future<List<Map<String, dynamic>>> getSearchResults(
      Map<String, dynamic> request, int page);

  Future<String?> getVideoUriFromID(String videoID);

  Future<Map<String, dynamic>> getVideoMetadata(
      String videoID, Map<String, dynamic> uvp);

  Future<List<Uint8List>?> getProgressThumbnails(
      String videoID, String rawHtml);

  Future<String?> getCommentUriFromID(String commentID, String videoID);

  Future<List<Map<String, dynamic>>> getComments(
      String videoID, String rawHtml, int page);

  Future<List<Map<String, dynamic>>> getVideoSuggestions(
      String videoID, String rawHtml, int page);

  Future<String?> getAuthorUriFromID(String authorID);

  Future<Map<String, dynamic>> getAuthorPage(String authorID);

  Future<List<Map<String, dynamic>>> getAuthorVideos(String authorID, int page);

  Map<String, Future<dynamic> Function(List args)> buildFunctionsMap() => {
        "init": (args) async => init(),
        "runFunctionalityTest": (args) async => runFunctionalityTest(),
        "parseExternalLink": (args) => parseExternalLink(args[0] as String),
        "getHomePage": (args) => getHomePage(args[0] as int),
        "downloadThumbnail": (args) => downloadThumbnail(
            args[0] as String, (args[1] as Map?)?.cast<String, String>()),
        "getSearchSuggestions": (args) =>
            getSearchSuggestions(args[0] as String),
        "getSearchResults": (args) => getSearchResults(
            Map<String, dynamic>.from(args[0] as Map), args[1] as int),
        "getVideoUriFromID": (args) => getVideoUriFromID(args[0] as String),
        "getVideoMetadata": (args) => getVideoMetadata(
            args[0] as String, Map<String, dynamic>.from(args[1] as Map)),
        "getProgressThumbnails": (args) =>
            getProgressThumbnails(args[0] as String, args[1] as String),
        "getCommentUriFromID": (args) =>
            getCommentUriFromID(args[0] as String, args[1] as String),
        "getComments": (args) =>
            getComments(args[0] as String, args[1] as String, args[2] as int),
        "getVideoSuggestions": (args) => getVideoSuggestions(
            args[0] as String, args[1] as String, args[2] as int),
        "getAuthorUriFromID": (args) => getAuthorUriFromID(args[0] as String),
        "getAuthorPage": (args) => getAuthorPage(args[0] as String),
        "getAuthorVideos": (args) =>
            getAuthorVideos(args[0] as String, args[1] as int),
      };
}
