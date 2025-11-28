import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pet_shop/core/services/theme_manager.dart';

class SeasonalEffectsOverlay extends StatefulWidget {
  final Widget child;
  const SeasonalEffectsOverlay({super.key, required this.child});

  @override
  State<SeasonalEffectsOverlay> createState() => _SeasonalEffectsOverlayState();
}

class _SeasonalEffectsOverlayState extends State<SeasonalEffectsOverlay>
    with SingleTickerProviderStateMixin {
  late final ThemeManager _themeManager;
  late final AnimationController _controller;
  late SeasonalTheme _theme;

  @override
  void initState() {
    super.initState();
    _themeManager = ThemeManager();
    _theme = _themeManager.current;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _themeManager.stream.listen((t) {
      if (mounted) setState(() => _theme = t);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_theme == SeasonalTheme.noel)
          IgnorePointer(child: _Snowfall(controller: _controller)),
        if (_theme == SeasonalTheme.tet)
          IgnorePointer(child: _FallingPetals(controller: _controller)),
        if (_theme == SeasonalTheme.summer)
          IgnorePointer(child: _SummerEffects(controller: _controller)),
        if (_theme == SeasonalTheme.autumn)
          IgnorePointer(child: _AutumnLeaves(controller: _controller)),
      ],
    );
  }
}

