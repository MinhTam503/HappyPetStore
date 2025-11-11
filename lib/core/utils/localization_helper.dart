// Deprecated shim: LocalizationHelper has been replaced by AppLocalizations (gen-l10n).
// This class remains only to avoid breaking imports during transition. It simply
// returns the provided fallback (or the key) without any real localization.
// Safe to delete once no imports remain.
// ignore_for_file: unused_import
import 'package:flutter/material.dart';

@Deprecated('Use AppLocalizations from flutter_gen instead')
class LocalizationHelper {
  static String getLocalizedText(BuildContext context, String key, {String? fallback}) {
    return fallback ?? key;
  }
}
