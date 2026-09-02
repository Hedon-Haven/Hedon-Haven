import 'dart:async';

import '/bundled_plugins/pornhub.dart';
import '/bundled_plugins/tester.dart';
import '/bundled_plugins/xhamster.dart';
import '/utils/global_vars.dart';
import '/utils/plugin_interface/plugin_interface.dart';

Future<PluginInterface?> getBundledPluginByName(String codename) async {
  switch (codename) {
    case "com.hedon_haven.tester_internal":
      if (!(await sharedStorage.getBool("general_enable_dev_options"))!) {
        logger.e("Tester plugin requested in non-debug mode");
        throw Exception("Tester plugin requested in non-debug mode");
      }
      return TesterPlugin();
    case "com.hedon_haven.pornhub":
      return PornhubPlugin();
    case "com.hedon_haven.xhamster":
      return XHamsterPlugin();
    default:
      break;
  }
  return null;
}

Future<List<PluginInterface>> getAllBundledPlugins() async {
  if ((await sharedStorage.getBool("general_enable_dev_options"))!) {
    return [TesterPlugin(), PornhubPlugin(), XHamsterPlugin()];
  } else {
    return [PornhubPlugin(), XHamsterPlugin()];
  }
}
