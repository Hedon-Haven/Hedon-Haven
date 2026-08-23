import 'dart:async';
import 'dart:io';

import 'package:auto_orientation_v2/auto_orientation_v2.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:window_manager/window_manager.dart';

import '/services/bug_report_manager.dart';
import '/services/database_manager.dart';
import '/services/loading_handler.dart';
import '/ui/screens/author_page.dart';
import '/ui/screens/bug_report/bug_report.dart';
import '/ui/screens/bug_report/bug_reports_list.dart';
import '/ui/screens/settings/settings_comments.dart';
import '/ui/screens/video_screen/player_widget.dart';
import '/ui/screens/video_screen/widgets.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/widgets/alert_dialog.dart';
import '/ui/widgets/external_link_warning.dart';
import '/ui/widgets/sliver_header.dart';
import '/utils/global_vars.dart';
import '/utils/universal_formats.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Future<UniversalVideoMetadata> videoMetadata;

  /// Pass videoID to be able to pass it to BugReport screen in case
  /// the videoMetadata fails to load completely
  final String videoID;

  const VideoPlayerScreen(
      {super.key, required this.videoMetadata, required this.videoID});

  @override
  State<VideoPlayerScreen> createState() => VideoPlayerScreenState();
}

class VideoPlayerScreenState extends State<VideoPlayerScreen> {
  ScrollController commentsScrollController = ScrollController();
  ScrollController screenScrollController = ScrollController();
  bool showControls = false;
  bool isMobile = true;
  LoadingHandler loadingHandler =
      LoadingHandler(navPath: navigatorPathObserver.currentPath);
  final videoPlayerWidgetKey = GlobalKey<VideoPlayerWidgetState>();

  List<Uint8List>? progressThumbnails;
  Timer? hideControlsTimer;
  bool isFullScreen = false;
  Exception? loadingException;
  String? loadErrorStacktrace;
  bool firstPlay = true;
  bool isLoadingMetadata = true;
  bool loadedCommentsOnce = false;
  bool isLoadingComments = true;
  bool isLoadingMoreComments = false;
  bool showCommentSection = false;
  bool showReplySection = false;
  String? replyCommentID;
  bool descriptionExpanded = false;
  int selectedResolution = 0;
  List<int> sortedResolutions = [];

  final Map<String, Future<UniversalAuthorPage>> _authorPageCache = {};

  // Fill with garbage for skeleton
  List<UniversalComment>? comments = List.generate(
    10,
    (index) => UniversalComment.skeleton(),
  );
  late UniversalVideoMetadata videoMetadata =
      UniversalVideoMetadata.skeleton(widget.videoID);

  Future<List<UniversalVideoPreview>?> videoSuggestions =
      Future.value(List.filled(12, UniversalVideoPreview.skeleton()));

  @override
  void initState() {
    super.initState();
    commentsScrollController.addListener((commentsScrollListener));
    _loadMetadata();
  }

