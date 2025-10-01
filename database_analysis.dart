// Check database for Golden Retriever pets
import 'dart:io';

void main() async {
  print('🔍 Database Analysis for Golden Retriever Issue...');
  
  // Simulated database check (you'll need to run this with Firebase connection)
  print('\n📊 Expected breed patterns in database:');
  
  final expectedBreeds = [
    'Chim yến phụng',
    'Chim hoạ mi', 
    'Cá vàng',
    'Chihuahua',
    'Golden Retriever', // This might be the issue
    'Chim sáo',
    'Husky'
  ];
  
  print('\n🔍 Breed name analysis:');
  for (final breed in expectedBreeds) {
    print('   "$breed" - Length: ${breed.length} chars');
    if (breed.contains('Golden')) {
      print('     ⚠️ Contains "Golden" - check for case sensitivity');
    }
    if (breed.contains('Retriever')) {
      print('     ⚠️ Contains "Retriever" - check for spacing/typos');
    }
  }
  
  print('\n🚨 Potential Issues:');
  print('   1. Database might have "golden retriever" (lowercase)');
  print('   2. Database might have "Golden retriever" (mixed case)');
  print('   3. Database might have "GoldenRetriever" (no space)');
  print('   4. Database might not have ANY Golden Retriever pets');
  print('   5. Breed field might be null/empty for Golden Retriever pets');
  
  print('\n💡 Solutions to test:');
  print('   1. Case-insensitive query');
  print('   2. Partial match query');
  print('   3. Debug all breeds in database');
  print('   4. Add sample Golden Retriever pets if missing');
  
  // Create analysis file
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final analysisFile = File('GOLDEN_RETRIEVER_DATABASE_ANALYSIS_$timestamp.txt');
  
  final content = '''
=== GOLDEN RETRIEVER DATABASE ANALYSIS ===
Generated: ${DateTime.now().toIso8601String()}

ISSUE: Golden Retriever not appearing in UI despite being included in targeting

BACKEND STATUS: ✅ WORKING
- Golden Retriever included in breed targeting list
- Dynamic threshold (16) successfully includes Golden Retriever (score: 17)
- Logs show: "PHASE 1: Dynamic breed targeting: [Chim yến phụng, Chim hoạ mi, Cá vàng, Chihuahua, Golden Retriever]"

FRONTEND STATUS: ❌ NOT WORKING  
- UI shows: Chim phụng yến, Chim họa mi, Chihuahua, Cá vàng, Chihuahua, Mèo anh lông ngắn
- Golden Retriever missing from display
- Chihuahua duplicated (suspicious)
- Mèo anh lông ngắn appears (not in targeting list)

HYPOTHESIS: DATABASE ISSUE
1. No pets with exact breed name "Golden Retriever"
2. Case sensitivity mismatch
3. Breed name variations in database
4. Query breaking early due to 60% limit

EXPECTED LOGS (MISSING):
🎯 BREED-SPECIFIC: "Chihuahua" (score: 20) -> X pets found
🎯 BREED-SPECIFIC: "Golden Retriever" (score: 17) -> X pets found

DEBUGGING STEPS:
1. Enhanced logging added to track each breed query
2. Check for empty results per breed
3. Add case-insensitive fallback queries
4. Verify database has Golden Retriever pets
5. Test with manual breed search

EXPECTED FIX:
After enhanced logging, we should see either:
- "0 pets found" for Golden Retriever (database issue)
- "Early break" before reaching Golden Retriever (limit issue)
- Successful matches but UI filtering issue
''';
  
  await analysisFile.writeAsString(content);
  print('\n📄 Analysis saved to: ${analysisFile.path}');
  
  print('\n🚀 Next Steps:');
  print('   1. Run app again with enhanced logging');
  print('   2. Check specific logs for Chihuahua and Golden Retriever');
  print('   3. If 0 pets found, add Golden Retriever pets to database');
  print('   4. If early break, increase recommendation limit');
}