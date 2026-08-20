import 'dart:io';

import 'package:flutter/material.dart';
import 'package:secure_app_switcher/secure_app_switcher.dart';
import 'package:url_launcher/url_launcher.dart';

import '/ui/utils/toast_notification.dart';
import '/ui/widgets/alert_dialog.dart';
import '/ui/widgets/options_switch.dart';
import '/utils/global_vars.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Privacy"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: <Widget>[
                    FutureBuilder<bool?>(
                        future:
                            sharedStorage.getBool("privacy_hide_app_preview"),
                        builder: (context, snapshot) {
                          return OptionsSwitch(
                              title: "Hide app preview",
                              subTitle: "Hide app preview in app switcher",
                              switchState: snapshot.data ?? true,
                              onToggled: (value) async {
                                await sharedStorage.setBool(
                                    "privacy_hide_app_preview", value);
                                // Force an immediate update
                                if (Platform.isAndroid || Platform.isIOS) {
                                  if (!value) {
                                    SecureAppSwitcher.off();
                                  } else {
                                    SecureAppSwitcher.on();
                                  }
                                }
                                // the hidePreview var is from main.dart
                                setState(() => hidePreview = value);
                              });
                        }),
                    FutureBuilder<bool?>(
                        future: sharedStorage
                            .getBool("privacy_keyboard_incognito_mode"),
                        builder: (context, snapshot) {
                          return OptionsSwitch(
                              title: "Enable keyboard incognito mode",
                              subTitle:
                                  "Instruct keyboard app to enable incognito mode (e.g. disable auto-suggest, learning of new words, etc.)",
                              switchState: snapshot.data ?? true,
                              onToggled: (value) async =>
                                  await sharedStorage.setBool(
                                      "privacy_keyboard_incognito_mode",
                                      value));
                        }),
                    FutureBuilder<bool?>(
                        future: sharedStorage
                            .getBool("privacy_show_external_link_warning"),
                        builder: (context, snapshot) {
                          return OptionsSwitch(
                              title: "Show external link warning",
                              subTitle:
                                  "Show a warning when opening an external link in default browser",
                              switchState: snapshot.data ?? true,
                              onToggled: (value) async =>
                                  await sharedStorage.setBool(
                                      "privacy_show_external_link_warning",
                                      value));
                        }),
                    ListTile(
                        trailing: Icon(Icons.arrow_forward),
                        title: const Text("Proxy settings"),
                        subtitle:
                            const Text("Enable/disable proxy, choose proxy"),
                        onTap: () {
                          showToast("Proxy support not yet fully implemented",
                              context);
                          return;
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  settings:
                                      RouteSettings(name: "/settings_proxy"),
                                  builder: (context) => const ProxyScreen()));
                        }),
                    ...buildAnalyticsOptions()
                  ],
                ))));
  }
}

