import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '/services/database_manager.dart';
import '/ui/screens/video_list.dart';
import '/ui/screens/video_screen/video_screen.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/widgets/sliver_header.dart';
import '/utils/convert.dart';
import '/utils/global_vars.dart';
import '/utils/universal_formats.dart';

Widget buildFailedToLoadWidget(
    BuildContext context, VideoPlayerScreenState vps) {
  return Center(
      child: Padding(
          padding: EdgeInsets.only(
              left: MediaQuery.of(context).size.width * 0.1,
              right: MediaQuery.of(context).size.width * 0.1,
              top: MediaQuery.of(context).size.height * 0.1),
          child: Column(children: [
            Text(
                vps.failedToLoadReason == "No internet connection"
                    ? "No internet connection"
                    : "Failed to scrape video page",
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center),
            if (vps.failedToLoadReason != "No internet connection") ...[
              SizedBox(height: 10),
              ElevatedButton(
                  style: TextButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary),
                  child: Text("Create bug report",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary)),
                  onPressed: () => vps.createVideoScreenBugReport())
            ]
          ])));
}

Widget buildTitleWidget(BuildContext context, VideoPlayerScreenState vps) {
  return SizedBox(
      width: double.infinity,
      child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
              onTap: () => vps.toggleDescription(),
              onLongPress: () => vps.copyVideoTitle(),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topLeft,
                            child: Text(
                                // Most videos result in a 2-line title, but mock usually displays only one causing jumps
                                vps.isLoadingMetadata
                                    ? "${"Title" * 10}\n${"Title" * 10}"
                                    : vps.videoMetadata.title,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: vps.descriptionExpanded ? 10 : 2))),
                    Icon(
                      vps.descriptionExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 30.0,
                    )
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topLeft,
                  child: vps.descriptionExpanded
                      ? Text(
                          vps.videoMetadata.description ??
                              "No description available",
                          style: Theme.of(context).textTheme.bodyMedium!)
                      : const SizedBox.shrink(),
                )
              ]))));
}

Widget buildMetadataSection(BuildContext context, VideoPlayerScreenState vps) {
  TextStyle mediumTextStyle = Theme.of(context)
      .textTheme
      .bodyLarge!
      .copyWith(color: Theme.of(context).colorScheme.onSurface);
  int? ratingsPositive = vps.videoMetadata.ratingsPositiveTotal;
  int? ratingsNegative = vps.videoMetadata.ratingsNegativeTotal;
  return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 20,
      children: [
        Row(children: [
          Text(
              vps.isLoadingMetadata
                  ? "3000 "
                  : vps.videoMetadata.viewsTotal == null
                      ? "-"
                      : vps.descriptionExpanded
                          ? "${formatWithDots(vps.videoMetadata.viewsTotal!)} "
                          : "${convertNumberIntoHumanReadable(vps.videoMetadata.viewsTotal!)} ",
              maxLines: 1,
              style: mediumTextStyle),
          Skeleton.shade(
              child: Icon(
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                  Icons.remove_red_eye))
        ]),
        Row(children: [
          Text(
              vps.isLoadingMetadata
                  ? "Xw ago"
                  : vps.videoMetadata.uploadDate == null
                      ? "-"
                      : vps.descriptionExpanded
                          ? DateFormat("dd-MMM-yyyy")
                              .format(vps.videoMetadata.uploadDate!)
                          : "${getTimeDeltaInHumanReadable(vps.videoMetadata.uploadDate)} ago ",
              maxLines: 1,
              style: mediumTextStyle),
          Skeleton.shade(
              child: Icon(
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                  Icons.upload))
        ]),
        Row(children: [
          Skeleton.shade(
              child: Icon(
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                  Icons.thumb_up)),
          const SizedBox(width: 5),
          Text(
            // @formatter:off
              vps.isLoadingMetadata
                  ? "9999 | 999"
                  : "${vps.descriptionExpanded
                      ? "${ratingsPositive ?? "-"}"
                      : convertNumberIntoHumanReadable(ratingsPositive)}"
                    " | "
                    "${vps.descriptionExpanded
                      ? "${ratingsNegative ?? "_"}"
                      : convertNumberIntoHumanReadable(ratingsNegative)}",
              // @formatter:on
              maxLines: 1,
              style: mediumTextStyle),
          const SizedBox(width: 5),
          Skeleton.shade(
              child: Icon(
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                  Icons.thumb_down))
        ])
      ]);
}

