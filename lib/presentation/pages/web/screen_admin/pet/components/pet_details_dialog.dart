import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/presentation/pages/web/model/pet_model.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/pet/components/pet_info_row.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/pet/components/pet_qr_code_section.dart';

/// Dialog hiển thị chi tiết thông tin thú cưng
class PetDetailsDialog extends StatelessWidget {
  final Pet pet;

  const PetDetailsDialog({
    super.key,
    required this.pet,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 800,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pets,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pet.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pet Image
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: SizedBox(
                          width: 300,
                          height: 300,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Image.network(
                              pet.imageUrl,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image,
                                      size: 56, color: Colors.grey),
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  width: 240,
                                  height: 240,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pet Information
                    PetInfoRow(
                      icon: Icons.category,
                      title: l10n.category,
                      value: pet.category,
                    ),
                    PetInfoRow(
                      icon: Icons.pets,
                      title: l10n.breed,
                      value: pet.breed,
                    ),
                    PetInfoRow(
                      icon: Icons.price_change,
                      title: l10n.price,
                      value: CurrencyHelper.formatVND(pet.price ?? pet.weight),
                    ),
                    PetInfoRow(
                      icon: Icons.cake,
                      title: l10n.age,
                      value: '${pet.age} ${l10n.years}',
                    ),
                    PetInfoRow(
                      icon: Icons.male,
                      title: l10n.gender,
                      value: pet.gender,
                    ),
                    if (pet.color != null)
                      PetInfoRowWithColor(
                        icon: Icons.palette,
                        title: l10n.color,
                        colorKey: pet.color!,
                      ),
                    PetInfoRow(
                      icon: Icons.monitor_weight,
                      title: l10n.weight,
                      value: '${pet.weight} Kg',
                    ),
                    PetInfoRow(
                      icon: pet.isAvailable ? Icons.check_circle : Icons.cancel,
                      title: l10n.availableForSale,
                      value: pet.isAvailable ? 'Có sẵn' : 'Không có sẵn',
                      valueColor: pet.isAvailable 
                          ? Colors.green 
                          : Colors.red,
                    ),
                    const SizedBox(height: 16),

                    // QR Code Section

                    // About Section
                    Text(
                      l10n.about,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      pet.about,
                      textAlign: TextAlign.justify,
                    ),
                    PetQRCodeSection(
                      petId: pet.id,
                      petName: pet.name,
                      petBreed: pet.breed,
                      imageUrl: pet.imageUrl,
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

           
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child:
                        Text(l10n.close, style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
