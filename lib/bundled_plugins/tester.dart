import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/services.dart';

import '/utils/plugin_interface/isolate_bundled_runtime.dart';
import '/utils/plugin_interface/plugin_interface.dart';

class TesterPlugin extends PluginInterface {
  @override
  bool get isBundledPlugin => true;

  @override
  String get codeName => "com.hedon_haven.tester_internal";

  @override
  String get prettyName => "Tester plugin";

  @override
  String get developer => "Hedon Haven";

  @override
  String get contactEmail => "contact@hedon-haven.top";

  @override
  String get issueTrackerUrl => "https://issues.hedon-haven.top";

  @override
  String get description => "Allows quickly testing all plugin-related "
      "functionality of the app without scraping actual websites";

  @override
  Uri get iconUrl => Uri.parse("https://placehold.co/favicon.ico");

  @override
  String get serviceUrl => "https://example.com";

  @override
  List<String> get handleUrls => [
        "https://example.com/home",
        "https://example.com/search",
        "https://example.com/video",
        "https://example.com/author"
      ];

  @override
  int get initialHomePage => 0;

  @override
  int get initialSearchResultsPage => 0;

  @override
  int get initialCommentsPage => 0;

  @override
  int get initialVideoSuggestionsPage => 0;

  @override
  int get initialAuthorVideosPage => 0;

  // The following fields are inherited from PluginInterface, as this plugin is bundled
  @override
  Uri? get updateUrl;

  @override
  String get version => "";

  @override
  void Function(SendPort) get isolateEntryPoint => initBundledPluginIsolate;
}

// For development only: set to true to enable simulated delays for all functions
const bool _simulateDelays = false;

late SendPort _fetchPort;
late SendPort _logPort;

// Set by a "cancelGetProgressThumbnails" call, checked inside the loop
bool _cancelProgressThumbnails = false;

void initBundledPluginIsolate(SendPort mainSendPort) {
  runBundledPluginIsolate(mainSendPort, _functionsMap,
      onSetup: (logPort, fetchPort) {
    _logPort = logPort;
    _fetchPort = fetchPort;
  });
}

final Map<String, Future<dynamic> Function(List args)> _functionsMap = {
  "init": (args) async => true,
  "runFunctionalityTest": (args) async => true,
  "parseExternalLink": (args) async => parseExternalLink(args[0] as String),
  "getHomePage": (args) => getHomePage(args[0] as int),
  "downloadThumbnail": (args) => downloadThumbnail(
      args[0] as String, (args[1] as Map?)?.cast<String, String>()),
  "getSearchSuggestions": (args) => getSearchSuggestions(args[0] as String),
  "getSearchResults": (args) =>
      getSearchResults(args[0] as Map, args[1] as int),
  "getVideoUriFromID": (args) => getVideoUriFromID(args[0] as String),
  "getVideoMetadata": (args) => getVideoMetadata(args[0] as String),
  "getProgressThumbnails": (args) =>
      getProgressThumbnails(args[0] as String, args[1] as String),
  "cancelGetProgressThumbnails": (args) async => cancelGetProgressThumbnails(),
  "getCommentUriFromID": (args) =>
      getCommentUriFromID(args[0] as String, args[1] as String),
  "getComments": (args) =>
      getComments(args[0] as String, args[1] as String, args[2] as int),
  "getVideoSuggestions": (args) =>
      getVideoSuggestions(args[0] as String, args[1] as String, args[2] as int),
  "getAuthorUriFromID": (args) => getAuthorUriFromID(args[0] as String),
  "getAuthorPage": (args) => getAuthorPage(args[0] as String),
  "getAuthorVideos": (args) =>
      getAuthorVideos(args[0] as String, args[1] as int),
};

