import 'package:flutter/material.dart';

import '/services/database_manager.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/widgets/alert_dialog.dart';
import '/utils/global_vars.dart';
import '/utils/universal_formats.dart';
import 'video_list.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  Future<List<UniversalVideoPreview>> videoResults = Future.value([]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(4),
                          child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              tileColor:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              leading: Icon(Icons.history),
                              trailing: Icon(Icons.arrow_forward),
                              title: Text("History"),
                              textColor: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              titleTextStyle: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(fontWeight: FontWeight.bold),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      settings: RouteSettings(name: "/settings_history"),
                                      builder: (context) =>
                                          const HistoryScreen())))),
                      Padding(
                          padding: const EdgeInsets.all(4),
                          child: ListTile(
                            tileColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            leading: Icon(Icons.star),
                            trailing: Icon(Icons.arrow_forward),
                            title: Text("Favorites"),
                            textColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    settings: RouteSettings(name: "/favorites_list"),
                                    builder: (context) =>
                                        const FavoritesScreen())),
                          )),
                      Padding(
                          padding: const EdgeInsets.all(4),
                          child: ListTile(
                            tileColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            leading: Icon(Icons.download),
                            trailing: Icon(Icons.arrow_forward),
                            title: Text("Downloads"),
                            textColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            onTap: () => showToast(
                                "Downloads not yet implemented", context),
                          ))
                    ]))));
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Key videoListKey = UniqueKey();
  bool clearedHistory = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        actions: [
          IconButton(
            icon: Icon(
                color: Theme.of(context).colorScheme.primary,
                Icons.delete_sweep),
            onPressed: () async {
              await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return ThemedDialog(
                      title: "Clear entire watch history?",
                      primaryText: "Continue",
                      onPrimary: () async {
                        await deleteAllFrom("watch_history");
                        clearedHistory = true;
                        Navigator.of(context).pop();
                      },
                      secondaryText: "Cancel",
                      onSecondary: Navigator.of(context).pop,
                    );
                  });
              if (clearedHistory) {
                logger.i("Forcing rebuild of VideoList");
                // Force rebuild of VideoList by changing the key and forcing flutter to create a new VideoList
                videoListKey = UniqueKey();
                clearedHistory = false;
              }
              setState(() {});
            },
          )
        ],
      ),
      body: SafeArea(
          child: CustomScrollView(slivers: [
        VideoList(
            // This key is needed to force rebuild the VideoList widget when history is cleared
            key: videoListKey,
            scrollController: ScrollController(),
            videoList: getWatchHistory(),
            deleteVideo: removeFromWatchHistory,
            noResultsMessage: "No watch history yet",
            noResultsErrorMessage: "Watch history disabled",
            playPreviews: false,
            useNetworkThumbnails: false)
      ])),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Key videoListKey = UniqueKey();
  bool clearedFavorites = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        actions: [
          IconButton(
            icon: Icon(
                color: Theme.of(context).colorScheme.primary,
                Icons.delete_sweep),
            onPressed: () async {
              await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return ThemedDialog(
                      title: "Clear all favorites?",
                      primaryText: "Continue",
                      onPrimary: () async {
                        await deleteAllFrom("favorites");
                        clearedFavorites = true;
                        Navigator.of(context).pop();
                      },
                      secondaryText: "Cancel",
                      onSecondary: Navigator.of(context).pop,
                    );
                  });
              if (clearedFavorites) {
                logger.i("Forcing rebuild of VideoList");
                // Force rebuild of VideoList by changing the key and forcing flutter to create a new VideoList
                videoListKey = UniqueKey();
                clearedFavorites = false;
              }
              setState(() {});
            },
          )
        ],
      ),
      body: SafeArea(
          child: CustomScrollView(slivers: [
        VideoList(
            scrollController: ScrollController(),
            // This key is needed to force rebuild the VideoList widget when favorites are cleared
            key: videoListKey,
            videoList: getFavorites(),
            deleteVideo: removeFromFavorites,
            noResultsMessage: "No favorites yet",
            noResultsErrorMessage:
                "Error getting favorites. Please report this to the developers",
            playPreviews: false,
            useNetworkThumbnails: false)
      ])),
    );
  }
}

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        actions: const [],
      ),
      body: SafeArea(child: Text("Downloads coming soon")),
    );
  }
}
