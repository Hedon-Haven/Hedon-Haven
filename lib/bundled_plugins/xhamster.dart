import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:image/image.dart';

import '/utils/exceptions.dart';
import '/utils/plugin_interface/isolate_bundled_runtime.dart';
import '/utils/plugin_interface/plugin_interface.dart';
import '/utils/try_parse.dart';
import '../services/external_link_manager.dart';

class XHamsterPlugin extends PluginInterface {
  @override
  bool get isBundledPlugin => true;

  @override
  String get codeName => "com.hedon_haven.xhamster";

  @override
  String get prettyName => "xHamster.com";

  @override
  String get developer => "Hedon Haven";

  @override
  String get contactEmail => "contact@hedon-haven.top";

  @override
  String get issueTrackerUrl => "https://issues.hedon-haven.top";

  @override
  String get description => "Full account-less functionality for xHamster.com";

  @override
  Uri get iconUrl => Uri.parse("https://xhamster.com/favicon.ico");

  @override
  String get serviceUrl => "https://xhamster.com";

  @override
  List<String> get handleUrls => [
        "https://xhamster.com",
        "https://xhamster.com/videos/",
        "https://xhamster.com/creators/",
        "https://xhamster.com/channels/",
        "https://xhamster.com/users/"
      ];

  @override
  int get initialHomePage => 1;

  @override
  int get initialSearchResultsPage => 1;

  @override
  int get initialCommentsPage => 1;

  @override
  int get initialVideoSuggestionsPage => 1;

  @override
  int get initialAuthorVideosPage => 1;

  // The following fields are inherited from PluginInterface, as this plugin is bundled
  @override
  Uri? get updateUrl;

  @override
  String get version => "";

  // Set BundledPlugin specific vars
  Map<String, dynamic> testingMap = {
    "ignoreScrapedErrors": {
      "homepage": [
        "authorID",
        "thumbnailHttpHeaders",
        "thumbnailBinary",
        "ratingsPositivePercent",
        "maxQuality",
        "lastWatched",
        "addedOn"
      ],
      "searchResults": [
        "authorID",
        "thumbnailHttpHeaders",
        "thumbnailBinary",
        "ratingsPositivePercent",
        "maxQuality",
        "lastWatched",
        "addedOn"
      ],
      "videoMetadata": ["playbackHttpHeaders", "chapters"],
      "videoSuggestions": [
        "authorID",
        "thumbnailHttpHeaders",
        "thumbnailBinary",
        "ratingsPositivePercent",
        "maxQuality",
        "lastWatched",
        "addedOn"
      ],
      "authorVideos": [
        "thumbnailHttpHeaders",
        "thumbnailBinary",
        "ratingsPositivePercent",
        "maxQuality",
        "authorName",
        "authorID",
        "lastWatched",
        "addedOn"
      ],
      "comments": [
        "ratingsPositiveTotal",
        "ratingsNegativeTotal",
        "countryID",
        "orientation",
        "profilePicture",
        "ratingsTotal"
      ],
      "authorPage": ["banner", "description", "rank", "lastViewed", "addedOn"]
    }
  };

  @override
  void Function(SendPort) get isolateEntryPoint => initBundledPluginIsolate;
}

void initBundledPluginIsolate(SendPort mainSendPort) {
  runBundledPluginIsolate(mainSendPort, _XHamsterIsolate());
}

class _XHamsterIsolate extends BundledPluginIsolate {
// Private vars
  final String _videoEndpoint = "https://xhamster.com/videos/";
  final String _searchEndpoint = "https://xhamster.com/search/";
  final String _creatorEndpoint = "https://xhamster.com/creators/";
  final String _channelEndpoint = "https://xhamster.com/channels/";
  final String _userEndpoint = "https://xhamster.com/users/";
  final Map<String, String> _sortingTypeMap = {
    "Relevance": "relevance",
    "Upload date": "newest",
    "Views": "views",
    "Rating": "best",
    "Duration": "longest"
  };
  final Map<String, String> _dateRangeMap = {
    "All time": "",
    "Last year": "yearly",
    "Last month": "monthly",
    "Last week": "weekly",
    "Last day/Last 3 days/Latest": "latest"
  };
  final Map<int, String> _minDurationMap = {
    0: "",
    300: "5",
    600: "10",
    // xhamster doesn't support 20 min and auto-converts it to 10
    1200: "10",
    1800: "30",
    3600: ""
  };
  final Map<int, String> _maxDurationMap = {
    0: "",
    300: "5",
    600: "10",
    // xhamster doesn't support 20 min and auto-converts it to 10
    1200: "10",
    1800: "30",
    3600: ""
  };

  /// Parse a master m3u8 into media m3u8s
  Future<Map<int, String>> _parseM3U8(String playListUri) async {
    Map<int, String> playListMap = {};
    // download and convert the m3u8 into a string
    var response = await httpRequest(playListUri);
    if (response.statusCode == 200) {
      String contentString = response.body;
      HlsMasterPlaylist? playList = (await HlsPlaylistParser.create()
              .parseString(Uri.parse(playListUri), contentString))
          as HlsMasterPlaylist?;

      // verify the playList is not empty
      if (playList != null) {
        for (var variant in playList.variants) {
          if (variant.format.height != null) {
            playListMap[variant.format.height!] = variant.url.toString();
          } else {
            logError("Error parsing m3u8: $playListUri");
          }
        }
      } else {
        logError("M3U8 is empty: $playListUri");
      }
    } else {
      logError("Error downloading m3u8 master file: ${response.statusCode}");
    }
    return playListMap;
  }

