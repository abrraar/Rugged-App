import 'package:flutter/material.dart';

class WaterGlassWidget extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;

  const WaterGlassWidget({
    super.key,
    required this.progress,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOutCubic,
        builder: (context, value, child) {
          return CustomPaint(
            painter: _GlassPainter(progress: value),
          );
        },
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  final double progress;

  _GlassPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Colors
    const waterColor = Colors.blueAccent;
    final glassColor = Colors.white.withValues(alpha : 0.2);

    // Path for the glass shape (tapered with rounded bottom)
    final glassPath = Path();
    const cornerRadius = 8.0;

    glassPath.moveTo(width * 0.15, 0); // Top left
    glassPath.lineTo(width * 0.85, 0); // Top right
    
    // Bottom right with curve
    glassPath.lineTo(width * 0.75, height - cornerRadius);
    glassPath.quadraticBezierTo(width * 0.75, height, width * 0.75 - cornerRadius, height);
    
    // Bottom left with curve
    glassPath.lineTo(width * 0.25 + cornerRadius, height);
    glassPath.quadraticBezierTo(width * 0.25, height, width * 0.25, height - cornerRadius);
    
    glassPath.close();

    // Draw the inner glass background
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha : 0.03)
      ..style = PaintingStyle.fill;
    canvas.drawPath(glassPath, bgPaint);

    // Draw the water
    if (progress > 0) {
      canvas.save();
      canvas.clipPath(glassPath);
      
      final double waterHeight = height * progress.clamp(0.0, 1.0);
      
      final waterPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            waterColor.withValues(alpha : 0.7),
            waterColor,
          ],
        ).createShader(Rect.fromLTRB(0, height - waterHeight, width, height))
        ..style = PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTRB(0, height - waterHeight, width, height), waterPaint);
      
      // Subtle top surface of the water
      if (progress < 1.0) {
        final surfacePaint = Paint()
          ..color = Colors.white.withValues(alpha : 0.5)
          ..style = PaintingStyle.fill;
          
        final Rect topSurfaceRect = Rect.fromCenter(
          center: Offset(width / 2, height - waterHeight),
          width: (width * 0.5) + (width * 0.2 * progress), // Width changes with taper
          height: 4.0,
        );
        canvas.drawOval(topSurfaceRect, surfacePaint);
      }
      
      canvas.restore();
    }

    // Draw glass outline
    final glassPaint = Paint()
      ..color = glassColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(glassPath, glassPaint);
    
    // Draw reflection highlight on the glass
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha : 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    final highlightPath = Path();
    highlightPath.moveTo(width * 0.2, height * 0.1);
    highlightPath.lineTo(width * 0.25, height * 0.8);
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _GlassPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
