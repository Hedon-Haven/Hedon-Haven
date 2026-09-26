import 'dart:isolate';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:html/dom.dart';
import 'package:image/image.dart';

import '/utils/bundled_plugin.dart';
import '/utils/plugin_interface/isolate_bundled_runtime.dart';
import '/utils/plugin_interface/plugin_interface.dart';
import '/utils/try_parse.dart';
import '/utils/universal_formats.dart';

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

void initBundledPluginIsolate(SendPort mainSendPort) {
  runBundledPluginIsolate(mainSendPort, _TesterIsolate());
}

class _TesterIsolate extends BundledPluginIsolate {
  @override
  Future<void> init() {
    return Future.value(null);
  }

// To test share/drop any of the following links into the app:
// https://example.com/home?page=3
// https://example.com/search?query=keyword&sortingType=Relevance&page=1
// https://example.com/video?videoId=123
// https://example.com/author?authorId=123
  @override
  Future<ExternalLinkParsed> parseExternalLink(String uriAsString) async {
    Uri uri = Uri.parse(uriAsString);
    switch (uri.path) {
      case "/home":
        return ExternalLinkParsed(
          type: ContentType.homePage,
          pageCount: int.parse(uri.queryParameters["page"] ??
              TesterPlugin().initialHomePage.toString()),
        );

      case "/search":
        final args = uri.queryParameters;
        return ExternalLinkParsed(
            type: ContentType.searchResultsPage,
            searchRequest: UniversalSearchRequest(
              searchString:
                  tryParse(() => Uri.decodeQueryComponent(args["query"]!)),
              sortingType: args["sortingType"],
              dateRange: args["dateRange"],
              minQuality: tryParse(() => int.parse(args["minQuality"]!)),
              maxQuality: tryParse(() => int.parse(args["maxQuality"]!)),
              minDuration: tryParse(() => int.parse(args["minDuration"]!)),
              maxDuration: tryParse(() => int.parse(args["maxDuration"]!)),
              minFramesPerSecond:
                  tryParse(() => int.parse(args["minFramesPerSecond"]!)),
              maxFramesPerSecond:
                  tryParse(() => int.parse(args["maxFramesPerSecond"]!)),
              virtualReality:
                  tryParse(() => bool.parse(args["virtualReality"]!)),
              // categories and keywords not yet fully supported
            ),
            pageCount: tryParse(() => int.parse(args["page"]!)));

      case "/video":
        return ExternalLinkParsed(
          type: ContentType.videoPage,
          iD: uri.queryParameters["videoId"]!,
        );

      case "/author":
        return ExternalLinkParsed(
          type: ContentType.authorPage,
          iD: uri.queryParameters["authorId"]!,
        );

      default:
        return const ExternalLinkParsed(type: ContentType.unknown);
    }
  }

  @override
  Future<List<UniversalVideoPreview>> getHomePage(int page) async {
    // Simulate a delay without blocking the entire isolate
    if (_simulateDelays) await Future.delayed(Duration(seconds: 2));
    return List.generate(
      10,
      (index) => UniversalVideoPreview(
        iD: "${(index * pi * 10000).toInt()}",
        title: "Test homepage video $index, page $page",
        plugin: null,
        thumbnail: "https://placehold.co/1280x720.png",
        thumbnailHttpHeaders: {"X-Ignore": "example-header"},
        previewVideo: Uri.parse(
            "https://docs.evostream.com/sample_content/assets/bunny.mp4"),
        previewVideoHttpHeaders: {"X-Ignore": "example-header"},
        duration: Duration(seconds: 120 + index * 10),
        // seconds
        viewsTotal: (index * pi * 1000000).toInt(),
        ratingsPositivePercent:
            int.tryParse((index * pi * 10000).toStringAsFixed(2)) ?? 50,
        maxQuality: 720,
        virtualReality: false,
        authorName: "Tester-author $index",
        authorID: "Tester-author $index",
        verifiedAuthor: index % 2 == 0,
        // Make every 4th video a fail
        scrapeFailMessage: index % 4 != 0 ? "Test fail scrape message" : null,
      ),
    );
  }

