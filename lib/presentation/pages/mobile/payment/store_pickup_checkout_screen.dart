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
import 'package:pet_shop/presentation/bloc/vnpay/vnpay_bloc.dart';
import 'package:pet_shop/presentation/bloc/vnpay/vnpay_event.dart';
import 'package:pet_shop/presentation/bloc/vnpay/vnpay_state.dart';
import 'package:pet_shop/core/config/vnpay_config.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/vnpay_webview_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/order/order_success.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/components/store_pickup_header.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/components/pickup_date_card.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/components/payment_option_card.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/components/payment_method_card.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/components/reservation_items_list.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/components/reservation_summary_card.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/services/reservation_service.dart';


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

class _StorePickupCheckoutScreenState extends State<StorePickupCheckoutScreen> {
  final UserManager userManager = UserManager();

  Map<String, dynamic>? userInfo;
  DateTime? selectedPickupDate;
  String paymentMethod = 'vnpay';
  bool isPayingDeposit = true;
  double? _recentPaymentAmount;
  
  // Store pending reservation data until payment succeeds
  ReservationModel? _pendingReservation;

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
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
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
    final l10n = AppLocalizations.of(context)!;
    
    if (selectedPickupDate == null) {
      NotificationHelper.showWarning(
        context,
        l10n.selectPickupDate,
        l10n.pleaseSelectPickupDate,
      );
      return;
    }

    // Build items list
    List<Map<String, dynamic>> items = [];
    for (var item in widget.carts) {
      final petId = item.grocery["productId"]?.toString() ?? '';
      if (petId.isEmpty) continue;

      final petDoc =
          await FirebaseFirestore.instance.collection('Pets').doc(petId).get();

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
        l10n.error,
        l10n.petNotFoundInCart,
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      NotificationHelper.showError(
          context, l10n.error, l10n.pleaseLoginToReserve);
      return;
    }

    final totalAmount = _calculateTotal();
    final depositAmount = settings.calculateDeposit(totalAmount);
    final paymentAmount = _calculatePaymentAmount(settings);

