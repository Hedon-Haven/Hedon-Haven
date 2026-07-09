/// Analytics are collected entirely anonymously
/// All data is sent to PostHog, where both IP collection and GeoIP lookups are disabled
/// Whenever an ID is needed, the analytics_salt is used to create a non-reversible unique ID
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart';

import '/services/bug_report_manager.dart';
import '/utils/global_vars.dart';

Future<bool> submitBugReport(
    {String? userMessage,
    List<BugReport>? appReports,
    List<BugReport>? bundledPluginReports}) async {
  // No need to use the salt here, since we just need a random id for this report
  String randomID =
      List.generate(12, (_) => Random.secure().nextInt(16).toRadixString(16))
          .join();
  String body = jsonEncode({
    "api_key": "phc_sGppPfQfhdrzQCWRG4BiTaFm6y5XPYE5x36EiQrSGN7w",
    "event": "bug_report",
    "distinct_id": randomID,
    "properties": {
      // Create anonymous report
      r"$process_person_profile": false,
      "appInfo": getAppInfo(),
      "userMessage": userMessage,
      "bugReports": {
        if (appReports?.isNotEmpty ?? false)
          "appReports": appReports!.map((x) => x.toMap()).toList(),
        if (bundledPluginReports?.isNotEmpty ?? false)
          "bundledPluginBugReports":
              bundledPluginReports!.map((x) => x.toMap()).toList()
      }
    },
  });

  logger.i("Sending bug reports to PostHot with body $body");
  Response response = await client.post(
      Uri.parse("https://eu.i.posthog.com/i/v0/e/"),
      headers: {"Content-Type": "application/json"},
      body: body);
  logger.i("Bug report analytics response: ${response.body}");
  if (response.statusCode != 200) {
    logger.e("Failed to send bug reports to PostHot: "
        "${response.statusCode} - ${response.body}");
  }
  return response.statusCode == 200;
}

/// Send a usage ping in a privacy-preserving way:
/// A local salt + current day are used to create per-day unique IDs to avoid
/// a single user appearing as multiple reports in analytics
Future<void> sendUsagePing() async {
  // Only send ping if opted-in by user
  if (!(await sharedStorage.getBool("analytics_enable_usage_ping") ?? false)) {
    logger.i("Usage ping not opted-in, not sending!");
    return;
  }
  logger.i("Sending usage ping to PostHot");
  String salt = (await sharedStorage.getString("analytics_salt"))!;
  // Extract the current date with day-precision (i.e. strip hours and minutes)
  final now = DateTime.now().toUtc();
  // @formatter:off
  final today = DateTime.utc(now.year, now.month, now.day, 0, 0, 0, 0, 0);
  // @formatter:on

  // Generate per-day unique ID
  final uniqueID = sha256
      .convert(utf8.encode(salt + today.toIso8601String().substring(0, 10)))
      .toString();

  String body = jsonEncode({
    "api_key": "phc_sGppPfQfhdrzQCWRG4BiTaFm6y5XPYE5x36EiQrSGN7w",
    "event": "usage_ping",
    "distinct_id": uniqueID,
    "properties": {
      // Create anonymous ping
      r"$process_person_profile": false,
      "appInfo": getAppInfo(),
    }
  });

  Response response = await client.post(
      Uri.parse("https://eu.i.posthog.com/i/v0/e/"),
      headers: {"Content-Type": "application/json"},
      body: body);
  logger.i("Usage ping analytics response: ${response.body}");
  if (response.statusCode != 200) {
    logger.e("Failed to send usage ping to PostHot: "
        "${response.statusCode} - ${response.body}");
  }
  return;
}
