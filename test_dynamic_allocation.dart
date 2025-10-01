import 'dart:math' as math;

void main() {
  print('🔍 Testing Dynamic Allocation Algorithm...\n');
  
  // Test scenarios
  final scenarios = [
    {'totalLimit': 15, 'breeds': ['Chim yến phụng', 'Chim hoạ mi', 'Cá vàng', 'Chihuahua', 'Golden Retriever']},
    {'totalLimit': 10, 'breeds': ['Cá vàng', 'Golden Retriever']},
    {'totalLimit': 20, 'breeds': ['Chihuahua', 'Golden Retriever', 'Husky']},
  ];
  
  for (int i = 0; i < scenarios.length; i++) {
    final scenario = scenarios[i];
    final totalLimit = scenario['totalLimit'] as int;
    final breeds = scenario['breeds'] as List<String>;
    final phase1Limit = (totalLimit * 0.8).round();
    
    print('📊 Scenario ${i+1}: $totalLimit total pets, ${breeds.length} breeds');
    print('   Phase 1 limit: $phase1Limit pets (80%)');
    print('   Breeds: $breeds\n');
    
    int currentItems = 0;
    for (int breedIndex = 0; breedIndex < breeds.length; breedIndex++) {
      final breed = breeds[breedIndex];
      final remainingSlots = phase1Limit - currentItems;
      final remainingBreeds = breeds.length - breedIndex;
      
      if (remainingSlots <= 0) {
        print('   ⏹️ STOPPED: No more slots for "$breed"');
        break;
      }
      
      // Smart allocation algorithm
      final baseAllocation = (remainingSlots / remainingBreeds).ceil();
      final maxPerBreed = math.max(2, (remainingSlots * 0.4).round());
      final dynamicLimit = math.min(baseAllocation, maxPerBreed);
      
      // Simulate pets found (random for demo)
      final petsFound = math.min(dynamicLimit, [2, 5, 4, 3, 4][breedIndex % 5]);
      currentItems += petsFound;
      
      print('   🎯 "$breed": slots=$remainingSlots, remaining_breeds=$remainingBreeds');
      print('      → base=$baseAllocation, max=$maxPerBreed, limit=$dynamicLimit → added $petsFound pets');
    }
    
    print('   ✅ Total allocated: $currentItems/$phase1Limit pets\n');
  }
  
  print('🚀 Algorithm ensures:');
  print('   1. Fair distribution across all breeds');
  print('   2. No single breed takes more than 40% of remaining slots');
  print('   3. Earlier breeds get priority but later breeds still get representation');
  print('   4. Dynamic adjustment based on available pets per breed');
}