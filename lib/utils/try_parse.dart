/// This function allows to safely set individual values and automatically returns null on any error
T? tryParse<T>(T Function() parser) {
  try {
    return parser();
  } catch (_) {
    return null;
  }
}

DateTime? tryParseFromUnixTime(int? unixTimeInSeconds) {
  return tryParse(() => DateTime.fromMillisecondsSinceEpoch(
      unixTimeInSeconds! * 1000,
      isUtc: true));
}

/// Converts a DateTime object to seconds since unix time (as int)
/// Returns null on failure (will not throw on anything)
int? convertToUnixTime(DateTime? dateTime) {
  return tryParse(() => (dateTime!.millisecondsSinceEpoch / 1000).toInt());
}
