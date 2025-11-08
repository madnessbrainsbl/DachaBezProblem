class ApiException implements Exception {
  final String message;
  final String? prefix;

  ApiException(this.message, [this.prefix]);

  @override
  String toString() {
    return "$prefix$message";
  }
}

class BadRequestException extends ApiException {
  BadRequestException(String message) : super(message, "Ошибка запроса: ");
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message)
      : super(message, "Ошибка авторизации: ");
}

class NotFoundException extends ApiException {
  NotFoundException(String message) : super(message, "Не найдено: ");
}

class ServerException extends ApiException {
  ServerException(String message) : super(message, "Ошибка сервера: ");
}

class NoInternetException extends ApiException {
  NoInternetException(String message) : super(message, "Нет соединения: ");
}

class ApiTimeoutException extends ApiException {
  ApiTimeoutException(String message) : super(message, "Тайм-аут: ");
}

class UnknownApiException extends ApiException {
  UnknownApiException(String message) : super(message, "Неизвестная ошибка: ");
}
