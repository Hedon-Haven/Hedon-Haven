import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:html/dom.dart';
import 'package:yaml/yaml.dart';

import '/utils/global_vars.dart';
import '/utils/plugin_interface/isolate_js_runtime.dart';
import '/utils/universal_formats.dart';

class PluginInterface {
  /// This is overridden to true in bundled plugins
  bool get isBundledPlugin => false;

  /// codeName must be a unique identifier for the plugin, to avoid conflicts.
  /// 3 alphanumeric segments separated by dots, underscores allowed mid-word,
  /// e.g. "com.hedon_haven.tester".
  /// Cannot conflict with bundled plugins
  late String codeName;

  /// prettyName must be the official, correctly cased name of the provider. Cannot be empty
  late String prettyName;

  /// Plugin version
  late String version;

  /// Plugin developer name
  late String developer;

  /// Contact email (e.g. for bug reports)
  late String contactEmail;

  /// Contact email (e.g. for bug reports)
  late String issueTrackerUrl;

  /// Short description (e.g. to mention functionality limitations)
  late String description;

  /// UpdateUri is optional. If provided, it will be used to check for updates.
  Uri? updateUrl;

  /// Icon must point to a small icon of the website, preferably the favicon
  late Uri iconUrl;

  /// Service this plugin scrapes / provides data from
  late String serviceUrl;

  /// URLs that this plugin can handle
  late List<String> handleUrls;

  /// Initial homepage number
  late int initialHomePage;

  /// Initial search page number
  late int initialSearchResultsPage;

  /// Initial comment page number
  late int initialCommentsPage;

  /// Initial video suggestions page number
  late int initialVideoSuggestionsPage;

  /// Initial video suggestions page number
  late int initialAuthorVideosPage;

  // Internal variables

  bool _pluginIsInitialized = false;

  /// The path to the root of the plugin
  final String _pluginPath;

  late Isolate _isolate;
  late SendPort _isolateSendPort;
  Completer<void> _isolateReady = Completer();

  PluginInterface([this._pluginPath = ""]) {
    if (!isBundledPlugin &&
        !_checkAndLoadFromConfig("$_pluginPath/plugin.yaml")) {
      throw Exception(
          "Failed to load from config file: $_pluginPath/plugin.yaml");
    }
  }

  // For the Sets in plugin_manager
  @override
  bool operator ==(Object other) =>
      other is PluginInterface && other.codeName == codeName;

  @override
  int get hashCode => codeName.hashCode;

  static bool codeNameIsValid(String codeName) {
    // Matches exactly 3 alphanumeric segments separated by dots (e.g. "com.hedon_haven.tester").
    // Segments may contain underscores internally, but not at the start or end.
    // Dots are not allowed at the start, end, or consecutively.
    final regex = RegExp(
        r"^(?!.*\.\.)[A-Za-z0-9]([A-Za-z0-9_]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9_]*[A-Za-z0-9])?){2}$");
    return regex.hasMatch(codeName);
  }

  bool _checkAndLoadFromConfig(String configPath) {
    try {
      var config = loadYaml(File(configPath).readAsStringSync());

      if (config["apiVersion"] != 1.0) {
        throw Exception("Unknown / unsupported plugin api version: "
            "${config["apiVersion"]}");
      }

      codeName = config["metadata"]["codeName"];
      prettyName = config["metadata"]["prettyName"];
      version = config["metadata"]["version"];
      developer = config["metadata"]["developer"];
      contactEmail = config["metadata"]["contactEmail"];
      issueTrackerUrl = config["metadata"]["issueTrackerUrl"];
      description = config["metadata"]["description"];
      updateUrl = Uri.parse(config["metadata"]["updateUrl"]);
      iconUrl = Uri.parse(config["providerData"]["iconUrl"]);
      serviceUrl = config["providerData"]["serviceUrl"];
      handleUrls = (config["providerData"]["handleUrls"] as YamlList)
          .map((e) => e as String)
          .toList();
      initialHomePage = config["initialPageCounts"]["initialHomePage"];
      initialSearchResultsPage =
          config["initialPageCounts"]["initialSearchResultsPage"];
      initialCommentsPage = config["initialPageCounts"]["initialCommentsPage"];
      initialVideoSuggestionsPage =
          config["initialPageCounts"]["initialVideoSuggestionsPage"];
      initialAuthorVideosPage =
          config["initialPageCounts"]["initialAuthorVideosPage"];
    } catch (e) {
      logger.e("Error loading configuration: $e");
      return false;
    }
    return true;
  }

