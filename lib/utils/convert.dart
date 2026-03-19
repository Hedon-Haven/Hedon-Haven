String convertNumberIntoHumanReadable(int number) {
  if (number < 1000) {
    return number.toString();
    // <100k
  } else if (number < 100000) {
    return "${(number / 1000).toStringAsFixed(1)}K";
    // <1M
  } else if (number < 1000000) {
    return "${(number / 1000).toStringAsFixed(0)}K";
    // <1000M
  } else if (number < 1000000000) {
    return "${(number / 1000000).toStringAsFixed(1)}M";
    // >1000M
  } else {
    return "${(number / 1000000000).toStringAsFixed(0)}B";
  }
}

String? getTimeDeltaInHumanReadable(DateTime? pastDate) {
  if (pastDate == null) {
    return null;
  }
  Duration delta = DateTime.now().difference(pastDate);
  if (delta.inSeconds < 60) {
    return "${delta.inSeconds}s";
  } else if (delta.inMinutes < 60) {
    return "${delta.inMinutes} min";
  } else if (delta.inHours < 24) {
    return "${delta.inHours}h";
  } else if (delta.inDays < 7) {
    return "${delta.inDays}d";
  } else if (delta.inDays >= 7 && delta.inDays <= 30) {
    return "${delta.inDays ~/ 7}w";
  } else if (delta.inDays < 365) {
    return "${delta.inDays ~/ 30}mo";
  } else {
    return "${delta.inDays ~/ 365}y";
  }
}

/// Add dots into "raw" number to make it more readable
String formatWithDots(int number) {
  // Convert the number to a string and reverse it
  String reversed = number.toString().split('').reversed.join();

  // Add dots every three characters
  String formattedReversed =
      reversed.replaceAllMapped(RegExp(r".{1,3}"), (match) {
    return "${match.group(0)}.";
  });

  // Reverse again and remove the trailing dot
  return formattedReversed
      .split('')
      .reversed
      .join()
      .replaceFirst(RegExp(r"^\."), "");
}
