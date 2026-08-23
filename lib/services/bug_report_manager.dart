import 'dart:io';
import 'dart:ui';

import 'package:system_info2/system_info2.dart';

import '/utils/global_vars.dart';

Map<String, String> getAppAndDeviceInfo() {
  final view = PlatformDispatcher.instance.views.first;
  return {
    "packageName": packageInfo.packageName,
    "version": packageInfo.version,
    "installerStore": packageInfo.installerStore ?? "Unknown",
    "buildSignature": packageInfo.buildSignature,
    "operatingSystem": Platform.operatingSystem,
    "architecture": SysInfo.kernelArchitecture.toString().toLowerCase(),
    "operatingSystemVersion": Platform.operatingSystemVersion,
    "resolution": "raw: ${view.physicalSize}, "
        "logical: ${view.physicalSize / view.devicePixelRatio}"
  };
}

/// Process raw list of bug reports into 3 categories
({
  List<BugReport>? appReports,
  Map<String, List<BugReport>>? bundledPluginGroups,
  Map<String, List<BugReport>>? thirdPartyPluginGroups
}) groupBugReports(List<BugReport> reports) {
  final Map<String, List<BugReport>> bundledPluginGroups = {};
  final Map<String, List<BugReport>> thirdPartyPluginGroups = {};
  final List<BugReport> appReports = [];

  for (final report in reports) {
    if (report is PluginBugReport) {
      if (report.isBundledPlugin) {
        bundledPluginGroups
            .putIfAbsent(report.pluginCodeName, () => [])
            .add(report);
      } else {
        thirdPartyPluginGroups
            .putIfAbsent(report.pluginCodeName, () => [])
            .add(report);
      }
    } else {
      appReports.add(report);
    }
  }

  return (
    appReports: appReports,
    bundledPluginGroups: bundledPluginGroups,
    thirdPartyPluginGroups: thirdPartyPluginGroups,
  );
}

/// How the bug report was submitted
/// automatic: Report was created and submitted fully automatically without user interaction
/// userApproved: Report was created automatically and sent after user approval
/// manual: Report was created and submitted fully manually by the user
enum SubmissionType {
  automatic,
  userApproved,
  manual;

  String toJson() => name;
}

class BugReport {
  /// Full navigator path including the screen where the bug occurred
  final String navigatorPath;

  /// The exception object with the error message string
  final Exception exception;

  /// Whether the error is a custom exception from utils/exceptions.dart
  final bool isCustomException;

  /// Full stack trace of the error
  final String? codeTrace;

  BugReport(
      {required this.navigatorPath,
      required this.exception,
      required this.isCustomException,
      this.codeTrace});

  Map<String, dynamic> toMap() => {
        "navigatorPath": navigatorPath,
        "exception": exception,
        "isCustomException": isCustomException,
        "codeTrace": codeTrace,
      };

  Map<String, dynamic> toJson() => toMap();
}

/// For bugs that were caused in plugins (bundled or third-party)
class PluginBugReport extends BugReport {
  final String pluginCodeName;

  /// For 3rd party plugins the contact email is used to send the report
  /// For bundled plugins the bug report is sent the same way as an app bug
  final bool isBundledPlugin;

  /// Scraped Universal-class object
  Map<String, dynamic> debugObject;

  /// Request that caused bug report converted to a map
  final Map<String, String>? requestMap;

  /// The entire html that failed to be scraped
  final String? scrapedHTML;

  PluginBugReport(
      {required super.navigatorPath,
      required super.exception,
      required super.isCustomException,
      super.codeTrace,
      required this.pluginCodeName,
      required this.isBundledPlugin,
      required this.debugObject,
      this.requestMap,
      this.scrapedHTML});

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        "pluginCodename": pluginCodeName,
        "isBundledPlugin": isBundledPlugin,
        "debugObject": debugObject,
        "requestMap": requestMap,
        "scrapedHTML": scrapedHTML,
      };
}