  @override
  void dispose() {
    commentsScrollController.dispose();
    videoMetadata.plugin?.cancelGetProgressThumbnails();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      videoMetadata = await widget.videoMetadata;
      // Start loading video suggestions, but don't wait for them
      videoSuggestions = loadingHandler.getVideoSuggestions(
          videoMetadata.plugin!, videoMetadata.iD, videoMetadata.rawHtml, null);
      // Pre-load images so they are immediately available when the skeletonizer stops
      await precacheImage(
          NetworkImage(videoMetadata.authorAvatar ?? "Avatar url is null"),
          context);
      setState(() {
        isLoadingMetadata = false;
      });
      // Update screen after progress thumbnails are loaded
      sharedStorage.getBool("media_show_progress_thumbnails").then((value) {
        if (value!) {
          videoMetadata.plugin!
              .getProgressThumbnails(videoMetadata.iD, videoMetadata.rawHtml)
              .then((value) {
            setState(() => progressThumbnails = value);
          });
        }
      });
    } catch (e, stacktrace) {
      logger.e("Error getting video metadata: $e\n$stacktrace");
      setState(() {
        loadingException = e as Exception;
        loadErrorStacktrace = stacktrace.toString();
      });
    }
  }

  // Return a page for the openBuilder
  Widget openAuthorPage(String authorID) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await beforeNavigate();
    });
    return AuthorPageScreen(
        authorPage: _authorPageCache.putIfAbsent(
          authorID,
          () => videoMetadata.plugin!.getAuthorPage(authorID),
        ),
        authorID: authorID);
  }

  /// To report all suggestionVideoBugReports
  void createSuggestionVideosBugReport() async {
    List<BugReport> reportedBugs = await Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: "/bug-reports-list-scraping-mode"),
        builder: (context) => BugReportsListScreen(
            scrapingReportMode: true,
            bugReportsList: loadingHandler.videoSuggestionsBugReports),
      ),
    );

    // Remove all reported bugs
    loadingHandler.videoSuggestionsBugReports
        .removeWhere((uvp) => reportedBugs.contains(uvp));

    setState(() {});
  }

  // Pause video and exit fullscreen before navigating to another page
  Future<void> beforeNavigate() async {
    videoPlayerWidgetKey.currentState?.pausePlayer();
    setState(() => isFullScreen = false);
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      await windowManager.setFullScreen(false);
    }
    // TODO: Get rid of visual bug due to system not resizing quick enough
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await AutoOrientation.portraitAutoMode();
  }

  void toggleDescription() {
    setState(() => descriptionExpanded = !descriptionExpanded);
  }

  void copyVideoTitle() {
    Clipboard.setData(ClipboardData(text: videoMetadata.title));
  }

  void openCommentSection() async {
    logger.d("Opening comment section");
    if (isMobile) {
      setState(() => showCommentSection = true);
    }
    if (!loadedCommentsOnce && !isLoadingMetadata) {
      logger.d("Getting comments for the first time");
      setState(() => isLoadingComments = true);
      comments = await loadingHandler.getCommentResults(
          videoMetadata.plugin!, videoMetadata.iD, videoMetadata.rawHtml, null);
      setState(() => isLoadingComments = false);
      logger.d("Finished getting comments");
      loadedCommentsOnce = true;

      if (comments?.isNotEmpty ?? false) {
        // Ensure the frame has been rendered before checking maxScrollExtent, as
        // it otherwise throws "ScrollController not attached to any scroll views"
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // If list is too short user will be unable to scroll and load more
          // comments -> check beforehand and automatically load another page
          if (commentsScrollController.hasClients &&
              commentsScrollController.position.maxScrollExtent == 0.0) {
            commentsScrollListener(forceLoad: true);
          }
        });
      }
    }
  }

  void openReplyCommentSection(String topLevelCommentID) {
    setState(() {
      replyCommentID = topLevelCommentID;
      showReplySection = true;
    });
  }

  void openCommentSettings() async {
    // Navigate to settings page of comments
    logger.i("Opening comment settings");
    await Navigator.push(
        context,
        MaterialPageRoute(
            settings: RouteSettings(name: "/settings_comments"),
            builder: (context) => const CommentsScreen()));
    logger.i("Refreshing comments");
    loadingHandler.commentsPageCounter = 0;
    loadedCommentsOnce = false;
    openCommentSection();
  }

  void openCommentAvatarInFullscreen(UniversalComment comment) {
    showDialog(
        context: context,
        builder: (BuildContext context) => ThemedDialog(
            title: "Avatar image",
            primaryText: "Close",
            onPrimary: () => Navigator.pop(context),
            secondaryText: "Go to author page",
            onSecondary: () async {
              await beforeNavigate();
              if (context.mounted) {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        settings: RouteSettings(name: "/author_page"),
                        builder: (context) => AuthorPageScreen(
                            authorPage: comment.plugin!
                                .getAuthorPage(comment.authorID!),
                            authorID: comment.authorID!)));
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            content: SingleChildScrollView(
                child: Image.network(
                    comment.profilePicture ?? "Avatar url is null",
                    errorBuilder: (context, error, stackTrace) {
              if (!error.toString().contains("mockAvatar")) {
                logger.e("Failed to load network avatar: $error\n$stackTrace");
              }
              return Icon(Icons.error,
                  color: Theme.of(context).colorScheme.error);
            }, fit: BoxFit.contain))));
  }

  void shareVideo() async {
    // Windows and linux don't have share implementations
    // -> Copy to clipboard and show warning instead
    if (Platform.isWindows || Platform.isLinux) {
      Clipboard.setData(ClipboardData(
          text: videoMetadata.plugin!
              .getVideoUriFromID(videoMetadata.iD)
              .toString()));
      showToast(
          "Share not available on "
          "${Platform.isWindows ? "Windows" : "Linux"}. "
          "Copied link to clipboard instead",
          context);
    }
    SharePlus.instance.share(ShareParams(
        uri: await videoMetadata.plugin!.getVideoUriFromID(videoMetadata.iD)));
  }

  void openInBrowser() async {
    Uri videoUri =
        (await videoMetadata.plugin!.getVideoUriFromID(videoMetadata.iD))!;
    if (mounted) openExternalLinkWithWarningDialog(context, videoUri);
  }

  void createManualVideoMetadataBugReport() {
    // Ignore return value since bug report was manually initiated
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: "/bug-report"),
        builder: (context) => BugReportScreen(
          submissionType: SubmissionType.manual,
          bugReportsList: [
            PluginBugReport(
              navigatorPath: navigatorPathObserver.currentPath,
              exception: Exception("Video action button manual bug report"),
              pluginCodeName: videoMetadata.plugin?.codeName ?? "Unknown",
              isBundledPlugin: videoMetadata.plugin?.isBundledPlugin ?? false,
              debugObject: videoMetadata.toMap(),
            )
          ],
        ),
      ),
    );
  }

  void copyComment(String body) {
    Clipboard.setData(ClipboardData(text: body));
    // TODO: Add vibration feedback for mobile
    showToast("Copied comment text to clipboard", context);
  }

  void shareComment(UniversalComment comment) async {
    Uri? commentUri =
        await comment.plugin!.getCommentUriFromID(comment.iD, comment.videoID);
    if (!mounted) return;

    if (commentUri == null) {
      showToast("Could not get link to comment", context);
      return;
    }

    // Windows and linux don't have share implementations
    // -> Copy to clipboard and show warning instead
    if (Platform.isWindows || Platform.isLinux) {
      Clipboard.setData(ClipboardData(text: commentUri.toString()));
      showToast(
          "Share not available on "
          "${Platform.isWindows ? "Windows" : "Linux"}. "
          "Copied link to clipboard instead",
          context);
    }

    SharePlus.instance.share(ShareParams(uri: commentUri));
  }

  void openCommentAuthor(UniversalComment comment) async {
    await beforeNavigate();
    if (mounted) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              settings: RouteSettings(name: "/author_page"),
              builder: (context) => AuthorPageScreen(
                  authorPage: comment.plugin!.getAuthorPage(comment.authorID!),
                  authorID: comment.authorID!)));
    }
    if (mounted) Navigator.of(context).pop();
  }

  void createManualBugReportForComment(UniversalComment comment) async {
    await beforeNavigate();
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          settings: RouteSettings(name: "/bug-report"),
          builder: (context) => BugReportScreen(
            submissionType: SubmissionType.manual,
            bugReportsList: [
              PluginBugReport(
                navigatorPath: navigatorPathObserver.currentPath,
                exception: Exception("Comment modal menu manual bug report"),
                pluginCodeName: comment.plugin?.codeName ?? "Unknown",
                isBundledPlugin: comment.plugin?.isBundledPlugin ?? false,
                debugObject: comment.toMap(),
              )
            ],
          ),
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  void commentsScrollListener({bool forceLoad = false}) async {
    if (!commentsScrollController.hasClients) return;
    if (!isLoadingMoreComments &&
            commentsScrollController.position.pixels >=
                0.95 * commentsScrollController.position.maxScrollExtent ||
        forceLoad) {
      logger.i(forceLoad
          ? "Force loading additional results to make list scrollable"
          : "Loading additional results");
      setState(() => isLoadingMoreComments = true);
      comments = await loadingHandler.getCommentResults(videoMetadata.plugin!,
          videoMetadata.iD, videoMetadata.rawHtml, comments);
      logger.i("Finished getting more results");
      // This also updates the scraping report button
      setState(() => isLoadingMoreComments = false);
    }
  }

  Future<void> toggleFullScreen() async {
    setState(() => isFullScreen = !isFullScreen);
    if (isFullScreen) {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        await windowManager.setFullScreen(true);
      }
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await AutoOrientation.landscapeAutoMode(forceSensor: true);
    } else {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        await windowManager.setFullScreen(false);
      }
      // TODO: Get rid of visual bug due to system not resizing quick enough
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await AutoOrientation.portraitAutoMode();
    }
  }

  Future<void> toggleFavorite(bool? isFavorite) async {
    if (isFavorite == null) return;
    if (isFavorite) {
      await removeFromFavorites(videoMetadata.universalVideoPreview);
    } else {
      await addToFavorites(videoMetadata.universalVideoPreview);
    }
    setState(() {});
  }

  void closeCommentSection({bool closeReplySectionOnly = false}) async {
    if (closeReplySectionOnly) {
      setState(() => showReplySection = false);
      return;
    }
    // Wait for reply section close animation to finish before closing the top level section
    if (showReplySection) {
      setState(() => showReplySection = false);
      await Future.delayed(const Duration(milliseconds: 200));
    }
    setState(() => showCommentSection = false);
  }

  void openCommentsScrapingReport() async {
    List<BugReport> reportedBugs = await Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: "/bug-reports-list-scraping-mode"),
        builder: (context) => BugReportsListScreen(
            scrapingReportMode: true,
            bugReportsList: loadingHandler.commentsBugReports),
      ),
    );

    // Remove all reported bugs
    loadingHandler.commentsBugReports
        .removeWhere((uc) => reportedBugs.contains(uc));

    setState(() {});
  }

  Future<List<UniversalVideoPreview>?> loadMoreResults() async {
    var results = loadingHandler.getVideoSuggestions(videoMetadata.plugin!,
        videoMetadata.iD, videoMetadata.rawHtml, await videoSuggestions);
    // Update warnings/errors button
    setState(() {});
    return results;
  }

  void handlePop() async {
    await beforeNavigate();
    if (showReplySection && isMobile) {
      setState(() {
        showReplySection = false;
      });
      return;
    }
    if (showCommentSection && isMobile) {
      setState(() {
        showCommentSection = false;
      });
    }
  }

  /// Used when the entire video screen fails to load
  void createVideoScreenBugReport() {
    // Immediately pop to avoid a duplicate bug report
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: "/bug-reports-list-scraping-mode"),
        builder: (context) => BugReportsListScreen(
          scrapingReportMode: true,
          bugReportsList: [
            PluginBugReport(
              navigatorPath: navigatorPathObserver.currentPath,
              exception: loadingException!,
              codeTrace: loadErrorStacktrace,
              pluginCodeName: videoMetadata.plugin?.codeName ?? "Unknown",
              isBundledPlugin: videoMetadata.plugin?.isBundledPlugin ?? false,
              debugObject: videoMetadata.toMap(),
            )
          ],
        ),
      ),
    ).then((value) => Navigator.of(context).pop());
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Add "warning button" when scraping partially fails for entire UVM
    isMobile = MediaQuery.of(context).size.width < 1100;
    if (!isMobile) openCommentSection();
    return Scaffold(
        body: SafeArea(
            top: !isFullScreen,
            bottom: !isFullScreen,
            left: !isFullScreen,
            right: !isFullScreen,
            child: PopScope(
                canPop:
                    !isFullScreen && !showCommentSection && !showReplySection,
                onPopInvokedWithResult: (_, __) => handlePop(),
                // Use a stack to add a back button overlay (see below)
                child: Stack(children: [
                  loadingException != null
                      ? buildFailedToLoadWidget(context, this)
                      : Skeletonizer(
                          enabled: isLoadingMetadata,
                          child: isMobile
                              ? _buildMobileLayout()
                              : _buildDesktopLayout(),
                        ),
                  // Overlay a back button
                  // Using an appbar is not an option, since it would push the
                  // entire content down (the video player needs to start at
                  // the very literal top left)
                  if (isLoadingMetadata || loadingException != null)
                    Positioned(
                        top: 0,
                        left: 0,
                        child: BackButton(
                            color: Theme.of(context).colorScheme.primary)),
                ]))));
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            width: constraints.maxWidth,
            height: isFullScreen
                ? MediaQuery.of(context).size.height
                : constraints.maxWidth * 9 / 16,
            child: Skeleton.shade(
              child: isLoadingMetadata
                  ? Container(color: Colors.black)
                  : VideoPlayerWidget(
                      key: videoPlayerWidgetKey,
                      videoMetadata: videoMetadata,
                      progressThumbnails: progressThumbnails,
                      toggleFullScreen: toggleFullScreen,
                      isFullScreen: isFullScreen,
                    ),
            ),
          ),
        ),
        if (!isFullScreen)
          Expanded(
            child: Stack(
              children: [
                Padding(
                    padding: EdgeInsets.all(10),
                    child: CustomScrollView(
                      controller: screenScrollController,
                      slivers: [
                        FloatingDynamicSliverHeader(
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          child: Column(
                            spacing: 5,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildTitleWidget(context, this),
                              buildMetadataSection(context, this),
                              if (descriptionExpanded)
                                buildActorsList(context, this),
                              buildAuthorWidget(context, this),
                              buildActionButtonsRow(context, this),
                              buildCommentButton(context, this),
                              SizedBox(height: 5),
                            ],
                          ),
                        ),
                        ...buildVideoSuggestions(context, this),
                      ],
                    )),
                AnimatedSlide(
                  offset: showCommentSection ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: !showCommentSection,
                    child: buildCommentSection(context, this),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return SizedBox.expand(
      child: SingleChildScrollView(
        controller: screenScrollController,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Skeleton.shade(
                      child: isLoadingMetadata
                          ? Container(color: Colors.black)
                          : VideoPlayerWidget(
                              key: videoPlayerWidgetKey,
                              videoMetadata: videoMetadata,
                              progressThumbnails: progressThumbnails,
                              toggleFullScreen: toggleFullScreen,
                              isFullScreen: isFullScreen,
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      spacing: 10,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildTitleWidget(context, this),
                        if (descriptionExpanded) buildActorsList(context, this),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: buildAuthorWidget(context, this)),
                              SizedBox(width: 20),
                              buildMetadataSection(context, this),
                            ]),
                        buildActionButtonsRow(context, this),
                        NotificationListener<ScrollNotification>(
                          onNotification: (_) => true,
                          child: SizedBox(
                              height: 1200,
                              child: buildCommentSection(context, this)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: CustomScrollView(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                slivers: buildVideoSuggestions(context, this),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
