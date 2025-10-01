# Search Navigation Flow Analysis

## Current Problem
Khi user search -> results -> detail -> back -> search again -> results -> detail... sẽ tạo ra navigation stack dài, khiến back button phải đi qua nhiều màn hình.

## Current Navigation Pattern
```
SearchPage -> SearchResultsPage (pushReplacement)
SearchResultsPage -> SearchPage (pushReplacement)  
SearchResultsPage -> DetailPet (push)
DetailPet -> Back to SearchResultsPage
```

## Issue Analysis
1. **SearchPage ↔ SearchResultsPage**: Đã dùng `pushReplacement` tốt
2. **SearchResultsPage → DetailPet**: Dùng `push` - tạo stack buildup
3. **DetailPet back**: Về SearchResultsPage, nhưng nếu search lại sẽ tích lũy stack

## Major Apps Navigation Pattern
### Instagram, Facebook, TikTok, Shopee:
- Search → Results: Replace
- Results → Detail: Replace (hoặc modal)
- Detail back: Về main search, không về results cũ

### Google, YouTube:
- Search → Results: Replace  
- Results → Detail: New stack (nhưng có smart back handling)
- Detail back: Về search với query preserved

## Recommended Solution

### Option 1: Modal Pattern (như Instagram)
```dart
// DetailPet as bottom sheet or modal
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) => DetailPet(pet: pet),
);
```

### Option 2: Smart Replace Pattern (như Shopee)
```dart
// SearchResultsPage → DetailPet
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => DetailPet(
      pet: pet,
      previousRoute: 'search', // Indicate source
      searchQuery: widget.searchQuery, // Preserve context
    ),
  ),
);

// DetailPet back button
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => SearchPage(
      initialQuery: widget.searchQuery, // Restore search
    ),
  ),
);
```

### Option 3: Single Search Stack (Recommended)
```dart
// Use custom Navigator with search-specific stack management
class SearchNavigationStack {
  static final GlobalKey<NavigatorState> _searchNavigatorKey = 
      GlobalKey<NavigatorState>();
  
  static void navigateToResults(BuildContext context, ...) {
    // Always replace, never stack
  }
  
  static void navigateToDetail(BuildContext context, ...) {
    // Replace results, store context for smart back
  }
  
  static void navigateBack(BuildContext context) {
    // Smart back to appropriate screen
  }
}
```

## Implementation Priority
1. **Immediate fix**: Modify DetailPet back button behavior
2. **Medium term**: Implement smart navigation with context preservation  
3. **Long term**: Consider modal pattern for details

## Files to Modify
1. `search_results_page.dart` - Navigation to DetailPet
2. `detail_pet.dart` - Back button behavior  
3. `search_page.dart` - Query preservation
4. Create `search_navigation_helper.dart` - Centralized navigation logic