List<Widget> buildAnalyticsOptions({bool reduceBorders = false}) {
  return [
    FutureBuilder<bool?>(
        future: sharedStorage.getBool("analytics_enable_usage_ping"),
        builder: (context, snapshot) {
          String description = "Sends a small anonymous ping "
              "on app startup with app details "
              "(version, build, install source) "
              "and OS details "
              "(type, version, architecture). "
              "Used to estimate user counts and platform "
              "distribution. "
              "\nRead more: https://docs.hedon-haven.top/analytics.md";
          return OptionsSwitch(
              title: "Enable usage pings",
              subTitle: "Sends an anonymous ping on startup",
              maxSubTitleLines: 2,
              trailingWidget: IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => showDialog(
                    context: context,
                    builder: (BuildContext context) => ThemedDialog(
                          title: "Anonymous Pings",
                          primaryText: "Ok",
                          onPrimary: () => Navigator.pop(context),
                          content: GestureDetector(
                              onTap: () => launchUrl(Uri.parse(
                                  "https://docs.hedon-haven.top/analytics.md")),
                              child: Text(description,
                                  style:
                                      Theme.of(context).textTheme.bodyLarge)),
                        )),
              ),
              switchState: snapshot.data ?? false,
              reduceBorders: reduceBorders,
              onToggled: (value) =>
                  sharedStorage.setBool("analytics_enable_usage_ping", value));
        }),
    FutureBuilder<bool?>(
        future: sharedStorage.getBool("analytics_enable_automatic_bug_reports"),
        builder: (context, snapshot) {
          String description = "Automatically submit anonymous"
              " bug reports whenever they are created. These "
              "contain app details (version, build, "
              "install source), OS details "
              "(type, version, architecture) and error message,"
              " code trace, screen path, plugin name and "
              "debug info. \nBug reports will not be "
              "automatically submitted for third party plugins. "
              "\nRead more: https://docs.hedon-haven.top/analytics.md";
          return OptionsSwitch(
              title: "Enable automatic bug reports",
              subTitle: "Automatically submit anonymous bug reports",
              maxSubTitleLines: 2,
              trailingWidget: IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => showDialog(
                    context: context,
                    builder: (BuildContext context) => ThemedDialog(
                          title: "Anonymous Pings",
                          primaryText: "Ok",
                          onPrimary: () => Navigator.pop(context),
                          content: GestureDetector(
                              onTap: () => launchUrl(Uri.parse(
                                  "https://docs.hedon-haven.top/analytics.md")),
                              child: Text(description,
                                  style:
                                      Theme.of(context).textTheme.bodyLarge)),
                        )),
              ),
              switchState: snapshot.data ?? false,
              reduceBorders: reduceBorders,
              onToggled: (value) => sharedStorage.setBool(
                  "analytics_enable_automatic_bug_reports", value));
        })
  ];
}

class ProxyScreen extends StatefulWidget {
  const ProxyScreen({super.key});

  @override
  State<ProxyScreen> createState() => _ProxyScreenState();
}

class _ProxyScreenState extends State<ProxyScreen> {
  void setCustomProxy(String proxy) async {
    TextEditingController textController = TextEditingController(text: proxy);

    String? newValue = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return ThemedDialog(
            title: "Set custom proxy server (ip:port)",
            primaryText: "Apply",
            onPrimary: () => Navigator.of(context).pop(textController.text),
            secondaryText: "Cancel",
            onSecondary: () => Navigator.of(context).pop(null),
            content: TextField(
                controller: textController,
                decoration:
                    InputDecoration(hintText: "e.g. 256.256.256.256:8080")));
      },
    );

    if (newValue != null) {
      await sharedStorage.setString("privacy_proxy_address", newValue);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Privacy"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: FutureBuilder<bool?>(
                    future: sharedStorage.getBool("privacy_proxy_enabled"),
                    builder: (context, proxyEnabled) {
                      return Column(children: <Widget>[
                        OptionsSwitch(
                            title: "Enable proxy",
                            subTitle: "Force all network requests to go through"
                                " the proxy",
                            switchState: proxyEnabled.data ?? false,
                            onToggled: (value) async {
                              await sharedStorage.setBool(
                                  "privacy_proxy_enabled", value);
                              setState(() {});
                            }),
                        FutureBuilder<String?>(
                            future: sharedStorage
                                .getString("privacy_proxy_address"),
                            builder: (context, snapshot) {
                              return ListTile(
                                enabled: proxyEnabled.data ?? false,
                                title: Text("Current proxy server"),
                                subtitle: Text(snapshot.data?.isEmpty ?? true
                                    ? "None set"
                                    : snapshot.data!),
                                trailing: Icon(Icons.edit),
                                onTap: () => setCustomProxy(snapshot.data!),
                              );
                            }),
                        ListTile(
                            enabled: proxyEnabled.data ?? false,
                            trailing: const Icon(Icons.bolt),
                            title: const Text("Find fastest proxy"),
                            onTap: () {
                              showToast("Not yet implemented", context);
                            }),
                        ListTile(
                            enabled: proxyEnabled.data ?? false,
                            trailing: const Icon(Icons.shuffle),
                            title: const Text("Find random proxy"),
                            onTap: () {
                              showToast("Not yet implemented", context);
                            })
                      ]);
                    }))));
  }
}