// To test share/drop any of the following links into the app:
// https://example.com/home?page=3
// https://example.com/search?query=keyword&sortingType=Relevance&page=1
// https://example.com/video?videoId=123
// https://example.com/author?authorId=123
Map<String, dynamic> parseExternalLink(String uriString) {
  final uri = Uri.parse(uriString);
  switch (uri.path) {
    case "/home":
      return {
        "type": "homePage",
        "pageCount": int.parse(uri.queryParameters["page"] ?? "0"),
      };

    case "/search":
      final args = uri.queryParameters;
      return {
        "type": "searchResultsPage",
        "searchRequest": {
          "searchString": Uri.decodeQueryComponent(args["query"] ?? ""),
          "sortingType": args["sortingType"],
          "dateRange": args["dateRange"],
          "minQuality": args["minQuality"],
          "maxQuality": args["maxQuality"],
          "minDuration": args["minDuration"],
          "maxDuration": args["maxDuration"],
          "minFramesPerSecond": args["minFramesPerSecond"],
          "maxFramesPerSecond": args["maxFramesPerSecond"],
          "virtualReality": args["virtualReality"],
          // categories and keywords not yet fully supported
        },
        "pageCount": int.parse(args["page"] ?? "0"),
      };

    case "/video":
      return {
        "type": "videoPage",
        "iD": uri.queryParameters["videoId"],
      };

    case "/author":
      return {
        "type": "authorPage",
        "iD": uri.queryParameters["authorId"],
      };

    default:
      return {"type": "unknown"};
  }
}

Future<List<Map<String, dynamic>>> getHomePage(int page) async {
  // Simulate a delay without blocking the entire isolate
  if (_simulateDelays) await Future.delayed(const Duration(seconds: 2));
  return List.generate(
    10,
    (index) => {
      "iD": "${(index * pi * 10000).toInt()}",
      "title": "Test homepage video $index, page $page",
      "thumbnail": "https://placehold.co/1280x720.png",
      "thumbnailHttpHeaders": {"X-Ignore": "example-header"},
      "previewVideo":
          "https://docs.evostream.com/sample_content/assets/bunny.mp4",
      "previewVideoHttpHeaders": {"X-Ignore": "example-header"},
      "duration": 120 + index * 10, // seconds
      "viewsTotal": (index * pi * 1000000).toInt(),
      "ratingsPositivePercent":
          int.tryParse((index * pi * 10000).toStringAsFixed(2)) ?? 50,
      "maxQuality": 720,
      "virtualReality": false,
      "authorName": "Tester-author $index",
      "authorID": "Tester-author $index",
      "verifiedAuthor": index % 2 == 0,
      // Make every 4th video a fail
      "scrapeFailMessage": index % 4 != 0 ? "Test fail scrape message" : null,
    },
  );
}

Future<String> downloadThumbnail(
    String uriString, Map<String, String>? thumbnailHttpHeaders) async {
  final bytes = await requestFetch(_fetchPort, uriString, thumbnailHttpHeaders);
  return base64Encode(bytes ?? Uint8List(0));
}

Future<List<String>> getSearchSuggestions(String searchString) async {
  // Simulate a delay without blocking the entire isolate
  if (_simulateDelays) await Future.delayed(const Duration(milliseconds: 200));
  return List.generate(5, (index) => "$searchString-$index");
}

Future<List<Map<String, dynamic>>> getSearchResults(
    Map request, int page) async {
  // Simulate a delay without blocking the entire isolate
  if (_simulateDelays) await Future.delayed(const Duration(seconds: 2));
  if (page == 5) return [];
  return List.generate(
    10,
    (index) => {
      "iD": "${(index * pi * 10000).toInt()}",
      "title": "Test result video $index, page $page, "
          "request ${request["searchString"]}",
      "thumbnail": "https://placehold.co/1280x720.png",
      "thumbnailHttpHeaders": {"X-Ignore": "example-header"},
      "previewVideo":
          "https://docs.evostream.com/sample_content/assets/bunny.mp4",
      "previewVideoHttpHeaders": {"X-Ignore": "example-header"},
      "duration": 120 + index * 10,
      "viewsTotal": (index * pi * 1000000).toInt(),
      "ratingsPositivePercent":
          int.tryParse((index * pi * 10000).toStringAsFixed(2)) ?? 50,
      "maxQuality": 720,
      "virtualReality": false,
      "authorName": "Tester-author $index",
      "authorID": "Tester-author $index",
      "verifiedAuthor": index % 2 == 0,
      // Make every 4th video a fail
      "scrapeFailMessage": index % 4 != 0 ? "Test fail scrape message" : null,
    },
  );
}

Future<String> getVideoUriFromID(String videoID) async {
  return "https://example.com/$videoID";
}

