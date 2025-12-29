// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:painter_app/core/classes/drawn_objects.dart';
import 'package:painter_app/core/enums/background_type.dart';
import 'package:painter_app/core/enums/tool_type.dart';

class DrawingPainter extends CustomPainter {
  final List<DrawnObject> completedObjects;
  final DrawnObject? currentDrawing;
  final BackgroundType backgroundType;
  final Color canvasBackgroundColor;
  final double backgroundSpacing;

  DrawingPainter(
    this.completedObjects,
    this.currentDrawing,
    this.backgroundType,
    this.canvasBackgroundColor,
    this.backgroundSpacing,
  );

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    for (final obj in completedObjects) {
      _drawObject(canvas, obj);
    }

    if (currentDrawing != null) {
      _drawObject(canvas, currentDrawing!);
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = canvasBackgroundColor;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    if (backgroundType == BackgroundType.none) return;

    final paint =
        Paint()
          ..color =
              canvasBackgroundColor == Colors.white
                  ? Colors.grey.withOpacity(0.3)
                  : Colors.white.withOpacity(0.3)
          ..strokeWidth = 1.0;

    switch (backgroundType) {
      case BackgroundType.grid:
        _drawGrid(canvas, size, paint);
        break;
      case BackgroundType.dotted:
        _drawDots(canvas, size, paint);
        break;
      case BackgroundType.lines:
        _drawLines(canvas, size, paint);
        break;
      case BackgroundType.diagonalGrid:
        _drawDiagonalGrid(canvas, size, paint);
        break;
      case BackgroundType.starryNight:
        _drawStarryNight(canvas, size);
        break;
      case BackgroundType.none:
        break;
    }
  }

  void _drawGrid(Canvas canvas, Size size, Paint paint) {
    for (double x = 0; x <= size.width; x += backgroundSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += backgroundSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawDots(Canvas canvas, Size size, Paint paint) {
    for (double x = backgroundSpacing; x < size.width; x += backgroundSpacing) {
      for (
        double y = backgroundSpacing;
        y < size.height;
        y += backgroundSpacing
      ) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  void _drawLines(Canvas canvas, Size size, Paint paint) {
    for (
      double y = backgroundSpacing;
      y < size.height;
      y += backgroundSpacing
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawDiagonalGrid(Canvas canvas, Size size, Paint paint) {
    for (double x = -size.height; x <= size.width; x += backgroundSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
    for (double x = 0; x <= size.width + size.height; x += backgroundSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        paint,
      );
    }
  }

  void _drawStarryNight(Canvas canvas, Size size) {
    final random = Random();
    final starPaint = Paint()..color = Colors.white.withOpacity(0.6);
    const int numberOfStars = 300;
    for (int i = 0; i < numberOfStars; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5;
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }
  }

  void _drawObject(Canvas canvas, DrawnObject obj) {
    final paint =
        Paint()
          ..color = obj.color
          ..strokeWidth = obj.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    switch (obj.tool) {
      case ToolType.pencil:
        _drawPath(canvas, obj.points, paint..style = PaintingStyle.stroke);
        break;
      case ToolType.eraser:
        _drawEraser(canvas, obj);
        break;
      case ToolType.line:
        _drawLine(canvas, obj.points, paint..style = PaintingStyle.stroke);
        break;
      case ToolType.rectangle:
        _drawRectangle(canvas, obj.points, paint..style = PaintingStyle.stroke);
        break;
      case ToolType.circle:
        _drawCircle(canvas, obj.points, paint..style = PaintingStyle.stroke);
        break;
      case ToolType.text:
        _drawText(canvas, obj);
        break;
    }
  }

  void _drawPath(Canvas canvas, List<Offset?> points, Paint paint) {
    if (points.length < 2) {
      if (points.length == 1 && points[0] != null) {
        canvas.drawCircle(points[0]!, paint.strokeWidth / 2, paint);
      }
      return;
    }

    final path = Path();
    Offset? lastPoint;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      if (point == null) {
        lastPoint = null;
        continue;
      }

      if (lastPoint == null) {
        path.moveTo(point.dx, point.dy);
      } else {
        if (i < points.length - 1) {
          final nextPoint = points[i + 1];
          if (nextPoint != null) {
            final controlPoint = Offset(
              (lastPoint.dx + point.dx) / 2,
              (lastPoint.dy + point.dy) / 2,
            );
            path.quadraticBezierTo(
              lastPoint.dx,
              lastPoint.dy,
              controlPoint.dx,
              controlPoint.dy,
            );
          } else {
            path.lineTo(point.dx, point.dy);
          }
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      lastPoint = point;
    }

    canvas.drawPath(path, paint);
  }

  void _drawEraser(Canvas canvas, DrawnObject obj) {
    final paint =
        Paint()
          ..color = obj.backgroundColor ?? Colors.white
          ..strokeWidth = obj.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..blendMode = BlendMode.src;

    _drawPath(canvas, obj.points, paint);
  }

  void _drawLine(Canvas canvas, List<Offset?> points, Paint paint) {
    if (points.length >= 2 && points[0] != null && points[1] != null) {
      canvas.drawLine(points[0]!, points[1]!, paint);
    }
  }

  void _drawRectangle(Canvas canvas, List<Offset?> points, Paint paint) {
    if (points.length >= 2 && points[0] != null && points[1] != null) {
      final rect = Rect.fromPoints(points[0]!, points[1]!);
      canvas.drawRect(rect, paint);
    }
  }

  void _drawCircle(Canvas canvas, List<Offset?> points, Paint paint) {
    if (points.length >= 2 && points[0] != null && points[1] != null) {
      final center = points[0]!;
      final radius = (points[1]! - center).distance;
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _drawText(Canvas canvas, DrawnObject obj) {
    if (obj.points.isNotEmpty && obj.points[0] != null && obj.text != null) {
      final textPainter = obj.textPainter;
      if (textPainter != null) {
        textPainter.paint(canvas, obj.points[0]!);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! DrawingPainter) return true;

    return completedObjects.length != oldDelegate.completedObjects.length ||
        currentDrawing != oldDelegate.currentDrawing ||
        backgroundType != oldDelegate.backgroundType ||
        canvasBackgroundColor != oldDelegate.canvasBackgroundColor ||
        backgroundSpacing != oldDelegate.backgroundSpacing;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DrawingPainter) return false;

    return completedObjects.length == other.completedObjects.length &&
        currentDrawing == other.currentDrawing &&
        backgroundType == other.backgroundType &&
        canvasBackgroundColor == other.canvasBackgroundColor &&
        backgroundSpacing == other.backgroundSpacing;
  }

  @override
  int get hashCode {
    return Object.hash(
      completedObjects.length,
      currentDrawing,
      backgroundType,
      canvasBackgroundColor,
      backgroundSpacing,
    );
  }
}
