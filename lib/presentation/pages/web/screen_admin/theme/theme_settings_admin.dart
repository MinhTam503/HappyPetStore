import 'package:flutter/material.dart';
import 'package:pet_shop/core/services/theme_manager.dart';

class ThemeSettingsAdmin extends StatefulWidget {
  const ThemeSettingsAdmin({super.key});

  @override
  State<ThemeSettingsAdmin> createState() => _ThemeSettingsAdminState();
}

class _ThemeSettingsAdminState extends State<ThemeSettingsAdmin> {
  final ThemeManager _themeManager = ThemeManager();
  bool _isLoading = false;

  Future<void> _updateTheme(SeasonalTheme theme) async {
    setState(() => _isLoading = true);
    try {
      await _themeManager.setTheme(theme);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật giao diện: ${_getThemeName(theme)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getThemeName(SeasonalTheme theme) {
    switch (theme) {
      case SeasonalTheme.noel:
        return 'Giáng Sinh (Noel) - Mùa Đông';
      case SeasonalTheme.tet:
        return 'Tết Nguyên Đán - Mùa Xuân';
      case SeasonalTheme.summer:
        return 'Mùa Hè';
      case SeasonalTheme.autumn:
        return 'Mùa Thu';
      case SeasonalTheme.defaultTheme:
        return 'Mặc định';
    }
  }

  String _getThemeDescription(SeasonalTheme theme) {
    switch (theme) {
      case SeasonalTheme.noel:
        return 'Đỏ/Xanh lá Giáng Sinh • Tuyết rơi ❄️ • Icon quà tặng 🎁';
      case SeasonalTheme.tet:
        return 'Đỏ/Vàng may mắn • Hoa mai rơi 🌸 • Icon hoa 💐';
      case SeasonalTheme.summer:
        return 'Xanh dương/Vàng • Bong bóng nổi ☀️ • Icon biển 🏖️';
      case SeasonalTheme.autumn:
        return 'Cam/Nâu • Lá rơi 🍂 • Icon lá cây 🍁';
      case SeasonalTheme.defaultTheme:
        return 'Xanh lá • Không có hiệu ứng mùa • Giao diện chuẩn 🌿';
    }
  }

  IconData _getThemeIcon(SeasonalTheme theme) {
    switch (theme) {
      case SeasonalTheme.noel:
        return Icons.ac_unit; // Snowflake
      case SeasonalTheme.tet:
        return Icons.local_florist; // Flower
      case SeasonalTheme.summer:
        return Icons.wb_sunny; // Sun
      case SeasonalTheme.autumn:
        return Icons.eco; // Leaf
      case SeasonalTheme.defaultTheme:
        return Icons.palette; // Palette
    }
  }

  Color _getThemeColor(SeasonalTheme theme) {
    switch (theme) {
      case SeasonalTheme.noel:
        return const Color(0xFFD32F2F); // Christmas red
      case SeasonalTheme.tet:
        return const Color(0xFFFFA000); // Amber gold
      case SeasonalTheme.summer:
        return const Color(0xFF00BCD4); // Cyan
      case SeasonalTheme.autumn:
        return const Color(0xFFFF8F00); // Orange
      case SeasonalTheme.defaultTheme:
        return const Color(0xff08A045); // Green
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý giao diện theo chủ đề'),
        backgroundColor: const Color(0xFF08A045),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<SeasonalTheme>(
        stream: _themeManager.stream,
        initialData: _themeManager.current,
        builder: (context, snapshot) {
          final currentTheme = snapshot.data ?? SeasonalTheme.defaultTheme;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.brush,
                          size: 40,
                          color: _getThemeColor(currentTheme),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Chủ đề hiện tại',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getThemeName(currentTheme),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Theme options
                const Text(
                  'Chọn giao diện',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  ...SeasonalTheme.values.map((theme) {
                    final isSelected = theme == currentTheme;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ThemeCard(
                        theme: theme,
                        isSelected: isSelected,
                        themeName: _getThemeName(theme),
                        description: _getThemeDescription(theme),
                        icon: _getThemeIcon(theme),
                        color: _getThemeColor(theme),
                        onTap: () => _updateTheme(theme),
                      ),
                    );
                  }).toList(),

                const SizedBox(height: 32),

                // Info section
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Thay đổi giao diện sẽ được áp dụng ngay lập tức cho tất cả người dùng trên ứng dụng mobile.',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final SeasonalTheme theme;
  final bool isSelected;
  final String themeName;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.themeName,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  List<Widget> _getColorPreview(SeasonalTheme theme) {
    List<Color> colors;
    switch (theme) {
      case SeasonalTheme.noel:
        colors = [const Color(0xFFD32F2F), const Color(0xFF1B5E20)];
        break;
      case SeasonalTheme.tet:
        colors = [const Color(0xFFFFA000), const Color(0xFFFFD54F)];
        break;
      case SeasonalTheme.summer:
        colors = [const Color(0xFF00BCD4), const Color(0xFFFFEB3B)];
        break;
      case SeasonalTheme.autumn:
        colors = [const Color(0xFFFF8F00), const Color(0xFF8D6E63)];
        break;
      case SeasonalTheme.defaultTheme:
        colors = [const Color(0xff08A045), const Color(0xff06803A)];
        break;
    }
    
    return colors.map((c) => Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          themeName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? color : Colors.black87,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_circle,
                            color: color,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Color preview
                    Row(
                      children: _getColorPreview(theme),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isSelected ? color : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
