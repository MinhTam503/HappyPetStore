import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/data/models/cart_model.dart';
import 'package:pet_shop/data/models/reservation_model.dart';
import 'package:pet_shop/data/models/deposit_settings_model.dart';
import 'package:pet_shop/presentation/bloc/deposit_settings/deposit_settings_bloc.dart';
import 'package:pet_shop/presentation/bloc/deposit_settings/deposit_settings_event.dart';
import 'package:pet_shop/presentation/bloc/deposit_settings/deposit_settings_state.dart';
import 'package:pet_shop/presentation/bloc/reservation/reservation_bloc.dart';
import 'package:pet_shop/presentation/bloc/reservation/reservation_event.dart';
import 'package:pet_shop/presentation/bloc/reservation/reservation_state.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/components/store_pickup_header.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/components/pickup_date_card.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/components/payment_option_card.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/components/payment_method_card.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/components/reservation_items_list.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/components/reservation_summary_card.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

/// Store Pickup Checkout Screen - For reserving pets with deposit
class StorePickupCheckoutScreen extends StatefulWidget {
  final String userIdentifier;
  final List<CartModel> carts;

  const StorePickupCheckoutScreen({
    super.key,
    required this.userIdentifier,
    required this.carts,
  });

  @override
  State<StorePickupCheckoutScreen> createState() =>
      _StorePickupCheckoutScreenState();
}

