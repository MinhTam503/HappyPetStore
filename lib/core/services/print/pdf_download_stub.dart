/// Stub for PDF download functionality
/// This file is used when dart:html is not available (mobile/desktop)
void downloadPdf(List<int> bytes, String filename) {
  throw UnsupportedError('PDF download is only supported on web platform');
}
