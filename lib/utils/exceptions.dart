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

class VirtualRealityNotSupportedException extends CustomException {
  VirtualRealityNotSupportedException(
      [super.message = "Virtual reality videos not yet supported"]);

  @override
  String get title => "VR not supported";
}

class PluginTimeoutException extends CustomException {
  PluginTimeoutException(
      [super.message = "Plugin timed out performing function"]);

  @override
  String get title => "Plugin timed out";
}

/// Map String -> CustomException
final List<CustomException Function(String)> _knownExceptionTypes = [
  NoInternetConnectionException.new,
  AgeGateException.new,
  BannedCountryException.new,
  UnreachableException.new,
  NotFoundException.new,
  PrivateAuthorProfileException.new,
  VirtualRealityNotSupportedException.new,
  PluginTimeoutException.new,
];

/// Converts any Exception (including special treatment for CustomExceptions) 
/// to a serializable Map
Map<String, dynamic> convertExceptionToMap(Object exception) {
  return {
    "type": exception.runtimeType.toString(),
    "message": exception.toString()
  };
}

/// Reconstructs whatever convertExceptionToMap produced: the real
/// CustomException subtype if map["type"] matches one of the known types,
/// or a plain Exception otherwise.
Exception convertMapToException(Map<String, dynamic> map) {
  for (final constructor in _knownExceptionTypes) {
    final instance = constructor(map["message"]);
    if (instance.runtimeType.toString() == map["type"]) return instance;
  }
  return Exception(map["message"]);
}
