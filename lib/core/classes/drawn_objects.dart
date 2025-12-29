import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:painter_app/core/enums/tool_type.dart';
import 'package:painter_app/core/utils/app_constants.dart';

@immutable
class DrawnObject {
  final List<Offset?> points;
  final Color color;
  final double width;
  final double? fontSize;
  final ToolType tool;
  final String? text;
  final Color? backgroundColor;

  DrawnObject({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
    this.text,
    this.backgroundColor,
    this.fontSize,
  });

  TextPainter? _cachedTextPainter;

  TextPainter? get textPainter {
    if (tool != ToolType.text ||
        text == null ||
        points.isEmpty ||
        points[0] == null) {
      return null;
    }

    if (_cachedTextPainter == null) {
      _cachedTextPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize ?? AppConstants.defaultFontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      _cachedTextPainter!.layout();
    }

    return _cachedTextPainter;
  }

  bool get isErasing => tool == ToolType.eraser;

  factory DrawnObject.fromJson(Map<String, dynamic> json) {
    try {
      final pointsList = json['points'] as List;
      final points =
          pointsList.map<Offset?>((p) {
            if (p == null) return null;
            return Offset(
              (p['dx'] as num).toDouble(),
              (p['dy'] as num).toDouble(),
            );
          }).toList();

      final toolName = json['tool'] as String;
      final tool = ToolType.values.firstWhere(
        (e) => e.name == toolName,
        orElse: () => ToolType.pencil,
      );

      return DrawnObject(
        points: points,
        color: Color(json['color'] as int),
        width: (json['width'] as num).toDouble(),
        tool: tool,
        text: json['text'] as String?,
        backgroundColor:
            json['backgroundColor'] != null
                ? Color(json['backgroundColor'] as int)
                : null,
        fontSize:
            json['fontSize'] != null
                ? (json['fontSize'] as num).toDouble()
                : null,
      );
    } catch (e) {
      throw FormatException('Invalid DrawnObject JSON: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'points':
          points
              .map((p) => p == null ? null : {'dx': p.dx, 'dy': p.dy})
              .toList(),
      'color': color.value,
      'width': width,
      'tool': tool.name,
      'text': text,
      'backgroundColor': backgroundColor?.value,
      'fontSize': fontSize,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DrawnObject) return false;

    return points.length == other.points.length &&
        color == other.color &&
        width == other.width &&
        tool == other.tool &&
        text == other.text &&
        backgroundColor == other.backgroundColor &&
        fontSize == other.fontSize;
  }

  @override
  int get hashCode {
    return Object.hash(
      points.length,
      color,
      width,
      tool,
      text,
      backgroundColor,
      fontSize,
    );
  }
}
