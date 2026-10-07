import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hedon_haven/services/http_manager.dart';
import 'package:hedon_haven/utils/bundled_plugin.dart';
import 'package:hedon_haven/utils/global_vars.dart';
import 'package:hedon_haven/utils/plugin_interface/plugin_interface.dart';
import 'package:hedon_haven/utils/universal_formats.dart';
import 'package:logger/logger.dart';
import 'package:mockito/mockito.dart';
import 'package:rhttp/rhttp.dart';
import 'package:yaml/yaml.dart';

// Keep in mind this import wont work until "flutter pub run build_runner build" is run
import 'utils/generate_mocks.mocks.dart';
import 'utils/testing_logger.dart';

// To avoid rate limiting and weird behavior from providers, wait between test groups
// Normal sleep() doesn't work -> need to simulate a test
void timeout() {
  test("Waiting for 20 seconds before next test group...", () async {
    await Future.delayed(Duration(seconds: 20));
  });
}

/// Dumps every network request/reply that produced a result to [dirPath], so
/// a failed scrape can be inspected (e.g. opening the .html directly to
/// check why a css selector stopped matching). One call can involve several
/// requests (retries, pagination helpers, ...), so all of them get dumped,
/// not just "the" page body like the old callback-based dumping did.
void dumpNetworkTraces(String dirPath, List<NetworkTrace> traces) {
  Directory(dirPath).createSync(recursive: true);
  for (int i = 0; i < traces.length; i++) {
    final contentType = traces[i].replyHeaders["content-type"] ?? "";
    final extension = contentType.contains("json")
        ? "json"
        : contentType.contains("html")
            ? "html"
            : contentType.contains("javascript")
                ? "js"
                : "bin";
    File("$dirPath/$i.$extension").writeAsBytesSync(traces[i].bodyBytes);
  }
  File("$dirPath/manifest.json").writeAsStringSync(JsonEncoder.withIndent("  ")
      .convert(traces
          .map((t) => {"requestUrl": t.requestUrl, "statusCode": t.statusCode})
          .toList()));
}

/// Runs [call], dumping whatever network traces it produced to [dirPath]
/// before returning/rethrowing. A thrown exception carries the traces
/// gathered up to the point of failure the same way a successful result
/// does (see PluginInterface._callFunction) -> dump those too instead of
/// losing them, since they're exactly what you'd want to inspect a failure
/// with.
Future<T> dumpingTraces<T extends Object>(
    String dirPath, Future<T> Function() call) async {
  try {
    final result = await call();
    dumpNetworkTraces(dirPath, result.networkTraces);
    return result;
  } catch (e) {
    dumpNetworkTraces(dirPath, e.networkTraces);
    rethrow;
  }
}

