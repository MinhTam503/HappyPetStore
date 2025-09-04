class ServerException implements Exception {
  final String message;
  
  const ServerException({required this.message});
}

class CacheException implements Exception {
  final String message;
  
  const CacheException({required this.message});
}

class NetworkException implements Exception {
  final String message;
  
  const NetworkException({required this.message});
}

class FirebaseAuthException implements Exception {
  final String message;
  
  const FirebaseAuthException({required this.message});
}

class FirestoreException implements Exception {
  final String message;
  
  const FirestoreException({required this.message});
}

class PaymentException implements Exception {
  final String message;
  
  const PaymentException({required this.message});
}

class StripeException implements Exception {
  final String message;
  
  const StripeException({required this.message});
}

class ValidationException implements Exception {
  final String message;
  
  const ValidationException({required this.message});
}

class NotFoundException implements Exception {
  final String message;
  
  const NotFoundException({required this.message});
}

class UnauthorizedException implements Exception {
  final String message;
  
  const UnauthorizedException({required this.message});
}