  void _consoleLog(Map<String, String> logMessage) {
    final String message = "$codeName: ${logMessage["message"]}";
    switch (logMessage["level"]) {
      case "trace":
        logger.t(message);
      case "debug":
        logger.d(message);
      case "info":
        logger.i(message);
      case "warning":
        logger.w(message);
      case "error":
        logger.e(message);
      case "fatal":
        logger.f(message);
      default:
        logger.w("no log level specified: $message");
    }
  }

  // Perform http requests using the main http client
  void _httpRequest(
      SendPort responseSendPort, Map<String, dynamic> args) async {
    try {
      final response = await client.get(
        Uri.parse(args["url"]),
        headers: (args["headers"] as Map?)?.cast<String, String>(),
      );
      responseSendPort.send(HttpResponse(
        statusCode: response.statusCode,
        bodyBytes: response.bodyBytes,
        body: response.body,
        headers: response.headers,
      ).toMap());
    } catch (e) {
      responseSendPort.send(HttpResponse(
          statusCode: 0,
          body: "",
          bodyBytes: Uint8List(0),
          headers: {}).toMap());
    }
  }

  Future<dynamic> _callFunction(String functionName, List<dynamic> args) async {
    await _isolateReady.future; // blocks until isolate is ready
    final replyPort = ReceivePort();
    _isolateSendPort.send({
      "replyPort": replyPort.sendPort,
      "function": functionName,
      "args": args,
    });
    final response = await replyPort.first as Map<String, dynamic>;
    replyPort.close();
    if (response.containsKey("error")) {
      logger.e("$codeName: ${response["error"].toString()}"
          "\n\n${response["stackTrace"].toString()}");
      throw Exception(response["error"]);
    }
    return response["result"];
  }

  /// Isolate entry point to use. By default uses the JS runtime isolate
  /// Overridden in bundledPlugins to use simpler dart isolates
  void Function(SendPort) get isolateEntryPoint => initJSRuntimeIsolate;

  /// Initialize the plugin isolate and init the plugin
  /// CAREFUL, this function doesn't handle errors!
  Future<void> init(String cachePath,
      [void Function(String body)? debugCallback]) async {
    if (_pluginIsInitialized) {
      return;
    }
    _pluginIsInitialized = true;

    if (!codeNameIsValid(codeName)) {
      throw Exception("Invalid plugin codeName: $codeName");
    }

    final mainPort = ReceivePort();
    final rootToken = RootIsolateToken.instance!;
    _isolate = await Isolate.spawn(isolateEntryPoint, mainPort.sendPort);
    _isolateSendPort = await mainPort.first as SendPort;
    mainPort.close();

    final logPort = ReceivePort();
    final fetchPort = ReceivePort();
    final readyPort = ReceivePort();

    logPort.listen((value) => _consoleLog(Map<String, String>.from(value)));

    fetchPort.listen(
        (message) async => _httpRequest(message["responsePort"], message));

    _isolateSendPort.send({
      if (!isBundledPlugin) "pluginPath": _pluginPath,
      if (!isBundledPlugin) "cachePath": cachePath,
      "rootToken": rootToken,
      "logPort": logPort.sendPort,
      "fetchPort": fetchPort.sendPort,
      "readyPort": readyPort.sendPort,
    });

    // Wait for runtime init in isolate
    await readyPort.first;
    readyPort.close();
    _isolateReady.complete();

    // Some plugins might need to be prepared before they can be used (e.g. fetch cookies)
    await _callFunction("init", []);
  }

  void dispose() {
    if (!_pluginIsInitialized) {
      return;
    }
    logger.d("Disposing $codeName plugin's isolate");
    bool exited = false;
    final exitPort = ReceivePort();
    exitPort.listen((_) {
      exited = true;
      exitPort.close();
    });
    _isolate.addOnExitListener(exitPort.sendPort);

    // Send message to isolate to have it clean up the JS runtime
    _isolateSendPort.send({"type": "dispose"});

    // Force-kill isolate if disposal didn't succeed for any reason
    Future.delayed(const Duration(seconds: 5), () {
      if (exited) {
        logger.d("$codeName plugin's isolate disposed successfully");
        return;
      }
      logger.w("$codeName: isolate did not dispose cleanly, forcing kill");
      _isolate.kill(priority: Isolate.immediate);
    });

    // This is technically set before the isolate force-kill happens, but users
    // might toggle the plugin quicker -> rather have 2 instances for a few
    // seconds than failing to initialize
    _pluginIsInitialized = false;
    _isolateReady = Completer();
  }

  /// Test full plugin functionality and return false if it fails
  //TODO: Set up proper Map<String, dynamic> testResults
  Future<bool> runFunctionalityTest() async {
    try {
      return await _callFunction("runFunctionalityTest", []) as bool;
    } catch (e) {
      logger.i("Functionality test failed with: $e");
      return false;
    }
  }

