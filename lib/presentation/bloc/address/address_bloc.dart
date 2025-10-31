import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'address_event.dart';
import 'address_state.dart';

class AddressBloc extends Bloc<AddressEvent, AddressState> {
  AddressBloc() : super(AddressState.initial()) {
    on<LoadAddresses>(_onLoad);
    on<AddOrUpdateAddress>(_onAddOrUpdate);
    on<DeleteAddress>(_onDelete);
    on<SetDefaultAddress>(_onSetDefault);
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> _onLoad(LoadAddresses event, Emitter<AddressState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;
    emit(state.copyWith(isLoading: true, errorMessage: null, infoMessage: null));
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      List<Map<String, dynamic>> addrs = [];

      // Prefer new format
      final deliveryData = data['deliveryInfos'];
      if (deliveryData is List) {
        addrs = List<Map<String, dynamic>>.from(deliveryData);
      } else {
        // Migration from old formats
        final addr = data['address'];
        if (addr is List && addr.isNotEmpty) {
          addrs = addr
              .map<Map<String, dynamic>>((a) => {
                    'name': data['displayName'] ?? '',
                    'phone': data['phone'] ?? '',
                    'address': a.toString(),
                    'isDefault': addrs.isEmpty,
                  })
              .toList();
          await _db.collection('users').doc(user.uid).update({'deliveryInfos': addrs});
        } else if (addr is String && addr.trim().isNotEmpty) {
          final parts = addr.split(', ');
          String? province;
          String? ward;
          String detail = addr.trim();
          if (parts.length >= 3) {
            province = parts.last.trim();
            ward = parts[parts.length - 2].trim();
            detail = parts.sublist(0, parts.length - 2).join(', ').trim();
          }
          addrs = [
            {
              'name': data['displayName'] ?? '',
              'phone': data['phone'] ?? '',
              'address': addr.trim(),
              'province': province,
              'ward': ward,
              'detail': detail,
              'isDefault': true,
            }
          ];
          await _db.collection('users').doc(user.uid).update({'deliveryInfos': addrs});
        }
      }
      emit(state.copyWith(isLoading: false, addresses: addrs));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onSetDefault(SetDefaultAddress event, Emitter<AddressState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null, infoMessage: null));
      final list = List<Map<String, dynamic>>.from(state.addresses);
      for (int i = 0; i < list.length; i++) {
        list[i]['isDefault'] = i == event.index;
      }
      // Sync top-level phone from default entry
      final def = list.firstWhere((a) => a['isDefault'] == true, orElse: () => {});
      final phone = (def['phone'] as String?)?.trim();
      final updates = <String, dynamic>{'deliveryInfos': list};
      if (phone != null && phone.isNotEmpty) updates['phone'] = phone;
      await _db.collection('users').doc(user.uid).update(updates);
      emit(state.copyWith(isLoading: false, addresses: list, infoMessage: 'Đã đặt làm địa chỉ mặc định'));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onDelete(DeleteAddress event, Emitter<AddressState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null, infoMessage: null));
      final list = List<Map<String, dynamic>>.from(state.addresses);
      bool wasDefault = list[event.index]['isDefault'] == true;
      list.removeAt(event.index);
      if (wasDefault && list.isNotEmpty) list[0]['isDefault'] = true;
      await _db.collection('users').doc(user.uid).update({'deliveryInfos': list});
      emit(state.copyWith(isLoading: false, addresses: list, infoMessage: 'Đã xóa địa chỉ'));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onAddOrUpdate(AddOrUpdateAddress event, Emitter<AddressState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null, infoMessage: null));
      final list = List<Map<String, dynamic>>.from(state.addresses);
      if (event.index != null) {
        list[event.index!] = {...list[event.index!], ...event.address};
      } else {
        if (list.isEmpty) {
          event.address['isDefault'] = true;
        }
        list.add(event.address);
      }

      // If new/edited isDefault, clear others
      final newIdx = event.index ?? (list.length - 1);
      if (event.address['isDefault'] == true) {
        for (int i = 0; i < list.length; i++) {
          list[i]['isDefault'] = i == newIdx;
        }
      }

      // Sync top-level phone from default entry
      final def = list.firstWhere((a) => a['isDefault'] == true, orElse: () => {});
      final phone = (def['phone'] as String?)?.trim();
      final updates = <String, dynamic>{'deliveryInfos': list};
      if (phone != null && phone.isNotEmpty) updates['phone'] = phone;

      await _db.collection('users').doc(user.uid).update(updates);
      emit(state.copyWith(
        isLoading: false,
        addresses: list,
        infoMessage: event.index != null ? 'Đã cập nhật địa chỉ' : 'Đã thêm địa chỉ',
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
}
