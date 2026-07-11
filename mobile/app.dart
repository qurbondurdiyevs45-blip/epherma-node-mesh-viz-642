import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(const EphemeraNodeApp());
}

class EphemeraNodeApp extends StatelessWidget {
  const EphemeraNodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EphemeraNode Mesh Viz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.cyan,
        scaffoldBackgroundColor: const Color(0xFF050505),
      ),
      home: const MeshVisualizationScreen(),
    );
  }
}

class MeshVisualizationScreen extends StatefulWidget {
  const MeshVisualizationScreen({super.key});

  @override
  State<MeshVisualizationScreen> createState() => _MeshVisualizationScreenState();
}

class _MeshVisualizationScreenState extends State<MeshVisualizationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<FailurePoint> _failures = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _generateMockTelemetry();
  }

  void _generateMockTelemetry() {
    for (int i = 0; i < 150; i++) {
      _failures.add(FailurePoint(
        Offset(_random.nextDouble(), _random.nextDouble()),
        _random.nextDouble(),
        _random.nextInt(24),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: HeatMapPainter(_failures, _controller.value),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EPHEMERANODE',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  const Text(
                    '24H TRANSIENT MESH TELEMETRY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat("ACTIVE NODES", "4,219"),
                        _buildStat("MTTR", "142ms"),
                        _buildStat("ERROR RATE", "0.04%"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.cyan)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}

class FailurePoint {
  final Offset position;
  final double intensity;
  final int hour;

  FailurePoint(this.position, this.intensity, this.hour);
}

class HeatMapPainter extends CustomPainter {
  final List<FailurePoint> failures;
  final double animationValue;

  HeatMapPainter(this.failures, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    for (var failure in failures) {
      final double x = failure.position.dx * size.width;
      final double y = failure.position.dy * size.height;
      
      final double pulse = 0.5 + (0.5 * math.sin(animationValue * math.pi * 2 + failure.hour));
      final double opacity = failure.intensity * pulse;
      
      Color color;
      if (failure.intensity > 0.8) {
        color = Colors.redAccent.withOpacity(opacity);
      } else if (failure.intensity > 0.4) {
        color = Colors.orangeAccent.withOpacity(opacity);
      } else {
        color = Colors.cyanAccent.withOpacity(opacity);
      }

      paint.color = color;
      canvas.drawCircle(Offset(x, y), 20 * failure.intensity * pulse, paint);
    }
    
    // Draw connecting mesh lines
    final linePaint = Paint()
      ..color = Colors.cyan.withOpacity(0.05)
      ..strokeWidth = 0.5;

    for (int i = 0; i < failures.length; i += 10) {
      for (int j = i + 1; j < i + 3 && j < failures.length; j++) {
        canvas.drawLine(
          Offset(failures[i].position.dx * size.width, failures[i].position.dy * size.height),
          Offset(failures[j].position.dx * size.width, failures[j].position.dy * size.height),
          linePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant HeatMapPainter oldDelegate) => true;
}