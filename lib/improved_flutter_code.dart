// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:painter_app/core/enums/background_type.dart';
import 'package:painter_app/core/enums/tool_type.dart';

import 'package:painter_app/core/utils/app_constants.dart';

void main() {
  runApp(const MyDrawingApp());
}

// ===========================================================================
// DATA MODELS
// ===========================================================================

@immutable
class DrawnObject {
  final List<Offset?> points;
  final Color color;
  final double width;
  final double? fontSize;
  final ToolType tool;
  final String? text;
  final Color? backgroundColor;

  const DrawnObject({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
    this.text,
    this.backgroundColor,
    this.fontSize,
  });

  // Lazy initialization of TextPainter for better performance
  TextPainter? get textPainter {
    if (tool != ToolType.text ||
        text == null ||
        points.isEmpty ||
        points[0] == null) {
      return null;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize ?? AppConstants.defaultFontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }

  bool get isErasing => tool == ToolType.eraser;

  // Serialization methods with better error handling
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

// ===========================================================================
// DRAWING STATE MANAGEMENT
// ===========================================================================

class DrawingState {
  final List<DrawnObject> completedObjects;
  final DrawnObject? currentDrawing;
  final Offset? shapeStartPoint;

  const DrawingState({
    this.completedObjects = const [],
    this.currentDrawing,
    this.shapeStartPoint,
  });

  DrawingState copyWith({
    List<DrawnObject>? completedObjects,
    DrawnObject? currentDrawing,
    Offset? shapeStartPoint,
    bool clearCurrent = false,
    bool clearStart = false,
  }) {
    return DrawingState(
      completedObjects: completedObjects ?? this.completedObjects,
      currentDrawing:
          clearCurrent ? null : (currentDrawing ?? this.currentDrawing),
      shapeStartPoint:
          clearStart ? null : (shapeStartPoint ?? this.shapeStartPoint),
    );
  }
}

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

// ===========================================================================
// MAIN APP WIDGET
// ===========================================================================

class MyDrawingApp extends StatefulWidget {
  const MyDrawingApp({super.key});

  @override
  State<MyDrawingApp> createState() => _MyDrawingAppState();
}

class _MyDrawingAppState extends State<MyDrawingApp> {
  bool _isDark = false;

  void _toggleTheme() {
    setState(() {
      _isDark = !_isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Drawing App',
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: DrawingPage(onToggleTheme: _toggleTheme, isDark: _isDark),
    );
  }
}

// ===========================================================================
// DRAWING PAGE WIDGET
// ===========================================================================

class DrawingPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const DrawingPage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  // State management
  final UndoRedoManager _undoRedoManager = UndoRedoManager();
  DrawingState _drawingState = const DrawingState();

  // Drawing settings
  Color _selectedColor = Colors.black;
  double _strokeWidth = AppConstants.defaultStrokeWidth;
  BackgroundType _backgroundType = BackgroundType.dotted;
  ToolType _selectedTool = ToolType.pencil;
  Color _canvasBackgroundColor = Colors.white;
  final double _backgroundSpacing = AppConstants.defaultBackgroundSpacing;

  // UI state
  bool _showControls = true;

  // Controllers
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _undoRedoManager.saveState(_drawingState.completedObjects);
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  // ===========================================================================
  // GESTURE HANDLERS
  // ===========================================================================

  void _onPanStart(Offset position) {
    final effectiveColor =
        _selectedTool == ToolType.eraser ? Colors.transparent : _selectedColor;
    final effectiveWidth =
        _selectedTool == ToolType.eraser
            ? _strokeWidth * AppConstants.eraserMultiplier
            : _strokeWidth;

    if (_selectedTool == ToolType.pencil || _selectedTool == ToolType.eraser) {
      setState(() {
        _drawingState = _drawingState.copyWith(
          currentDrawing: DrawnObject(
            points: [position],
            color: effectiveColor,
            width: effectiveWidth,
            tool: _selectedTool,
            backgroundColor: _canvasBackgroundColor,
          ),
        );
      });
    } else {
      setState(() {
        _drawingState = _drawingState.copyWith(shapeStartPoint: position);
      });
    }
  }

  void _onPanUpdate(Offset position) {
    if (_drawingState.currentDrawing != null &&
        (_selectedTool == ToolType.pencil ||
            _selectedTool == ToolType.eraser)) {
      setState(() {
        _drawingState.currentDrawing!.points.add(position);
      });
    }
  }

  void _onPanEnd(Offset position) {
    if (_selectedTool == ToolType.pencil || _selectedTool == ToolType.eraser) {
      if (_drawingState.currentDrawing != null) {
        _completeCurrentDrawing();
      }
    } else if (_drawingState.shapeStartPoint != null) {
      _completeShape(position);
    }

    setState(() {
      _drawingState = _drawingState.copyWith(
        clearCurrent: true,
        clearStart: true,
      );
    });
  }

  void _onTapDown(Offset position) {
    if (_selectedTool == ToolType.text) {
      setState(() {
        _drawingState = _drawingState.copyWith(shapeStartPoint: position);
      });
    }
  }

  void _onTapUp(Offset position) {
    if (_selectedTool == ToolType.text &&
        _drawingState.shapeStartPoint != null) {
      _showTextInputDialog(_drawingState.shapeStartPoint!);
    }
    setState(() {
      _drawingState = _drawingState.copyWith(clearStart: true);
    });
  }

  // ===========================================================================
  // DRAWING OPERATIONS
  // ===========================================================================

  void _completeCurrentDrawing() {
    final newObjects = List<DrawnObject>.from(_drawingState.completedObjects)
      ..add(_drawingState.currentDrawing!);

    setState(() {
      _drawingState = _drawingState.copyWith(
        completedObjects: newObjects,
        clearCurrent: true,
      );
    });
    _undoRedoManager.saveState(newObjects);
  }

  void _completeShape(Offset endPosition) {
    final points = [_drawingState.shapeStartPoint!, endPosition];
    final newObjects = List<DrawnObject>.from(_drawingState.completedObjects)
      ..add(
        DrawnObject(
          points: points,
          color: _selectedColor,
          width: _strokeWidth,
          tool: _selectedTool,
        ),
      );

    setState(() {
      _drawingState = _drawingState.copyWith(
        completedObjects: newObjects,
        clearStart: true,
      );
    });
    _undoRedoManager.saveState(newObjects);
  }

  void _undo() {
    final previousState = _undoRedoManager.undo();
    if (previousState != null) {
      setState(() {
        _drawingState = _drawingState.copyWith(
          completedObjects: previousState,
          clearCurrent: true,
          clearStart: true,
        );
      });
    } else {
      _showSnackbar('Nothing to undo.');
    }
  }

  void _redo() {
    final nextState = _undoRedoManager.redo();
    if (nextState != null) {
      setState(() {
        _drawingState = _drawingState.copyWith(
          completedObjects: nextState,
          clearCurrent: true,
          clearStart: true,
        );
      });
    } else {
      _showSnackbar('Nothing to redo.');
    }
  }

  void _clearCanvas() {
    if (_drawingState.completedObjects.isNotEmpty) {
      setState(() {
        _drawingState = const DrawingState();
      });
      _undoRedoManager.saveState([]);
    } else {
      _showSnackbar('Canvas is already empty.');
    }
  }

  // ===========================================================================
  // TEXT INPUT DIALOG
  // ===========================================================================

  Future<void> _showTextInputDialog(Offset position) async {
    _textController.clear();
    double currentFontSize = AppConstants.defaultFontSize;
    Color currentTextColor = _selectedColor;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              elevation: 10,
              backgroundColor: const Color.fromARGB(255, 223, 223, 219),
              title: Row(
                children: [
                  Icon(
                    Icons.text_fields,
                    color: const Color.fromARGB(255, 1, 9, 32),
                  ),
                  const SizedBox(width: 8),
                  const Text('Enter Text'),
                ],
              ),

              titlePadding: const EdgeInsets.all(20),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 60.0,
              ),
              contentPadding: const EdgeInsets.all(15),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  minWidth: MediaQuery.of(context).size.width * 0.7,
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  minHeight: 200,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _textController,
                        focusNode: _textFocusNode,
                        decoration: const InputDecoration(
                          hintText: "Type here",
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                          filled: true,
                          fillColor: Color.fromARGB(255, 255, 255, 255),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(8.0),
                            ),
                            borderSide: BorderSide(
                              color: Color.fromARGB(255, 142, 40, 40),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(8.0),
                            ),
                            borderSide: BorderSide(
                              color: Color.fromARGB(255, 1, 12, 133),
                              width: 1.9,
                            ),
                          ),
                        ),
                        autofocus: true,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: currentFontSize,
                          color: currentTextColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildFontSizeSlider(currentFontSize, (value) {
                        setDialogState(() {
                          currentFontSize = value;
                        });
                      }),
                      const SizedBox(height: 10),
                      _buildTextColorPicker(currentTextColor, (color) {
                        setDialogState(() {
                          currentTextColor = color;
                        });
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color.fromARGB(255, 1, 12, 133),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color.fromARGB(255, 1, 12, 133),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context, {
                      'text': _textController.text,
                      'fontSize': currentFontSize,
                      'textColor': currentTextColor,
                    });
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null &&
        result['text'] != null &&
        (result['text'] as String).isNotEmpty) {
      _addTextObject(position, result);
    }
    _textFocusNode.unfocus();
  }

  void _addTextObject(Offset position, Map<String, dynamic> textData) {
    final newObjects = List<DrawnObject>.from(_drawingState.completedObjects)
      ..add(
        DrawnObject(
          points: [position],
          color: textData['textColor'] as Color,
          width: _strokeWidth,
          tool: ToolType.text,
          text: textData['text'] as String,
          fontSize: textData['fontSize'] as double,
        ),
      );

    setState(() {
      _drawingState = _drawingState.copyWith(completedObjects: newObjects);
    });
    _undoRedoManager.saveState(newObjects);
  }

  // ===========================================================================
  // UI BUILDERS
  // ===========================================================================

  Widget _buildFontSizeSlider(double fontSize, ValueChanged<double> onChanged) {
    return Row(
      children: [
        const Text('Font Size :'),
        Expanded(
          child: Slider(
            autofocus: true,
            value: fontSize,
            min: AppConstants.minFontSize,
            max: AppConstants.maxFontSize,
            divisions: 50,
            label: fontSize.round().toString(),
            onChanged: onChanged,
            activeColor: const Color.fromARGB(
              255,
              223,
              39,
              11,
            ), // part selected
            inactiveColor: Colors.transparent, //part remaining
            thumbColor: Color.fromARGB(255, 4, 46, 118), // circle color
            secondaryActiveColor: const Color.fromARGB(255, 4, 46, 118),
          ),
        ),
        Text(fontSize.round().toString()),
      ],
    );
  }

  Widget _buildTextColorPicker(
    Color currentColor,
    ValueChanged<Color> onChanged,
  ) {
    const colors = [Colors.black, Colors.red, Colors.blue, Colors.green];

    return Row(
      children: [
        const Text('Text Color :'),
        const SizedBox(width: 10),
        ...colors.map(
          (color) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => onChanged(color),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: color,
                child:
                    currentColor == color
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPalette() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: AppConstants.paletteColors.length,
        itemBuilder: (context, index) {
          final color = AppConstants.paletteColors[index];
          final isSelected =
              _selectedColor == color && _selectedTool == ToolType.pencil;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedColor = color;
                _selectedTool = ToolType.pencil;
              });
            },
            child: Container(
              width: 32,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.4),
                  width: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackgroundColorPalette() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: AppConstants.backgroundPaletteColors.length,
        itemBuilder: (context, index) {
          final color = AppConstants.backgroundPaletteColors[index];
          final isSelected = _canvasBackgroundColor == color;

          return GestureDetector(
            onTap: () {
              setState(() {
                _canvasBackgroundColor = color;
              });
            },
            child: Container(
              width: 32,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.4),
                  width: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolSelector() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: ToolType.values.length,
        itemBuilder: (context, index) {
          final tool = ToolType.values[index];
          final isSelected = _selectedTool == tool;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tool.icon, size: 18),
                  const SizedBox(width: 4),
                  Text(tool.displayName),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedTool = tool;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackgroundTypeDropdown() {
    return DropdownButton<BackgroundType>(
      value: _backgroundType,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _backgroundType = value;
          });
        }
      },
      items:
          BackgroundType.values.map((bg) {
            return DropdownMenuItem(
              value: bg,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(bg.icon),
                  const SizedBox(width: 8),
                  Text(bg.displayName),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildStrokeWidthSlider() {
    return Row(
      children: [
        const Text('Stroke:'),
        Expanded(
          child: Slider(
            value: _strokeWidth,
            min: 1.0,
            max: 20.0,
            divisions: 19,
            label: _strokeWidth.round().toString(),
            onChanged: (value) {
              setState(() {
                _strokeWidth = value;
              });
            },
          ),
        ),
        Text(_strokeWidth.round().toString()),
      ],
    );
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ===========================================================================
  // MAIN BUILD METHOD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    bool isSelected = false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Drawing App'),
        actions: [
          IconButton(
            onPressed: _undoRedoManager.canUndo ? _undo : null,
            icon: Container(child: const Icon(Icons.undo_sharp)),
            tooltip: 'Undo',
          ),
          IconButton(
            onPressed: _undoRedoManager.canRedo ? _redo : null,
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
          ),
          IconButton(
            onPressed: _clearCanvas,
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear Canvas',
          ),
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: Icon(_showControls ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            tooltip: _showControls ? 'Hide Controls' : 'Show Controls',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              key: _repaintBoundaryKey,
              child: Builder(
                builder:
                    (canvasContext) => GestureDetector(
                      onPanStart:
                          (details) => _onPanStart(
                            (canvasContext.findRenderObject() as RenderBox)
                                .globalToLocal(details.globalPosition),
                          ),
                      onPanUpdate:
                          (details) => _onPanUpdate(
                            (canvasContext.findRenderObject() as RenderBox)
                                .globalToLocal(details.globalPosition),
                          ),
                      onPanEnd:
                          (details) => _onPanEnd(
                            (canvasContext.findRenderObject() as RenderBox)
                                .globalToLocal(details.globalPosition),
                          ),
                      onTapDown:
                          (details) => _onTapDown(
                            (canvasContext.findRenderObject() as RenderBox)
                                .globalToLocal(details.globalPosition),
                          ),
                      onTapUp:
                          (details) => _onTapUp(
                            (canvasContext.findRenderObject() as RenderBox)
                                .globalToLocal(details.globalPosition),
                          ),
                      child: CustomPaint(
                        painter: DrawingPainter(
                          _drawingState.completedObjects,
                          _drawingState.currentDrawing,
                          _backgroundType,
                          _canvasBackgroundColor,
                          _backgroundSpacing,
                        ),
                        size: Size.infinite,
                      ),
                    ),
              ),
            ),
          ),
          if (_showControls) ...[
            const Divider(height: 1),
            Container(
              color: Theme.of(context).canvasColor,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildToolSelector(),
                  const SizedBox(height: 8),
                  _buildColorPalette(),
                  const SizedBox(height: 8),
                  _buildStrokeWidthSlider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Background: '),
                      _buildBackgroundTypeDropdown(),
                      const Spacer(),
                      const Text('Canvas Color: '),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildBackgroundColorPalette(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// CUSTOM PAINTER
// ===========================================================================

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
    // Draw background
    _drawBackground(canvas, size);

    // Draw completed objects
    for (final obj in completedObjects) {
      _drawObject(canvas, obj);
    }

    // Draw current drawing
    if (currentDrawing != null) {
      _drawObject(canvas, currentDrawing!);
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    // Fill canvas with background color
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
      case BackgroundType.none:
        break;
    }
  }

  void _drawGrid(Canvas canvas, Size size, Paint paint) {
    // Vertical lines
    for (double x = 0; x <= size.width; x += backgroundSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal lines
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
    if (points.length < 2) return;

    final path = Path();
    Offset? lastPoint;

    for (final point in points) {
      if (point == null) {
        lastPoint = null;
        continue;
      }

      if (lastPoint == null) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
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
          ..style = PaintingStyle.stroke;

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
    return oldDelegate != this;
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