Widget buildActorsList(BuildContext context, VideoPlayerScreenState vps) {
  return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
          padding: const EdgeInsets.all(4),
          child: vps.videoMetadata.actors == null
              ? Center(child: Text("No actors available"))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 10,
                    children: vps.videoMetadata.actors!
                            .map((actor) => OpenContainer(
                                closedElevation: 0,
                                openElevation: 0,
                                closedColor: Colors.transparent,
                                openColor:
                                    Theme.of(context).colorScheme.surface,
                                transitionDuration:
                                    const Duration(milliseconds: 400),
                                openBuilder: (_, __) =>
                                    vps.openAuthorPage(actor.authorID),
                                closedBuilder: (context, openContainer) =>
                                    buildActorWidget(
                                        context, openContainer, actor)))
                            .toList() ??
                        [],
                  ))));
}

Widget buildActorWidget(BuildContext context, void Function() openContainer,
    ({String name, String authorID, String? avatar}) actor) {
  return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextButton(
          style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              )),
          onPressed: () => openContainer(),
          child: Row(spacing: 3, children: [
            ClipOval(
              child: Image.network(
                width: 30,
                height: 30,
                actor.avatar ?? "Avatar url is null",
                fit: BoxFit.cover,
                errorBuilder: (context, e, st) {
                  if (!e.toString().contains("mockAvatar")) {
                    logger.e("Failed to load network avatar: $e\n$st");
                  }
                  return FittedBox(
                      fit: BoxFit.cover,
                      child: Icon(Icons.person,
                          color: Theme.of(context).colorScheme.onTertiary));
                },
              ),
            ),
            Text(actor.name)
          ])));
}

Widget buildAuthorWidget(BuildContext context, VideoPlayerScreenState vps) {
  return OpenContainer(
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      openColor: Theme.of(context).colorScheme.surface,
      transitionDuration: const Duration(milliseconds: 400),
      openBuilder: (_, __) => vps.openAuthorPage(vps.videoMetadata.authorID),
      closedBuilder: (context, openContainer) => Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
              style: ButtonStyle(
                  alignment: Alignment.centerLeft,
                  padding: WidgetStateProperty.all(EdgeInsets.all(5))),
              onPressed: () => openContainer(),
              child: Row(
                  mainAxisSize:
                      vps.isMobile ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Skeleton.replace(
                      width: 50,
                      height: 50,
                      replacement: ClipRRect(
                        borderRadius: BorderRadius.circular(255),
                        child: ColoredBox(
                            color: Theme.of(context).colorScheme.surface),
                      ),
                      child: ClipOval(
                          child: Container(
                        width: 50,
                        height: 50,
                        color: Theme.of(context).colorScheme.tertiary,
                        child: Image.network(
                          vps.videoMetadata.authorAvatar ??
                              "Avatar url is null",
                          fit: BoxFit.cover,
                          errorBuilder: (context, e, st) {
                            if (!e.toString().contains("mockAvatar")) {
                              logger
                                  .e("Failed to load network avatar: $e\n$st");
                            }
                            return FittedBox(
                                fit: BoxFit.cover,
                                child: Icon(Icons.person,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onTertiary));
                          },
                        ),
                      )),
                    ),
                    SizedBox(width: 10),
                    Flexible(
                      fit: vps.isMobile ? FlexFit.tight : FlexFit.loose,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vps.videoMetadata.authorName ?? "-",
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                              "Subscribers: ${convertNumberIntoHumanReadable(vps.videoMetadata.authorSubscriberCount ?? 0)}",
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.titleSmall)
                        ],
                      ),
                    ),
                    SizedBox(width: 50),
                    FutureBuilder<bool?>(
                        // TODO: Add call to check subscription here
                        future: Future.value(false),
                        builder: (context, snapshot) {
                          return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary),
                              onPressed: () =>
                                  showToast("Not yet implemented", context),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        size: 20,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        snapshot.data ?? false
                                            ? Icons.notifications_off_outlined
                                            : Icons.notification_add),
                                    Text(snapshot.data ?? false
                                        ? " Unsubscribe"
                                        : " Subscribe")
                                  ]));
                        }),
                  ]))));
}

