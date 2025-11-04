import 'package:flutter/material.dart';

class BreedPerformanceChart extends StatelessWidget {
  final Map<String, Map<String, int>> breedData;

  const BreedPerformanceChart({
    super.key,
    required this.breedData,
  });

  @override
  Widget build(BuildContext context) {
    if (breedData.isEmpty) {
      return const Center(
        child: Text('Không có giống còn hàng', style: TextStyle(color: Colors.grey)),
      );
    }

    // Sort breeds by total count
    final sortedBreeds = breedData.entries.toList()
      ..sort((a, b) => (b.value['total'] ?? 0).compareTo(a.value['total'] ?? 0));

    // Take top 10 breeds
    final topBreeds = sortedBreeds.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phân tích hiệu xuất giống',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Headers
          const Row(
            children: [
              Expanded(flex: 3, child: Text('Giống', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Tổng', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Đã bán', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Có sẵn', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Thành công %', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const Divider(),
          
          // Data rows
          Expanded(
            child: ListView.builder(
              itemCount: topBreeds.length,
              itemBuilder: (context, index) {
                final entry = topBreeds[index];
                final breed = entry.key;
                final data = entry.value;
                final total = data['total'] ?? 0;
                final sold = data['sold'] ?? 0;
                final available = total - sold;
                final successRate = total > 0 ? (sold / total) * 100.0 : 0.0;

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getBreedColor(index),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                breed,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          total.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          sold.toString(),
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          available.toString(),
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Text(
                              '${successRate.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: _getSuccessRateColor(successRate),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 40,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: successRate / 100,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _getSuccessRateColor(successRate),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  Color _getBreedColor(int index) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }

  Color _getSuccessRateColor(double rate) {
    if (rate >= 70) return Colors.green;
    if (rate >= 50) return Colors.orange;
    if (rate >= 30) return Colors.red;
    return Colors.grey;
  }
}