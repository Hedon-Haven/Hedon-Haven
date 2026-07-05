import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/services/http_manager.dart';
import '/ui/utils/navigator_path_observer.dart';
import 'custom_logger.dart';

// Make these late-initialized to allow mocking them in tests
late SharedPreferencesAsync sharedStorage;
late Logger logger;
late PackageInfo packageInfo;
late http.Client client;
// Generic Windows Chrome user agent
String httpUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36";
// Generic hint headers from a Windows Chrome Browser
Map<String, String> defaultHttpHeaders = {
  "accept": 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
  "accept-language": 'en-US,en;q=0.9',
  "priority": 'u=0, i',
  "sec-ch-ua": '"Google Chrome";v="149", "Chromium";v="149", "Not)A;Brand";v="24"',
  "sec-ch-ua-mobile": '?0',
  "sec-ch-ua-platform": '"Windows"',
  "sec-fetch-dest": 'document',
  "sec-fetch-mode": 'navigate',
  "sec-fetch-site": 'none',
  "sec-fetch-user": '?1',
  "upgrade-insecure-requests": '1'
};
late StreamController<void> reloadVideoListEvent;
late StreamController<int> pluginUpdatesAvailableEvent;

/// Global visual app reload. MUST be set from initGlobalSetState, NOT from the main initGlobalVars()
late void Function() globalSetState;

/// This stores the global setting of whether the preview should be hidden
bool hidePreview = true;

// Make this bool a global var, -> user only sees the warning once per session
bool thirdPartyPluginWarningShown = false;

late NavigatorPathObserver navigatorPathObserver;

// Each initialization is a separate function to allow mocking only some parts
// of the app
Future<void> initGlobalVars() async {
  await initSharedStorage();
  await initLogger();
  await initPackageInfo();
  await initHttpClient();
  await initEvents();
  await initNavigatorPathObserver();
}

// This function is not called by the main initGlobalVars as it has to be set
// from the UI part of main, not the startup part
Future<void> initGlobalSetState(void Function() function) async {
  globalSetState = function;
}

Future<void> initSharedStorage() async {
  sharedStorage = SharedPreferencesAsync();
}

Future<void> initLogger() async {
  logger = Logger(
    printer: BetterSimplePrinter(),
    filter: VariableFilter(),
  );
}

Future<void> initPackageInfo() async {
  packageInfo = await PackageInfo.fromPlatform();
}

Future<void> initHttpClient() async {
  logger.i("Initializing http client");
  String? proxy = await sharedStorage.getString("privacy_proxy_address");
  logger.i("Using proxy: ${proxy?.isEmpty ?? true ? "None" : proxy}");
  client = await getHttpClient(proxy);
}

Future<void> initEvents() async {
  logger.i("Initializing stream controllers");
  reloadVideoListEvent = StreamController<void>.broadcast();
  pluginUpdatesAvailableEvent = StreamController<int>.broadcast();
}

Future<void> initNavigatorPathObserver() async {
  navigatorPathObserver = NavigatorPathObserver();
}