  /// FIXME: Why is this handling and suppressing errors?
  @override
  Future<Uint8List> downloadThumbnail(
      String uriString, Map<String, String>? thumbnailHttpHeaders) async {
    try {
      var response =
          await httpRequest(uriString, headers: thumbnailHttpHeaders);
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        logError("Error downloading preview: ${response.statusCode}");
        return Uint8List(0);
      }
    } catch (e, stacktrace) {
      logError("Error downloading preview: $e\n$stacktrace");
      return Uint8List(0);
    }
  }

  @override
  Future<List<String>> getSearchSuggestions(String searchString) async {
    // Simulate a delay without blocking the entire isolate
    if (_simulateDelays) await Future.delayed(Duration(milliseconds: 200));
    return List.generate(5, (index) => "$searchString-$index");
  }

  @override
  Future<List<UniversalVideoPreview>> getSearchResults(
      UniversalSearchRequest request, int page) async {
    // Simulate a delay without blocking the entire isolate
    if (_simulateDelays) await Future.delayed(Duration(seconds: 2));
    if (page == 5) {
      return [];
    }
    return List.generate(
      10,
      (index) => UniversalVideoPreview(
        iD: "${(index * pi * 10000).toInt()}",
        title: "Test result video $index, page $page, "
            "request ${request.searchString}",
        plugin: null,
        thumbnail: "https://placehold.co/1280x720.png",
        thumbnailHttpHeaders: {"X-Ignore": "example-header"},
        previewVideo: Uri.parse(
            "https://docs.evostream.com/sample_content/assets/bunny.mp4"),
        previewVideoHttpHeaders: {"X-Ignore": "example-header"},
        duration: Duration(seconds: 120 + index * 10),
        viewsTotal: (index * pi * 1000000).toInt(),
        ratingsPositivePercent:
            int.tryParse((index * pi * 10000).toStringAsFixed(2)) ?? 50,
        maxQuality: 720,
        virtualReality: false,
        authorName: "Tester-author $index",
        authorID: "Tester-author $index",
        verifiedAuthor: index % 2 == 0,
        // Make every 4th video a fail
        scrapeFailMessage: index % 4 != 0 ? "Test fail scrape message" : null,
      ),
    );
  }

  @override
  Future<String> getVideoUriFromID(String videoID) async {
    return "https://example.com/$videoID";
  }

  @override
  Future<UniversalVideoMetadata> getVideoMetadata(
      String videoId, UniversalVideoPreview uvp) async {
    // Simulate a delay without blocking the entire isolate
    if (_simulateDelays) await Future.delayed(Duration(seconds: 2));
    return UniversalVideoMetadata(
      iD: videoId,
      m3u8Uris: {
        1080: Uri.parse(
            "https://docs.evostream.com/sample_content/assets/bunny.mp4"),
        720: Uri.parse(
            "https://docs.evostream.com/sample_content/assets/bunny.mp4"),
        480: Uri.parse(
            "https://docs.evostream.com/sample_content/assets/bunny.mp4"),
      },
      title: "Tester video metadata title",
      plugin: null,
      universalVideoPreview: uvp,
      // Uncomment to test partial metadata scrape fail
      //scrapeFailMessage: "Test fail scrape message",
      authorID: "tester-author-$videoId",
      authorName: "Tester-author",
      authorSubscriberCount: 335433,
      authorAvatar: "https://placehold.co/1280x720.png",
      actors: [
        (
          name: "Tester-actor-1",
          authorID: "Tester-author-actor-1",
          avatar: "https://placehold.co/200x200.png"
        ),
        (
          name: "Tester-actor-2",
          authorID: "Tester-author-actor-2",
          avatar: "https://placehold.co/200x200.png"
        )
      ],
      description: "Tester video description" * 10,
      viewsTotal: 2532823,
      tags: ["Tester-tag-1", "Tester-tag-2"],
      categories: ["Tester-category-1", "Tester-category-2"],
      uploadDate: DateTime.now(),
      ratingsPositiveTotal: 90,
      ratingsNegativeTotal: 10,
      ratingsTotal: 47384,
      virtualReality: false,
      chapters: {
        Duration.zero: "Chapter 1",
        Duration(seconds: 120): "Chapter 2",
        Duration(seconds: 240): "Chapter 3",
      },
      rawHtml: Document(),
    );
  }

  @override
  Future<List<Uint8List>?> getProgressThumbnails(
      String videoID, String rawHtmlString) async {
    List<Uint8List> completedProcessedImages = [];

    // Simulate heavy processing
    final end = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(end)) {
      // Burn CPU cycles
      sqrt(DateTime.now().microsecondsSinceEpoch.toDouble());
    }
    logDebug("Heavy processing completed");

    // Request the main thread to fetch the image
    final response = await httpRequest("https://placehold.co/720x480.png");
    Uint8List encodedImage = encodeJpg(decodePng(response.bodyBytes)!);
    for (int i = 0; i < 1000; i++) {
      completedProcessedImages.add(encodedImage);
    }

    return completedProcessedImages;
  }

  @override
  Future<String> getCommentUriFromID(String commentID, String videoID) async {
    return "https://example.com/$videoID/$commentID";
  }

  @override
  Future<List<UniversalComment>> getComments(
      String videoID, String rawHtmlString, int page) async {
    if (page == 5) {
      return [];
    }
    // Simulate a delay without blocking the entire isolate
    if (_simulateDelays) await Future.delayed(Duration(seconds: 2));
    return List.generate(
      5,
      (index) => UniversalComment(
        iD: "comment-$index",
        videoID: videoID,
        author: "author-$index",
        commentBody:
            List<String>.filled(5, "test comment $index, page $page ").join(),
        hidden: index % 4 == 0,
        plugin: null,
        authorID: "author-$index",
        countryID: "US",
        orientation: null,
        profilePicture: "https://placehold.co/240x240.png",
        ratingsPositiveTotal: index % 4 == 0 ? 30 : null,
        ratingsNegativeTotal: index % 4 == 0 ? 2 : null,
        ratingsTotal: index % 4 == 0 ? 32 : 76,
        commentDate: DateTime.now().subtract(Duration(days: index)),
        replyComments: index % 2 == 0
            ? List.generate(
                3,
                (index) => UniversalComment(
                  iD: "comment-reply-$index",
                  videoID: videoID,
                  author: "author-reply-$index",
                  commentBody:
                      List<String>.filled(5, "test reply comment $index ")
                          .join(),
                  hidden: index % 4 == 0,
                  plugin: null,
                  authorID: "author-reply-$index",
                  countryID: "US",
                  orientation: null,
                  profilePicture: "https://placehold.co/240x240",
                  ratingsPositiveTotal: index % 2 == 0 ? 4 : null,
                  ratingsNegativeTotal: index % 2 == 0 ? 1 : null,
                  ratingsTotal: index % 2 == 0 ? 5 : 6,
                  commentDate: DateTime.now().subtract(Duration(days: index)),
                  replyComments: [],
                  // Make every 4th comment a fail
                  scrapeFailMessage:
                      index % 4 != 0 ? "Test fail scrape message" : null,
                ),
              )
            : [],
        // Make every 4th comment a fail
        scrapeFailMessage: index % 4 != 0 ? "Test fail scrape message" : null,
      ),
    );
  }

  @override
  Future<List<UniversalVideoPreview>> getVideoSuggestions(
      String videoID, String rawHtmlString, int page) async {
    // Simulate a delay without blocking the entire app
    if (_simulateDelays) await Future.delayed(Duration(seconds: 2));
    if (page == 5) {
      return [];
    }
    return List.generate(
      10,
      (index) => UniversalVideoPreview(
        iD: "${(index * pi * 10000).toInt()}",
        title: "Test suggestion video $index",
        plugin: null,
        thumbnail: "https://placehold.co/1280x720.png",
        thumbnailHttpHeaders: {"X-Ignore": "example-header"},
        previewVideo: Uri.parse(
            "https://docs.evostream.com/sample_content/assets/bunny.mp4"),
        previewVideoHttpHeaders: {"X-Ignore": "example-header"},
        duration: Duration(seconds: 120 + index * 10),
        viewsTotal: (index * pi * 1000000).toInt(),
        ratingsPositivePercent:
            int.tryParse((index * pi * 10000).toStringAsFixed(2)) ?? 50,
        maxQuality: 720,
        virtualReality: false,
        authorName: "Tester-suggestion-author $index",
        authorID: "Tester-suggestion-author $index",
        verifiedAuthor: index % 2 == 0,
        // Make every 4th video a fail
        scrapeFailMessage: index % 4 != 0 ? "Test fail scrape message" : null,
      ),
    );
  }

  @override
  Future<String> getAuthorUriFromID(String authorID) async {
    return "https://example.com/$authorID";
  }

  @override
  Future<UniversalAuthorPage> getAuthorPage(String authorID) async {
    if (_simulateDelays) await Future.delayed(Duration(seconds: 2));
    return UniversalAuthorPage(
      iD: authorID,
      name: "Test author name",
      plugin: null,
      avatar: "https://placehold.co/240x240.png",
      banner: "https://placehold.co/1270x400.png",
      aliases: ["Test alias 1", "Test alias 2"],
      description: "Very long description" * 1000,
      advancedDescription: {
        for (int i = 1; i <= 1000; i++)
          "Test description key $i": "Test description value $i",
      },
      externalLinks: {
        "external link 1": Uri.parse("https://example.com/link1"),
        "external link 2": Uri.parse("https://example.com/link2"),
        "external link 3": Uri.parse("https://example.com/link3")
      },
      viewsTotal: 23773212,
      videosTotal: 114,
      subscribers: 573529,
      rank: 3746,
      rawHtml: Document(),
    );
  }

  @override
  Future<List<UniversalVideoPreview>> getAuthorVideos(
      String authorID, int page) async {
    if (_simulateDelays) await Future.delayed(Duration(seconds: 2));
    if (page == 5) {
      return [];
    }
    return List.generate(
      10,
      (index) => UniversalVideoPreview(
        iD: "${(index * pi * 10000).toInt()}",
        title: "Test author video $index, page $page",
        plugin: null,
        thumbnail: "https://placehold.co/1280x720.png",
        thumbnailHttpHeaders: {"X-Ignore": "example-header"},
        previewVideo: Uri.parse(
            "https://docs.evostream.com/sample_content/assets/bunny.mp4"),
        previewVideoHttpHeaders: {"X-Ignore": "example-header"},
        duration: Duration(seconds: 120 + index * 10),
        viewsTotal: (index * pi * 1000000).toInt(),
        ratingsPositivePercent:
            int.tryParse((index * pi * 10000).toStringAsFixed(2)) ?? 50,
        maxQuality: 720,
        virtualReality: false,
        authorName: "Tester-author-same $index",
        authorID: "Tester-author-same $index",
        verifiedAuthor: index % 2 == 0,
        // Make every 4th video a fail
        scrapeFailMessage: index % 4 != 0 ? "Test fail scrape message" : null,
      ),
    );
  }
}