  /// Parses a raw external link and returns an ExternalLinkParsed
  Future<ExternalLinkParsed> parseExternalLink(Uri uri) async {
    return ExternalLinkParsed.fromMap(
        await _callFunction("parseExternalLink", [uri.toString()]));
  }

  /// Return the homepage
  Future<List<UniversalVideoPreview>> getHomePage(int page,
      [void Function(String body)? debugCallback]) async {
    final results = await _callFunction("getHomePage", [page]) as List;
    List<UniversalVideoPreview> list = [];
    for (final uvp in results) {
      try {
        list.add(UniversalVideoPreview.fromMap(uvp, this));
      } catch (e, st) {
        logger.e("$codeName: Error mapping video: $e$st");
        continue;
      }
    }
    return list;
  }

  /// This function returns the requested thumbnail as a blob
  Future<Uint8List> downloadThumbnail(
      Uri uri, Map<String, String>? thumbnailHttpHeaders) async {
    final result = await _callFunction(
        "downloadThumbnail", [uri.toString(), thumbnailHttpHeaders]);
    return Uint8List.fromList((result as List).cast<int>());
  }

  /// Some websites have custom search results with custom elements (e.g. preview images). Only return simple word based search suggestions
  Future<List<String>> getSearchSuggestions(String searchString,
      [void Function(String body)? debugCallback]) async {
    final result = await _callFunction("getSearchSuggestions", [searchString]);
    return result.cast<String>();
  }

  /// Return list of search results
  Future<List<UniversalVideoPreview>> getSearchResults(
      UniversalSearchRequest sr, int page,
      [void Function(String body)? debugCallback]) async {
    final results =
        await _callFunction("getSearchResults", [sr.toMap(), page]) as List;

    return results
        .map((uvp) => UniversalVideoPreview.fromMap(uvp, this))
        .toList();
  }

  Future<Uri?> getVideoUriFromID(String videoID) async {
    final result = await _callFunction("getVideoUriFromID", [videoID]);
    return Uri.tryParse(result);
  }

  // TODO: Maybe find a better way to pass the uvp or get rid of it entirely?
  Future<UniversalVideoMetadata> getVideoMetadata(
      String videoID, UniversalVideoPreview uvp,
      [void Function(String body)? debugCallback]) async {
    final result =
        await _callFunction("getVideoMetadata", [videoID, uvp.toMap()]);
    return UniversalVideoMetadata.fromMap(result, this);
  }

  /// Get all progressThumbnails for a video and return them as a List
  Future<List<Uint8List>?> getProgressThumbnails(
      String videoID, Document rawHtml) async {
    final result = await _callFunction(
        "getProgressThumbnails", [videoID, rawHtml.outerHtml]) as List?;

    if (result == null) return null;

    return result
        .map((pic) => Uint8List.fromList((pic as List).cast<int>()))
        .toList();
  }

  void cancelGetProgressThumbnails() {
    return;
  }

  Future<Uri?> getCommentUriFromID(String commentID, String videoID) async {
    final result =
        await _callFunction("getCommentUriFromID", [commentID, videoID]);
    return Uri.tryParse(result);
  }

  /// Get comments for a video, per page
  Future<List<UniversalComment>> getComments(
      String videoID, Document rawHtml, int page,
      [void Function(String body)? debugCallback]) async {
    final result =
        await _callFunction("getComments", [videoID, rawHtml.outerHtml, page])
            as List;

    return result.map((uc) => UniversalComment.fromMap(uc, this)).toList();
  }

  /// Get video suggestions for a video, per page
  Future<List<UniversalVideoPreview>> getVideoSuggestions(
      String videoID, Document rawHtml, int page,
      [void Function(String body)? debugCallback]) async {
    final result = await _callFunction(
        "getVideoSuggestions", [videoID, rawHtml.outerHtml, page]) as List;

    return result.map((e) => UniversalVideoPreview.fromMap(e, this)).toList();
  }

  Future<Uri?> getAuthorUriFromID(String authorID) async {
    final result = await _callFunction("getAuthorUriFromID", [authorID]);
    return Uri.tryParse(result);
  }

  /// Request author page and convert it to UniversalFormat
  Future<UniversalAuthorPage> getAuthorPage(String authorID,
      [void Function(String body)? debugCallback]) async {
    final result = await _callFunction("getAuthorPage", [authorID]);

    return UniversalAuthorPage.fromMap(result, this);
  }

  /// Get video suggestions for a video, per page
  Future<List<UniversalVideoPreview>> getAuthorVideos(String authorID, int page,
      [void Function(String body)? debugCallback]) async {
    final result =
        await _callFunction("getAuthorVideos", [authorID, page]) as List;

    return result.map((e) => UniversalVideoPreview.fromMap(e, this)).toList();
  }
}
