class ScrapingException implements Exception {
  final String message;

  ScrapingException([this.message = "unknown scraping exception"]);

  @override
  String toString() => message;
}

abstract class CustomException implements Exception {
  /// short label to display as title to user
  String get title;

  /// the long exception message that can be overridden at creation
  @override
  String toString() => message;
  final String message;

  String toJson() => message;

  CustomException(this.message);
}

class NoInternetConnectionException extends CustomException {
  NoInternetConnectionException(
      [super.message =
          "The app cannot access the internet. Check your connection!"]);

  @override
  String get title => "No internet connection";
}

class AgeGateException extends CustomException {
  AgeGateException(
      [super.message = "This plugin requires age verification in your country. "
          "Try setting a proxy in settings or using a VPN service."]);

  @override
  String get title => "Age Gate detected";
}

class BannedCountryException extends CustomException {
  BannedCountryException(
      [super.message = "This plugin is not accessible from your country. "
          "Try setting a proxy in settings or using a VPN service."]);

  @override
  String get title => "Banned country detected";
}

class UnreachableException extends CustomException {
  UnreachableException(
      [super.message = "Couldn't connect to provider. Try again later."]);

  @override
  String get title => "Couldn't reach provider";
}

class NotFoundException extends CustomException {
  NotFoundException(
      [super.message = "Couldn't find whatever was requested. Soft error 404"]);

  @override
  String get title => "Not found";
}

class PrivateAuthorProfileException extends CustomException {
  PrivateAuthorProfileException(
      [super.message = "Private author profile. Access forbidden."]);

  @override
  String get title => "Private profile";
}
