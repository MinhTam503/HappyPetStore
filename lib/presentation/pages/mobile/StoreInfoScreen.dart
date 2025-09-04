import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/auth/firestore_service.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/chat_page.dart';
import 'package:url_launcher/url_launcher.dart';



class StoreInfoScreen extends StatefulWidget {
  const StoreInfoScreen({super.key});

  @override
  State<StoreInfoScreen> createState() => _StoreInfoScreenState();
}

class _StoreInfoScreenState extends State<StoreInfoScreen> {
  Map<String, dynamic>? user;
  Map<String, dynamic>? shopInfo;
  final fService = Firestore_Service();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAll();
  }

  Future<void> fetchAll() async {
    await Future.wait([fetchUser(), fetchShopInfo()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> fetchUser() async {
    final userData = await authService.value.getUserInfo();
    if (mounted) {
      setState(() => user = userData);
    }
  }

  Future<void> fetchShopInfo() async {
    final shopData = await fService.getShopInfo();
    if (shopData != null && mounted) {
      setState(() => shopInfo = shopData);
    }
  }

  // Ảnh static map (fallback)
  final String mapUrl =
      "https://static-maps.yandex.ru/1.x/?ll=106.675045,10.984057&z=14&size=600,300&l=map&pt=106.675045,10.984057,pm2rdm";

  // Google Maps (fallback)
  final String googleMapsUrl =
      "https://www.google.com/maps/search/?api=1&query=10.980712020778228, 106.6743278503418";

  void _openMap() async {
    final fallback = "https://www.google.com/maps/search/?api=1&query=10.981024, 106.674015";
    final urlStr = (shopInfo?['googleMapsUrl'] as String?)?.trim();
    final Uri url = Uri.parse(urlStr?.isNotEmpty == true ? urlStr! : fallback);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở bản đồ!')),
      );
    }
  }

  Future<void> _onRefresh() async {
    await fetchAll();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addressText = (shopInfo?['address'] as String?)?.trim();
    final aboutText = (shopInfo?['about'] as String?)?.trim();
    final nameText = (shopInfo?['name'] as String?)?.trim();
    final avatarUrl = (shopInfo?['avatar'] as String?)?.trim();

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        centerTitle: true,
        elevation: 0,
        title: Text(
          'Pets Shop',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
          ),
        ),
      ),
      body: _isLoading
          ? const _LoadingSkeleton()
          : RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header: cover + avatar nổi
            _Header(
              avatarUrl: avatarUrl?.isNotEmpty == true
                  ? avatarUrl!
                  : "https://lh3.googleusercontent.com/a/ACg8ocKhMOLcdi-5_fYDYkgolOG9C0NL3HemimWOfg2Dpv7Jkp04JuOx=s96-c",
            ),

            // Tên shop
            const SizedBox(height: 56),
            Center(
              child: Text(
                (nameText?.isNotEmpty == true) ? nameText! : "abc",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Địa chỉ
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: primaryColor, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    (addressText?.isNotEmpty == true)
                        ? addressText!
                        : '123 Đường ABC, Thành phố XYZ',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Hai nút hành động
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChatPage()),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Nhắn tin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openMap,
                      icon: const Icon(Icons.map_outlined, color: primaryColor),
                      label: const Text('Xem bản đồ', style: TextStyle(color: primaryColor)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Static map (preview) có bo góc & bóng
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openMap,
                      child: Image.network(
                        mapUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.map, color: Colors.black26, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Giới thiệu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Giới thiệu',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        (aboutText?.isNotEmpty == true)
                            ? aboutText!
                            : "Happy Pet là cửa hàng chuyên cung cấp các sản phẩm và dịch vụ dành cho thú cưng.",
                        textAlign: TextAlign.start,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black87,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// =========================
// Sub-widgets
// =========================

class _Header extends StatelessWidget {
  final String avatarUrl;
  const _Header({required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Cover
        Container(
          width: double.infinity,
          height: 220,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            image: DecorationImage(
              image: AssetImage("assets/images/loginImage.png"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Overlay gradient nhẹ để chữ/ảnh nổi hơn (nếu cần thêm text sau)
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.0),
                Colors.black.withOpacity(0.0),
                Colors.black.withOpacity(0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Avatar nổi
        Positioned.fill(
          top: 160,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(avatarUrl),
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Loading skeleton đơn giản
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box({double h = 16, double w = double.infinity, double r = 12}) {
      return Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // cover
        Container(
          width: double.infinity,
          height: 220,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        const SizedBox(height: 56),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              box(h: 20, w: 180, r: 8),
              const SizedBox(height: 8),
              box(h: 14, w: 240, r: 8),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: box(h: 44, r: 12)),
                  const SizedBox(width: 12),
                  Expanded(child: box(h: 44, r: 12)),
                ],
              ),
              const SizedBox(height: 20),
              box(h: 180, r: 16),
              const SizedBox(height: 24),
              box(h: 20, w: 120, r: 8),
              const SizedBox(height: 10),
              box(h: 80, r: 12),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }
}
