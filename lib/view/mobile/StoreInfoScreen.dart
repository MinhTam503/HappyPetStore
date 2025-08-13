import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/auth/firestore_service.dart';
import 'package:pet_shop/view/mobile/chat_page.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_service.dart';
import '../../utils/contants.dart';

class StoreInfoScreen extends StatefulWidget {
  @override
  State<StoreInfoScreen> createState() => _StoreInfoScreenState();
}

class _StoreInfoScreenState extends State<StoreInfoScreen> {
  Map<String, dynamic>? user;
  Map<String, dynamic>? shopInfo;
  final fService = Firestore_Service();

  @override
  void initState() {
    fetchUser();
    fetchShopInfo();
    super.initState();
  }

  Future<void> fetchUser() async {
    final userData = await authService.value.getUserInfo();
    setState(() {
      user = userData;
    });
  }

  Future<void> fetchShopInfo() async {
    final shopData = await fService.getShopInfo();
    if (shopData != null) {
      setState(() {
        shopInfo = shopData;
      });
    }
  }

  final String mapUrl =
      "https://static-maps.yandex.ru/1.x/?ll=106.675045,10.984057&z=14&size=600,300&l=map&pt=106.675045,10.984057,pm2rdm";

  final String googleMapsUrl =
      "https://www.google.com/maps/search/?api=1&query=10.980712020778228, 106.6743278503418";

  void _openMap() async {
    Uri url = Uri.parse(shopInfo?['googleMapsUrl'] ??
        "https://www.google.com/maps/search/?api=1&query=10.981024, 106.674015");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Không thể mở bản đồ!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        centerTitle: true,
        elevation: 0,
        title: const Text('Pets Shop',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ảnh bìa và avatar
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30)),
                    image: DecorationImage(
                      image: AssetImage("assets/images/loginImage.png"),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 4),
                      shape: BoxShape.circle,
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
                      backgroundImage: NetworkImage(shopInfo?['avatar'] ??
                          "https://lh3.googleusercontent.com/a/ACg8ocKhMOLcdi-5_fYDYkgolOG9C0NL3HemimWOfg2Dpv7Jkp04JuOx=s96-c"),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            // Tên cửa hàng
            Text(
              shopInfo?['name'] ?? "abc",
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor),
            ),
            const SizedBox(height: 8),
            // Địa chỉ
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: primaryColor, size: 20),
                const SizedBox(width: 4),
                Text(
                  '123 Đường ABC, Thành phố XYZ',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Nút nhắn tin và bản đồ
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Nhắn tin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _openMap,
                  icon: const Icon(Icons.map, color: primaryColor),
                  label: const Text('Xem bản đồ',
                      style: TextStyle(color: primaryColor)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Bản đồ thu nhỏ
            Container(
              height: 180,
              margin: const EdgeInsets.symmetric(horizontal: 24),
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
                child: GestureDetector(
                  onTap: _openMap,
                  child: Image.network(
                    mapUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Phần giới thiệu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: EdgeInsets.all(18.0),
                  child: Column(
                    children: [
                      const Text(
                        'Giới thiệu',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        shopInfo?['about'] ??
                            "Happy Pet là cửa hàng chuyên cung cấp các sản phẩm và dịch vụ dành cho thú cưng.",
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black87),
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
