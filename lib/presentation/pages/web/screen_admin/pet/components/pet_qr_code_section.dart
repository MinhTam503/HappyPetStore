import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pet_shop/core/services/print/qr_print_service.dart';

/// Widget hiển thị QR code section trong pet detail dialog
class PetQRCodeSection extends StatelessWidget {
  final String petId;
  final String petName;
  final String petBreed;
  final String imageUrl;

  const PetQRCodeSection({
    super.key,
    required this.petId,
    required this.petName,
    required this.petBreed,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
  // Tạo URL đầy đủ theo chuẩn mới để quét: /home/pet/:id trên domain production
  // NOTE: Nếu thay domain, đổi BASE_DOMAIN bên dưới.
  const baseDomain = 'https://adopt-pet-d1c88.web.app';
  final qrUrl = '$baseDomain/home/pet/$petId';

    return Center(
      child: Column(
        children: [
          // const Divider(),
          const SizedBox(height: 16),
          Text(
            l10n.qrCode,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: QrImageView(
              data: qrUrl,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ID: $petId',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            qrUrl,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await QRPrintService.printSinglePetQR(
                  petId: petId,
                  petName: petName,
                  petBreed: petBreed,
                  imageUrl: imageUrl,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${l10n.errorPrintingQR}: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.print),
            label: Text(l10n.printQRCode),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // const Divider(),
        ],
      ),
    );
  }
}