class _Snowfall extends StatelessWidget {
  final AnimationController controller;
  const _Snowfall({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final rnd = Random(1234);
        return CustomPaint(
          painter: _SnowPainter(progress: controller.value, rnd: rnd),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _SnowPainter extends CustomPainter {
  final double progress;
  final Random rnd;
  _SnowPainter({required this.progress, required this.rnd});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 60; i++) {
      // Varied speeds and starting offsets
      final speed = 0.4 + (i % 5) * 0.1; // Different fall speeds
      final sway = sin(progress * 4 + i * 0.5) * (12 + (i % 3) * 8); // Horizontal sway
      final x = (i * 67 % size.width.toInt()).toDouble() + sway;
      final y = ((progress * speed * size.height) + (i * 30)) % (size.height + 50);
      
      // Varied sizes: small, medium, large snowflakes
      final sizeVariant = i % 7;
      final iconSize = sizeVariant < 3 ? 10.0 : (sizeVariant < 6 ? 14.0 : 18.0);
      
      // Varied opacity for depth effect
      final opacity = sizeVariant < 3 ? 0.5 : (sizeVariant < 6 ? 0.7 : 0.9);
      
      // Draw snowflake icon
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      textPainter.text = TextSpan(
        text: String.fromCharCode(Icons.ac_unit.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.ac_unit.fontFamily,
          color: Colors.white.withOpacity(opacity),
        ),
      );
      textPainter.layout();
      
      canvas.save();
      canvas.translate(x - iconSize / 2, y - iconSize / 2);
      // Gentle rotation
      canvas.rotate((progress * 2 + i) % (2 * pi));
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => true;
}

class _FallingPetals extends StatelessWidget {
  final AnimationController controller;
  const _FallingPetals({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _PetalPainter(progress: controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _PetalPainter extends CustomPainter {
  final double progress;
  _PetalPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Only 10 petals at a time
    for (int i = 0; i < 10; i++) {
      // Varied speeds and swaying patterns - slower
      final speed = 0.3 + (i % 3) * 0.1;
      final swayAmount = 20 + (i % 4) * 10;
      final x = (i * 120 % size.width.toInt()).toDouble() + sin(progress * 4 + i * 0.8) * swayAmount;
      final y = ((progress * speed * size.height) + (i * 80)) % (size.height + 80);
      
      // Varied petal types and colors - larger icons
      final petalType = i % 3;
      IconData icon;
      Color petalColor;
      double iconSize;
      
      if (petalType == 0) {
        // Yellow star for mai flower
        icon = Icons.star;
        petalColor = const Color(0xFFFFC107); // Yellow-gold
        iconSize = 24.0;
      } else if (petalType == 1) {
        // Pink flower for peach blossom
        icon = Icons.local_florist;
        petalColor = const Color(0xFFFFB6C1); // Light pink
        iconSize = 22.0;
      } else {
        // Orange/gold flower
        icon = Icons.filter_vintage;
        petalColor = const Color(0xFFFFAB40); // Orange
        iconSize = 20.0;
      }
      
      // Depth effect with opacity
      final opacity = 0.6 + (i % 4) * 0.1;
      
      // Draw flower icon
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      textPainter.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          color: petalColor.withOpacity(opacity),
        ),
      );
      textPainter.layout();
      
      canvas.save();
      canvas.translate(x - iconSize / 2, y - iconSize / 2);
      // Rotating and tumbling motion - gentler
      canvas.rotate(sin(progress * 4 + i) * 1.2 + (i * 0.4));
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PetalPainter oldDelegate) => true;
}

// Summer effects - bubbles/water drops
class _SummerEffects extends StatelessWidget {
  final AnimationController controller;
  const _SummerEffects({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _SummerPainter(progress: controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _SummerPainter extends CustomPainter {
  final double progress;
  _SummerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // 12 bubbles floating up
    for (int i = 0; i < 12; i++) {
      final speed = 0.25 + (i % 4) * 0.08;
      final sway = sin(progress * 3 + i * 0.6) * (15 + (i % 3) * 10);
      final x = (i * 100 % size.width.toInt()).toDouble() + sway;
      // Bubbles rise up instead of fall
      final y = size.height - ((progress * speed * size.height) + (i * 70)) % (size.height + 70);
      
      final bubbleType = i % 3;
      IconData icon;
      Color bubbleColor;
      double iconSize;
      
      if (bubbleType == 0) {
        icon = Icons.water_drop;
        bubbleColor = const Color(0xFF00BCD4); // Cyan
        iconSize = 20.0;
      } else if (bubbleType == 1) {
        icon = Icons.bubble_chart;
        bubbleColor = const Color(0xFF4DD0E1); // Light cyan
        iconSize = 18.0;
      } else {
        icon = Icons.wb_sunny;
        bubbleColor = const Color(0xFFFFEB3B); // Yellow sun
        iconSize = 22.0;
      }
      
      final opacity = 0.5 + (i % 4) * 0.12;
      
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          color: bubbleColor.withOpacity(opacity),
        ),
      );
      textPainter.layout();
      
      canvas.save();
      canvas.translate(x - iconSize / 2, y - iconSize / 2);
      canvas.rotate(sin(progress * 3 + i) * 0.8);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SummerPainter oldDelegate) => true;
}

// Autumn effects - falling leaves
class _AutumnLeaves extends StatelessWidget {
  final AnimationController controller;
  const _AutumnLeaves({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _AutumnPainter(progress: controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AutumnPainter extends CustomPainter {
  final double progress;
  _AutumnPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // 15 falling leaves
    for (int i = 0; i < 15; i++) {
      final speed = 0.3 + (i % 4) * 0.12;
      final sway = sin(progress * 4.5 + i * 0.7) * (25 + (i % 4) * 12);
      final x = (i * 90 % size.width.toInt()).toDouble() + sway;
      final y = ((progress * speed * size.height) + (i * 60)) % (size.height + 70);
      
      final leafType = i % 4;
      IconData icon;
      Color leafColor;
      double iconSize;
      
      if (leafType == 0) {
        icon = Icons.eco;
        leafColor = const Color(0xFFFF8F00); // Orange
        iconSize = 22.0;
      } else if (leafType == 1) {
        icon = Icons.park;
        leafColor = const Color(0xFFD84315); // Deep orange/red
        iconSize = 20.0;
      } else if (leafType == 2) {
        icon = Icons.nature;
        leafColor = const Color(0xFF8D6E63); // Brown
        iconSize = 24.0;
      } else {
        icon = Icons.yard;
        leafColor = const Color(0xFFFF6F00); // Dark orange
        iconSize = 18.0;
      }
      
      final opacity = 0.6 + (i % 5) * 0.08;
      
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          color: leafColor.withOpacity(opacity),
        ),
      );
      textPainter.layout();
      
      canvas.save();
      canvas.translate(x - iconSize / 2, y - iconSize / 2);
      // Tumbling motion like real leaves
      canvas.rotate(sin(progress * 6 + i) * 2.5 + (i * 0.5));
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AutumnPainter oldDelegate) => true;
}
