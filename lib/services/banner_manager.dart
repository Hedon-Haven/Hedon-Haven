import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

import '/ui/utils/toast_notification.dart';
import '/utils/global_vars.dart';

Future<({String severity, String title, String message})?> getBanner(
    BuildContext context) async {
  try {
    final yamlRaw = (await client
            .get(Uri.parse("https://banner.hedon-haven.top/banner.yaml")))
        .body;
    YamlMap yaml = loadYaml(yamlRaw);

    // Show version specific message if it exists
    YamlMap? override = yaml['overrides']?[packageInfo.version];
    var bannerRecord = (
      severity: (override?["severity"] ?? yaml["severity"]) as String,
      title: (override?["title"] ?? yaml["title"]) as String,
      message: (override?["message"] ?? yaml["message"]) as String
    );
    logger.i("Displaying banner with: $bannerRecord");
    return bannerRecord;
  } catch (e) {
    logger.e("Error getting banner: $e");
    if (context.mounted) showToast("Error getting banner: $e", context);
    return null;
  }
}
