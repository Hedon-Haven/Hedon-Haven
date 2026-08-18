import 'dart:convert';

import 'package:flutter/material.dart';

import '/services/bug_report_manager.dart';
import '/services/plugin_manager.dart';
import '/utils/plugin_interface/plugin_interface.dart';

class ScrapingReportScreen extends StatefulWidget {
  final List<BugReport> bugReportsList;

  const ScrapingReportScreen({super.key, required this.bugReportsList});

  @override
  State<ScrapingReportScreen> createState() => _ScrapingReportScreenState();
}

class _ScrapingReportScreenState extends State<ScrapingReportScreen> {
  /// Concatenated list of all bug reports
  late Map<String, List<BugReport>> sortedBugReports;

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            iconTheme:
                IconThemeData(color: Theme.of(context).colorScheme.primary),
            title: Text("Included bug reports",
                style: Theme.of(context).textTheme.headlineLarge)),
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.all(8),
                children: List.generate(
                    sortedBugReports.isEmpty ? 1 : sortedBugReports.length,
                    (index) {
                  if (sortedBugReports.isEmpty) {
                    return Padding(
                        padding: const EdgeInsets.only(top: 50),
                        child: Center(
                            child: Text("No more scraping errors to report")));
                  } else {
                    return buildGroupTile(
                        sortedBugReports.entries.elementAt(index));
                  }
                }))));
  }

  Widget buildGroupTile(MapEntry<String, List<BugReport>> bugReportGroup) {
    return FutureBuilder<PluginInterface?>(
        future: PluginManager.getPluginByName(bugReportGroup.key),
        builder: (context, snapshot) {
          return ExpansionTile(
            title: Text(bugReportGroup.key == "appReports"
                ? "App bug reports"
                : snapshot.data?.prettyName ?? bugReportGroup.key),
            controlAffinity: ListTileControlAffinity.leading,
            // Remove white lines
            collapsedShape: RoundedRectangleBorder(),
            shape: RoundedRectangleBorder(),
            tilePadding: const EdgeInsets.only(left: 16, right: 8),
            childrenPadding: const EdgeInsets.only(left: 16.0),
            children: List.generate(bugReportGroup.value.length, (index) {
              return buildReportTile(bugReportGroup.value[index]);
            }),
          );
        });
  }

  Widget buildReportTile(BugReport report) {
    return ExpansionTile(
        title: Text(report.errorMessage),
        controlAffinity: ListTileControlAffinity.leading,
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
                  contentPadding: const EdgeInsets.all(5),
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
