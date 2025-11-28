import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/pet_analytics/components/breed_performance_chart.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/pet_analytics/components/pet_status_chart.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/pet/components/pet_details_dialog.dart';
import 'package:pet_shop/presentation/pages/web/model/pet_model.dart';

class PetAnalyticsPage extends StatefulWidget {
  const PetAnalyticsPage({super.key});

  @override
  State<PetAnalyticsPage> createState() => _PetAnalyticsPageState();
}

class _PetAnalyticsPageState extends State<PetAnalyticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.petAnalytics,
          style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: Theme.of(context).colorScheme.onSurface),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.onSurface,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(
                icon: const Icon(Icons.analytics),
                text: AppLocalizations.of(context)!.overview),
            Tab(
                icon: const Icon(Icons.inventory),
                text: AppLocalizations.of(context)!.available),
            Tab(
                icon: const Icon(Icons.shopping_cart),
                text: AppLocalizations.of(context)!.sold),
            // Tab(
            //     icon: const Icon(Icons.trending_up),
            //     text: AppLocalizations.of(context)!.statistics),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAvailablePetsTab(),
          _buildSoldPetsTab(),
          // _buildStatisticsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Pets').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return Center(
              child: Text(AppLocalizations.of(context)!.noDataAvailable));
        }

        final pets = snapshot.data!.docs;
        final totalPets = pets.length;
        final soldPets = pets
            .where((doc) =>
                doc.data() is Map<String, dynamic> &&
                (doc.data() as Map<String, dynamic>)['status'] == 'sold')
            .length;
        final availablePets = totalPets - soldPets;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        AppLocalizations.of(context)!.totalPets,
                        totalPets.toString(),
                        Icons.pets,
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        AppLocalizations.of(context)!.available,
                        availablePets.toString(),
                        Icons.inventory,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        AppLocalizations.of(context)!.sold,
                        soldPets.toString(),
                        Icons.shopping_cart,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        AppLocalizations.of(context)!.successRate,
                        totalPets > 0
                            ? '${((soldPets / totalPets) * 100).toStringAsFixed(1)}%'
                            : '0%',
                        Icons.trending_up,
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: PetStatusChart(
                        totalPets: totalPets,
                        soldPets: soldPets,
                        availablePets: availablePets,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 400,
                        child: _buildBreedPerformanceChart(pets),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 500, // Fixed height for breed analysis
                  child: _buildBreedAnalysis(pets),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailablePetsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Pets').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.noDataAvailable,
                    style: const TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        // Filter available pets (pets without 'sold' status)
        final availablePets = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] != 'sold';
        }).toList();

        if (availablePets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.noAvailablePets,
                    style: const TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        return _buildPetsList(availablePets,
            AppLocalizations.of(context)!.availablePets, Colors.blue);
      },
    );
  }

  Widget _buildSoldPetsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Pets')
          .where('status', isEqualTo: 'sold')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.noSoldPets,
                    style: const TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        final pets = snapshot.data!.docs;
        return _buildPetsList(
            pets, AppLocalizations.of(context)!.soldPets, Colors.orange);
      },
    );
  }

  // ignore: unused_element
  Widget _buildStatisticsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Pets').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return Center(
              child: Text(AppLocalizations.of(context)!.noDataAvailable));
        }

        final pets = snapshot.data!.docs;
        return _buildDetailedStatistics(pets);
      },
    );
  }

  Widget _buildBreedPerformanceChart(List<QueryDocumentSnapshot> pets) {
    Map<String, Map<String, int>> breedData = {};

    for (var doc in pets) {
      final data = doc.data() as Map<String, dynamic>;
      final breed = data['breed'] ?? 'Unknown';
      final status = data['status'];

      if (!breedData.containsKey(breed)) {
        breedData[breed] = {'total': 0, 'sold': 0};
      }

      breedData[breed]!['total'] = (breedData[breed]!['total'] ?? 0) + 1;
      if (status == 'sold') {
        breedData[breed]!['sold'] = (breedData[breed]!['sold'] ?? 0) + 1;
      }
    }

    return BreedPerformanceChart(breedData: breedData);
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreedAnalysis(List<QueryDocumentSnapshot> pets) {
    Map<String, int> breedCount = {};
    Map<String, int> breedSold = {};

    for (var doc in pets) {
      final data = doc.data() as Map<String, dynamic>;
      final breed = data['breed'] ?? 'Chưa rõ';
      final status = data['status'];

      breedCount[breed] = (breedCount[breed] ?? 0) + 1;
      if (status == 'sold') {
        breedSold[breed] = (breedSold[breed] ?? 0) + 1;
      }
    }

    final sortedBreeds = breedCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.breedAnalysis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: sortedBreeds.length,
              itemBuilder: (context, index) {
                final entry = sortedBreeds[index];
                final breed = entry.key;
                final total = entry.value;
                final sold = breedSold[breed] ?? 0;
                final available = total - sold;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          breed,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        child: Text(
                            '${AppLocalizations.of(context)!.totalPets}: $total'),
                      ),
                      Expanded(
                        child: Text(
                          '${AppLocalizations.of(context)!.available}: $available',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${AppLocalizations.of(context)!.sold}: $sold',
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${total > 0 ? ((sold / total) * 100).toStringAsFixed(1) : 0}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetsList(
      List<QueryDocumentSnapshot> pets, String title, Color color) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: color.withOpacity(0.1),
          child: Text(
            '$title (${pets.length})',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pets.length,
            itemBuilder: (context, index) {
              final data = pets[index].data() as Map<String, dynamic>;
              return _buildPetCard(data, pets[index].id);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPetCard(Map<String, dynamic> data, String id) {
    return InkWell(
      onTap: () => _showPetDetails(data, id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                data['imageUrl'] ?? '',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.pets),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? 'Chưa rõ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppLocalizations.of(context)!.breeds}: ${data['breed'] ?? 'Chưa rõ'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Tuổi: ${data['age'] ?? 'Chưa rõ'} năm',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyHelper.formatVND(data['price']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xff08A045),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: data['status'] == 'sold' ? Colors.orange : Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data['status'] == 'sold' ? 'Sold' : 'Available',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showPetDetails(Map<String, dynamic> data, String id) {
    // Convert data to Pet model
    final pet = Pet(
      id: id,
      name: data['name'] ?? 'Unknown',
      category: data['category'] ?? 'Unknown',
      imageUrl: data['imageUrl'] ?? '',
      age: data['age']?.toString() ?? '0',
      breed: data['breed'] ?? 'Unknown',
      about: data['about'] ?? 'No description',
      gender: data['sex'] ?? 'Unknown',
      weight: data['weight']?.toString() ?? '0',
      price: data['price'],
      color: data['color'],
      isAvailable: data['isAvailable'] ?? false,
      status: data['status'],
    );

    showDialog(
      context: context,
      builder: (context) => PetDetailsDialog(pet: pet),
    );
  }

  Widget _buildDetailedStatistics(List<QueryDocumentSnapshot> pets) {
    // Calculate various statistics
    Map<String, dynamic> stats = _calculateDetailedStats(pets);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsSection(AppLocalizations.of(context)!.revenueAnalysis, [
              _buildStatRow(AppLocalizations.of(context)!.totalRevenue,
                  CurrencyHelper.formatVND(stats['totalRevenue'])),
              _buildStatRow(AppLocalizations.of(context)!.averagePrice,
                  CurrencyHelper.formatVND(stats['avgPrice'])),
              _buildStatRow(AppLocalizations.of(context)!.highestPrice,
                  CurrencyHelper.formatVND(stats['maxPrice'])),
              _buildStatRow(AppLocalizations.of(context)!.lowestPrice,
                  CurrencyHelper.formatVND(stats['minPrice'])),
            ]),
            const SizedBox(height: 24),
            _buildStatsSection(AppLocalizations.of(context)!.petDemographics, [
              _buildStatRow(AppLocalizations.of(context)!.mostPopularBreed,
                  stats['popularBreed']),
              _buildStatRow(AppLocalizations.of(context)!.averageAge,
                  '${stats['avgAge'].toStringAsFixed(1)} years'),
              _buildStatRow(AppLocalizations.of(context)!.malePets,
                  '${stats['maleCount']} (${stats['malePercentage'].toStringAsFixed(1)}%)'),
              _buildStatRow(AppLocalizations.of(context)!.femalePets,
                  '${stats['femaleCount']} (${stats['femalePercentage'].toStringAsFixed(1)}%)'),
            ]),
            const SizedBox(height: 24),
            _buildStatsSection(AppLocalizations.of(context)!.salesPerformance, [
              _buildStatRow(AppLocalizations.of(context)!.conversionRate,
                  '${stats['conversionRate'].toStringAsFixed(1)}%'),
              _buildStatRow(AppLocalizations.of(context)!.petsAddedThisMonth,
                  stats['addedThisMonth'].toString()),
              _buildStatRow(AppLocalizations.of(context)!.petsSoldThisMonth,
                  stats['soldThisMonth'].toString()),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xff08A045),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateDetailedStats(
      List<QueryDocumentSnapshot> pets) {
    if (pets.isEmpty) {
      return {
        'totalRevenue': 0.0,
        'avgPrice': 0.0,
        'maxPrice': 0.0,
        'minPrice': 0.0,
        'popularBreed': 'N/A',
        'avgAge': 0.0,
        'maleCount': 0,
        'femaleCount': 0,
        'malePercentage': 0.0,
        'femalePercentage': 0.0,
        'conversionRate': 0.0,
        'addedThisMonth': 0,
        'soldThisMonth': 0,
      };
    }

    double totalRevenue = 0.0;
    double totalPrice = 0.0;
    double maxPrice = 0.0;
    double minPrice = double.infinity;
    double totalAge = 0.0;
    int maleCount = 0;
    int femaleCount = 0;
    int soldCount = 0;
    int addedThisMonth = 0;
    int soldThisMonth = 0;

    Map<String, int> breedCount = {};

    for (var doc in pets) {
      final data = doc.data() as Map<String, dynamic>;

      // Safe price conversion
      double price = 0.0;
      final priceValue = data['price'];
      if (priceValue != null) {
        if (priceValue is num) {
          price = priceValue.toDouble();
        } else if (priceValue is String) {
          price = double.tryParse(priceValue) ?? 0.0;
        }
      }

      // Safe age conversion
      double age = 0.0;
      final ageValue = data['age'];
      if (ageValue != null) {
        if (ageValue is num) {
          age = ageValue.toDouble();
        } else if (ageValue is String) {
          age = double.tryParse(ageValue) ?? 0.0;
        }
      }

      final sex = data['sex']?.toString().toLowerCase() ?? '';
      final breed = data['breed']?.toString() ?? 'Chưa rõ';
      final status = data['status']?.toString();

      // Price calculations
      totalPrice += price;
      if (price > maxPrice) maxPrice = price;
      if (price < minPrice && price > 0) minPrice = price;

      // Revenue from sold pets
      if (status == 'sold') {
        totalRevenue += price;
        soldCount++;
      }

      // Age calculation
      totalAge += age;

      // Gender count
      if (sex.contains('male') && !sex.contains('female')) {
        maleCount++;
      } else if (sex.contains('female')) {
        femaleCount++;
      }

      // Breed popularity
      breedCount[breed] = (breedCount[breed] ?? 0) + 1;

      // Monthly statistics (simplified - you might want to use timestamp fields)
      addedThisMonth++;
      if (status == 'sold') soldThisMonth++;
    }

    // Find most popular breed
    String popularBreed = 'N/A';
    int maxBreedCount = 0;
    breedCount.forEach((breed, count) {
      if (count > maxBreedCount) {
        maxBreedCount = count;
        popularBreed = breed;
      }
    });

    final totalPets = pets.length;

    return {
      'totalRevenue': totalRevenue,
      'avgPrice': totalPets > 0 ? totalPrice / totalPets : 0.0,
      'maxPrice': maxPrice == 0 ? 0.0 : maxPrice,
      'minPrice': minPrice == double.infinity ? 0.0 : minPrice,
      'popularBreed': popularBreed,
      'avgAge': totalPets > 0 ? totalAge / totalPets : 0.0,
      'maleCount': maleCount,
      'femaleCount': femaleCount,
      'malePercentage': totalPets > 0 ? (maleCount / totalPets) * 100 : 0.0,
      'femalePercentage': totalPets > 0 ? (femaleCount / totalPets) * 100 : 0.0,
      'conversionRate': totalPets > 0 ? (soldCount / totalPets) * 100 : 0.0,
      'addedThisMonth': addedThisMonth,
      'soldThisMonth': soldThisMonth,
    };
  }
}
