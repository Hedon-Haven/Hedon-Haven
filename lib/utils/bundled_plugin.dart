import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '/bundled_plugins/pornhub.dart';
import '/bundled_plugins/tester.dart';
import '/bundled_plugins/xhamster.dart';
import '/utils/global_vars.dart';
import '/utils/plugin_interface/plugin_interface.dart';
import '/utils/universal_formats.dart';

Future<PluginInterface?> getBundledPluginByName(String codename) async {
  switch (codename) {
    case "com.hedon_haven.tester_internal":
      if (!(await sharedStorage.getBool("general_enable_dev_options"))!) {
        logger.e("Tester plugin requested in non-debug mode");
        throw Exception("Tester plugin requested in non-debug mode");
      }
      return TesterPlugin();
    case "com.hedon_haven.pornhub":
      return PornhubPlugin();
    case "com.hedon_haven.xhamster":
      return XHamsterPlugin();
    default:
      break;
  }
  return null;
}

Future<List<PluginInterface>> getAllBundledPlugins() async {
  if ((await sharedStorage.getBool("general_enable_dev_options"))!) {
    return [TesterPlugin(), PornhubPlugin(), XHamsterPlugin()];
  } else {
    return [PornhubPlugin(), XHamsterPlugin()];
  }
}

/// Base class for bundled plugin isolate implementations.
abstract class BundledPluginIsolate {
  /// Zone key used by [runBundledPluginIsolate] to make a per-call
  /// [List<NetworkTrace>] available to [httpRequest] without threading it
  /// through every function signature.
  static const networkTraceZoneKey = #networkTraceZoneKey;

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

  /// Perform an http request via the main isolate's http client. Every
  /// call is automatically recorded as a [NetworkTrace] and sent back to
  /// the main isolate alongside the function's result
  Future<HttpResponse> httpRequest(String url,
      {Map<String, String>? headers}) async {
    final responsePort = ReceivePort();
    _fetchPort.send({
      "responsePort": responsePort.sendPort,
      "url": url,
      "headers": headers,
    });
    final response = await responsePort.first as Map<String, dynamic>;
    responsePort.close();

    final httpResponse = HttpResponse.fromMap(response);
    (Zone.current[networkTraceZoneKey] as List<NetworkTrace>?)?.add(
      NetworkTrace(
        requestUrl: url,
        requestHeaders: headers,
        statusCode: httpResponse.statusCode,
        replyHeaders: httpResponse.headers,
        bodyBytes: httpResponse.bodyBytes,
      ),
    );

    return httpResponse;
  }

  Future<void> init();

  // Not implemented yet, disabled for now.
  // Future<bool> runFunctionalityTest() async => true;

  Future<ExternalLinkParsed> parseExternalLink(String uriAsString);

  Future<List<UniversalVideoPreview>> getHomePage(int page);

  Future<Uint8List> downloadThumbnail(String uri, Map<String, String>? headers);

  Future<List<String>> getSearchSuggestions(String searchString);

  Future<List<UniversalVideoPreview>> getSearchResults(
      UniversalSearchRequest request, int page);

  Future<String?> getVideoUriFromID(String videoID);

  Future<UniversalVideoMetadata> getVideoMetadata(
      String videoID, UniversalVideoPreview uvp);

  Future<List<Uint8List>?> getProgressThumbnails(
      String videoID, String rawHtml);

  Future<String?> getCommentUriFromID(String commentID, String videoID);

  Future<List<UniversalComment>> getComments(
      String videoID, String rawHtml, int page);

  Future<List<UniversalVideoPreview>> getVideoSuggestions(
      String videoID, String rawHtml, int page);

  Future<String?> getAuthorUriFromID(String authorID);

  Future<UniversalAuthorPage> getAuthorPage(String authorID);

  Future<List<UniversalVideoPreview>> getAuthorVideos(
      String authorID, int page);

  Map<String, Future<dynamic> Function(List args)> buildFunctionsMap() => {
        "init": (args) async => init(),
        // "runFunctionalityTest": (args) async => runFunctionalityTest(),
        "parseExternalLink": (args) => parseExternalLink(args[0] as String),
        "getHomePage": (args) => getHomePage(args[0] as int),
        "downloadThumbnail": (args) => downloadThumbnail(
            args[0] as String, (args[1] as Map?)?.cast<String, String>()),
        "getSearchSuggestions": (args) =>
            getSearchSuggestions(args[0] as String),
        "getSearchResults": (args) => getSearchResults(
            UniversalSearchRequest.fromMap(
                Map<String, dynamic>.from(args[0] as Map)),
            args[1] as int),
        "getVideoUriFromID": (args) => getVideoUriFromID(args[0] as String),
        "getVideoMetadata": (args) => getVideoMetadata(
            args[0] as String,
            UniversalVideoPreview.fromMap(
                Map<String, dynamic>.from(args[1] as Map), null)),
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