Widget buildActionButtonsRow(BuildContext context, VideoPlayerScreenState vps) {
  return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          spacing: 10,
          children: [
            SizedBox(
                child: FutureBuilder<bool?>(
              future: isInFavorites(vps.videoMetadata.iD),
              builder: (context, snapshot) {
                return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.onSecondary,
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary),
                    child: Row(children: [
                      Icon(
                          size: 20,
                          color: Theme.of(context).colorScheme.onSecondary,
                          snapshot.data ?? false
                              ? Icons.favorite
                              : Icons.favorite_border),
                      Text(snapshot.data ?? false
                          ? " Remove from favorites"
                          : " Add to favorites")
                    ]),
                    onPressed: () => vps.toggleFavorite(snapshot.data));
              },
            )),
            SizedBox(
                child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  backgroundColor: Theme.of(context).colorScheme.secondary),
              child: Row(children: [
                Icon(
                    size: 20,
                    color: Theme.of(context).colorScheme.onSecondary,
                    Icons.share),
                Text(" Share")
              ]),
              onPressed: () => vps.shareVideo(),
            )),
            SizedBox(
                child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  backgroundColor: Theme.of(context).colorScheme.secondary),
              child: Row(children: [
                Icon(
                    size: 20,
                    color: Theme.of(context).colorScheme.onSecondary,
                    Icons.open_in_new),
                Text(" Open in browser")
              ]),
              onPressed: () => vps.openInBrowser(),
            )),
            SizedBox(
                child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  backgroundColor: Theme.of(context).colorScheme.secondary),
              child: Row(children: [
                Icon(
                    size: 20,
                    color: Theme.of(context).colorScheme.onSecondary,
                    Icons.bug_report),
                Text(" Report bug")
              ]),
              onPressed: () => vps.createManualVideoMetadataBugReport(),
            ))
          ]));
}

Widget buildCommentButton(BuildContext context, VideoPlayerScreenState vps) {
  return SizedBox(
    width: double.infinity,
    child: Skeleton.shade(
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
        onPressed:
            vps.isLoadingMetadata ? null : () => vps.openCommentSection(),
        child: const Text("Comments"),
      ),
    ),
  );
}

Widget buildCommentSection(BuildContext context, VideoPlayerScreenState vps) {
  UniversalComment? replyTopLevelComment;
  for (var comment in vps.comments ?? []) {
    if (comment.iD == vps.replyCommentID) {
      replyTopLevelComment = comment;
      break;
    }
  }
  return Stack(children: [
    Positioned.fill(child: buildTopLevelCommentSection(context, vps)),
    // Don't render reply section if not shown,
    // otherwise it renders under the suggested videos in desktop mode
    if (vps.showReplySection)
      Positioned.fill(
        child: AnimatedSlide(
          offset: vps.showReplySection ? Offset.zero : const Offset(1, 0),
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: !vps.showReplySection,
            child: buildReplyCommentSection(context, vps, replyTopLevelComment),
          ),
        ),
      )
  ]);
}

