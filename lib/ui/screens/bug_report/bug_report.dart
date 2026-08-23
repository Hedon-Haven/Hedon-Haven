import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hedon_haven/utils/exceptions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '/services/analytics_manager.dart' as analytics;
import '/services/bug_report_manager.dart';
import '/services/plugin_manager.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/widgets/alert_dialog.dart';
import '/utils/global_vars.dart';
import '/utils/plugin_interface/plugin_interface.dart';
import 'bug_reports_list.dart';

class BugReportScreen extends StatefulWidget {
  final List<BugReport> bugReportsList;
  final SubmissionType submissionType;
  final bool unexpectedError;

  const BugReportScreen(
      {super.key,
      required this.bugReportsList,
      required this.submissionType,
      bool? unexpectedError})
      : unexpectedError = unexpectedError ?? false;

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen>
    with WidgetsBindingObserver {
  TextEditingController appInfoController = TextEditingController();
  TextEditingController userInputController = TextEditingController();
  bool allowPop = false;
  late List<BugReport> bugReportsList;
  List<BugReport> submittedBugReports = [];

  Completer<void>? _appResumedCompleter;

  late ({
    List<BugReport>? appReports,
    Map<String, List<BugReport>>? bundledPluginGroups,
    Map<String, List<BugReport>>? thirdPartyPluginGroups
  }) groupedBugReports;

  @override
  initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Remove all ProviderException BugReports
    bugReportsList = widget.bugReportsList
        .where((report) => report.exception is! ProviderException)
        .toList();
    groupedBugReports = groupBugReports(bugReportsList);
    if (bugReportsList.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showEmptyWarning();
      });
    }
    if (widget.unexpectedError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showUnexpectedErrorWarning();
      });
    }
    appInfoController.text = getAppAndDeviceInfo()
        .entries
        .map((e) => "${e.key}: ${e.value}")
        .join("\n")
        .trim();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appResumedCompleter?.complete();
    }
  }

  void showEmptyWarning() {
    showDialog(
        context: context,
        builder: (BuildContext context) => ThemedDialog(
            title: "Create empty bug report?",
            primaryText: "Continue",
            onPrimary: () => Navigator.of(context).pop(),
            secondaryText: "Cancel report",
            onSecondary: () {
              // Close dialog
              Navigator.of(context).pop();
              // Go back a screen
              Navigator.of(context).pop(<BugReport>[]);
            },
            content: const Text(
                "Long press anything in the app to create a more specific "
                "bug report.\n\n"
                "Ignore this message if you want to create a suggestion.")));
  }

  void showUnexpectedErrorWarning() {
    showDialog(
        context: context,
        builder: (BuildContext context) => ThemedDialog(
            title: "An unexpected error has occurred",
            primaryText: "Continue",
            onPrimary: () => Navigator.of(context).pop(),
            secondaryText: "Cancel report",
            onSecondary: () {
              // Close dialog
              Navigator.of(context).pop();
              // Go back a screen
              Navigator.of(context).pop(<BugReport>[]);
            },
            content: const Text(
                "An unexpected error has occurred in the app. Please submit "
                "this bug report to help fix it. Check the "
                "\"App bug reports\" section for more details.")));
  }

  void handlePop(bool goingToPop) {
    if (!goingToPop) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return ThemedDialog(
              title: "Cancel bug report?",
              primaryText: "Stay",
              onPrimary: () => Navigator.of(context).pop(),
              secondaryText: "Cancel bug report",
              onSecondary: () {
                allowPop = true;
                // close popup
                Navigator.of(context).pop();
                // Go back a screen
                Navigator.of(context).pop(<BugReport>[]);
              },
            );
          });
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  String combinedReport({bool includeThirdParty = false}) {
    return JsonEncoder.withIndent("  ")
        .convert(combinedReportMap(includeThirdParty: includeThirdParty));
  }

  Map<String, dynamic> combinedReportMap({bool includeThirdParty = false}) {
    return {
      "appInfo": getAppAndDeviceInfo(),
      "userMessage": userInputController.text,
      "submissionType": widget.submissionType,
      "bugReports": {
        if (groupedBugReports.appReports?.isNotEmpty ?? false)
          "appReports": groupedBugReports.appReports,
        if (groupedBugReports.bundledPluginGroups?.isNotEmpty ?? false)
          "bundledPluginBugReports": groupedBugReports
              .bundledPluginGroups?.values
              .expand((e) => e)
              .toList(),
        if (includeThirdParty &&
            (groupedBugReports.thirdPartyPluginGroups?.isNotEmpty ?? false))
          "thirdPartyPluginBugReports": groupedBugReports
              .thirdPartyPluginGroups?.values
              .expand((e) => e)
              .toList(),
      }
    };
  }

  Future<void> copyCombinedReport() async {
    await Clipboard.setData(
        ClipboardData(text: combinedReport(includeThirdParty: true)));
    showToast("Entire bug report copied to clipboard as JSON", context);
  }

  void showRawDialog() async {
    showDialog(
        context: context,
        builder: (BuildContext context) => ThemedDialog(
            title: "Bug report in JSON form",
            primaryText: "Close",
            onPrimary: () => Navigator.pop(context),
            secondaryText: "Copy",
            onSecondary: () => copyCombinedReport(),
            content: SingleChildScrollView(
                child: Column(
                    spacing: 10,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                    padding: const EdgeInsets.all(5.0),
                    child: SelectableText(
                        combinedReport(includeThirdParty: true),
                        style: Theme.of(context).textTheme.bodyMedium),
                  )
                ]))));
  }

  Future<bool> showSubmitOptionsDialog() async {
    return await showDialog(
        context: context,
        builder: (BuildContext context) => ThemedDialog(
            title: "Submit to Hedon Haven developers",
            primaryText: "Cancel",
            onPrimary: () => Navigator.pop(context, false),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                title: Text("Submit anonymously"),
                subtitle: Text("https://eu.posthog.com"),
                leading: Icon(Icons.person_off),
                onTap: () async {
                  bool submitted =
                      await analytics.submitBugReport(combinedReportMap());
                  if (context.mounted) Navigator.pop(context, submitted);
                },
              ),
              ListTile(
                title: Text("Submit via email"),
                subtitle: Text("contact@hedon-haven.top"),
                leading: Icon(Icons.email),
                onTap: () async {
                  _appResumedCompleter = Completer<void>();
                  bool submittedReport = await launchUrl(Uri(
                      scheme: "mailto",
                      path: "contact@hedon-haven.top",
                      query: _encodeQueryParameters(<String, String>{
                        "subject": "Bug report",
                        "body": combinedReport()
                      })));
                  if (submittedReport) {
                    // wait for user to return
                    await _appResumedCompleter!.future;
                    _appResumedCompleter = null;
                  }
                  if (context.mounted) Navigator.pop(context, submittedReport);
                },
              ),
              ListTile(
                title: Text("Create issue in issue tracker"),
                subtitle: Text("https://issues.hedon-haven.top"),
                leading: Icon(Icons.bug_report),
                onTap: () async {
                  await copyCombinedReport();
                  _appResumedCompleter = Completer<void>();
                  bool submittedReport = await launchUrl(
                      Uri.parse("https://issues.hedon-haven.top"));
                  if (submittedReport) {
                    // wait for user to return
                    await _appResumedCompleter!.future;
                    _appResumedCompleter = null;
                  }
                  if (context.mounted) Navigator.pop(context, submittedReport);
                },
              )
            ])));
  }

  Future<bool> showThirdPartySubmitOptionsDialog(
      List<BugReport> bugReports) async {
    // Get Plugin from the first bug report
    String pluginCodeName =
        (bugReports.first as PluginBugReport).pluginCodeName;
    PluginInterface? plugin =
        await PluginManager.getPluginByName(pluginCodeName);
    if (plugin == null && mounted) {
      await showDialog(
          context: context,
          builder: (BuildContext context) => ThemedDialog(
              title: "Plugin not found",
              primaryText: "Ok",
              onPrimary: () => Navigator.pop(context, false),
              content: Text("Could not find third party plugin with"
                  " codeName: $pluginCodeName. It might not be installed "
                  "anymore. Cannot submit bug report!")));
      return false;
    }
    return await showDialog(
        context: context,
        builder: (BuildContext context) => ThemedDialog(
            title: "Submit to third party developers",
            primaryText: "Cancel",
            onPrimary: () => Navigator.pop(context, false),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text("Submit ${bugReports.length} "
                  "${bugReports.length == 1 ? "bug report" : "bug reports"} "
                  "to the ${plugin!.prettyName} "
                  "developer ${plugin.developer}:"),
              const SizedBox(height: 10),
              ListTile(
                title: Text("Submit via email"),
                subtitle: Text(plugin.contactEmail),
                leading: Icon(Icons.email),
                onTap: () async {
                  _appResumedCompleter = Completer<void>();
                  bool submittedReport = await launchUrl(Uri(
                      scheme: "mailto",
                      path: plugin.contactEmail,
                      query: _encodeQueryParameters(<String, String>{
                        "subject": "${plugin.prettyName} Hedon Haven "
                            "plugin bug report",
                        "body": combinedReport(includeThirdParty: true)
                      })));
                  if (submittedReport) {
                    // wait for user to return
                    await _appResumedCompleter!.future;
                    _appResumedCompleter = null;
                  }
                  if (context.mounted) Navigator.pop(context, submittedReport);
                },
              ),
              ListTile(
                title: Text("Create issue in third party tracker"),
                subtitle: Text(plugin.issueTrackerUrl),
                leading: Icon(Icons.bug_report),
                onTap: () async {
                  await copyCombinedReport();
                  _appResumedCompleter = Completer<void>();
                  bool submittedReport =
                      await launchUrl(Uri.parse(plugin.issueTrackerUrl));
                  if (submittedReport) {
                    // wait for user to return
                    await _appResumedCompleter!.future;
                    _appResumedCompleter = null;
                  }
                  if (context.mounted) Navigator.pop(context, submittedReport);
                },
              )
            ])));
  }

  void submitReports() async {
    if ((groupedBugReports.appReports?.isNotEmpty ?? false) ||
        (groupedBugReports.bundledPluginGroups?.isNotEmpty ?? false)) {
      if (await showSubmitOptionsDialog()) {
        submittedBugReports.addAll(groupedBugReports.appReports ?? []);
        submittedBugReports.addAll(groupedBugReports.bundledPluginGroups?.values
                .expand((x) => x)
                .toList() ??
            []);
        // Remove submitted reports from UI
        setState(() => groupedBugReports = (
              appReports: [],
              bundledPluginGroups: {},
              thirdPartyPluginGroups: groupedBugReports.thirdPartyPluginGroups
            ));
      }
    }

    if (groupedBugReports.thirdPartyPluginGroups?.isNotEmpty ?? false) {
      for (var reportGroup
          in groupedBugReports.thirdPartyPluginGroups!.values) {
        if (await showThirdPartySubmitOptionsDialog(reportGroup)) {
          submittedBugReports.addAll(reportGroup);
          // Remove submitted reports from UI
          setState(() => groupedBugReports = (
                appReports: groupedBugReports.appReports,
                bundledPluginGroups: groupedBugReports.bundledPluginGroups,
                thirdPartyPluginGroups: {}
              ));
        }
      }
    }

    if (submittedBugReports.isNotEmpty && mounted) {
      logger.i("Returning ${submittedBugReports.length} submitted bug reports");
      showToast("Thank you for submitting the bug reports!", context);
      Navigator.of(context).pop(submittedBugReports);
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalAppReports = groupedBugReports.appReports?.length ?? 0;
    int totalBundledPluginReports = groupedBugReports
            .bundledPluginGroups?.values
            .fold<int>(0, (sum, list) => sum + list.length) ??
        0;
    int totalThirdPartyPluginReports = groupedBugReports
            .thirdPartyPluginGroups?.values
            .fold<int>(0, (sum, list) => sum + list.length) ??
        0;
    return PopScope(
        canPop: allowPop,
        onPopInvokedWithResult: (goingToPop, _) => handlePop(goingToPop),
        child: Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(widget.unexpectedError
                  ? "Unexpected error Bug Report"
                  : "Bug Report"),
            ),
            body: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.only(
                        left: 20, right: 20, top: 10, bottom: 40),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("App info: ",
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 5),
                          buildAppInfoField(),
                          const SizedBox(height: 15),
                          if (totalAppReports > 0)
                            ListTile(
                                title:
                                    Text("App bug reports ($totalAppReports)"),
                                trailing: const Icon(Icons.arrow_forward),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 0),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        settings: RouteSettings(
                                            name: "/bug_reports_list"),
                                        builder: (context) =>
                                            BugReportsListScreen(
                                              bugReportsList:
                                                  groupedBugReports.appReports!,
                                            )))),
                          if (totalBundledPluginReports > 0)
                            ListTile(
                                title: Text(
                                    "Bundled plugin bug reports ($totalBundledPluginReports)"),
                                trailing: const Icon(Icons.arrow_forward),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 0),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        settings: RouteSettings(
                                            name: "/bug_reports_list"),
                                        builder: (context) =>
                                            BugReportsListScreen(
                                              bugReportsList: groupedBugReports
                                                  .bundledPluginGroups!.values
                                                  .expand((list) => list)
                                                  .toList(),
                                            )))),
                          if (totalThirdPartyPluginReports > 0)
                            ListTile(
                                title: Text(
                                    "Third party plugin bug reports ($totalThirdPartyPluginReports)"),
                                trailing: const Icon(Icons.arrow_forward),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 0),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        settings: RouteSettings(
                                            name: "/bug_reports_list"),
                                        builder: (context) =>
                                            BugReportsListScreen(
                                              bugReportsList: groupedBugReports
                                                  .thirdPartyPluginGroups!
                                                  .values
                                                  .expand((list) => list)
                                                  .toList(),
                                            )))),
                          const SizedBox(height: 10),
                          Text("Additional details: ",
                              style: Theme.of(context).textTheme.titleMedium),
                          buildUserMessageField(),
                          Spacer(),
                          buildActionButtons()
                        ])))));
  }

  Widget buildAppInfoField() {
    return TextFormField(
        controller: appInfoController,
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
                const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
            enabledBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.onSurface)),
            focusedBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.onSurface)),
            border: OutlineInputBorder(
                borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface))));
  }

  Widget buildUserMessageField() {
    return TextField(
        controller: userInputController,
        maxLines: null,
        minLines: 3,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceVariant,
          contentPadding: const EdgeInsets.all(5),
          hintText: "Any other relevant context for the problem: ",
          border: const OutlineInputBorder(),
          disabledBorder: OutlineInputBorder(
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.primary),
          ),
        ));
  }

  Widget buildActionButtons() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(
          style: IconButton.styleFrom(
              backgroundColor:
                  Theme.of(context).colorScheme.secondaryContainer),
          icon: Icon(Icons.raw_on,
              color: Theme.of(context).colorScheme.onSecondaryContainer),
          onPressed: () => showRawDialog()),
      ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () => submitReports(),
          child: Text(
              bugReportsList.length > 1
                  ? "Submit bug reports"
                  : "Submit bug report",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(color: Theme.of(context).colorScheme.onPrimary))),
      IconButton(
          style: IconButton.styleFrom(
              backgroundColor:
                  Theme.of(context).colorScheme.secondaryContainer),
          icon: Icon(Icons.copy_all,
              color: Theme.of(context).colorScheme.onSecondaryContainer),
          onPressed: () => copyCombinedReport())
    ]);
  }
}
