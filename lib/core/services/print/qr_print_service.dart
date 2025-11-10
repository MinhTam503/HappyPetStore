import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart';

class QRPrintService {
  /// In QR code cho một thú cưng
  static Future<void> printSinglePetQR({
    required String petId,
    required String petName,
    String? petBreed,
    String? imageUrl,
  }) async {
    try {
      final pdf = pw.Document();

      // Tạo QR data với format JSON
      final qrData = 'PET:$petId';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(40),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey300,
                    width: 2,
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    // Pet name
                    pw.Text(
                      petName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    if (petBreed != null && petBreed.isNotEmpty)
                      pw.Text(
                        petBreed,
                        style: const pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.grey700,
                        ),
                      ),
                    pw.SizedBox(height: 24),
                    
                    // QR Code
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrData,
                      width: 200,
                      height: 200,
                    ),
                    
                    pw.SizedBox(height: 16),
                    
                    // Pet ID
                    pw.Text(
                      'ID: $petId',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                    
                    pw.SizedBox(height: 24),
                    
                    // Footer
                    pw.Text(
                      'Happy Pet Shop',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      // Check if running on web
      if (kIsWeb) {
        // On web, download PDF instead of printing
        final pdfBytes = await pdf.save();
        downloadPdf(pdfBytes, 'pet_qr_$petId.pdf');
      } else {
        // On native platforms, use printing dialog
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'pet_qr_$petId.pdf',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error printing single pet QR: $e');
      }
      rethrow;
    }
  }

  /// In QR code cho nhiều thú cưng
  static Future<void> printMultiplePetQRs({
    required List<Map<String, dynamic>> pets,
  }) async {
    try {
      final pdf = pw.Document();

      // Tính số trang cần thiết (4 QR codes per page trong grid 2x2)
      const itemsPerPage = 4;
      final totalPages = (pets.length / itemsPerPage).ceil();

      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final startIndex = pageIndex * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, pets.length);
        final pagePets = pets.sublist(startIndex, endIndex);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Padding(
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  children: [
                    // Header
                    pw.Text(
                      'Happy Pet Shop - QR Codes',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(),
                    pw.SizedBox(height: 20),
                    
                    // Grid of QR codes (2x2)
                    pw.Expanded(
                      child: pw.GridView(
                        crossAxisCount: 2,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        children: pagePets.map((pet) {
                          final petId = pet['id'] ?? '';
                          final petName = pet['name'] ?? 'Unknown';
                          final petBreed = pet['breed'] ?? '';
                          final qrData = 'PET:$petId';

                          return pw.Container(
                            padding: const pw.EdgeInsets.all(16),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                color: PdfColors.grey400,
                                width: 1.5,
                              ),
                              borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(8),
                              ),
                            ),
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                // Pet name
                                pw.Text(
                                  petName,
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                  maxLines: 1,
                                  overflow: pw.TextOverflow.clip,
                                ),
                                if (petBreed.isNotEmpty) ...[
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    petBreed,
                                    style: const pw.TextStyle(
                                      fontSize: 10,
                                      color: PdfColors.grey700,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                    maxLines: 1,
                                  ),
                                ],
                                pw.SizedBox(height: 12),
                                
                                // QR Code
                                pw.BarcodeWidget(
                                  barcode: pw.Barcode.qrCode(),
                                  data: qrData,
                                  width: 120,
                                  height: 120,
                                ),
                                
                                pw.SizedBox(height: 8),
                                
                                // Pet ID
                                pw.Text(
                                  'ID: $petId',
                                  style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.grey600,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    
                    // Footer
                    pw.SizedBox(height: 20),
                    pw.Divider(),
                    pw.Text(
                      'Page ${pageIndex + 1} of $totalPages',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }

      // Check if running on web
      if (kIsWeb) {
        // On web, download PDF instead of printing
        final pdfBytes = await pdf.save();
        downloadPdf(pdfBytes, 'pets_qr_codes.pdf');
      } else {
        // On native platforms, use printing dialog
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'pets_qr_codes.pdf',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error printing multiple pet QRs: $e');
      }
      rethrow;
    }
  }

  /// Kiểm tra xem in có khả dụng không
  static Future<bool> isPrintingAvailable() async {
    try {
      await Printing.info();
      return true;
    } catch (e) {
      return false;
    }
  }
}