Widget buildTopLevelCommentSection(
    BuildContext context, VideoPlayerScreenState vps) {
  return Container(
      decoration: BoxDecoration(
        color: vps.isMobile
            ? Theme.of(context).colorScheme.surfaceVariant
            : Theme.of(context).colorScheme.surface,
        // Set the background color of the container
        borderRadius: BorderRadius.circular(
            vps.isMobile ? 25 : 0), // Set the border radius
      ),
      // build as many widgets as there are in the list
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
            padding: vps.isMobile
                ? const EdgeInsets.only(left: 20, right: 10, top: 10, bottom: 5)
                : EdgeInsets.zero,
            child: Row(children: [
              Text(
                  "Comments (${vps.isLoadingComments ? "?" : vps.comments?.length ?? 0}) ",
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              if (vps.loadingHandler.commentsBugReports.isNotEmpty &&
                  !vps.isLoadingComments &&
                  !vps.isLoadingMoreComments) ...[
                IconButton(
                  icon: Icon(
                      color: Theme.of(context).colorScheme.error,
                      Icons.error_outline),
                  onPressed: () => vps.openCommentsScrapingReport(),
                )
              ],
              IconButton(
                  onPressed: () => vps.openCommentSettings(),
                  icon: Icon(Icons.filter_alt,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (vps.isMobile)
                IconButton(
                    onPressed: () => vps.closeCommentSection(),
                    icon: Icon(Icons.close,
                        color: Theme.of(context).colorScheme.onSurfaceVariant))
            ])),
        Divider(
            height: 0,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            thickness: 1),
        Expanded(
            child: Skeletonizer(
                enabled: vps.isLoadingComments,
                child: vps.comments?.isEmpty ?? true
                    ? Column(children: [
                        Padding(
                            padding: const EdgeInsets.only(top: 50, bottom: 10),
                            child: Text(
                                vps.comments == null
                                    ? "Failed to load comments"
                                    : "No comments",
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall!
                                    .copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                textAlign: TextAlign.center)),
                        if (vps.comments == null) ...[
                          ElevatedButton(
                              style: TextButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary),
                              child: Text("Open scraping report",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary)),
                              onPressed: () => vps.openCommentsScrapingReport())
                        ]
                      ])
                    : ListView.builder(
                        controller: vps.commentsScrollController,
                        physics: AlwaysScrollableScrollPhysics(),
                        itemCount: vps.comments!.length +
                            (vps.isLoadingMoreComments ? 1 : 0),
                        itemBuilder: (context, index) {
                          return index == vps.comments?.length
                              ? Center(
                                  child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: CircularProgressIndicator(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)))
                              : Padding(
                                  padding: EdgeInsets.only(
                                      top: 10, left: vps.isMobile ? 15 : 5),
                                  child: buildComment(
                                      context, vps, vps.comments![index]));
                        },
                      )))
      ]));
}

Widget buildReplyCommentSection(BuildContext context,
    VideoPlayerScreenState vps, UniversalComment? topLevelComment) {
  if (vps.comments?.isEmpty ?? true) return Container();
  return topLevelComment == null
      ? Center(child: const Text("topLevelComment is null? Report this!"))
      : Container(
          decoration: BoxDecoration(
            color: vps.isMobile
                ? Theme.of(context).colorScheme.surfaceVariant
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(vps.isMobile ? 25 : 0),
          ),
          // build as many widgets as there are in the list
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
                padding: vps.isMobile
                    ? const EdgeInsets.only(
                        left: 5, right: 10, top: 10, bottom: 5)
                    : EdgeInsets.zero,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                  IconButton(
                      onPressed: () =>
                          vps.closeCommentSection(closeReplySectionOnly: true),
                      icon: Icon(Icons.arrow_back,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text(
                      "Replies (${topLevelComment.replyComments?.length ?? "No reply comments?"})",
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500)),
                  if (vps.isMobile) ...[
                    const Spacer(),
                    IconButton(
                        onPressed: () => vps.closeCommentSection(),
                        icon: Icon(Icons.close,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant))
                  ]
                ])),
            Divider(
                height: 0,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                thickness: 1),
            Expanded(
                child: topLevelComment.replyComments?.isEmpty ?? true
                    ? Center(
                        child: Text("No reply comments? Report this!",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall!
                                .copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                            textAlign: TextAlign.center),
                      )
                    : ListView.builder(
                        physics: AlwaysScrollableScrollPhysics(),
                        itemCount: topLevelComment.replyComments!.length + 1,
                        itemBuilder: (context, index) {
                          return Container(
                              decoration: BoxDecoration(
                                  color: index == 0
                                      ? vps.isMobile
                                          ? Theme.of(context)
                                              .colorScheme
                                              .surface
                                          : Theme.of(context)
                                              .colorScheme
                                              .surfaceVariant
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                      vps.isMobile ? 0 : 25)),
                              child: Padding(
                                  // only insert some space at the top for the first ListTile
                                  padding: EdgeInsets.only(
                                      top: 10, left: vps.isMobile ? 15 : 5),
                                  child: index == 0
                                      ? buildComment(
                                          context, vps, topLevelComment,
                                          hideRepliesCounter: true)
                                      : buildComment(
                                          context,
                                          vps,
                                          topLevelComment
                                              .replyComments![index - 1])));
                        },
                      ))
          ]));
}

