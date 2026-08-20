import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:url_launcher/url_launcher.dart';

import '/ui/screens/settings/settings_plugins/settings_plugins.dart';
import '/ui/screens/settings/settings_privacy.dart';
import '/utils/global_vars.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static bool _didInit = false;

  @override
  void initState() {
    super.initState();

    // Guard against repeated executions caused by transitions
    if (_didInit) return;
    _didInit = true;

    sharedStorage
        .setBool("analytics_enable_usage_ping", true)
        .whenComplete(() => setState(() {}));
    sharedStorage
        .setBool("analytics_enable_automatic_bug_reports", true)
        .whenComplete(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Center(child: Text("Anonymous analytics")),
            // Don't show back button
            automaticallyImplyLeading: false),
        body: SafeArea(
            child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(
                              "Would you like to enable anonymous analytics to "
                              "help improve this app? All data is fully "
                              "anonymized before being sent, making it "
                              "impossible to identify any single user.",
                              style: Theme.of(context).textTheme.bodyMedium)),
                      Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(
                              "These settings can be adjusted anytime in "
                              "Settings > Privacy.",
                              style: Theme.of(context).textTheme.bodyMedium)),
                      Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: GestureDetector(
                              onTap: () => launchUrl(Uri.parse(
                                  "https://docs.hedon-haven.top/analytics.md")),
                              child: Text(
                                  "Read more: https://docs.hedon-haven.top/analytics.md",
                                  style:
                                      Theme.of(context).textTheme.bodyMedium))),
                      ...buildAnalyticsOptions(),
                      Spacer(),
                      Row(children: [
                        Align(
                            alignment: Alignment.bottomLeft,
                            child: ElevatedButton(
                                style: TextButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant),
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text("Back",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant)))),
                        Spacer(),
                        Align(
                            alignment: Alignment.bottomRight,
                            child: ElevatedButton(
                                style: TextButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary),
                                onPressed: () => Navigator.push(
                                    context,
                                    PageTransition(
                                        settings: RouteSettings(
                                            name: "/onboarding_plugins_list"),
                                        type: PageTransitionType
                                            .rightToLeftJoined,
                                        childCurrent: widget,
                                        child: PluginsScreen(
                                            partOfOnboarding: true))),
                                child: Text("Next",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary))))
                      ])
                    ]))));
  }
}