class _StorePickupCheckoutScreenState
    extends State<StorePickupCheckoutScreen> {
  final UserManager userManager = UserManager();

  Map<String, dynamic>? userInfo;
  DateTime? selectedPickupDate;
  String paymentMethod = 'vnpay';
  bool isPayingDeposit = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await userManager.initialize();
    userInfo = await userManager.getCurrentUserInfo();
    setState(() {});
  }

  double _calculateTotal() {
    double total = 0.0;
    for (var item in widget.carts) {
      final priceStr = item.grocery["price"].toString();
      final price = double.tryParse(priceStr) ?? 0.0;
      total += item.quantity * price;
    }
    return total;
  }

  double _calculatePaymentAmount(DepositSettingsModel settings) {
    final total = _calculateTotal();
    return isPayingDeposit ? settings.calculateDeposit(total) : total;
  }

  Future<void> _selectPickupDate(int maxDays) async {
    final now = DateTime.now();
    final firstDate = now.add(const Duration(days: 1));
    final lastDate = now.add(Duration(days: maxDays));

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedPickupDate ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedPickupDate = picked);
    }
  }

  Future<void> _createReservation(DepositSettingsModel settings) async {
    if (selectedPickupDate == null) {
      NotificationHelper.showWarning(
        context,
        AppLocalizations.of(context)!.selectPickupDate,
        'Vui lòng chọn ngày đến lấy thú cưng',
      );
      return;
    }

    // Build items list
    List<Map<String, dynamic>> items = [];
    for (var item in widget.carts) {
      final petId = item.grocery["productId"]?.toString() ?? '';
      if (petId.isEmpty) continue;

      final petDoc = await FirebaseFirestore.instance
          .collection('Pets')
          .doc(petId)
          .get();

      if (petDoc.exists) {
        final petData = petDoc.data()!;
        items.add({
          'productId': petId,
          'id': petId,
          'name': petData['name'] ?? '',
          'imageUrl': petData['imageUrl'] ?? '',
          'price': (petData['price'] is num)
              ? (petData['price'] as num).toDouble()
              : double.tryParse(petData['price']?.toString() ?? '0') ?? 0.0,
          'quantity': item.quantity,
          'breed': petData['breed'] ?? '',
          'category': petData['category'] ?? '',
        });
      }
    }

    if (items.isEmpty) {
      NotificationHelper.showError(
        context,
        'Lỗi',
        'Không tìm thấy thú cưng trong giỏ hàng',
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      NotificationHelper.showError(context, 'Lỗi',
          'Vui lòng đăng nhập để đặt trước');
      return;
    }

    final totalAmount = _calculateTotal();
    final depositAmount = settings.calculateDeposit(totalAmount);
    final paymentAmount = _calculatePaymentAmount(settings);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đặt trước'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn sẽ thanh toán ${isPayingDeposit ? "tiền cọc" : "toàn bộ"}: ${CurrencyHelper.formatVND(paymentAmount)}'),
            const SizedBox(height: 8),
            Text('Phương thức: ${paymentMethod == "vnpay" ? "VNPay" : "Stripe"}'),
            const SizedBox(height: 8),
            const Text('Lưu ý: Bạn cần thanh toán để hoàn tất đặt trước.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Create reservation first with pending payment status
    final reservation = ReservationModel(
      id: '',
      userId: currentUser.uid,
      userIdentifier: widget.userIdentifier,
      displayName: userInfo?['displayName'] ?? '',
      phone: userInfo?['phone'] ?? '',
      email: userInfo?['email'] ?? currentUser.email ?? '',
      items: items,
      pickupDate: selectedPickupDate!,
      createdAt: DateTime.now(),
      status: ReservationStatus.pending,
      paymentStatus: ReservationPaymentStatus.pending,
      totalAmount: totalAmount,
      depositAmount: depositAmount,
      paidAmount: 0,
      remainingAmount: totalAmount,
      paymentMethod: paymentMethod,
    );

    if (!mounted) return;

    DialogHelper.showLoadingDialog(context,
        message: 'Đang tạo đơn đặt trước...');
    
    // TODO: After reservation is created, redirect to payment
    // For now, just create the reservation
    context.read<ReservationBloc>().add(CreateReservation(reservation));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (_) =>
                DepositSettingsBloc()..add(const LoadDepositSettings())),
        BlocProvider(create: (_) => ReservationBloc()),
      ],
      child: BlocListener<ReservationBloc, ReservationState>(
        listener: (context, state) async {
          if (state is ReservationSuccess) {
            await DialogHelper.safeHideLoadingDialog();

            // Remove items from cart
            final cartDoc = FirebaseFirestore.instance
                .collection('carts')
                .doc(widget.userIdentifier);
            final doc = await cartDoc.get();
            if (doc.exists) {
              final data = doc.data();
              final items = (data != null && data['items'] is List)
                  ? List<Map<String, dynamic>>.from(data['items'] as List)
                  : <Map<String, dynamic>>[];
              final purchasedIds = widget.carts
                  .map((c) => c.grocery['productId']?.toString() ?? '')
                  .where((id) => id.isNotEmpty)
                  .toSet();
              items.removeWhere((it) =>
                  purchasedIds.contains(it['productId']?.toString() ?? ''));
              final selected =
                  (data != null && data['selectedProductIds'] is List)
                      ? List<String>.from(data['selectedProductIds'] as List)
                      : <String>[];
              selected.removeWhere((id) => purchasedIds.contains(id));
              await cartDoc.set({
                'items': items,
                'selectedProductIds': selected
              }, SetOptions(merge: true));
            }

            if (!mounted) return;
            NotificationHelper.showSuccess(
              context,
              l10n.reservationCreatedSuccess,
              'Vui lòng chờ cửa hàng xác nhận.',
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (state is ReservationError) {
            DialogHelper.safeHideLoadingDialog();
            NotificationHelper.showError(context, 'Lỗi', state.message);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(l10n.storePickup),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          body: BlocBuilder<DepositSettingsBloc, DepositSettingsState>(
            builder: (context, state) {
              if (state is DepositSettingsLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is DepositSettingsError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      state.message,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (state is! DepositSettingsLoaded) {
                return const SizedBox.shrink();
              }

              final settings = state.settings;

              if (!settings.isEnabled) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Chức năng đặt trước tạm thời không khả dụng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vui lòng chọn giao hàng tận nơi',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final totalAmount = _calculateTotal();
              final depositAmount = settings.calculateDeposit(totalAmount);
              final paymentAmount = _calculatePaymentAmount(settings);
              final remainingAmount = totalAmount - paymentAmount;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StorePickupHeader(),
                    const SizedBox(height: 24),
                    PickupDateCard(
                      selectedDate: selectedPickupDate,
                      maxDays: settings.maxReservationDays,
                      onTap: () => _selectPickupDate(settings.maxReservationDays),
                    ),
                    const SizedBox(height: 24),
                    PaymentOptionCard(
                      isPayingDeposit: isPayingDeposit,
                      depositAmount: depositAmount,
                      totalAmount: totalAmount,
                      depositPercentage: settings.depositPercentage.toInt(),
                      onChanged: (val) => setState(() => isPayingDeposit = val),
                    ),
                    const SizedBox(height: 24),
                    PaymentMethodCard(
                      selectedMethod: paymentMethod,
                      onChanged: (val) => setState(() => paymentMethod = val),
                    ),
                    const SizedBox(height: 24),
                    ReservationItemsList(carts: widget.carts),
                    const SizedBox(height: 24),
                    ReservationSummaryCard(
                      totalAmount: totalAmount,
                      paymentAmount: paymentAmount,
                      remainingAmount: remainingAmount,
                      isPayingDeposit: isPayingDeposit,
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              );
            },
          ),
          bottomNavigationBar:
              BlocBuilder<DepositSettingsBloc, DepositSettingsState>(
            builder: (context, state) {
              if (state is! DepositSettingsLoaded || !state.settings.isEnabled) {
                return const SizedBox.shrink();
              }

              final paymentAmount = _calculatePaymentAmount(state.settings);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: ElevatedButton(
                    onPressed: () => _createReservation(state.settings),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '${l10n.reserveNow} - ${CurrencyHelper.formatVND(paymentAmount)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
