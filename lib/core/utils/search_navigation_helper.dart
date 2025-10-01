import 'package:flutter/material.dart';
import 'package:pet_shop/presentation/pages/mobile/search/search_page.dart';
import 'package:pet_shop/presentation/pages/mobile/search/search_results_page.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';
import 'package:pet_shop/presentation/bloc/search/search_bloc.dart';

/// Helper class to manage search-related navigation flows
/// Prevents navigation stack buildup by using smart replacement patterns
class SearchNavigationHelper {
  
  /// Navigate from SearchPage to SearchResultsPage
  /// Always uses pushReplacement to avoid stack buildup
  static void navigateToResults({
    required BuildContext context,
    required String searchQuery,
    required List<Map<String, dynamic>> results,
    required SearchBloc searchBloc,
    String? originalSearchText,
    dynamic searchImage,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsPage(
          searchQuery: searchQuery,
          initialResults: results,
          searchImage: searchImage,
          searchBloc: searchBloc,
          originalSearchText: originalSearchText,
        ),
      ),
    );
  }
  
  /// Navigate from SearchResultsPage to DetailPet
  /// Uses push with special back handling to prevent deep stack
  static void navigateToDetail({
    required BuildContext context,
    required Map<String, dynamic> pet,
    String? fromSearchQuery,
    SearchBloc? searchBloc,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailPet(
          pet: pet,
        ),
      ),
    );
  }
  
  /// Navigate back from SearchResultsPage to SearchPage
  /// Always uses pushReplacement to maintain clean navigation
  static void navigateBackToSearch({
    required BuildContext context,
    String? preserveQuery,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const SearchPage(),
      ),
    );
  }
  
  /// Smart back navigation from DetailPet
  /// Decides whether to go back to results or directly to search
  static void navigateBackFromDetail({
    required BuildContext context,
    Map<String, dynamic>? searchContext,
  }) {
    if (searchContext != null) {
      // If came from search, go back to search page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const SearchPage(),
        ),
      );
    } else {
      // Normal back navigation
      Navigator.pop(context);
    }
  }
  
  /// Replace current results with new search results
  /// Used when searching from within SearchResultsPage
  static void replaceResults({
    required BuildContext context,
    required String newSearchQuery,
    required List<Map<String, dynamic>> newResults,
    required SearchBloc searchBloc,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsPage(
          searchQuery: newSearchQuery,
          initialResults: newResults,
          searchBloc: searchBloc,
        ),
      ),
    );
  }
  
  /// Clear entire search stack and return to fresh SearchPage
  /// Useful for "Start New Search" functionality
  static void clearSearchStack({
    required BuildContext context,
  }) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const SearchPage(),
      ),
      (route) => route.isFirst, // Keep only the root route
    );
  }
}