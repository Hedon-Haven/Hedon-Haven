import 'package:material_ui/material_ui.dart';

import '/services/database_manager.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/widgets/options_switch.dart';
import '/utils/global_vars.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("History"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: <Widget>[
                    FutureBuilder<bool?>(
                        future: sharedStorage.getBool("history_watch"),
                        builder: (context, snapshot) {
                          return OptionsSwitch(
                              title: "Enable watch history",
                              subTitle: "Keep track of watched videos",
                              switchState: snapshot.data ?? true,
                              onToggled: (value) => sharedStorage.setBool(
                                  "history_watch", value));
                        }),
                    ListTile(
                        trailing: const Icon(Icons.clear),
                        title: const Text("Clear watch history"),
                        onTap: () {
                          deleteAllFrom("watch_history");
                          showToast("Watch history cleared", context);
                        }),
                    FutureBuilder<bool?>(
                        future: sharedStorage.getBool("history_search"),
                        builder: (context, snapshot) {
                          return OptionsSwitch(
                              title: "Enable search history",
                              subTitle: "Keep track of search queries",
                              switchState: snapshot.data ?? true,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("history_search", value));
                        }),
                    ListTile(
                        trailing: const Icon(Icons.clear),
                        title: const Text("Clear search history"),
                        onTap: () {
                          deleteAllFrom("search_history");
                          showToast("Search history cleared", context);
                        }),
                    ListTile(
                        trailing: const Icon(Icons.clear),
                        title: const Text("Delete all favorites"),
                        onTap: () {
                          deleteAllFrom("favorites");
                          showToast("All favorites deleted", context);
                        }),
                  ],
                ))));
  }
}