    // Show confirmation dialog
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmReservationAction),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.youWillPay(
              isPayingDeposit ? l10n.depositPaymentType : l10n.fullPaymentType,
              CurrencyHelper.formatVND(paymentAmount),
            )),
            const SizedBox(height: 8),
            Text(
                '${l10n.paymentMethodLabel}: ${paymentMethod == "vnpay" ? "VNPay" : "Stripe"}'),
            const SizedBox(height: 8),
            Text(l10n.paymentNote),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Store reservation data (don't create Firestore doc yet - wait for payment)
    _pendingReservation = ReservationModel(
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
    _recentPaymentAmount = paymentAmount;

    if (!mounted) return;

    // Redirect to payment immediately (no Firestore reservation yet)
    if (paymentMethod == 'vnpay') {
      final orderId = 'RES_${DateTime.now().millisecondsSinceEpoch}';
      final orderInfo = 'Thanh toan dat truoc HappyPetStore $orderId';
      
      DialogHelper.showLoadingDialog(context, message: 'Đang tạo giao dịch VNPay...');
      context.read<VnpayBloc>().add(CreateVnpayPayment(
        orderId: orderId,
        amount: paymentAmount,
        orderInfo: orderInfo,
        returnUrl: VnpayConfig.returnUrl,
      ));
    } else if (paymentMethod == 'stripe') {
      NotificationHelper.showWarning(
        context,
        'Tính năng đang phát triển',
        'Thanh toán Stripe cho đặt trước đang được phát triển. Vui lòng chọn VNPay.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocProvider(
      create: (_) => DepositSettingsBloc()..add(const LoadDepositSettings()),
      child: MultiBlocListener(
        listeners: [
          // ReservationBloc listener removed - reservation created after payment success
      BlocListener<VnpayBloc, VnpayState>(
        listener: (context, state) async {
          if (state is VnpayPaymentUrlCreated) {
            final paymentUrl = state.payment.paymentUrl;
            if (paymentUrl == null) return;
            
            await DialogHelper.safeHideLoadingDialog();
            final result = await Navigator.push<Map<String, String>>(
              context,
              MaterialPageRoute(
                builder: (context) => VnpayWebViewScreen(
                  paymentUrl: paymentUrl,
                  returnUrl: VnpayConfig.returnUrl,
                ),
              ),
            );
            
            if (result != null && mounted) {
              // Verify VNPay callback immediately
              context.read<VnpayBloc>().add(VerifyVnpayCallback(result));
            } else if (mounted) {
              // User cancelled or closed payment window
              NotificationHelper.showInfo(
                context,
                'Đã hủy thanh toán',
                'Bạn có thể thử lại khi sẵn sàng.',
              );
            }
          } else if (state is VnpayPaymentVerified) {
            if (state.isSuccess) {
              // Payment successful - NOW create reservation in Firestore
              DialogHelper.showLoadingDialog(context, message: 'Đang xử lý đặt trước...');
              try {
                // Create reservation with payment info
                if (_pendingReservation != null && _recentPaymentAmount != null) {
                  final reservationId = await ReservationService().createReservation(_pendingReservation!);
                  
                  // Update payment status immediately
                  await ReservationService().updateReservationPayment(
                    reservationId,
                    _recentPaymentAmount!,
                  );
                }
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
                  await cartDoc.set(
                      {'items': items, 'selectedProductIds': selected},
                      SetOptions(merge: true));
                }
                
                // Extract breeds for OrderSuccess
                final purchasedBreeds = widget.carts
                    .map((item) => item.grocery["breed"] as String?)
                    .where((breed) => breed != null && breed.isNotEmpty)
                    .cast<String>()
                    .toSet()
                    .toList();
                
                await DialogHelper.safeHideLoadingDialog();
                if (!mounted) return;
                
                // Navigate directly to OrderSuccess
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderSuccess(purchasedBreeds: purchasedBreeds),
                  ),
                  (route) => route.isFirst,
                );
              } catch (e) {
                await DialogHelper.safeHideLoadingDialog();
                debugPrint('⚠️ Failed to process reservation payment: $e');
                if (!mounted) return;
                NotificationHelper.showError(
                  context,
                  'Lỗi xử lý',
                  'Không thể xử lý đặt trước. Vui lòng liên hệ hỗ trợ.',
                );
              }
            } else {
              // Payment failed or cancelled
              await DialogHelper.safeHideLoadingDialog();
              if (!mounted) return;
              NotificationHelper.showWarning(
                context,
                'Thanh toán chưa hoàn tất',
                'Đơn đặt trước chưa được tạo. Bạn có thể thử lại bất cứ lúc nào.',
              );
            }
          } else if (state is VnpayError) {
            await DialogHelper.safeHideLoadingDialog();
            NotificationHelper.showError(
              context,
              'Lỗi thanh toán VNPay',
              state.message,
            );
          }
        },
      ),
      ],
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: AppBar(
            title: Text(l10n.storePickup),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4)),
                        const SizedBox(height: 16),
                        Text(
                          l10n.reservationTemporarilyUnavailable,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.pleaseSelectHomeDelivery,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
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
                      onTap: () =>
                          _selectPickupDate(settings.maxReservationDays),
                    ),
                    const SizedBox(height: 24),
                    PaymentOptionCard(
                      isPayingDeposit: isPayingDeposit,
                      depositAmount: depositAmount,
                      totalAmount: totalAmount,
                      depositPercentage: settings.depositPercentage.toInt(),
                      isPercentageDeposit: settings.depositType == DepositType.percentage,
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
              if (state is! DepositSettingsLoaded ||
                  !state.settings.isEnabled) {
                return const SizedBox.shrink();
              }

              final paymentAmount = _calculatePaymentAmount(state.settings);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: ElevatedButton(
                    onPressed: () => _createReservation(state.settings),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
