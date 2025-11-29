import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/auth/firestore_service.dart';
import 'package:pet_shop/presentation/pages/mobile/chat/chat_page.dart';
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

  final MapController _mapController = MapController();
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

  static const LatLng defaultLatLng = LatLng(10.762622, 106.660172);

  LatLng _getShopLatLng() {
    // Ưu tiên lấy từ trường 'latitude' và 'longitude' trực tiếp
    final double? lat = shopInfo?['latitude'] as double?;
    final double? lng = shopInfo?['longitude'] as double?;

    if (lat != null && lng != null) {
      debugPrint(
          "Lấy tọa độ từ Firebase: LatLng(latitude:$lat, longitude:$lng)");
      return LatLng(lat, lng);
    }

    // Nếu không có trường latitude/longitude, thì thử phân tích từ googleMapsUrl
    // Lưu ý: hàm _parseLatLngFromGoogleMapsUrl có thể bị xóa nếu bạn chắc chắn
    // luôn có latitude/longitude trực tiếp. Tôi vẫn giữ nó làm fallback nếu
    // bạn muốn giữ chức năng phân tích URL cũ.
    debugPrint("Không thể lấy tọa độ, trả về mặc định: $defaultLatLng");
    return defaultLatLng;
  }

  void _openMap() async {
    final LatLng coords = _getShopLatLng();

    // Sử dụng định dạng Universal Link cho Google Maps, ưu tiên mở ứng dụng
    final String mapSchemeUrl =
        'https://www.google.com/maps/search/?api=1&query=${coords.latitude},${coords.longitude}';
    final Uri url = Uri.parse(mapSchemeUrl);

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

    // Sử dụng hàm mới để lấy tọa độ
    final LatLng initialLatLng = _getShopLatLng();
    print("initialLatLng (trong build):  $initialLatLng");
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
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
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Địa chỉ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on,
                          color: Theme.of(context).colorScheme.primary, size: 20),
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
                                MaterialPageRoute(
                                    builder: (context) => const ChatPage()),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Nhắn tin'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openMap,
                            icon: Icon(Icons.map_outlined,
                                color: Theme.of(context).colorScheme.primary),
                            label: Text('Mở bản đồ',
                                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Theme.of(context).colorScheme.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
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
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).shadowColor.withOpacity(0.05),
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
                            child: InkWell(
                              onTap:
                                  _openMap, // Vẫn giữ InkWell để khi click vào map sẽ mở app Maps
                              child: FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter:
                                      initialLatLng, // Sử dụng tọa độ đã phân tích
                                  initialZoom: 15.0,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.all &
                                        ~InteractiveFlag
                                            .rotate, // Không cho phép xoay map
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                    userAgentPackageName:
                                        'com.example.pet_shop',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: initialLatLng,
                                        width: 80,
                                        height: 80,
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 40,
                                        ),
                                      )
                                    ],
                                  ),
                                ],
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Giới thiệu',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              (aboutText?.isNotEmpty == true)
                                  ? aboutText!
                                  : "Happy Pet là cửa hàng chuyên cung cấp các sản phẩm và dịch vụ dành cho thú cưng.",
                              textAlign: TextAlign.start,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.87),
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
                border: Border.all(color: Theme.of(context).cardColor, width: 4),
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
                backgroundColor: Theme.of(context).cardColor,
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
