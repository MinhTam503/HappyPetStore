import 'package:equatable/equatable.dart';

class AddressState extends Equatable {
  final bool isLoading;
  final List<Map<String, dynamic>> addresses;
  final String? errorMessage;
  final String? infoMessage;

  const AddressState({
    required this.isLoading,
    required this.addresses,
    this.errorMessage,
    this.infoMessage,
  });

  factory AddressState.initial() => const AddressState(
        isLoading: true,
        addresses: [],
      );

  AddressState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? addresses,
    String? errorMessage,
    String? infoMessage,
  }) {
    return AddressState(
      isLoading: isLoading ?? this.isLoading,
      addresses: addresses ?? this.addresses,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
    );
  }

  @override
  List<Object?> get props => [isLoading, addresses, errorMessage, infoMessage];
}
