import 'dart:ui';

import 'package:painter_app/core/classes/drawn_objects.dart';

class DrawingState {
  final List<List<DrawnObject>> pages;
  final int currentPageIndex;
  final DrawnObject? currentDrawing;
  final Offset? shapeStartPoint;

  const DrawingState({
    this.pages = const [[]],
    this.currentPageIndex = 0,
    this.currentDrawing,
    this.shapeStartPoint,
  });

  List<DrawnObject> get currentPageObjects => pages[currentPageIndex];

  DrawingState copyWith({
    List<List<DrawnObject>>? pages,
    int? currentPageIndex,
    DrawnObject? currentDrawing,
    Offset? shapeStartPoint,
    bool clearCurrent = false,
    bool clearStart = false,
  }) {
    return DrawingState(
      pages: pages ?? this.pages,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      currentDrawing:
          clearCurrent ? null : (currentDrawing ?? this.currentDrawing),
      shapeStartPoint:
          clearStart ? null : (shapeStartPoint ?? this.shapeStartPoint),
    );
  }
}
