String generateSearchKeywords(String text) {
  if (text.isEmpty) return '';
  
  // Convert to lowercase
  final lowercaseText = text.toLowerCase();
  
  // Split into words
  final words = lowercaseText.split(RegExp(r'[^\w\s]+'));
  
  // Generate n-grams (1 to 3 characters)
  final Set<String> keywords = {};
  
  for (var word in words) {
    word = word.trim();
    if (word.isEmpty) continue;
    
    // Add full word
    keywords.add(word);
    
    // Add word parts (ngrams)
    if (word.length > 1) {
      for (int i = 0; i < word.length - 1; i++) {
        for (int j = i + 1; j <= word.length && j <= i + 3; j++) {
          keywords.add(word.substring(i, j));
        }
      }
    }
  }
  
  return keywords.join(' ');
}