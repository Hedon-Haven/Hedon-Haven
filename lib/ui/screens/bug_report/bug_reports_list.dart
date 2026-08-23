import 'dart:convert';

import 'package:hedon_haven/ui/utils/toast_notification.dart';
import 'package:material_ui/material_ui.dart';

import '/services/bug_report_manager.dart';
import '/services/plugin_manager.dart';
import '/utils/exceptions.dart';
import '/utils/global_vars.dart';
import '/utils/plugin_interface/plugin_interface.dart';
import 'bug_report.dart';

class BugReportsListScreen extends StatefulWidget {
  final List<BugReport> bugReportsList;
  final bool scrapingReportMode;

  const BugReportsListScreen(
      {super.key, required this.bugReportsList, bool? scrapingReportMode})
      : scrapingReportMode = scrapingReportMode ?? false;

  @override
  State<BugReportsListScreen> createState() => _BugReportsListScreenState();
}

class _BugReportsListScreenState extends State<BugReportsListScreen> {
  /// Concatenated list of all bug reports
  late Map<String, List<BugReport>> sortedBugReports;
  bool enableReportButton = false;

  @override
  void initState() {
    super.initState();
    final groupedReports = groupBugReports(widget.bugReportsList);
    sortedBugReports = {
      if (groupedReports.appReports?.isNotEmpty ?? false)
        "App bug reports": groupedReports.appReports!,
      ...?groupedReports.bundledPluginGroups,
      ...?groupedReports.thirdPartyPluginGroups
    };

    if (widget.scrapingReportMode) {
      // Enable report button only if non-CustomExceptions are in the list
      enableReportButton =
          widget.bugReportsList.any((r) => r.exception is! CustomException);
      logger.i("Bug report button enabled: $enableReportButton");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            iconTheme:
                IconThemeData(color: Theme.of(context).colorScheme.primary),
            title: Text(
                widget.scrapingReportMode
                    ? "Scraping report"
                    : "Included bug reports",
                style: Theme.of(context).textTheme.headlineLarge)),
        floatingActionButtonLocation: widget.scrapingReportMode
            ? FloatingActionButtonLocation.centerFloat
            : null,
        floatingActionButton:
            widget.scrapingReportMode ? buildFloatingButton() : null,
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.all(8),
                // Display AppReports directly without nesting
                children: (sortedBugReports.keys.length == 1 &&
                        sortedBugReports.keys.first == "App bug reports")
                    ? sortedBugReports.values.first
                        .map(buildReportTile)
                        .toList()
                    : sortedBugReports.entries.map(buildGroupTile).toList())));
  }

  Widget buildFloatingButton() {
    return FloatingActionButton.extended(
      backgroundColor: enableReportButton
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
      foregroundColor: enableReportButton
          ? Theme.of(context).colorScheme.onPrimary
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
      // reduce padding around text
      extendedPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
      label: Text("Create bug report"),
      onPressed: () async {
        if (!enableReportButton) {
          showToast("Nothing to report, all issues were external site problems",
              context);
          return;
        }
        List<BugReport> submittedReports = await Navigator.push(
          context,
          MaterialPageRoute(
            settings: RouteSettings(name: "/bug-report"),
            builder: (context) => BugReportScreen(
                submissionType: SubmissionType.userApproved,
                bugReportsList: widget.bugReportsList),
          ),
        );
        // Close Scraping report on successful return
        if (mounted && submittedReports.isNotEmpty) {
          Navigator.of(context).pop(submittedReports);
        }
      },
    );
  }

  Widget buildGroupTile(MapEntry<String, List<BugReport>> bugReportGroup) {
    return FutureBuilder<PluginInterface?>(
        future: PluginManager.getPluginByName(bugReportGroup.key),
        builder: (context, snapshot) {
          // Simplify display for CustomExceptions
          if (bugReportGroup.value.length == 1 &&
              bugReportGroup.value.first.exception is CustomException) {
            String titleText =
                "${snapshot.data?.prettyName ?? bugReportGroup.key}"
                ": "
                "${(bugReportGroup.value.first.exception as CustomException).title}";

            return ListTile(
              title: Text(titleText),
              subtitle: Text(bugReportGroup.value.first.exception.toString()),
              // Remove white lines
              shape: RoundedRectangleBorder(),
              contentPadding: const EdgeInsets.only(left: 16, right: 8),
            );
          }

          return ExpansionTile(
            title: Text(bugReportGroup.key == "appReports"
                ? "App bug reports"
                : snapshot.data?.prettyName ?? bugReportGroup.key),
            controlAffinity: ListTileControlAffinity.trailing,
            // Remove white lines
            collapsedShape: RoundedRectangleBorder(),
            shape: RoundedRectangleBorder(),
            tilePadding: const EdgeInsets.only(left: 16, right: 8),
            childrenPadding: const EdgeInsets.only(left: 16.0),
            children: List.generate(bugReportGroup.value.length,
                (index) => buildReportTile(bugReportGroup.value[index])),
          );
        });
  }

  Widget buildReportTile(BugReport report) {
    return ExpansionTile(
        title: Text(report.exception.toString()),
        controlAffinity: ListTileControlAffinity.trailing,
        // Remove white lines
        collapsedShape: RoundedRectangleBorder(),
        shape: RoundedRectangleBorder(),
        tilePadding: const EdgeInsets.only(left: 16, right: 8),
        children: [
          TextFormField(
              initialValue:
                  JsonEncoder.withIndent("    ").convert(report.toMap()),
              readOnly: true,
              maxLines: null,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
              ),
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 13),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.onSurface)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.onSurface)),
                  border: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.onSurface))))
        ]);
  }
}