  Future<List<Map<String, dynamic>>> _parseVideoList(
      List<Map<String, dynamic>> resultsList,
      {String? authorNamePassed,
      String? authorIDPassed}) async {
    // convert the divs into UniversalSearchResults
    List<Map<String, dynamic>> results = [];
    for (Map<String, dynamic> element in resultsList) {
      String? iD = element["pageURL"]?.split("-").last;
      String? title = element["title"];

      String authorName = authorNamePassed ??
          (element["landing"]?["name"] ?? "Unknown amateur author");

      Map<String, dynamic> uniResult = {
        // Don't enforce null safety here
        // treat error below in scrapeFailMessage instead
        "iD": iD ?? "null",
        "title": title ?? "null",
        "thumbnail": element["imageURL"],
        "previewVideo": element["trailerURL"],
        "duration": element["duration"],
        "viewsTotal": element["views"],
        "ratingsPositivePercent": null,
        "maxQuality": element["isUHD"] == true ? 2160 : null,
        "virtualReality": false,
        "authorName": authorName,
        "authorID":
            authorIDPassed ?? element["landing"]?["link"]?.split("/")?.last,
        "verifiedAuthor": (element["landing"]?["type"] ?? "user") != "user" &&
            authorName != "Unknown amateur author",
      };

      if (iD == null || title == null) {
        uniResult["scrapeFailMessage"] =
            "Error: Failed to scrape critical variable(s):"
            "${iD == null ? " ID" : ""}"
            "${title == null ? " title" : ""}";
      }

      results.add(uniResult);
    }

    return results;
  }

  @override
  Future<void> init([void Function(String body)? debugCallback]) async {
    // Request main page to check for age gate / banned country
    final response = await httpRequest("https://xhamster.com");
    if (response.statusCode != 200) {
      throw Exception("Failed to initialize plugin. "
          "Received status code ${response.statusCode}");
    }

    debugCallback
        ?.call("Headers: ${response.headers}\n\nBody: ${response.body}");

    // Check for age blocks
    if (parse(response.body).body!.classes.contains("xh-scroll-disabled")) {
      throw AgeGateException();
    }
  }

