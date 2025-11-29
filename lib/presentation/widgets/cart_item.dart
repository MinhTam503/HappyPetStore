import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_bloc.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_event.dart';
import '../../data/models/cart_model.dart';

class CartItem extends StatelessWidget {
  final CartModel cart;
  final bool showRemoveButton;
  const CartItem({
    super.key,
    required this.cart,
    this.showRemoveButton = true,
  });

  // Static method to check if pet is sold/unavailable
  static Future<bool> isPetSold(String productId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Pets')
          .doc(productId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        final status = data?['status']?.toString() ?? 'available';
        final isAvailable = data?['isAvailable'] ?? true;
        return status != 'available' || !isAvailable;
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (cart.grocery["imageUrl"] ?? '').toString();
    final name = (cart.grocery['name'] ?? '').toString();
    final priceText = CurrencyHelper.formatVND(cart.grocery['price']);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : const Icon(Icons.pets, color: Colors.black45),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _MetaRow(cart: cart),
                            const SizedBox(height: 8),
                            Text(
                              priceText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                        // Remove button
                        if (showRemoveButton) _RemoveButton(cart: cart),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatefulWidget {
  final CartModel cart;
  const _MetaRow({required this.cart});

  @override
  State<_MetaRow> createState() => _MetaRowState();
}

class _MetaRowState extends State<_MetaRow> {
  String? _breed;
  String? _color;
  bool _isSold = false;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Prefer data from cart item if available
    String? breed = widget.cart.grocery['breed']?.toString();
    String? gender =
        (widget.cart.grocery['gender'] ?? widget.cart.grocery['sex'])
            ?.toString();
    String? color = widget.cart.grocery['color']?.toString();
    
    // Check if pet is sold or not available
    bool isSold = false;
    bool isAvailable = true;

    if ((breed == null || breed.isEmpty) ||
        (gender == null || gender.isEmpty) ||
        (color == null || color.isEmpty)) {
      final productId = widget.cart.grocery['productId']?.toString();
      if (productId != null && productId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('Pets')
              .doc(productId)
              .get();
          if (doc.exists) {
            final data = doc.data();
            breed =
                breed?.isNotEmpty == true ? breed : data?['breed']?.toString();
            final g = data?['sex'] ?? data?['gender'];
            gender = gender?.isNotEmpty == true ? gender : g?.toString();
            color =
                color?.isNotEmpty == true ? color : data?['color']?.toString();
            
            // Check status
            final status = data?['status']?.toString().toLowerCase() ?? '';
            isSold = status == 'sold';
            isAvailable = data?['isAvailable'] ?? true;
          }
        } catch (_) {
          // ignore fetch error silently
        }
      }
    }

    if (mounted) {
      setState(() {
        _breed = breed;
        _color = color;
        _isSold = isSold;
        _isAvailable = isAvailable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = [
      _breed ?? widget.cart.grocery['breed']?.toString(),
      _color ?? widget.cart.grocery['color']?.toString(),
    ]
        .where((e) => e != null && e.toString().isNotEmpty)
        .map((e) => e!)
        .toList();
    
    // Show sold status if pet is sold
    if (_isSold || !_isAvailable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.red.shade700),
            const SizedBox(width: 4),
            Text(
              'Đã bán',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (parts.isEmpty) {
      // Show nothing to keep UI clean; could show a small placeholder if wanted
      return const SizedBox.shrink();
    }

    return Text(
      parts.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final CartModel cart;
  const _RemoveButton({required this.cart});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final userManager = UserManager();
        final userIdentifier = await userManager.getUserIdentifier();
        if (userIdentifier == null) {
          final l10n = AppLocalizations.of(context);
          NotificationHelper.showWarning(
            context,
            l10n?.notificationTitle ?? 'Thông báo',
            l10n?.pleaseLoginToContinue ?? 'Vui lòng đăng nhập để tiếp tục',
          );
          return;
        }
        context
            .read<CartBloc>()
            .add(RemoveFromCart(userIdentifier, cart.grocery['productId']));
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
      ),
    );
  }
}

// Note: Navigation to detail is handled by parent list item. This widget is display-only.