Future<Map<String, dynamic>> getVideoMetadata(String videoId) async {
  // Simulate a delay without blocking the entire isolate
  if (_simulateDelays) await Future.delayed(const Duration(seconds: 2));
  const sampleUrl =
      "https://docs.evostream.com/sample_content/assets/bunny.mp4";
  return {
    "iD": videoId,
    "m3u8Uris": {
      "1080": sampleUrl,
      "720": sampleUrl,
      "480": sampleUrl,
    },
    "title": "Tester video metadata title",
    // Change this to test partial metadata scrape fail
    //scrapeFailMessage: "Test fail scrape message",
    "authorID": "tester-author-$videoId",
    "authorName": "Tester-author",
    "authorSubscriberCount": 335433,
    "authorAvatar": "https://placehold.co/1280x720.png",
    "actors": [
      {
        "name": "Tester-actor-1",
        "authorID": "Tester-author-actor-1",
        "avatar": "https://placehold.co/200x200.png",
      },
      {
        "name": "Tester-actor-2",
        "authorID": "Tester-author-actor-2",
        "avatar": "https://placehold.co/200x200.png",
      },
    ],
    "description": "Tester video description" * 10,
    "viewsTotal": 2532823,
    "tags": ["Tester-tag-1", "Tester-tag-2"],
    "categories": ["Tester-category-1", "Tester-category-2"],
    "uploadDate": DateTime.now().millisecondsSinceEpoch ~/ 1000,
    "ratingsPositiveTotal": 90,
    "ratingsNegativeTotal": 10,
    "ratingsTotal": 47384,
    "virtualReality": false,
    "chapters": {
      "0": "Chapter 1",
      "120": "Chapter 2",
      "240": "Chapter 3",
    },
  };
}

Future<List<String>?> getProgressThumbnails(
    String videoID, String rawHtml) async {
  _cancelProgressThumbnails = false;
  List<String> completedProcessedImages = [];

  // Simulate processing, while checking for cancellation flag
  for (int i = 0; i < 30; i++) {
    if (_cancelProgressThumbnails) return null;
    await Future.delayed(const Duration(milliseconds: 100));
  }

  _logPort.send({"level": "debug", "message": "Image processing completed"});

  final imageRaw =
      await requestFetch(_fetchPort, "https://placehold.co/720x480.png", null);
  if (imageRaw == null) return null;
  final encodedImage = base64Encode(imageRaw);
  for (int i = 0; i < 1000; i++) {
    if (_cancelProgressThumbnails) return null;
    completedProcessedImages.add(encodedImage);
  }
  return completedProcessedImages;
}

bool cancelGetProgressThumbnails() {
  _cancelProgressThumbnails = true;
  return true;
}

Future<String> getCommentUriFromID(String commentID, String videoID) async {
  return "https://example.com/$videoID/$commentID";
}

Map<String, dynamic> _buildComment(int index, String videoID, int page,
    {bool withReplies = true}) {
  return {
    "iD": "comment-$index",
    "videoID": videoID,
    "author": "author-$index",
    "commentBody":
        List<String>.filled(5, "test comment $index, page $page ").join(),
    "hidden": index % 4 == 0,
    "authorID": "author-$index",
    "countryID": "US",
    "orientation": null,
    "profilePicture": "https://placehold.co/240x240.png",
    "ratingsPositiveTotal": index % 4 == 0 ? 30 : null,
    "ratingsNegativeTotal": index % 4 == 0 ? 2 : null,
    "ratingsTotal": index % 4 == 0 ? 32 : 76,
    "commentDate": DateTime.now().millisecondsSinceEpoch ~/ 1000,
    "replyComments": withReplies && index % 2 == 0
        ? List.generate(
            3,
            (replyIndex) => {
              "iD": "comment-reply-$replyIndex",
              "videoID": videoID,
              "author": "author-reply-$replyIndex",
              "commentBody":
                  List<String>.filled(5, "test reply comment $replyIndex ")
                      .join(),
              "hidden": replyIndex % 4 == 0,
              "authorID": "author-reply-$replyIndex",
              "countryID": "US",
              "orientation": null,
              "profilePicture": "https://placehold.co/240x240",
              "ratingsPositiveTotal": replyIndex % 2 == 0 ? 4 : null,
              "ratingsNegativeTotal": replyIndex % 2 == 0 ? 1 : null,
              "ratingsTotal": replyIndex % 2 == 0 ? 5 : 6,
              "commentDate": DateTime.now().millisecondsSinceEpoch ~/ 1000,
              "replyComments": [],
              // Make every 4th reply comment a fail
              "scrapeFailMessage":
                  replyIndex % 4 != 0 ? "Test fail scrape message" : null,
            },
          )
        : [],
    // Make every 4th comment a fail
    "scrapeFailMessage": index % 4 != 0 ? "Test fail scrape message" : null,
  };
}