  @override
  Future<Map<String, dynamic>> parseExternalLink(String uriAsString) async {
    Uri uri = Uri.parse(uriAsString);
    logInfo("Parsing ${uri.path}");
    switch (uri.path) {
      case "/" || "":
        int pageCount = XHamsterPlugin().initialHomePage;
        if (uri.pathSegments.isNotEmpty) {
          pageCount = int.parse(uri.pathSegments.last);
        }
        return {"type": ContentType.homePage, "pageCount": pageCount};

      case var path when path.startsWith('/search/'):
        final args = uri.queryParameters;

        // Reverse-lookup using search Maps
        String sortingType = _sortingTypeMap.entries
            .firstWhere((entry) => entry.value == args["sort"],
                orElse: () => const MapEntry("Relevance", ""))
            .key;
        String dateRange = _dateRangeMap.entries
            .firstWhere((entry) => entry.value == args["date"],
                orElse: () => const MapEntry("All time", ""))
            .key;
        int minDuration = _minDurationMap.entries
            .firstWhere((entry) => entry.value == args["min_duration"],
                orElse: () => const MapEntry(0, ""))
            .key;
        int maxDuration = _maxDurationMap.entries
            .firstWhere((entry) => entry.value == args["max_duration"],
                orElse: () => const MapEntry(3600, ""))
            .key;

        return {
          "type": ContentType.searchResultsPage,
          "searchRequest": {
            "searchString": Uri.decodeQueryComponent(uri.pathSegments.last),
            "sortingType": sortingType,
            "dateRange": dateRange,
            "minQuality": 0,
            // maxQuality not supported
            "minDuration": minDuration,
            "maxDuration": maxDuration,
            "virtualReality": args["format"] != null
          },
          "pageCount": int.parse(args["page"] ??
              XHamsterPlugin().initialSearchResultsPage.toString()),
        };

      case var path when path.startsWith('/videos/'):
        return {
          "type": ContentType.videoPage,
          "iD": uri.pathSegments.last.split("-").last,
        };

      case _
          when {"creators", "channels", "users"}
              .contains(uri.pathSegments.first):
        return {
          "type": ContentType.authorPage,
          "iD": uri.pathSegments.last,
        };

      default:
        return {"type": ContentType.unknown};
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getHomePage(int page,
      [void Function(String body)? debugCallback]) async {
    logDebug("Requesting https://xhamster.com/$page");
    var response = await httpRequest("https://xhamster.com/$page");
    debugCallback?.call(response.body);
    if (response.statusCode != 200) {
      logError("Error downloading html: ${response.statusCode}");
      throw Exception("Error downloading html: ${response.statusCode}");
    }
    Document resultHtml = parse(response.body);
    if (resultHtml.outerHtml == "<html><head></head><body></body></html>") {
      throw Exception("Received empty html");
    }

    String jscript = resultHtml.querySelector('#initials-script')!.text;
    Map<String, dynamic> jscriptMap = jsonDecode(
        jscript.substring(jscript.indexOf("{"), jscript.indexOf('};') + 1));

    return _parseVideoList(jscriptMap["layoutPage"]["videoListProps"]
            ["videoThumbProps"]
        .cast<Map<String, dynamic>>());
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
  Future<List<String>> getSearchSuggestions(String searchString,
      [void Function(String body)? debugCallback]) async {
    List<String> parsedMap = [];
    var response = await httpRequest(
        "https://xhamster.com/api/front/search/suggest?searchValue=$searchString",
        // If either of these headers is missing, the server throws a 403 for some reason
        headers: {"x-csrf-token": "1", "Cookie": "x_csrf_token=1"});
    debugCallback?.call(response.body);
    if (response.statusCode == 200) {
      for (var item in jsonDecode(response.body).cast<Map>()) {
        if (item["type2"] == "search") {
          parsedMap.add(item["plainText"]);
        }
      }
    } else {
      throw Exception("Error downloading json list: ${response.statusCode}");
    }
    return parsedMap;
  }

  Future<List<Map<String, dynamic>>> getSearchResults2(
      Map request, int page) async {
    // @formatter:off
    String urlString = "$_searchEndpoint${Uri.encodeComponent(request["searchString"])}"
        "?page=$page"
        "&sort=${_sortingTypeMap[request["sortingType"]]!}"
        "${request["dateRange"] != "All time" ? "&date=${_dateRangeMap[request["dateRange"]]}": ""}"
        "${[720, 1080, 2160].contains(request["minQuality"]) ? "&quality=${request["minQuality"]}p" : ""}"
    // no max quality filter
        "${[0, 3600].contains(request["minDuration"]) ? "" : "&min_duration=${_minDurationMap[request["minDuration"]]!}"}"
        "${[0, 3600].contains(request["maxDuration"]) ? "" : "&max_duration=${_maxDurationMap[request["maxDuration"]]!}"}"
        "${(request["minFramesPerSecond"] ?? 0) > 0 ? "&fps=${request["minFramesPerSecond"]}" : ""}"
    // no min FPS filter
        "${request["virtualReality"] == true ? "&format=vr" : ""}"
    // Categories and keywords not yet implemented
        ;
    // @formatter:on
    logDebug("Requesting $urlString");
    final response = await httpRequest(urlString);
    Document resultHtml = parse(response.body);
    String jscript = resultHtml.querySelector('#initials-script')!.text;
    Map<String, dynamic> jscriptMap = jsonDecode(
        jscript.substring(jscript.indexOf("{"), jscript.indexOf('};') + 1));
    return _parseVideoList(jscriptMap["searchResult"]["videoThumbProps"]
        .cast<Map<String, dynamic>>());
  }

  @override
  Future<List<Map<String, dynamic>>> getSearchResults(
      Map<String, dynamic> request, int page,
      [void Function(String body)? debugCallback]) async {
    // @formatter:off
    String urlString = "$_searchEndpoint${Uri.encodeComponent(request["searchString"])}"
        "?page=$page"
        "&sort=${_sortingTypeMap[request["sortingType"]]!}"
        "${request["dateRange"] != "All time" ? "&date=${_dateRangeMap[request["dateRange"]]}": ""}"
        "${[720, 1080, 2160].contains(request["minQuality"]) ? "&quality=${request["minQuality"]}p" : ""}"
    // no max quality filter
        "${[0, 3600].contains(request["minDuration"]) ? "" : "&min_duration=${_minDurationMap[request["minDuration"]]!}"}"
        "${[0, 3600].contains(request["maxDuration"]) ? "" : "&max_duration=${_maxDurationMap[request["maxDuration"]]!}"}"
        "${request["minFramesPerSecond"] > 0 ? "&fps=${request["minFramesPerSecond"]}" : ""}"
    // no min FPS filter
        "${request["virtualReality"] ? "&format=vr" : ""}"
    // Categories and keywords not yet implemented
        ;
    // @formatter:on

    logDebug("Requesting $urlString");
    var response = await httpRequest(urlString);
    debugCallback?.call(response.body);
    if (response.statusCode != 200) {
      logError("Error downloading html: ${response.statusCode}");
      throw Exception("Error downloading html: ${response.statusCode}");
    }
    Document resultHtml = parse(response.body);

    String jscript = resultHtml.querySelector('#initials-script')!.text;
    Map<String, dynamic> jscriptMap = jsonDecode(
        jscript.substring(jscript.indexOf("{"), jscript.indexOf('};') + 1));

    return _parseVideoList(jscriptMap["searchResult"]["videoThumbProps"]
        .cast<Map<String, dynamic>>());
  }

  @override
  Future<String> getVideoUriFromID(String videoID) async {
    return _videoEndpoint + videoID;
  }

  @override
  Future<Map<String, dynamic>> getVideoMetadata(
      String videoId, Map<String, dynamic> uvp,
      [void Function(String body)? debugCallback]) async {
    logDebug("Requesting ${_videoEndpoint + videoId}");
    var response = await httpRequest("$_videoEndpoint$videoId");
    debugCallback?.call(response.body);
    if (response.statusCode != 200) {
      logError("Error downloading html: ${response.statusCode}");
      throw Exception("Error downloading html: ${response.statusCode}");
    }

    Document rawHtml = parse(response.body);
    String jscript = rawHtml.querySelector('#initials-script')!.text;
    Map<String, dynamic> jscriptMap = jsonDecode(
        jscript.substring(jscript.indexOf("{"), jscript.indexOf('};') + 1));

    // ratings
    int? ratingsPositive =
        jscriptMap["ratingComponent"]?["ratingModel"]?["likes"];
    int? ratingsNegative =
        jscriptMap["ratingComponent"]?["ratingModel"]?["dislikes"];
    int? ratingsTotal;
    if (ratingsPositive != null && ratingsNegative != null) {
      ratingsTotal = ratingsPositive + ratingsNegative;
    }

    // Extract tags, categories and actors from jscriptMap
    List<String>? tags = [];
    List<String>? categories = [];
    List<({String name, String authorID, String avatar})>? actors;
    try {
      for (Map<String, dynamic> element
          in jscriptMap["videoTagsComponent"]!["tags"]!) {
        if (element["isCategory"]!) {
          categories.add(element["name"]!);
        } else if (element["isPornstar"]!) {
          try {
            actors ??= [];
            actors.add((
              name: element["name"],
              authorID: element["slug"],
              avatar: element["thumbUrl"]
            ));
          } catch (e, st) {
            logWarning("Failed to parse actor: $e\n$st");
          }
        } else if (element["isTag"]!) {
          tags.add(element["name"]!);
        } else {
          logDebug("Skipping element: ${element["name"]!}");
        }
      }
    } catch (e, stacktrace) {
      logWarning("Failed to parse actors/tags/categories (but continuing "
          "anyway): $e\n$stacktrace");
    }

    // Use the tooltip as video upload date
    DateTime? date;
    String? dateString = rawHtml
        .querySelector(
            'div[class="entity-info-container__date tooltip-nocache"]')
        ?.attributes["data-tooltip"]!;
    // 2022-05-06 12:33:41 UTC
    if (dateString != null) {
      // Convert to a format that DateTime can read
      // Convert to 20120227T132700 format
      dateString = dateString
          .replaceAll("-", "")
          .replaceFirst(" ", "T")
          .replaceAll(":", "")
          .replaceAll(" UTC", "");
      date = DateTime.tryParse(dateString);
    }

    // convert master m3u8 to list of media m3u8
    // TODO: Maybe check if the m3u8 is a master m3u8
    var videoM3u8 = rawHtml.querySelector(
        'link[rel="preload"][href*=".m3u8"][as="fetch"][crossorigin]');
    Map<int, String> m3u8Map = await _parseM3U8(videoM3u8!.attributes["href"]!);

    String? authorID;
    String? authorName;
    int? authorSubscriberCount;
    String? authorAvatar;
    if (jscriptMap["xplayerPluginSettings"]?["subscribe"]?["link"] != null) {
      authorID = jscriptMap["xplayerPluginSettings"]!["subscribe"]!["link"]!
          .replaceAll("/videos", "")!
          .split("/")!
          .last;
      authorName = jscriptMap["xplayerPluginSettings"]?["subscribe"]?["title"];
      authorSubscriberCount =
          jscriptMap["xplayerPluginSettings"]?["subscribe"]?["subscribers"];
      authorAvatar = jscriptMap["xplayerPluginSettings"]?["subscribe"]?["logo"];
    } else {
      authorID = jscriptMap["videoModel"]?["author"]?["pageURL"]
          ?.replaceAll("/videos", "")!
          .split("/")!
          .last;
      authorName = jscriptMap["videoModel"]?["author"]?["name"];
      authorSubscriberCount = jscriptMap["videoTagsComponent"]
          ?["subscriptionModel"]?["subscribers"];
      authorAvatar = jscriptMap["videoTagsComponent"]?["tags"]?[0]?["thumbUrl"];
    }

    String? description = jscriptMap["videoModel"]?["description"] == ""
        ? null
        : jscriptMap["videoModel"]?["description"];

    return {
      "iD": videoId,
      "m3u8Uris": m3u8Map,
      "title": jscriptMap["videoModel"]!["title"]!,
      "universalVideoPreview": uvp,
      "authorID": authorID!,
      "authorName": authorName,
      "authorSubscriberCount": authorSubscriberCount,
      "authorAvatar": authorAvatar,
      "actors": actors,
      "description": description,
      "viewsTotal": jscriptMap["videoTitle"]?["views"],
      "tags": tags,
      "categories": categories,
      "uploadDate": tryParse(() => date!.millisecondsSinceEpoch ~/ 1000),
      "ratingsPositiveTotal": ratingsPositive,
      "ratingsNegativeTotal": ratingsNegative,
      "ratingsTotal": ratingsTotal,
      "virtualReality": jscriptMap["videoModel"]?["isVR"],
      "chapters": null,
      "rawHtml": rawHtml.outerHtml
    };
  }

  @override
  Future<List<Uint8List>?> getProgressThumbnails(
      String videoID, String rawHtmlString) async {
    final rawHtml = parse(rawHtmlString);

    try {
      // Get the video json
      String jscript = rawHtml.querySelector('#initials-script')!.text;
      Map<String, dynamic> jscriptMap = jsonDecode(
          jscript.substring(jscript.indexOf("{"), jscript.indexOf('};') + 1));

      String imageBuildUrl =
          jscriptMap["xplayerPluginSettings"]["spriteLoader"]["template"];

      logDebug(imageBuildUrl);

      // Extract the video duration
      int duration = jscriptMap["xplayerSettings"]["duration"];

      // Extract the width of the individual preview image from the baseUrl
      String imageWidthString = imageBuildUrl.split("/").last.split(".")[0];
      // New format has the width only, old format has width x height
      int imageWidth = int.parse(imageWidthString.contains("x")
          ? imageWidthString.split("x").first
          : imageWidthString);

      // Assume old format
      String suffix = "";
      String baseUrl = imageBuildUrl;
      // Old format has 50 preview thumbnails for the entire video
      int samplingFrequency = (duration / 50).floor();
      // only one combined image in old format
      int lastImageIndex = 0;
      bool isOldFormat = true;

      // determine kind of preview images
      logDebug("Checking whether video uses new preview format");
      if (imageBuildUrl.endsWith("%d.webp")) {
        isOldFormat = false;
        suffix = ".${imageBuildUrl.split(".").last}";
        logDebug("suffix $suffix");
        baseUrl = imageBuildUrl.split("%d").first;
        logDebug("baseUrl: $baseUrl");
        // from limited testing it seems as if the sampling frequency is always 4 in the new format, but have this just in case
        // Although usually the sampling frequency is not 4.0, but rather something like 4.003
        // For some reason xhamster just ignores that and uses a whole number resulting in drift at the end in long videos.
        samplingFrequency =
            int.parse(imageBuildUrl.split("/").last.split(".")[1]);
        // Each combined image contains 50 images
        lastImageIndex = duration ~/ samplingFrequency ~/ 50;
      }
      logDebug("Is old format: $isOldFormat");
      logDebug("Sampling frequency: $samplingFrequency");
      logDebug("lastImageIndex: $lastImageIndex");

      logInfo("Downloading and processing progress images");
      List<List<Uint8List>> allThumbnails =
          List.generate(lastImageIndex + 1, (_) => []);
      List<Future<void>> imageFutures = [];

      for (int i = 0; i <= lastImageIndex; i++) {
        // Create a future for downloading and processing
        imageFutures.add(Future(() async {
          String url = isOldFormat ? baseUrl : "$baseUrl$i$suffix";
          logDebug("Requesting download for $url");

          final response = await httpRequest(url);
          Uint8List image = response.bodyBytes;

          final decodedImage = decodeImage(image)!;
          List<Uint8List> thumbnails = [];
          for (int w = 0; w < decodedImage.width; w += imageWidth) {
            // XHamster has a set amount of thumbnails (usually multiples of 50) for the whole video.
            // every progress image is for samplingFrequency (usually 4) seconds -> store the same image samplingFrequency times
            // To avoid overfilling the ram, create a temporary variable and store it in the list multiple times
            // As Lists contain references to data and not the data itself, this should reduce ram usage
            Uint8List firstThumbnail = Uint8List(0);
            for (int j = 0; j < samplingFrequency; j++) {
              if (j == 0) {
                // Only encode and add the first image once
                firstThumbnail = encodeJpg(copyCrop(decodedImage,
                    x: w,
                    y: 0,
                    width: imageWidth,
                    height: decodedImage.height));
                thumbnails.add(firstThumbnail); // Add the first encoded image
              } else {
                // Reuse the reference to the first thumbnail
                thumbnails.add(firstThumbnail);
              }
            }
          }
          allThumbnails[i] = thumbnails;
        }));
      }
      // Await all futures
      await Future.wait(imageFutures);

      // Combine all results into single, chronological list
      List<Uint8List> completedProcessedImages =
          allThumbnails.expand((x) => x).toList();

      // Add 55 seconds more of the last thumbnail
      // This is done as the sampling frequency is floored. 0.99*50 = 49.5, means in theory we could be off by 50 seconds
      Uint8List lastImage = completedProcessedImages.last;
      for (int j = 0; j < 55; j++) {
        completedProcessedImages.add(lastImage);
      }

      logInfo("Completed processing all images");
      logDebug(
          "Total memory consumption apprx: ${completedProcessedImages[0].lengthInBytes * completedProcessedImages.length / 1024 / 1024} mb");
      // return the completed processed images through the separate resultsPort
      logDebug(
          "Sending ${completedProcessedImages.length} progress images to main process");
      return completedProcessedImages;
    } catch (e, stackTrace) {
      logError("Error in getProgressThumbnails: $e\n$stackTrace");
      return null;
    }
  }

  @override
  Future<String> getCommentUriFromID(String commentID, String videoID) async {
    // Pornhub doesn't have comment links
    return "$_videoEndpoint/$videoID#comment-$commentID";
  }

  @override
  Future<List<Map<String, dynamic>>> getComments(
      String videoID, String rawHtmlString, int page,
      [void Function(String body)? debugCallback]) async {
    Document rawHtml = parse(rawHtmlString);
    List<Map<String, dynamic>> commentList = [];

    // find the video's entity-id in the json inside the html
    String jscript = rawHtml.querySelector("#initials-script")!.text;
    Map<String, dynamic> jscriptMap = jsonDecode(
        jscript.substring(jscript.indexOf("{"), jscript.indexOf('};') + 1));

    // use the entity id from the comment section specifically
    // Its usually an integer -> convert it to a string, just in case
    String entityID = jscriptMap["commentsComponent"]["commentsList"]["target"]
            ["id"]
        .toString();
    logDebug("Video comment entity ID: $entityID");

    String commentUri = 'https://xhamster.com/x-api?r='
        '[{"name":"entityCommentCollectionFetch",'
        '"requestData":{"page":$page,"entity":{"entityModel":"videoModel","entityID":$entityID}}}]';
    logDebug("Comment URI (page: $page): $commentUri");
    final response = await httpRequest(
      commentUri,
      // For some reason this header is required, otherwise the request 404s.
      headers: {
        "X-Requested-With": "XMLHttpRequest",
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Error downloading json: ${response.statusCode}");
    }
    debugCallback?.call(response.body);
    final commentsJson = jsonDecode(response.body)[0]["responseData"];
    if (commentsJson == null) {
      logWarning("No comments found for $videoID");
      return [];
    }

    for (var comment in commentsJson) {
      String? iD = comment["id"];
      String? author = comment["author"]?["name"];
      String? commentBody;
      if (comment["text"] != null) {
        commentBody = HtmlUnescape().convert(comment["text"]!).trim();
      }

      Map<String, dynamic> uniComment = {
        // Don't enforce null safety here
        // treat error below in scrapeFailMessage instead
        "iD": iD ?? "null",
        "videoID": videoID,
        "author": author ?? "null",
        // The comment body includes html chars like &amp and &nbsp, which need to be cleaned up
        "commentBody": commentBody ?? "null",
        "hidden": false,
        "authorID": comment["userId"]?.toString(),
        "countryID": comment["author"]?["personalInfo"]?["geo"]?["countryCode"],
        "orientation": comment["author"]?["personalInfo"]?["orientation"]
            ?["name"],
        "profilePicture": comment["author"]?["thumbUrl"],
        "ratingsPositiveTotal": null,
        "ratingsNegativeTotal": null,
        // null in the json means 0
        "ratingsTotal": comment["likes"] ?? 0,
        "commentDate": tryParse(() =>
            DateTime.fromMillisecondsSinceEpoch(comment["created"] * 1000)),
        "replyComments": [],
      };

      if (iD == null || author == null || commentBody == null) {
        uniComment["scrapeFailMessage"] =
            "Error: Failed to scrape critical variable(s):"
            "${iD == null ? " iD" : ""}"
            "${author == null ? " author" : ""}"
            "${commentBody == null ? " commentBody" : ""}";
      }

      commentList.add(uniComment);
    }

    if (commentList.length != commentsJson.length) {
      logWarning(
          "${commentsJson.length - commentList.length} comments failed to parse.");
      if (commentList.length < commentsJson.length * 0.5) {
        throw Exception("More than 50% of the results failed to parse.");
      }
    }

    return commentList;
  }

  @override
  Future<List<Map<String, dynamic>>> getVideoSuggestions(
      String videoID, String rawHtmlString, int page,
      [void Function(String body)? debugCallback]) async {
    Document rawHtml = parse(rawHtmlString);

    // find the video's relatedID in the json inside the html
    String jscript = rawHtml.querySelector("#initials-script")!.text;
    // use the relatedID from the related videos section specifically
    int startIndex =
        jscript.indexOf('"relatedVideosComponent":{"videoId":') + 36;
    int endIndex = jscript.substring(startIndex).indexOf(',');
    String relatedID = jscript.substring(startIndex, startIndex + endIndex);
    logDebug("Video relatedID: $relatedID");

    // API returns error if no parameters are passed,
    // but doesn't actually care which parameters are passed...
    String suggestionsUri = "https://xhamster.com/api/front/video/"
        "related?videoId=$relatedID&page=$page&params={%22none%22:{}}";
    logDebug("Parsed URI: $suggestionsUri");
    final response = await httpRequest(suggestionsUri);
    if (response.statusCode != 200) {
      throw Exception("Failed to get suggestions: ${response.statusCode}");
    }
    debugCallback?.call(response.body);

    List<Map<String, dynamic>> relatedVideos = [];
    for (var result in jsonDecode(response.body)["videoThumbProps"]) {
      String? title = tryParse(() => result["title"]);

      Map<String, dynamic> relatedVideo = {
        // Don't enforce null safety here
        // treat error below in scrapeFailMessage instead
        "iD":
            tryParse(() => result["pageURL"].trim().split("/").last) ?? "null",
        "title": title ?? "null",
        "thumbnail": result["thumbURL"],
        "previewVideo": result["trailerURL"],
        "duration": result["duration"],
        "viewsTotal": result["views"],
        "ratingsPositivePercent": null,
        "maxQuality":
            tryParse<int?>(() => result["isUHD"] != null ? 2160 : null),
        "virtualReality": null,
        "authorName": result["landing"]?["name"] ?? "Unknown amateur author",
        "authorID": result["landing"]?["link"]
            ?.replaceAll("/videos", "")
            ?.split("/")
            ?.last,
        "verifiedAuthor": result["landing"]?["name"] != null,
      };

      if (title == null) {
        relatedVideo["scrapeFailMessage"] =
            "Error: Failed to scrape critical variable: title";
      }

      relatedVideos.add(relatedVideo);
    }
    return relatedVideos;
  }

  /// FIXME: Use .head() instead of .get() for quicker processing
  @override
  Future<String?> getAuthorUriFromID(String authorID) async {
    logInfo("Getting author page URL of: $authorID");

    // Assume every author is a channel at first
    String authorPageLink = "$_channelEndpoint$authorID";

    logDebug("Checking http status of: $authorPageLink");
    var response = await httpRequest(authorPageLink);
    if (response.statusCode != 200) {
      // Try again for creator author type
      authorPageLink = "$_creatorEndpoint$authorID";

      logDebug(
          "Received non 200 status code -> Requesting creator page: $authorPageLink");
      response = await httpRequest(authorPageLink);

      if (response.statusCode != 200) {
        // Try again for user author type
        authorPageLink = "$_userEndpoint$authorID";
        logDebug(
            "Received non 200 status code -> Requesting user page: $authorPageLink");
        response = await httpRequest(authorPageLink);
        if (response.statusCode != 200) {
          logError(
              "Error downloading html (tried channel, creator, user): ${response.statusCode}");
          throw Exception(
              "Error downloading html (tried channel, creator, user): ${response.statusCode}");
        }
      }
    }
    return authorPageLink;
  }

  @override
  Future<Map<String, dynamic>> getAuthorPage(String authorID,
      [void Function(String body)? debugCallback]) async {
    // Assume every author is a channel at first
    String authorPageLink = "$_channelEndpoint$authorID";
    logDebug("Requesting channel page: $authorPageLink");
    var response = await httpRequest(authorPageLink);
    if (response.statusCode != 200) {
      // Try again for creator author type
      authorPageLink = "$_creatorEndpoint$authorID";
      logDebug(
          "Received non 200 status code -> Requesting creator page: $authorPageLink");
      response = await httpRequest(authorPageLink);

      if (response.statusCode != 200) {
        // Try again for user author type
        authorPageLink = "$_userEndpoint$authorID";
        logDebug(
            "Received non 200 status code -> Requesting user page: $authorPageLink");
        response = await httpRequest(authorPageLink);

        if (response.statusCode != 200) {
          logError(
              "Error downloading html (tried channel, creator, user): ${response.statusCode}");
          throw Exception(
              "Error downloading html (tried channel, creator, user): ${response.statusCode}");
        }
      }
    }

    debugCallback?.call(response.body);
    Document pageHtml = parse(response.body);
    String jscript = pageHtml.querySelector('#initials-script')!.text;
    Map<String, dynamic> jscriptMap = jsonDecode(
        jscript.substring(jscript.indexOf("{"), jscript.indexOf('};') + 1));

    // Check if the profile is private
    if ((pageHtml.querySelector(".status-text")?.text ?? "") ==
        "This profile is visible to friends only") {
      throw PrivateAuthorProfileException();
    }

    // normal description
    String? shortDescription;
    if (jscriptMap["aboutMeComponent"]?["text"] != null) {
      shortDescription = jscriptMap["aboutMeComponent"]["text"].trim();
      shortDescription = HtmlUnescape().convert(shortDescription!);
      shortDescription = shortDescription
          .replaceAll("<br\\/>", "\n")
          .replaceAll("<br/>", "\n");
    }

    Map<String, String>? externalLinks;
    Map<String, String>? advancedDescription;
    try {
      Map<dynamic, dynamic>? infoMap = jscriptMap["infoComponent"]
              ?["displayUserModel"]?["personalInfo"] ??
          jscriptMap["displayUserModel"]?["personalInfo"];
      if (infoMap != null) {
        advancedDescription = {};
        infoMap.forEach((key, item) {
          if (item == null) {
            return;
          }
          switch (key) {
            case "gender":
            case "orientation":
            case "ethnicity":
            case "body":
            case "hairLength":
            case "hairColor":
            case "eyeColor":
            case "relations":
            case "kids":
            case "education":
            case "religion":
            case "smoking":
            case "alcohol":
            case "star_sign":
            case "income":
            case "seekingOrientation":
            case "seekingGender":
              advancedDescription![key] = item["label"];
              break;
            case "allLanguages":
              advancedDescription![key] = item.join(", ");
              break;
            case "height":
              advancedDescription![key] =
                  "${item["cm"]}cm (${item["feet"]}ft ${item["in"] == null ? "" : "${item["in"]}in"})";
              break;
            case "social":
              externalLinks ??= {};
              if (item.isNotEmpty) {
                item.forEach((key, value) {
                  if (key == "fapHouseMirror") {
                    externalLinks!["FapHouse"] = value["urlLanding"];
                  } else {
                    externalLinks![key[0].toUpperCase() + key.substring(1)] =
                        value;
                  }
                });
              }
              break;
            case "website":
              externalLinks ??= {};
              externalLinks!["website"] = item["URL"];
              break;
            case "geo":
              advancedDescription ??= {};
              advancedDescription!["country"] = "${item["countryName"]}"
                  "${item?["region"]?["label"] != null ? ", ${item["region"]["label"]}" : ""}";
              break;
            // These are not shown in the xhamster UI or are irrelevant/obsolete
            case "birthday":
            case "score":
            case "modelName":
            case "userID":
            case "fullName":
            case "iAm":
            case "langs_other":
            case "languages":
            case "interests":
              break;
            default:
              logDebug("Adding as unknown as String: $key: $item");
              advancedDescription![key] = item.toString();
          }
        });
      }
      if (jscriptMap["aboutMeComponent"]?["personalInfoList"] != null) {
        advancedDescription ??= {};
        advancedDescription!["Interests and fetishes"] =
            jscriptMap["aboutMeComponent"]["personalInfoList"][2]["value"];
      }
      if (jscriptMap["layoutPage"]?["channelLandingInfoProps"]
              ?["showJoinButton"] !=
          null) {
        externalLinks ??= {};
        externalLinks!["Official site"] = jscriptMap["layoutPage"]
            ["channelLandingInfoProps"]["showJoinButton"]["url"];
      }
    } catch (e, stacktrace) {
      logWarning(
          "Error parsing advanced description or external links: $e\n$stacktrace");
    }

    String? name;
    if (jscriptMap["infoComponent"]?["pageTitle"] != null) {
      name = jscriptMap["infoComponent"]["pageTitle"];
    } else if (jscriptMap["layoutPage"]?["pageTitle"] != null) {
      // For some reason xhamster adds a " Porn Videos: website.com" to all
      // channel titles (even in the official UI)
      name =
          jscriptMap["layoutPage"]["pageTitle"].split(" Porn Videos: ").first;
    } else {
      name = jscriptMap["displayUserModel"]?["modelName"];
    }

    String? thumbnail;
    if (jscriptMap["infoComponent"]?["pornstarTop"]?["thumbUrl"] != null) {
      thumbnail = jscriptMap["infoComponent"]["pornstarTop"]["thumbUrl"];
    } else if (jscriptMap["layoutPage"]?["channelLandingInfoProps"]
            ?["sponsorChannel"]?["siteLogoURL"] !=
        null) {
      thumbnail = jscriptMap["layoutPage"]?["channelLandingInfoProps"]
          ?["sponsorChannel"]?["siteLogoURL"];
    } else {
      thumbnail = jscriptMap["displayUserModel"]?["thumbURL"];
    }

    int? viewsTotal;
    int? videosTotal;
    int? subscribers;
    int? rank;
    Map<String, dynamic>? infoMap;
    if (jscriptMap["infoComponent"] != null) {
      infoMap = jscriptMap["infoComponent"]?["pornstarTop"];
      subscribers = jscriptMap["infoComponent"]?["subscribeButtonsProps"]
          ?["subscribeButtonProps"]?["subscribers"];
      viewsTotal = infoMap?["viewsCount"];
      videosTotal = infoMap?["videoCount"];
      rank = infoMap?["rating"];
    } else if (jscriptMap["layoutPage"]?["channelLandingInfoProps"] != null) {
      infoMap = jscriptMap["layoutPage"]?["channelLandingInfoProps"]
          ?["sponsorChannel"];
      subscribers = jscriptMap["layoutPage"]?["channelLandingInfoProps"]
          ?["subscribeButtonsProps"]?["subscribeButtonProps"]?["subscribers"];
      viewsTotal = infoMap?["viewsCount"];
      videosTotal = infoMap?["videoCount"];
      rank = infoMap?["rating"];
    } else {
      logDebug(
          "Trying to scrape views, videosTotal, subscribers and rank from html");
      // some users don't have this info in the jsonmap -> scrape from html
      try {
        videosTotal = int.tryParse(pageHtml
            .querySelector('a[class="followable videos"]')!
            .children
            .first
            .text);
        viewsTotal = int.tryParse(pageHtml
            .querySelector('div[class="user-details"]')!
            .children[3]
            .querySelector("span")!
            .attributes["data-tooltip"]!
            .replaceAll(",", "")
            .trim());
        subscribers = int.tryParse(pageHtml
            .querySelector('div[class="user-details"]')!
            .children[4]
            .querySelector("span")!
            .attributes["data-tooltip"]!
            .replaceAll(",", "")
            .trim());
        // users don't have ranks
      } catch (e, stacktrace) {
        logWarning(
            "Error parsing views/videosTotal/subscribers/rank: $e\n$stacktrace");
      }
    }

    Map<String, dynamic> authorPage = {
      "iD": authorID,
      "name": name!,
      "avatar": thumbnail,
      // xhamster doesn't have banners
      "banner": null,
      "aliases": jscriptMap["infoComponent"]?["aliases"]?.split(", "),
      "description": shortDescription,
      "advancedDescription": advancedDescription,
      "externalLinks": externalLinks,
      "viewsTotal": viewsTotal,
      "videosTotal": videosTotal,
      "subscribers": subscribers,
      "rank": rank,
      "rawHtml": pageHtml.outerHtml
    };

    return authorPage;
  }

  @override
  Future<List<Map<String, dynamic>>> getAuthorVideos(String authorID, int page,
      [void Function(String body)? debugCallback]) async {
    // First get the author page URI
    String authorPageLink = (await getAuthorUriFromID(authorID))!;

    // differentiate between creators/channels and users
    String? videosLink;
    if (authorPageLink.toString().contains("user")) {
      videosLink = "$authorPageLink/videos/$page";
    } else {
      videosLink = "$authorPageLink/best/$page";
    }

    logDebug("Requesting $videosLink");
    // Request mobile version to get the full jsonmap
    var response = await httpRequest(videosLink,
        headers: {"Cookie": "x_platform_switch=mobile"});
    if (response.statusCode != 200) {
      // 404 means both error and no videos in this case
      // -> return empty list instead of throwing exception
      if (response.statusCode == 404) {
        logWarning(
            "Error downloading html: ${response.statusCode}; Treating as no more videos found");
        return [];
      }
      logError("Error downloading html: ${response.statusCode}");
      throw Exception("Error downloading html: ${response.statusCode}");
    }
    debugCallback?.call(response.body);
    Document resultHtml = parse(response.body);

    String jscript = resultHtml.querySelector('#initials-script')!.text;
    Map<String, dynamic> jscriptMap = jsonDecode(
        jscript.substring(jscript.indexOf("{"), jscript.indexOf('};') + 1));

    // the Map layout varies -> just search through it to find the videoThumbProps List

    // Stack-based iterative search
    final stack = <Map<String, dynamic>>[jscriptMap];
    List<Map<String, dynamic>>? videoThumbProps;
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (current.containsKey("videoThumbProps")) {
        videoThumbProps =
            (current["videoThumbProps"] as List).cast<Map<String, dynamic>>();
        break;
      }
      for (final value in current.values) {
        if (value is Map<String, dynamic>) stack.add(value);
      }
    }

    if (authorPageLink.toString().contains("user")) {
      String authorName = jscriptMap["displayUserModel"]?["name"] ??
          authorPageLink.toString().split("/").last;
      return _parseVideoList(videoThumbProps!,
          authorNamePassed: authorName, authorIDPassed: authorID);
    } else {
      return _parseVideoList(videoThumbProps!);
    }
  }
}