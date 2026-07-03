import 'package:yaml/yaml.dart';

import '/utils/global_vars.dart';

Future<({String title, String message})> getBanner() async {
  final yamlRaw = (await client
          .get(Uri.parse("https://banner.hedon-haven.top/banner.yaml")))
      .body;
  YamlMap yaml = loadYaml(yamlRaw);
  return (title: yaml["title"] as String, message: yaml["message"] as String);
}
