import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '/services/plugin_manager.dart';
import '/ui/widgets/alert_dialog.dart';
import '/utils/global_vars.dart';

class Install3rdPartyPluginScreen extends StatefulWidget {
  final bool partOfOnboarding;

  const Install3rdPartyPluginScreen({super.key, this.partOfOnboarding = false});

  @override
  State<Install3rdPartyPluginScreen> createState() =>
      _Install3rdPartyPluginScreenState();
}

class _Install3rdPartyPluginScreenState
    extends State<Install3rdPartyPluginScreen> {
  String? fileName;
  Map<String, dynamic>? pluginConfigMap;
  String? configFormatted;
  bool? isImportingPlugin;
  bool allowPop = false;

  @override
  void initState() {
    super.initState();
    // Don't show warning in dev mode
    sharedStorage.getBool("general_enable_dev_options").then((value) {
      if (!thirdPartyPluginWarningShown && !value!) {
        logger.d("Showing third party warning");
        WidgetsBinding.instance
            .addPostFrameCallback((_) => showThirdPartyWarning());
      }
    });
  }

  void resetProgress() {
    setState(() {
      fileName = null;
      pluginConfigMap = null;
      configFormatted = null;
      isImportingPlugin = null;
    });
  }

  void showThirdPartyWarning() async {
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return PopScope(
              canPop: false,
              child: ThemedDialog(
                title: "Third party warning",
                primaryText: "Accept risks and continue",
                onPrimary: () {
                  Navigator.pop(context);
                  thirdPartyPluginWarningShown = true;
                },
                secondaryText: "Cancel",
                onSecondary: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                content: const Text(
                    "Importing plugins from untrusted sources may put your device at risk! "
                    "The developers of Hedon Haven take no responsibility for any damage or "
                    "unintended consequences of using plugins from untrusted sources.",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ));
        });
  }

  void showErrorDialog(String title, String message) async {
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return ThemedDialog(
            title: title,
            primaryText: "Ok",
            onPrimary: () {
              resetProgress();
              Navigator.pop(context);
            },
            content: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(5.0),
              ),
              padding: const EdgeInsets.all(5.0),
              child: Text(message.trim(),
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          );
        });
  }

  void extractPlugin() async {
    resetProgress();
    try {
      final selectedFile = (await FilePicker.pickFile(
          type: FileType.custom, allowedExtensions: ["zip"]))!;
      pluginConfigMap =
          await PluginManager.extractNewPlugin(selectedFile.path!);
      configFormatted = "Name: ${pluginConfigMap!["metadata"]["prettyName"]} "
          "(${pluginConfigMap!["metadata"]["codeName"]})"
          "\nProvider for: ${pluginConfigMap!["providerData"]["serviceUrl"]}"
          "\nVersion: ${pluginConfigMap!["metadata"]["version"]}"
          "\nDeveloper: ${pluginConfigMap!["metadata"]["developer"]}"
          "\nContact email: ${pluginConfigMap!["metadata"]["contactEmail"] ?? "Not provided"}"
          "\nIssue tracker: ${pluginConfigMap!["metadata"]["issueTrackerUrl"] ?? "Not provided"}"
          "\nDescription: ${pluginConfigMap!["metadata"]["description"]}"
          "\nUpdate URL: ${pluginConfigMap!["metadata"]["updateUrl"] ?? "Updates unsupported"}";
      setState(() => fileName = selectedFile.name);
    } catch (e, stacktrace) {
      if (e.toString().contains("AlreadyInstalled")) {
        showErrorDialog(
            "Duplicate plugin detected",
            "A plugin with the codename: "
                "${e.toString().split(":").last.trim()} is already installed! "
                "Please uninstall it first!");
        return;
      }
      logger.w("Error extracting plugin: $e\n$stacktrace");
      showErrorDialog("Not a valid plugin zip file!", "$e\n$stacktrace");
      setState(() => fileName = null);
    }
    logger.i("Finished extracting plugin, waiting for user confirmation");
  }

  void importPlugin() async {
    setState(() => isImportingPlugin = true);
    try {
      await PluginManager.importNewPlugin(pluginConfigMap!);
      // Tell videoLists to update
      reloadVideoListEvent.add(null);
      setState(() => isImportingPlugin = false);
    } catch (e, stacktrace) {
      logger.e("Failed to import plugin: $e\n$stacktrace");
      showErrorDialog("Failed to import plugin", "$e\n$stacktrace");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: allowPop || isImportingPlugin != true,
        onPopInvokedWithResult: (goingToPop, __) {
          if (!goingToPop) {
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return ThemedDialog(
                    title: "Cancel plugin installation?",
                    primaryText: "Continue installing",
                    onPrimary: Navigator.of(context).pop,
                    secondaryText: "Cancel installation",
                    onSecondary: () {
                      allowPop = true;
                      // close popup
                      Navigator.pop(context);
                      // Go back a screen
                      Navigator.of(context).pop(false);
                    },
                  );
                });
          }
        },
        child: Scaffold(
            appBar: AppBar(
              iconTheme:
                  IconThemeData(color: Theme.of(context).colorScheme.primary),
              title: Text("Third party plugin installation"),
            ),
            body: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 20,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  fileName != null
                                      ? "$fileName"
                                      : "Select zip file: ",
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      foregroundColor: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  onPressed: isImportingPlugin != null
                                      ? null
                                      : () => extractPlugin(),
                                  child: Row(children: [
                                    Text("Select "),
                                    Icon(size: 20, Icons.open_in_new),
                                  ]))
                            ],
                          ),
                          if (configFormatted != null) ...[
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 5,
                              children: [
                                Text("Plugin details:",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                    borderRadius: BorderRadius.circular(5.0),
                                  ),
                                  padding: const EdgeInsets.all(5.0),
                                  child: Text(configFormatted!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium),
                                )
                              ],
                            ),
                            if (isImportingPlugin == null)
                              Row(mainAxisSize: MainAxisSize.max, children: [
                                Spacer(),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    onPressed: () => importPlugin(),
                                    child: Text("Import")),
                                Spacer()
                              ])
                          ],
                          if (isImportingPlugin != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text("Importing plugin:",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                isImportingPlugin!
                                    ? SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: CircularProgressIndicator())
                                    : Icon(Icons.check_circle,
                                        size: 30,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)
                              ],
                            ),
                            if (!isImportingPlugin!)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Spacer(),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: Text("Done")),
                                Spacer()
                              ])
                          ]
                        ])))));
  }
}
