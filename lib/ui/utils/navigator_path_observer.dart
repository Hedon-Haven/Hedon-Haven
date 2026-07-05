import 'package:flutter/material.dart';

import '/utils/global_vars.dart';

// Store the entire navigation path to include it in bug reports
class NavigatorPathObserver extends NavigatorObserver {
  final List<String> routeStack = [];

  String get currentPath {
    // Remove empty strings
    routeStack.removeWhere((element) => element.isEmpty);
    logger.f("Current path: $routeStack");
    return "/${routeStack.join("/")}";
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    logger.f("Pushed route: ${route.settings.name}");
    routeStack.add(route.settings.name?.isNotEmpty == true
        ? route.settings.name!.replaceAll("/", "")
        : "unknown");
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    logger.f("Popped route: ${route.settings.name}");
    routeStack.remove(route.settings.name?.isNotEmpty == true
        ? route.settings.name!.replaceAll("/", "")
        : "unknown");
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    logger.f("Removed route: ${route.settings.name}");
    routeStack.remove(route.settings.name?.isNotEmpty == true
        ? route.settings.name!.replaceAll("/", "")
        : "unknown");
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    logger.f(
        "Replaced route: ${oldRoute?.settings.name} with ${newRoute?.settings.name}");
    routeStack.remove(oldRoute?.settings.name?.isNotEmpty == true
        ? oldRoute!.settings.name!.replaceAll("/", "")
        : "unknown");
    routeStack.add(newRoute?.settings.name?.isNotEmpty == true
        ? newRoute!.settings.name!.replaceAll("/", "")
        : "unknown");
  }
}
