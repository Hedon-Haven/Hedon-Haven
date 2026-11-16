# Plugin hosting and updates

Updates are optional. If a plugin developer does not set `updateUrl` in
the [plugin.yaml](https://docs.hedon-haven.top/plugin-yaml.md) the app will not check for updates
for that plugin.

To offer updates, two files must be hosted at any https location:

- `update.yaml`: its https link goes into `updateUrl` in the `plugin.yaml`
- the plugin zip: its https link goes into `downloadUrl` in the `update.yaml`

## update.yaml

Contains update metadata. Is loaded by the app every time it checks for plugin updates.

| Key           | Value                                                                               |
|---------------|-------------------------------------------------------------------------------------|
| `version`     | The new semantic version as `vX.Y.Z`. Offered only if higher than the installed one |
| `downloadUrl` | Https link to the plugin zip                                                        |
| `sha256Sum`   | SHA-256 checksum of the zip. The app compares it with the downloaded file.          |
| `changelog`   | List of changes, shown to the user in the update prompt                             |

## GitHub

A GitHub release works well for hosting. A link like
`https://github.com/<user>/<repo>/releases/latest/download/<file>` always points to the newest
release.