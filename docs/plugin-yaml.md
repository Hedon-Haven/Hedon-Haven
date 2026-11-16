# plugin.yaml

Every third party plugin zip contains a `plugin.yaml` in its root. It describes the plugin to the
app. The [plugin template](https://github.com/Hedon-Haven/3rd-party-plugin-examples) provides some
examples.

All keys must have a valid value, otherwise the app will refuse to load the plugin. Only the keys
marked optional may be left empty.

| Key                 | Value                                                                                                                                  |
|---------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| `apiVersion`        | Must be `1.0`                                                                                                                          |
| `codeName`          | Unique ID, see [below](#codename)                                                                                                      |
| `prettyName`        | The official, correctly cased name of the provider                                                                                     |
| `version`           | Plugin version as `vX.Y.Z`                                                                                                             |
| `developer`         | Developer name, shown to users                                                                                                         |
| `contactEmail`      | (optional, recommended) Email address for bug reports                                                                                  |
| `issueTrackerUrl`   | (optional, recommended) Link to the issue tracker for bug reports                                                                      |
| `description`       | Short description, e.g. to mention limitations                                                                                         |
| `updateUrl`         | (optional) https link to the hosted update file, see [Hosting and updates](https://docs.hedon-haven.top/plugin-hosting-and-updates.md) |
| `iconUrl`           | https link to a small icon of the website, preferably its favicon                                                                      |
| `serviceUrl`        | The website the plugin scrapes. Shown to users in the app                                                                              |
| `handleUrls`        | Links that the plugin can handle, see [below](#handleurls)                                                                             |
| `initialPageCounts` | First page number of each list, see [below](#initialpagecounts)                                                                        |

## codeName

The `codeName` is the unique ID of the plugin. It consists of exactly 3 segments separated by dots,
e.g. `com.myname.myplugin`. Each segment can use letters, digits and underscores, but must not
start or end with an underscore. The `com.hedon_haven` namespace is reserved for bundled plugins.

## handleUrls

Links that the plugin can open when users share or drag-and-drop them into the app. Entries are
matched as plain prefixes of the full link, scheme included. For example `https://example.com/video`
matches `https://example.com/video/123`, but not `https://www.example.com/video/123`. Every variant
of the host that the plugin supports needs its own entry. The order does not matter.

## initialPageCounts

`initialPageCounts` sets the counter of the first page that the app requests for each list:

| Key                           | List                |
|-------------------------------|---------------------|
| `initialHomePage`             | Home page result    |
| `initialSearchResultsPage`    | Search results      |
| `initialCommentsPage`         | Comments of a video |
| `initialVideoSuggestionsPage` | Video suggestions   |
| `initialAuthorVideosPage`     | Videos of an author |

E.g. use `0` if the provider counts pages from 0 or if the first additional page count starts at 1.
To see a real implementation, check the code inside bundled plugins.

Do not use `-1` as a value, because the app uses it internally to mark the end of a list.