Widget buildComment(
    BuildContext context, VideoPlayerScreenState vps, UniversalComment comment,
    {bool hideRepliesCounter = false}) {
  return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                      leading: const Icon(Icons.copy_all),
                      title: const Text("Copy comment text"),
                      onTap: () => vps.copyComment(comment.commentBody)),
                  ListTile(
                      leading: const Icon(Icons.share),
                      title: const Text("Share link to comment"),
                      onTap: () async => vps.shareComment(comment)),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text("Go to author page"),
                    onTap: () => vps.openCommentAuthor(comment),
                  ),
                  ListTile(
                      leading: const Icon(Icons.bug_report),
                      title: const Text("Create bug report"),
                      onTap: () => vps.createManualBugReportForComment(comment))
                ],
              );
            });
      },
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Skeleton.shade(
          child: ClipOval(
            child: Container(
              width: 40,
              height: 40,
              color: Theme.of(context).colorScheme.tertiary,
              child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                      onTap: () => vps.openCommentAvatarInFullscreen(comment),
                      child: Image.network(
                        comment.profilePicture ?? "",
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.onTertiary,
                        ),
                      ))),
            ),
          ),
        ),
        title: Text(
            "${comment.hidden ? "(hidden comment) " : ""}${comment.author} • ${getTimeDeltaInHumanReadable(comment.commentDate)} ago",
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: comment.hidden
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            comment.commentBody,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 5),
          Row(children: [
            Row(children: [
              Skeleton.shade(
                  child: Icon(
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      Icons.thumb_up)),
              const SizedBox(width: 5),
              Text(
                  vps.isLoadingComments
                      ? "3000 | 300"
                      : comment.ratingsPositiveTotal != null &&
                              comment.ratingsNegativeTotal != null
                          ? "${convertNumberIntoHumanReadable(comment.ratingsPositiveTotal!)} "
                              "| ${convertNumberIntoHumanReadable(comment.ratingsNegativeTotal!)}"
                          : "${comment.ratingsTotal}",
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(width: 5),
              Skeleton.shade(
                  child: Icon(
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      Icons.thumb_down))
            ]),
            if ((comment.replyComments?.isNotEmpty ?? false) &&
                !hideRepliesCounter) ...[
              const SizedBox(width: 15),
              TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.all(0),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(children: [
                    Skeleton.shade(
                        child: Icon(
                            size: 16,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            Icons.comment)),
                    const SizedBox(width: 5),
                    Text(
                        vps.isLoadingComments
                            ? "10"
                            : convertNumberIntoHumanReadable(
                                comment.replyComments!.length),
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ]),
                  onPressed: () => vps.openReplyCommentSection(comment.iD)),
            ],
          ])
        ]),
        isThreeLine: true,
      ));
}

List<Widget> buildVideoSuggestions(
    BuildContext context, VideoPlayerScreenState vps) {
  return [
    FloatingDynamicSliverHeader(
        pinned: true,
        floating: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  "Related videos from ${vps.videoMetadata.plugin?.prettyName ?? ""}:",
                  style: vps.isMobile
                      ? Theme.of(context).textTheme.titleMedium!
                      : Theme.of(context).textTheme.bodyMedium!),
              Spacer(),
              if (vps.loadingHandler.videoSuggestionsBugReports.isNotEmpty &&
                  !vps.isLoadingMetadata) ...[
                IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                        color: Theme.of(context).colorScheme.error,
                        Icons.error_outline),
                    onPressed: () => vps.createSuggestionVideosBugReport())
              ]
            ]))),
    VideoList(
        videoList: vps.videoSuggestions,
        scrollController: vps.screenScrollController,
        onVideoTap: () => vps.videoPlayerWidgetKey.currentState?.pausePlayer(),
        loadMoreResults: vps.loadMoreResults,
        noResultsMessage: "No video suggestions found",
        noResultsErrorMessage: "Error getting video suggestions",
        showScrapingReportButton: true,
        bugReports: vps.loadingHandler.videoSuggestionsBugReports,
        ignoreInternetError: false,
        noListPadding: true,
        overrideListViewTo: "Card")
  ];
}
