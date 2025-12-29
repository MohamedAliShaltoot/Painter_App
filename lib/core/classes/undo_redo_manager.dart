import 'package:painter_app/core/classes/drawn_objects.dart';
import 'package:painter_app/core/utils/app_constants.dart';

class UndoRedoManager {
  final List<List<DrawnObject>> _undoStack = [];
  final List<List<DrawnObject>> _redoStack = [];

  bool get canUndo => _undoStack.length > 1;
  bool get canRedo => _redoStack.isNotEmpty;

  void saveState(List<DrawnObject> objects) {
    if (_undoStack.isNotEmpty && _listEquals(objects, _undoStack.last)) {
      return;
    }

    _undoStack.add(List.from(objects));
    if (_undoStack.length > AppConstants.maxUndoRedoStates) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  List<DrawnObject>? undo() {
    if (!canUndo) return null;

    _redoStack.add(_undoStack.removeLast());
    return List.from(_undoStack.last);
  }

  List<DrawnObject>? redo() {
    if (!canRedo) return null;

    final stateToRedo = _redoStack.removeLast();
    _undoStack.add(stateToRedo);
    return List.from(stateToRedo);
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }

  bool _listEquals(List<DrawnObject> a, List<DrawnObject> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
