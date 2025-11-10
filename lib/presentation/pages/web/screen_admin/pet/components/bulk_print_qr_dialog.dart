import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/services/qr_print_service.dart';

/// Dialog cho phép chọn nhiều thú cưng để in QR code hàng loạt
class BulkPrintQRDialog extends StatefulWidget {
  final CollectionReference petsCollection;

  const BulkPrintQRDialog({
    super.key,
    required this.petsCollection,
  });

  @override
  State<BulkPrintQRDialog> createState() => _BulkPrintQRDialogState();
}

class _BulkPrintQRDialogState extends State<BulkPrintQRDialog> {
  final Set<String> _selectedPets = {};
  List<Map<String, dynamic>> _allPets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    try {
      final snapshot = await widget.petsCollection.get();
      setState(() {
        _allPets = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading pets: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectAll() {
    setState(() {
      _selectedPets.clear();
      _selectedPets.addAll(_allPets.map((p) => p['id'] as String));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPets.clear();
    });
  }

  void _toggleSelection(String petId) {
    setState(() {
      if (_selectedPets.contains(petId)) {
        _selectedPets.remove(petId);
      } else {
        _selectedPets.add(petId);
      }
    });
  }

  Future<void> _printSelected(BuildContext context) async {
    if (_selectedPets.isEmpty) return;

    Navigator.pop(context);

    final petsToPrint = _allPets
        .where((p) => _selectedPets.contains(p['id']))
        .toList();

    try {
      await QRPrintService.printMultiplePetQRs(pets: petsToPrint);
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorPrintingQR}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: 700,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(context, l10n),

            // Action buttons
            _buildActionButtons(l10n),

            const Divider(height: 1),

            // Pets grid
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : _buildPetsGrid(context, l10n),
            ),

            const Divider(height: 1),

            // Bottom actions
            _buildBottomActions(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.print,
            size: 28,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.printQRCodes,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '${_selectedPets.length} ${l10n.selected}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: _selectAll,
            icon: const Icon(Icons.select_all),
            label: Text(l10n.selectAll),
          ),
          TextButton.icon(
            onPressed: _clearSelection,
            icon: const Icon(Icons.deselect),
            label: Text(l10n.clearSelection),
          ),
        ],
      ),
    );
  }

  Widget _buildPetsGrid(BuildContext context, AppLocalizations l10n) {
    if (_allPets.isEmpty) {
      return Center(child: Text(l10n.noPetsAvailable));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _allPets.length,
        itemBuilder: (context, index) {
          return _buildPetCard(context, _allPets[index]);
        },
      ),
    );
  }

  Widget _buildPetCard(BuildContext context, Map<String, dynamic> pet) {
    final petId = pet['id'] as String;
    final isSelected = _selectedPets.contains(petId);

    return InkWell(
      onTap: () => _toggleSelection(petId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pet image
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                    child: Image.network(
                      pet['imageUrl'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.pets,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                // Pet info
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        pet['breed'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Checkbox indicator
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _selectedPets.isEmpty
                ? null
                : () => _printSelected(context),
            icon: const Icon(Icons.print),
            label: Text('${l10n.printQRCode} (${_selectedPets.length})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