/// Checks a scraped Universal* object's map for keys that are null despite
/// not being declared in [unavailableFields], logging and returning false if
/// any are found.
bool verifyScrapedData(String pluginCodeName, String className, String iD,
    Map<String, dynamic> map, Set<String> unavailableFields) {
  final exception = throwOnMissedField(map, unavailableFields);
  if (exception != null) {
    logger.w("$pluginCodeName: $className ($iD): ${exception.message}");
    return false;
  }
  return true;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Rhttp.init();

  // Init global values
  logger = Logger(printer: TestingPrinter());
  client = await getHttpClient(null);
  final mock = MockSharedPreferencesAsync();
  when(mock.getBool("general_enable_dev_options"))
      .thenAnswer((_) async => false);
  sharedStorage = mock;

  // Read plugin name that should be tested from env
  String? pluginFromEnv = Platform.environment["PLUGIN"];

  if (pluginFromEnv == null) {
    logger.f("Couldn't read PLUGIN environment variable value");
    return;
  }

  PluginInterface? plugin = await getBundledPluginByName(pluginFromEnv);
  if (plugin == null) {
    logger.f("Plugin with name $pluginFromEnv not found");
    return;
  }

  File testMapFile = File("${Directory.current.path}/test/"
      "bundled_plugins_test_maps/${plugin.codeName}.yaml");
  if (!testMapFile.existsSync()) {
    logger.f("No test map found at ${testMapFile.path}");
    return;
  }
  YamlMap testMap = loadYaml(testMapFile.readAsStringSync());
  List<Map<String, dynamic>> testingSearchSuggestions =
      (testMap["testingSearchSuggestions"] as YamlList)
          .map((e) => Map<String, dynamic>.from(e as YamlMap))
          .toList();
  List<Map<String, dynamic>> testingSearchResults =
      (testMap["testingSearchResults"] as YamlList)
          .map((e) => Map<String, dynamic>.from(e as YamlMap))
          .toList();
  List<Map<String, dynamic>> testingVideos =
      (testMap["testingVideos"] as YamlList)
          .map((e) => Map<String, dynamic>.from(e as YamlMap))
          .toList();
  List<String> testingAuthorPageIds =
      (testMap["testingAuthorPageIds"] as YamlList).cast<String>();

  // Wipe and recreate the dump dir. Subdirectories are created on demand by
  // dumpNetworkTraces / when writing result Maps
  Directory dumpDir = Directory("${Directory.current.path}/dumps");
  if (dumpDir.existsSync()) dumpDir.deleteSync(recursive: true);
  dumpDir.createSync(recursive: true);
  logger.i("Dump dir created at ${dumpDir.path}");

  // Create encoder with indent for nicer dumps
  JsonEncoder encoder = JsonEncoder.withIndent("  ");

  group("Testing ${plugin.codeName}", () {
    test("init", () async {
      logger.i("Testing init");

      try {
        List<NetworkTrace> traces =
            await plugin.init(Directory("${dumpDir.path}/pluginCache").path);
        dumpNetworkTraces("${dumpDir.path}/init", traces);
      } catch (e) {
        dumpNetworkTraces("${dumpDir.path}/init", e.networkTraces);
        fail("plugin.init threw: $e");
      }
    });

    timeout();

    // Don't test icons for now, as its unlikely that favicon.ico urls will change
    /*
    group("iconUrl", () {
      logger.i("Testing iconUrl");
      http.Response? response;
      test("Make sure iconUrl is valid and decodable", () async {
        // Fetch the .ico file
        response = await client.get(plugin.iconUrl);
        expect(response!.statusCode, 200);

        // Try to decode the image using the image package (supports various formats)
        final imageBytes = response!.bodyBytes;
        expect(imageBytes.isNotEmpty, isTrue);
        try {
          final decodedImage = decodeImage(Uint8List.fromList(imageBytes));
          expect(decodedImage, isNotNull);
        } catch (e) {
          fail("Failed to decode image: $e");
        }
      });
      tearDownAll(() {
        logger.i(
            "Dumping iconUrl to file (Warning, might not be actually an ico)");
        File("${dumpDir.path}/iconUrl.ico")
            .writeAsBytesSync(response!.bodyBytes);
      });
    });

    timeout();
    */

    group("getSearchSuggestions", () {
      for (final testCase in testingSearchSuggestions) {
        final String query = testCase["query"];
        final String expectedSuggestion = testCase["expectedSuggestion"];

        group("query \"$query\"", () {
          List<String>? suggestions;
          setUpAll(() async {
            suggestions = await dumpingTraces(
                "${dumpDir.path}/getSearchSuggestions/$query",
                () => plugin.getSearchSuggestions(query));
          });
          test("Make sure amount of returned result is greater than 0", () {
            expect(suggestions!.length, greaterThan(0));
          });
          test(
              "Check at least one of the suggestions is \"$expectedSuggestion\"",
              () {
            expect(suggestions!.contains(expectedSuggestion), isTrue);
          });
          tearDownAll(() {
            logger.i("Dumping suggestions Map to file");
            File("${dumpDir.path}/getSearchSuggestions/$query/Map.json")
                .writeAsStringSync(encoder.convert(suggestions));
          });
        });

        timeout();
      }
    });

    group("getHomePage", () {
      List<UniversalVideoPreview> homepageResults = [];
      setUpAll(() async {
        // Get 3 pages of homepage. Fetched (and dumped) one page at a time,
        // instead of merging with a spread, so each page's networkTraces
        // (attached via an Expando keyed on that exact List instance) don't
        // get lost when building the combined list
        for (int page = plugin.initialHomePage;
            page < plugin.initialHomePage + 3;
            page++) {
          List<UniversalVideoPreview> pageResults = await dumpingTraces(
              "${dumpDir.path}/getHomePage/page_$page",
              () => plugin.getHomePage(page));
          homepageResults.addAll(pageResults);
        }
      });
      test("Make sure amount of returned result is greater than 0", () {
        expect(homepageResults.length, greaterThan(0));
      });
      test("Check if all results were fully scraped", () {
        for (var result in homepageResults) {
          expect(
              verifyScrapedData(plugin.codeName, "UniversalVideoPreview",
                  result.iD, result.toMap(), result.unavailableFields),
              isTrue);
        }
      });
      tearDownAll(() {
        logger.i("Dumping getHomePage Map to file.");
        List<Map<String, dynamic>> homepageResultsAsMap =
            homepageResults.map((e) => e.toMap()).toList();
        File("${dumpDir.path}/getHomePage/Map.json")
            .writeAsStringSync(encoder.convert(homepageResultsAsMap));
      });
    });

    timeout();

    group("getSearchResults", () {
      for (final testCase in testingSearchResults) {
        final String searchString = testCase["searchString"];

        group("search \"$searchString\"", () {
          List<UniversalVideoPreview> searchResults = [];
          setUpAll(() async {
            // Getting 3 pages of search results
            for (int page = plugin.initialSearchResultsPage;
                page < plugin.initialSearchResultsPage + 3;
                page++) {
              List<UniversalVideoPreview> pageResults = await dumpingTraces(
                  "${dumpDir.path}/getSearchResults/${searchString}_page_$page",
                  () => plugin.getSearchResults(
                      UniversalSearchRequest(searchString: searchString),
                      page));
              searchResults.addAll(pageResults);
            }
          });
          test("Make sure amount of returned result is greater than 0", () {
            expect(searchResults.length, greaterThan(0));
          });
          test("Check if all results were fully scraped", () {
            for (var result in searchResults) {
              expect(
                  verifyScrapedData(plugin.codeName, "UniversalVideoPreview",
                      result.iD, result.toMap(), result.unavailableFields),
                  isTrue);
            }
          });
          tearDownAll(() {
            logger.i("Dumping getSearchResults Map to file.");
            List<Map<String, dynamic>> searchResultsAsMap =
                searchResults.map((e) => e.toMap()).toList();
            File("${dumpDir.path}/getSearchResults/$searchString.json")
                .writeAsStringSync(encoder.convert(searchResultsAsMap));
          });
        });

        timeout();
      }
    });

    group("VideoMetadata tests", () {
      for (final videoMap in testingVideos) {
        final String videoID = videoMap["videoID"];
        final int expectedProgressThumbnails =
            videoMap["progressThumbnailsAmount"];

        group("video $videoID", () {
          UniversalVideoMetadata? metadata;
          setUpAll(() async {
            // Pass a skeleton, the uvp is only needed in ui tests
            metadata = await dumpingTraces(
                "${dumpDir.path}/getVideoMetadata/$videoID",
                () => plugin.getVideoMetadata(
                    videoID, UniversalVideoPreview.skeleton()));
          });

          group("getVideoMetadata", () {
            test("Check if video metadata was fully scraped", () {
              expect(
                  verifyScrapedData(
                      plugin.codeName,
                      "UniversalVideoMetadata",
                      metadata!.iD,
                      metadata!.toMap(),
                      metadata!.unavailableFields),
                  isTrue);
            });
            tearDownAll(() {
              logger.i("Dumping getVideoMetadata Map to file");
              File("${dumpDir.path}/getVideoMetadata/$videoID/Map.json")
                  .writeAsStringSync(encoder.convert(metadata!.toMap()));
            });
          });

          timeout();

          group("getProgressThumbnails", () {
            List<Uint8List>? thumbnails;
            setUpAll(() async {
              try {
                thumbnails = await plugin.getProgressThumbnails(
                    metadata!.iD, metadata!.rawHtml);
                dumpNetworkTraces(
                    "${dumpDir.path}/getProgressThumbnails/$videoID",
                    thumbnails?.networkTraces ?? []);
              } catch (e) {
                dumpNetworkTraces(
                    "${dumpDir.path}/getProgressThumbnails/$videoID",
                    e.networkTraces);
                rethrow;
              }
            });
            test(
                "Check if $expectedProgressThumbnails progress thumbnails were scraped",
                () {
              expect(thumbnails!.length, expectedProgressThumbnails);
            });
            tearDownAll(() {
              logger
                  .i("Dumping each getProgressThumbnails thumbnail to a file");
              Directory("${dumpDir.path}/getProgressThumbnails/$videoID")
                  .createSync(recursive: true);
              for (int i = 0; i < thumbnails!.length; i++) {
                File("${dumpDir.path}/getProgressThumbnails/$videoID/$i.jpeg")
                    .writeAsBytesSync(thumbnails![i]);
              }
            });
          });

          timeout();

          group("getVideoSuggestions", () {
            List<UniversalVideoPreview> suggestions = [];
            setUpAll(() async {
              // Get 3 pages of video suggestions
              for (int page = plugin.initialVideoSuggestionsPage;
                  page < plugin.initialVideoSuggestionsPage + 3;
                  page++) {
                List<UniversalVideoPreview> pageResults = await dumpingTraces(
                    "${dumpDir.path}/getVideoSuggestions/${videoID}_page_$page",
                    () => plugin.getVideoSuggestions(
                        metadata!.iD, metadata!.rawHtml, page));
                suggestions.addAll(pageResults);
              }
            });
            test("Make sure amount of returned result is greater than 0", () {
              expect(suggestions.length, greaterThan(0));
            });
            test("Check if all video suggestions were fully scraped", () {
              for (var suggestion in suggestions) {
                expect(
                    verifyScrapedData(
                        plugin.codeName,
                        "UniversalVideoPreview",
                        suggestion.iD,
                        suggestion.toMap(),
                        suggestion.unavailableFields),
                    isTrue);
              }
            });
            tearDownAll(() {
              logger.i("Dumping getVideoSuggestions Map to file");
              File("${dumpDir.path}/getVideoSuggestions/$videoID.json")
                  .writeAsStringSync(encoder
                      .convert(suggestions.map((e) => e.toMap()).toList()));
            });
          });

          timeout();

          group("getComments", () {
            List<UniversalComment> comments = [];
            setUpAll(() async {
              // Get 3 pages of comments
              for (int page = plugin.initialCommentsPage;
                  page < plugin.initialCommentsPage + 3;
                  page++) {
                List<UniversalComment> pageResults = await dumpingTraces(
                    "${dumpDir.path}/getComments/${videoID}_page_$page",
                    () => plugin.getComments(
                        metadata!.iD, metadata!.rawHtml, page));
                comments.addAll(pageResults);
              }
            });
            test("Make sure amount of returned comments is greater than 0", () {
              expect(comments.length, greaterThan(0));
            });
            test("Check if all comments were fully scraped", () {
              for (var comment in comments) {
                expect(
                    verifyScrapedData(plugin.codeName, "UniversalComment",
                        comment.iD, comment.toMap(), comment.unavailableFields),
                    isTrue);
              }
            });
            tearDownAll(() {
              logger.i("Dumping getComments Map to file");
              File("${dumpDir.path}/getComments/$videoID.json")
                  .writeAsStringSync(
                      encoder.convert(comments.map((e) => e.toMap()).toList()));
            });
          });
        });

        timeout();
      }
    });

    group("AuthorPage tests", () {
      for (final authorID in testingAuthorPageIds) {
        group("author $authorID", () {
          UniversalAuthorPage? authorPage;
          setUpAll(() async {
            authorPage = await dumpingTraces(
                "${dumpDir.path}/getAuthorPage/$authorID",
                () => plugin.getAuthorPage(authorID));
          });

          group("getAuthorPage", () {
            test("Check if authorPage metadata was fully scraped", () {
              expect(
                  verifyScrapedData(
                      plugin.codeName,
                      "UniversalAuthorPage",
                      authorPage!.iD,
                      authorPage!.toMap(),
                      authorPage!.unavailableFields),
                  isTrue);
            });
            tearDownAll(() {
              logger.i("Dumping getAuthorPage Map to file");
              File("${dumpDir.path}/getAuthorPage/$authorID/Map.json")
                  .writeAsStringSync(encoder.convert(authorPage!.toMap()));
            });
          });

          timeout();

          group("getAuthorVideos", () {
            List<UniversalVideoPreview> authorVideos = [];
            setUpAll(() async {
              // Get 3 pages of author videos
              for (int page = plugin.initialAuthorVideosPage;
                  page < plugin.initialAuthorVideosPage + 3;
                  page++) {
                List<UniversalVideoPreview> pageResults = await dumpingTraces(
                    "${dumpDir.path}/getAuthorVideos/${authorID}_page_$page",
                    () => plugin.getAuthorVideos(
                        authorPage!.iD, authorPage!.rawHtml, page));
                authorVideos.addAll(pageResults);
              }
            });
            test("Make sure amount of returned results is greater than 0", () {
              expect(authorVideos.length, greaterThan(0));
            });
            test("Check if all author videos were fully scraped", () {
              for (var video in authorVideos) {
                expect(
                    verifyScrapedData(plugin.codeName, "UniversalVideoPreview",
                        video.iD, video.toMap(), video.unavailableFields),
                    isTrue);
              }
            });
            tearDownAll(() {
              logger.i("Dumping getAuthorVideos Map to file");
              File("${dumpDir.path}/getAuthorVideos/$authorID.json")
                  .writeAsStringSync(encoder
                      .convert(authorVideos.map((e) => e.toMap()).toList()));
            });
          });
        });

        timeout();
      }
    });
  });
}
