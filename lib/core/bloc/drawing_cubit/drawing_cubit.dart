import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:painter_app/core/classes/drawing_state.dart';
import 'package:painter_app/core/classes/drawn_objects.dart';
import 'package:painter_app/core/classes/undo_redo_manager.dart';

class DrawingCubit extends Cubit<DrawingState> {
  final UndoRedoManager undoRedo = UndoRedoManager();

  DrawingCubit() : super(const DrawingState()) {
    undoRedo.saveState(state.currentPageObjects);
  }

  void startFreeDraw(DrawnObject obj) {
    emit(state.copyWith(currentDrawing: obj));
  }

  void updateFreeDraw(Offset p) {
    if (state.currentDrawing == null) return;
    state.currentDrawing!.points.add(p);
    emit(state.copyWith());
  }

  void endFreeDraw() {
    if (state.currentDrawing == null) return;

    final list = [...state.currentPageObjects, state.currentDrawing!];
    final pages = [...state.pages];
    pages[state.currentPageIndex] = list;

    undoRedo.saveState(list);

    emit(state.copyWith(pages: pages, clearCurrent: true));
  }

  void startShape(Offset p) {
    emit(state.copyWith(shapeStartPoint: p));
  }

  void endShape(DrawnObject shape) {
    final list = [...state.currentPageObjects, shape];
    final pages = [...state.pages];
    pages[state.currentPageIndex] = list;

    undoRedo.saveState(list);

    emit(state.copyWith(pages: pages, clearStart: true));
  }

  void undo() {
    final prev = undoRedo.undo();
    if (prev == null) return;
    final pages = [...state.pages];
    pages[state.currentPageIndex] = prev;
    emit(state.copyWith(pages: pages));
  }

  void redo() {
    final next = undoRedo.redo();
    if (next == null) return;
    final pages = [...state.pages];
    pages[state.currentPageIndex] = next;
    emit(state.copyWith(pages: pages));
  }

  void clearCanvas() {
    final pages = [...state.pages];
    pages[state.currentPageIndex] = [];
    undoRedo.saveState([]);
    emit(state.copyWith(pages: pages));
  }

  void changePage(int index) {
    emit(
      state.copyWith(
        currentPageIndex: index,
        clearCurrent: true,
        clearStart: true,
      ),
    );
    undoRedo.saveState(state.pages[index]);
  }
}
