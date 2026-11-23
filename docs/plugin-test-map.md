# Plugin test map

The test map is a YAML file that tells the Hedon Haven plugin test suite what to test.

The values must exist on the provider's side, as the tests run against the live website. Pick
stable content, e.g. well-known authors and popular videos. A missing key or an empty list skips
the related tests.

| Key                        | Value                                                                      |
|----------------------------|----------------------------------------------------------------------------|
| `testingSearchSuggestions` | List of `query` and `expectedSuggestion`, see [below](#search-suggestions) |
| `testingSearchResults`     | List of `searchString`, see [below](#search-results)                       |
| `testingVideos`            | List of `videoID` and `progressThumbnailsAmount`, see [below](#videos)     |
| `testingAuthorPageIds`     | List of author IDs, see [below](#authors)                                  |

Paged functions (search results, video suggestions, comments, author videos) are requested for 3
pages, starting at the matching `initialPageCounts` value of the
[plugin.yaml](https://docs.hedon-haven.top/plugin-yaml.md).

## Test criteria

Returned items must be fully scraped to pass a test:

- Every field needs a value, or must be listed in the item's `unavailableFields`.
- Use `unavailableFields` only for data that the provider does not offer at all, e.g. ratings. Any
  other `null` field fails the test, as it usually means the website changed and the
  plugin no longer finds the data.
- Only the presence of values is checked, not their correctness.

### Search suggestions

`getSearchSuggestions` is called with `query`. It must return at least one suggestion, and one of
them must equal `expectedSuggestion`.

### Search results

`getSearchResults` is called with `searchString`. It must return at least one fully scraped result.

### Videos

For every entry:

- `getVideoMetadata` must return fully scraped metadata for `videoID`.
- `getProgressThumbnails` must return exactly `progressThumbnailsAmount` thumbnails.
- `getVideoSuggestions` and `getComments` must each return at least one fully scraped item.

### Authors

For every author ID, `getAuthorPage` must return a fully scraped author page, and
`getAuthorVideos` must return at least one fully scraped video.