import 'package:equatable/equatable.dart';

abstract class AddressEvent extends Equatable {
  const AddressEvent();
  @override
  List<Object?> get props => [];
}

class LoadAddresses extends AddressEvent {}

class AddOrUpdateAddress extends AddressEvent {
  final Map<String, dynamic> address;
  final int? index; // null => add new
  const AddOrUpdateAddress({required this.address, this.index});

  @override
  List<Object?> get props => [address, index];
}

class DeleteAddress extends AddressEvent {
  final int index;
  const DeleteAddress(this.index);
  @override
  List<Object?> get props => [index];
}

class SetDefaultAddress extends AddressEvent {
  final int index;
  const SetDefaultAddress(this.index);
  @override
  List<Object?> get props => [index];
}
