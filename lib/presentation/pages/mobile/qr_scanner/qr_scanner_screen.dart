import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _handleQRCode(String code) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    final l10n = AppLocalizations.of(context)!;

    try {
      // Show loading dialog
      if (mounted) {
        DialogHelper.showLoadingDialog(context, message: l10n.scanningPet);
      }

      // Validate if code looks like a pet ID
      if (code.isEmpty) {
        throw Exception(l10n.invalidQRCode);
      }

      // Parse QR code - support both "PET:xxx" format and plain "xxx" format
      String petId = code;
      if (code.startsWith('PET:')) {
        petId = code.substring(4); // Remove "PET:" prefix
      }

      // Validate petId is not empty after parsing
      if (petId.isEmpty) {
        throw Exception(l10n.invalidQRCode);
      }

      // Query Firestore for pet with this ID
      final petDoc = await FirebaseFirestore.instance
          .collection('Pets')
          .doc(petId)
          .get();

      // Hide loading dialog
      if (mounted) {
        DialogHelper.safeHideLoadingDialog();
      }

      if (!petDoc.exists) {
        if (mounted) {
          _showErrorDialog(l10n.petNotFound);
        }
        return;
      }

      // Get pet data
      final petData = petDoc.data() as Map<String, dynamic>;
      petData['id'] = petDoc.id;

      // Navigate to detail pet screen
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailPet(pet: petData),
          ),
        );
      }
    } catch (e) {
      // Hide loading dialog on error
      if (mounted) {
        DialogHelper.safeHideLoadingDialog();
        _showErrorDialog(l10n.invalidQRCode);
      }
      debugPrint('Error processing QR code: $e');
    } finally {
      // Reset processing flag after a delay to prevent rapid scans
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.authError),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanQRCode),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_off),
            iconSize: 32.0,
            onPressed: () => cameraController.toggleTorch(),
            tooltip: 'Flash',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            iconSize: 32.0,
            onPressed: () => cameraController.switchCamera(),
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null && code.isNotEmpty && !_isProcessing) {
                  debugPrint('QR Code detected: $code');
                  _handleQRCode(code);
                  break;
                }
              }
            },
          ),
          // Overlay with scanning area
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
            ),
            child: Stack(
              children: [
                // Cut out center for scanning area
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                    ),
                  ),
                ),
                // Instruction text
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Text(
                      l10n.scanQRCodeDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Make center area transparent for camera view
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 300,
                height: 300,
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
