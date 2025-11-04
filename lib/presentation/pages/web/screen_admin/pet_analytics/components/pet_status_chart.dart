import 'package:flutter/material.dart';

class PetStatusChart extends StatelessWidget {
  final int totalPets;
  final int soldPets;
  final int availablePets;

  const PetStatusChart({
    super.key,
    required this.totalPets,
    required this.soldPets,
    required this.availablePets,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPets == 0) {
      return const Center(
        child: Text('Không có dữu liệu', style: TextStyle(color: Colors.grey)),
      );
    }

    final soldPercentage = (soldPets / totalPets);
    final availablePercentage = (availablePets / totalPets);

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
            'Pet Status Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Simple bar chart
          Column(
            children: [
              _buildBarRow(
                'Đã bán', 
                soldPets, 
                soldPercentage, 
                Colors.orange,
                totalPets,
              ),
              const SizedBox(height: 12),
              _buildBarRow(
                'Còn hàng', 
                availablePets, 
                availablePercentage, 
                Colors.blue,
                totalPets,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total', totalPets, Colors.grey),
              _buildSummaryItem('Sold', soldPets, Colors.orange),
              _buildSummaryItem('Available', availablePets, Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarRow(String label, int count, double percentage, Color color, int total) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Container(
            height: 30,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(15),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 30,
          child: Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}