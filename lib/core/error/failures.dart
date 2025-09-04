abstract class Failure {
  final String message;
  
  const Failure({required this.message});
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Failure && other.message == message;
  }
  
  @override
  int get hashCode => message.hashCode;
}

// General failures
class ServerFailure extends Failure {
  const ServerFailure({required super.message});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

// Firebase specific failures
class FirebaseAuthFailure extends Failure {
  const FirebaseAuthFailure({required super.message});
}

class FirestoreFailure extends Failure {
  const FirestoreFailure({required super.message});
}

// Payment specific failures
class PaymentFailure extends Failure {
  const PaymentFailure({required super.message});
}

class StripeFailure extends Failure {
  const StripeFailure({required super.message});
}

// Data validation failures
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({required super.message});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({required super.message});
}
