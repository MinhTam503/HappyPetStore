import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/presentation/pages/web_user/widgets/pet_card_web_user.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/pet_colors.dart';

/// Trang chi tiết thú cưng cho web user
/// URL: /pet/{petId}
class PetDetailScreenWeb extends StatefulWidget {
  final String petId;

  const PetDetailScreenWeb({
    super.key,
    required this.petId,
  });

  @override
  State<PetDetailScreenWeb> createState() => _PetDetailScreenWebState();
}

class _PetDetailScreenWebState extends State<PetDetailScreenWeb> {
  Map<String, dynamic>? _petData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDescriptionExpanded = false;
  List<Map<String, dynamic>> _similarPets = [];
  bool _loadingSimilar = false;

  @override
  void initState() {
    super.initState();
    _loadPetData();
  }

  Future<void> _loadPetData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Pets')
          .doc(widget.petId)
          .get();

      if (!doc.exists) {
        setState(() {
          _errorMessage = 'Không tìm thấy thú cưng';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _petData = {...doc.data()!, 'id': doc.id};
        _isLoading = false;
      });

      // Load similar pets after detail fetched
      _fetchSimilarPets();
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi tải dữ liệu: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSimilarPets() async {
    if (_petData == null) return;
    setState(() => _loadingSimilar = true);
    try {
      final category = _petData!['category'];
      final breed = _petData!['breed'];
      final currentId = _petData!['id'];

      final snapshot = await FirebaseFirestore.instance
          .collection('Pets')
          .where('category', isEqualTo: category)
          .limit(50)
          .get();

      final List<Map<String, dynamic>> sameBreed = [];
      final List<Map<String, dynamic>> sameCategoryOtherBreed = [];
      for (final doc in snapshot.docs) {
        if (doc.id == currentId) continue;
        final data = doc.data();
        data['id'] = doc.id;
        if (breed != null && breed.toString().isNotEmpty && data['breed'] == breed) {
          sameBreed.add(data);
        } else {
          sameCategoryOtherBreed.add(data);
        }
      }

      final combined = <Map<String, dynamic>>[...sameBreed, ...sameCategoryOtherBreed];
      setState(() {
        _similarPets = combined.take(12).toList();
        _loadingSimilar = false;
      });
    } catch (e) {
      setState(() => _loadingSimilar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPetData,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_petData == null) {
      return const Center(
        child: Text('Không có dữ liệu'),
      );
    }

    return _buildPetDetail();
  }

  Widget _buildPetDetail() {
    final width = MediaQuery.of(context).size.width;
    final name = _petData!['name']?.toString() ?? '';
    final breed = _petData!['breed']?.toString() ?? '';
    final imageUrl = _petData!['imageUrl']?.toString() ?? '';
    final price = _petData!['price'];
    final category = _petData!['category']?.toString() ?? '';
    final sex = _petData!['sex']?.toString() ?? _petData!['gender']?.toString() ?? '';
    final age = _petData!['age']?.toString() ?? '';
    final colorKey = _petData!['color']?.toString() ?? '';
    final weight = _petData!['weight']?.toString() ?? '';
    final description = _petData!['about']?.toString() ?? _petData!['description']?.toString() ?? '';
    final healthStatus = _petData!['healthStatus']?.toString() ?? '';
    final vaccineStatus = _petData!['vaccineStatus']?.toString() ?? '';

    // Wide screens: split layout (image left, info right)
    if (width >= 900) {
      return SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                         padding: const EdgeInsets.only(top: 30),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF3F4F6)),
                                    )
                                  : const ColoredBox(color: Color(0xFFF3F4F6)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              decoration: BoxDecoration(
                                color: secondaryColor.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                                        if (breed.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(breed, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: primaryColor, width: 2),
                                    ),
                                    child: Text(
                                      CurrencyHelper.formatVND(price),
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: primaryColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _infoCard(children: [
                              const Text('Thông tin cơ bản', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              _buildInfoRow('Danh mục', category),
                              _buildInfoRow('Giống', breed),
                              _buildInfoRow('Giới tính', sex),
                              _buildInfoRow('Tuổi', age),
                              _buildColorRow('Màu sắc', colorKey),
                              _buildInfoRow('Cân nặng', weight.isNotEmpty ? '$weight kg' : ''),
                              _buildInfoRow('Tình trạng sức khỏe', healthStatus),
                              _buildInfoRow('Tình trạng tiêm chủng', vaccineStatus),
                            ]),
                            const SizedBox(height: 16),
                            if (description.isNotEmpty)
                              _infoCard(children: [
                                const Text('Mô tả', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                Text(
                                  _isDescriptionExpanded
                                      ? description
                                      : (description.length > 220 ? '${description.substring(0, 220)}...' : description),
                                  style: const TextStyle(fontSize: 15),
                                ),
                                if (description.length > 220)
                                  TextButton(
                                    onPressed: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                                    child: Text(_isDescriptionExpanded ? 'Thu gọn' : 'Xem thêm'),
                                  ),
                              ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Sản phẩm tương tự', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (_loadingSimilar)
                    const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: CircularProgressIndicator()))
                  else if (_similarPets.isEmpty)
                    Text('Không tìm thấy sản phẩm tương tự', style: TextStyle(color: Colors.grey.shade600))
                  else
                    LayoutBuilder(builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      int cross = 5;
                      if (w < 600) cross = 2;
                      else if (w < 900) cross = 3;
                      else if (w < 1200) cross = 4;
                      else cross = 5;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _similarPets.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (context, i) {
                          final pet = _similarPets[i];
                          return PetCardWebUser(
                            pet: pet,
                            onTap: () {
                              final id = pet['id']?.toString() ?? '';
                              if (id.isEmpty) return;
                              Navigator.pushReplacementNamed(context, '/home/pet/$id');
                            },
                          );
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: screenHeight * 0.45,
          pinned: true,
          backgroundColor: secondaryColor,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: _buildHeroImage(imageUrl),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title header panel
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        color: secondaryColor.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (breed.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    breed,
                                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: primaryColor, width: 2),
                            ),
                            child: Text(
                              CurrencyHelper.formatVND(price),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Basic info card
                    _infoCard(children: [
                      const Text('Thông tin cơ bản', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildInfoRow('Danh mục', category),
                      _buildInfoRow('Giống', breed),
                      _buildInfoRow('Giới tính', sex),
                      _buildInfoRow('Tuổi', age),
                      _buildColorRow('Màu sắc', colorKey),
                      _buildInfoRow('Cân nặng', weight.isNotEmpty ? '$weight kg' : ''),
                      _buildInfoRow('Tình trạng sức khỏe', healthStatus),
                      _buildInfoRow('Tình trạng tiêm chủng', vaccineStatus),
                    ]),

                    const SizedBox(height: 16),

                    // Description card with expand/collapse like mobile
                    if (description.isNotEmpty)
                      _infoCard(children: [
                        const Text('Mô tả', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(
                          _isDescriptionExpanded
                              ? description
                              : (description.length > 180 ? '${description.substring(0, 180)}...' : description),
                          style: const TextStyle(fontSize: 15),
                        ),
                        if (description.length > 180)
                          TextButton(
                            onPressed: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                            child: Text(_isDescriptionExpanded ? 'Thu gọn' : 'Xem thêm'),
                          ),
                      ]),

                    const SizedBox(height: 24),

                    // Similar pets
                    const Text('Sản phẩm tương tự', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (_loadingSimilar)
                      const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_similarPets.isEmpty)
                      Text('Không tìm thấy sản phẩm tương tự', style: TextStyle(color: Colors.grey.shade600))
                    else
                      LayoutBuilder(builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        int cross = 4;
                        if (w < 600) cross = 2; // mobile: 2 columns as requested
                        else if (w < 900) cross = 3;
                        else if (w < 1200) cross = 4;
                        else cross = 5;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _similarPets.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.78,
                          ),
                          itemBuilder: (context, i) {
                            final pet = _similarPets[i];
                            return PetCardWebUser(
                              pet: pet,
                              onTap: () {
                                final id = pet['id']?.toString() ?? '';
                                if (id.isEmpty) return;
                                // Navigate to new pet via deep link path under /home
                                Navigator.pushReplacementNamed(context, '/home/pet/$id');
                              },
                            );
                          },
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroImage(String imageUrl) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        image: imageUrl.isNotEmpty
            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrl.isEmpty
          ? const ColoredBox(
              color: Color(0xFFF3F4F6),
              child: Center(child: Icon(Icons.pets, size: 64, color: Colors.grey)),
            )
          : null,
    );
  }

  // Legacy image section & placeholder removed (replaced by _buildHeroImage)

  // Legacy info section removed (restructured into new sliver layout)

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorRow(String label, String colorKey) {
    if (colorKey.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final color = PetColors.getColorFromKey(colorKey);
    final name = l10n != null ? PetColors.getLocalizedColor(l10n, colorKey) : colorKey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
