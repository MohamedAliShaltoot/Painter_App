import 'package:flutter/material.dart';
import 'package:painter_app/core/enums/background_type.dart';
import 'package:painter_app/core/enums/tool_type.dart';


class ToolState {
  final Color color;
  final double strokeWidth;
  final ToolType tool;
  final Color canvasColor;
  final BackgroundType backgroundType;

  const ToolState({
    required this.color,
    required this.strokeWidth,
    required this.tool,
    required this.canvasColor,
    required this.backgroundType,
  });

  ToolState copyWith({
    Color? color,
    double? strokeWidth,
    ToolType? tool,
    Color? canvasColor,
    BackgroundType? backgroundType,
  }) {
    return ToolState(
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      tool: tool ?? this.tool,
      canvasColor: canvasColor ?? this.canvasColor,
      backgroundType: backgroundType ?? this.backgroundType,
    );
  }
}