Future<List<Map<String, dynamic>>> getComments(
    String videoID, String rawHtml, int page) async {
  if (page == 5) return [];
  // Simulate a delay without blocking the entire isolate
  if (_simulateDelays) await Future.delayed(const Duration(seconds: 2));
  return List.generate(5, (index) => _buildComment(index, videoID, page));
}

Future<List<Map<String, dynamic>>> getVideoSuggestions(
    String videoID, String rawHtml, int page) async {
  // Simulate a delay without blocking the entire isolate
  if (_simulateDelays) await Future.delayed(const Duration(seconds: 2));
  if (page == 5) return [];
  return List.generate(
    10,
    (index) => {
      "iD": "${(index * pi * 10000).toInt()}",
      "title": "Test suggestion video $index",
      "thumbnail": "https://placehold.co/1280x720.png",
      "thumbnailHttpHeaders": {"X-Ignore": "example-header"},
      "previewVideo":
          "https://docs.evostream.com/sample_content/assets/bunny.mp4",
      "previewVideoHttpHeaders": {"X-Ignore": "example-header"},
      "duration": 120 + index * 10,
      "viewsTotal": (index * pi * 1000000).toInt(),
      "ratingsPositivePercent":
          int.tryParse((index * pi * 10000).toStringAsFixed(2)) ?? 50,
      "maxQuality": 720,
      "virtualReality": false,
      "authorName": "Tester-suggestion-author $index",
      "authorID": "Tester-suggestion-author $index",
      "verifiedAuthor": index % 2 == 0,
      // Make every 4th video a fail
      "scrapeFailMessage": index % 4 != 0 ? "Test fail scrape message" : null,
    },
  );
}

Future<String> getAuthorUriFromID(String authorID) async {
  return "https://example.com/$authorID";
}

Future<Map<String, dynamic>> getAuthorPage(String authorID) async {
  // Simulate a delay without blocking the entire isolate
  if (_simulateDelays) await Future.delayed(const Duration(seconds: 2));
  return {
    "iD": authorID,
    "name": "Test author name",
    "avatar": "https://placehold.co/240x240.png",
    "banner": "https://placehold.co/1270x400.png",
    "aliases": ["Test alias 1", "Test alias 2"],
    "description": "Very long description" * 1000,
    "advancedDescription": {
      for (int i = 1; i <= 1000; i++)
        "Test description key $i": "Test description value $i",
    },
    "externalLinks": {
      "external link 1": "https://example.com/link1",
      "external link 2": "https://example.com/link2",
      "external link 3": "https://example.com/link3",
    },
    "viewsTotal": 23773212,
    "videosTotal": 114,
    "subscribers": 573529,
    "rank": 3746,
  };
}

Future<List<Map<String, dynamic>>> getAuthorVideos(
    String authorID, int page) async {
  // Simulate a delay without blocking the entire isolate
  if (_simulateDelays) await Future.delayed(const Duration(seconds: 2));
  if (page == 5) return [];
  return List.generate(
    10,
    (index) => {
      "iD": "${(index * pi * 10000).toInt()}",
      "title": "Test author video $index, page $page",
      "thumbnail": "https://placehold.co/1280x720.png",
      "thumbnailHttpHeaders": {"X-Ignore": "example-header"},
      "previewVideo":
          "https://docs.evostream.com/sample_content/assets/bunny.mp4",
      "previewVideoHttpHeaders": {"X-Ignore": "example-header"},
      "duration": 120 + index * 10,
      "viewsTotal": (index * pi * 1000000).toInt(),
      "ratingsPositivePercent":
          int.tryParse((index * pi * 10000).toStringAsFixed(2)) ?? 50,
      "maxQuality": 720,
      "virtualReality": false,
      "authorName": "Tester-author-same $index",
      "authorID": "Tester-author-same $index",
      "verifiedAuthor": index % 2 == 0,
      // Make every 4th video a fail
      "scrapeFailMessage": index % 4 != 0 ? "Test fail scrape message" : null,
    },
  );
}
