class AgeGateException implements Exception {
  final String message;

  AgeGateException(
      [this.message =
          "Age gate encountered. Try setting a proxy in settings or using a VPN service."]);

  @override
  String toString() => message;
}

class BannedCountryException implements Exception {
  final String message;

  BannedCountryException(
      [this.message =
          "Banned country encountered. Try setting a proxy in settings or using a VPN service."]);

  @override
  String toString() => message;
}

class UnreachableException implements Exception {
  final String message;

  UnreachableException(
      [this.message = "Couldn't connect to provider. Try again later."]);

  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;

  NotFoundException(
      [this.message = "Couldn't find whatever was requested. Soft error 404"]);

  @override
  String toString() => message;
}

class PrivateAuthorProfileException implements Exception {
  final String message;

  PrivateAuthorProfileException(
      [this.message = "Private author profile. Access forbidden."]);

  @override
  String toString() => message;
}

bool isCustomException(Exception? e) {
  if (e == null) {
    return false;
  }
  return e is AgeGateException ||
      e is BannedCountryException ||
      e is UnreachableException ||
      e is NotFoundException ||
      e is PrivateAuthorProfileException;
}
