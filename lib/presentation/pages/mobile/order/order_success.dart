import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/order/your_order_screen.dart';
import 'package:pet_shop/data/datasources/local/apriori/apriori_algorithm.dart';

import '../../../widgets/pet_items_all.dart';
import '../pet/detail_pet.dart';

class OrderSuccess extends StatefulWidget {
  final List<Map<String, dynamic>> suggestions;
  final List<String>? purchasedBreeds; // optional: breeds from the order to seed Apriori

  const OrderSuccess({super.key, this.suggestions = const [], this.purchasedBreeds});

  @override
  State<OrderSuccess> createState() => _OrderSuccessState();
}

class _OrderSuccessState extends State<OrderSuccess> {
  late List<Map<String, dynamic>> petItems;
  List<Map<String, dynamic>> top5BestSell = [];
  bool _loadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    petItems = widget.suggestions;
    // If no suggestions were passed, try to compute via Apriori using purchased breeds
    if (petItems.isEmpty && (widget.purchasedBreeds != null && widget.purchasedBreeds!.isNotEmpty)) {
      _loadAprioriSuggestions(widget.purchasedBreeds!);
    }
    getTop5BestSellingBreeds();
  }

  Future<void> _loadAprioriSuggestions(List<String> purchasedBreeds) async {
    try {
      setState(() => _loadingSuggestions = true);
      final algo = AprioriAlgorithm();
      // Use multi-breed mining; slightly loosen thresholds for small datasets
      final suggestions = await algo.getSuggestedPetsForBreeds(
        purchasedBreeds,
        minSupport: 0.01,
        minConfidence: 0.1,
        maxConsequents: 1,
        maxItemsetSize: 3,
        maxResults: 8,
      );
      if (!mounted) return;
      setState(() {
        petItems = suggestions;
        _loadingSuggestions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> getTop5BestSellingBreeds() async {
    Map<String, int> breedSales = {};
    Set<String> neededProductIds = {};

    try {
      // Lấy tất cả orders hoàn thành
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection("orders")
          .where("statusOrder", isEqualTo: "Completed")
          .get();

      // Thu thập tất cả productIds
      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final items = List<Map<String, dynamic>>.from(orderData["items"]);

        for (var item in items) {
          neededProductIds.add(item["productId"]);
        }
      }

      // Lấy tất cả thú cưng theo danh sách productId
      final petsSnapshot = await FirebaseFirestore.instance
          .collection("Pets")
          .where(FieldPath.documentId, whereIn: neededProductIds.toList())
          .get();

      Map<String, String> productIdToBreed = {
        for (var doc in petsSnapshot.docs) doc.id: doc.data()["breed"]
      };

      // Tính tổng số lượng theo breed
      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final items = List<Map<String, dynamic>>.from(orderData["items"]);

        for (var item in items) {
          final String productId = item["productId"];
          final int quantity = item["quantity"];
          final String? breed = productIdToBreed[productId];

          if (breed != null) {
            breedSales[breed] = (breedSales[breed] ?? 0) + quantity;
          }
        }
      }

      // Lấy top 5 giống phổ biến
      final sortedBreeds = breedSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5Breeds = sortedBreeds.take(5).map((e) => e.key).toList();

      // Lấy thú cưng tương ứng với top 5 giống
      final topPetsSnapshot = await FirebaseFirestore.instance
          .collection("Pets")
          .where("breed", whereIn: top5Breeds)
          .get();

      if (!mounted) return;
      setState(() {
        top5BestSell = topPetsSnapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      // ignore top-5 fetch errors silently for UX
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        centerTitle: true,
        title: const Text("Thanh Toán Thành Công   "),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
                child: Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 100,
            )),
            Center(
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: const WidgetStatePropertyAll(Colors.black),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const YourOrderScreen(),
                    ),
                  );
                },
                child: const Text(
                  "Xem chi tiết",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            _loadingSuggestions
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : petItems.isEmpty
                ? const Text("")
                : const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Text(
                      "Sản phẩm gợi ý",
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
            petItems.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GridView.builder(
                      itemCount: petItems.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.8,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DetailPet(pet: petItems[index]),
                              ),
                            );
                          },
                          child: PetItemsAll(
                            pet: petItems[index],
                          ),
                        );
                      },
                    ),
                  ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "Thú cưng phổ biến",
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            top5BestSell.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(
                      "Không có sản phẩm tương tự",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GridView.builder(
                      itemCount: top5BestSell.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.8,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DetailPet(pet: top5BestSell[index]),
                              ),
                            );
                          },
                          child: PetItemsAll(
                            pet: top5BestSell[index],
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
