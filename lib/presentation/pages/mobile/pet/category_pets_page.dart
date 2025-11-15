import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';
import 'package:pet_shop/presentation/widgets/pet_items_all.dart';

class CategoryPetsPage extends StatefulWidget {
  final String categoryName;
  final String categoryId;

  const CategoryPetsPage({
    super.key,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  State<CategoryPetsPage> createState() => _CategoryPetsPageState();
}

class _CategoryPetsPageState extends State<CategoryPetsPage> {
  List<Map<String, dynamic>> pets = [];
  List<Map<String, dynamic>> filteredPets = [];
  List<String> availableBreeds = ['all'];
  bool isLoading = true;
  String selectedBreed = 'all';
  Set<String> selectedSortCriteria = {'name'};
  bool isAscending = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    try {
      setState(() => isLoading = true);
      
      final snapshot = await FirebaseFirestore.instance
          .collection('Pets')
          .where('category', isEqualTo: widget.categoryName)
          .get();
      
      if (mounted) {
        final petsData = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).where((pet) {
          // Only show available pets (not sold)
          final isAvailable = pet['isAvailable'] ?? true;
          final status = pet['status']?.toString().toLowerCase() ?? '';
          return isAvailable && status != 'sold';
        }).toList();
        
        // Extract unique breeds
        final breeds = <String>{'all'};
        for (final pet in petsData) {
          final breed = pet['breed']?.toString();
          if (breed != null && breed.isNotEmpty) {
            breeds.add(breed);
          }
        }
        
        setState(() {
          pets = petsData;
          filteredPets = List.from(pets);
          availableBreeds = breeds.toList()..sort();
          isLoading = false;
        });
        _applySorting();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      print('Error loading pets: $e');
    }
  }

  void _filterByBreed(String breed) {
    setState(() {
      selectedBreed = breed;
      if (breed == 'all') {
        filteredPets = List.from(pets);
      } else {
        filteredPets = pets.where((pet) => 
          pet['breed']?.toString() == breed
        ).toList();
      }
    });
    _applySorting();
  }

  void _applySorting() {
    setState(() {
      filteredPets.sort((a, b) {
        int result = 0;
        
        // Apply multiple sorting criteria in order
        for (final criteria in selectedSortCriteria) {
          dynamic valueA, valueB;
          
          switch (criteria) {
            case 'name':
              valueA = a['name'] ?? '';
              valueB = b['name'] ?? '';
              break;
            case 'price':
              valueA = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
              valueB = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
              break;
            case 'age':
              valueA = int.tryParse(a['age']?.toString() ?? '0') ?? 0;
              valueB = int.tryParse(b['age']?.toString() ?? '0') ?? 0;
              break;
            case 'sex':
              valueA = a['sex'] ?? '';
              valueB = b['sex'] ?? '';
              break;
            default:
              valueA = a['name'] ?? '';
              valueB = b['name'] ?? '';
          }
          
          result = valueA.compareTo(valueB);
          if (result != 0) {
            break; // If values are different, stop here
          }
        }
        
        return isAscending ? result : -result;
      });
    });
  }

  void _showSortOptions() {
    final l10n = AppLocalizations.of(context);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.sortBy ?? 'Sắp xếp theo',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chọn nhiều tiêu chí (theo thứ tự ưu tiên):',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        _buildMultiSortOption('name', 'Tên', Icons.sort_by_alpha, setModalState),
                        _buildMultiSortOption('price', l10n?.priceAsc ?? 'Giá', Icons.attach_money, setModalState),
                        _buildMultiSortOption('age', 'Tuổi', Icons.cake, setModalState),
                        _buildMultiSortOption('sex', 'Giới tính', Icons.pets, setModalState),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => isAscending = true);
                            _applySorting();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.arrow_upward),
                          label: Text(l10n?.priceAsc ?? 'Tăng dần'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isAscending ? primaryColor : Colors.grey,
                            side: BorderSide(
                              color: isAscending ? primaryColor : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => isAscending = false);
                            _applySorting();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.arrow_downward),
                          label: Text(l10n?.priceDesc ?? 'Giảm dần'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: !isAscending ? primaryColor : Colors.grey,
                            side: BorderSide(
                              color: !isAscending ? primaryColor : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _applySorting();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMultiSortOption(String value, String label, IconData icon, StateSetter setModalState) {
    final isSelected = selectedSortCriteria.contains(value);
    final selectedIndex = selectedSortCriteria.toList().indexOf(value);
    
    return CheckboxListTile(
      secondary: Icon(icon, color: isSelected ? primaryColor : Colors.grey),
      title: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? primaryColor : Colors.black,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isSelected && selectedSortCriteria.length > 1) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${selectedIndex + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      value: isSelected,
      activeColor: primaryColor,
      onChanged: (bool? checked) {
        setModalState(() {
          if (checked == true) {
            selectedSortCriteria.add(value);
          } else {
            selectedSortCriteria.remove(value);
          }
          
          // Ensure at least one criterion is selected
          if (selectedSortCriteria.isEmpty) {
            selectedSortCriteria.add('name');
          }
        });
        
        setState(() {}); // Update main widget state
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text(widget.categoryName),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showSortOptions,
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: Column(
        children: [
          // Breed filter
          Container(
            height: 60,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Giống:',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: availableBreeds.map((breed) => 
                        _buildBreedChip(breed, breed == 'all' ? 'Tất cả' : breed)
                      ).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Pets grid
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredPets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pets_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n?.noResults ?? 'Không có thú cưng nào',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.78,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredPets.length,
                          itemBuilder: (context, index) {
                            final pet = filteredPets[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetailPet(pet: pet),
                                  ),
                                );
                              },
                              child: PetItemsAll(pet: pet),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreedChip(String value, String label) {
    final isSelected = selectedBreed == value;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (selected) => _filterByBreed(value),
        selectedColor: primaryColor.withOpacity(0.2),
        checkmarkColor: primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? primaryColor : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? primaryColor : Colors.grey.shade300,
        ),
      ),
    );
  }
}