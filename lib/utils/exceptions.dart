class ScrapingException implements Exception {
  final String message;

  ScrapingException([this.message = "unknown scraping exception"]);

  @override
  String toString() => message;
}

abstract class ProviderException implements Exception {
  /// short label to display as title to user
  String get title;

  /// the long exception message that can be overridden at creation
  @override
  String toString() => message;
  final String message;

  String toJson() => message;

  ProviderException(this.message);
}

class AgeGateException extends ProviderException {
  AgeGateException(
      [super.message = "This plugin requires age verification in your country. "
          "Try setting a proxy in settings or using a VPN service."]);

  @override
  String get title => "Age Gate detected";
}

class BannedCountryException extends ProviderException {
  BannedCountryException(
      [super.message = "This plugin is not accessible from your country. "
          "Try setting a proxy in settings or using a VPN service."]);

  @override
  String get title => "Banned country detected";
}

class UnreachableException extends ProviderException {
  UnreachableException(
      [super.message = "Couldn't connect to provider. Try again later."]);

  @override
  String get title => "Couldn't reach provider";
}

class NotFoundException extends ProviderException {
  NotFoundException(
      [super.message = "Couldn't find whatever was requested. Soft error 404"]);

  @override
  String get title => "Not found";
}

class PrivateAuthorProfileException extends ProviderException {
  PrivateAuthorProfileException(
      [super.message = "Private author profile. Access forbidden."]);

  @override
  String get title => "Private profile";
}
