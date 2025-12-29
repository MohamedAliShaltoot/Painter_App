import 'package:flutter/material.dart';
import 'dart:math';

// ===========================================================================
// ENUMS AND CONSTANTS (Moved outside for better organization)
// ===========================================================================

enum BackgroundType {
  none('None', Icons.clear),
  dotted('Dotted', Icons.more_horiz),
  grid('Grid', Icons.grid_on),
  lines('Lines', Icons.line_weight),
  diagonalGrid('Diagonal Grid', Icons.grid_3x3),
  starryNight('Starry Night', Icons.stars);

  final String displayName;
  final IconData icon;

  const BackgroundType(this.displayName, this.icon);
}

enum ToolType {
  pencil('Pencil', Icons.edit),
  eraser('Eraser', Icons.layers_clear),
  line('Line', Icons.show_chart),
  rectangle('Rectangle', Icons.rectangle_outlined),
  circle('Circle', Icons.circle_outlined),
  text('Text', Icons.text_fields);

  final String displayName;
  final IconData icon;

  const ToolType(this.displayName, this.icon);
}

class AppConstants {
  static const double defaultStrokeWidth = 5.0;
  static const double eraserMultiplier = 2.0;
  static const double defaultFontSize = 24.0;
  static const double minFontSize = 10.0;
  static const double maxFontSize = 60.0;
  static const double defaultBackgroundSpacing = 20.0;
  static const int maxUndoRedoStates = 20;

  static const List<Color> paletteColors = [
    Colors.black,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.brown,
  ];

  static const List<Color> backgroundPaletteColors = [
    Colors.white,
    Color(0xFFE0E0E0),
    Color(0xFFD4E6F1),
    Color(0xFFD1F2EB),
    Color(0xFFF9E79F),
    Color(0xFFCCD1D1),
  ];
}

// ===========================================================================
// MAIN APP WIDGET
// ===========================================================================

void main() {
  runApp(const MyDrawingApp());
}

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
    _undoRedoManager.saveState(_drawingState.currentPageObjects);
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
      final newDrawing = DrawnObject(
        points: [position],
        color: effectiveColor,
        width: effectiveWidth,
        tool: _selectedTool,
        backgroundColor: _canvasBackgroundColor,
      );

      setState(() {
        _drawingState = _drawingState.copyWith(currentDrawing: newDrawing);
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
      _drawingState.currentDrawing!.points.add(position);

      if (mounted) {
        setState(() {});
      }
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
    if (_drawingState.currentDrawing == null) return;

    final newPageObjects = List<DrawnObject>.from(
      _drawingState.currentPageObjects,
    )..add(_drawingState.currentDrawing!);

    final newPages = List<List<DrawnObject>>.from(_drawingState.pages);
    newPages[_drawingState.currentPageIndex] = newPageObjects;

    setState(() {
      _drawingState = _drawingState.copyWith(
        pages: newPages,
        clearCurrent: true,
      );
    });
    _undoRedoManager.saveState(newPageObjects);
  }

  void _completeShape(Offset endPosition) {
    if (_drawingState.shapeStartPoint == null) return;

    final points = [_drawingState.shapeStartPoint!, endPosition];
    final newPageObjects = List<DrawnObject>.from(
      _drawingState.currentPageObjects,
    )..add(
      DrawnObject(
        points: points,
        color: _selectedColor,
        width: _strokeWidth,
        tool: _selectedTool,
      ),
    );

    final newPages = List<List<DrawnObject>>.from(_drawingState.pages);
    newPages[_drawingState.currentPageIndex] = newPageObjects;

    setState(() {
      _drawingState = _drawingState.copyWith(pages: newPages, clearStart: true);
    });
    _undoRedoManager.saveState(newPageObjects);
  }

  void _undo() {
    final previousState = _undoRedoManager.undo();
    if (previousState != null) {
      final newPages = List<List<DrawnObject>>.from(_drawingState.pages);
      newPages[_drawingState.currentPageIndex] = previousState;

      setState(() {
        _drawingState = _drawingState.copyWith(
          pages: newPages,
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
      final newPages = List<List<DrawnObject>>.from(_drawingState.pages);
      newPages[_drawingState.currentPageIndex] = nextState;

      setState(() {
        _drawingState = _drawingState.copyWith(
          pages: newPages,
          clearCurrent: true,
          clearStart: true,
        );
      });
    } else {
      _showSnackbar('Nothing to redo.');
    }
  }

  void _clearCanvas() {
    if (_drawingState.currentPageObjects.isNotEmpty) {
      final newPages = List<List<DrawnObject>>.from(_drawingState.pages);
      newPages[_drawingState.currentPageIndex] = [];

      setState(() {
        _drawingState = _drawingState.copyWith(pages: newPages);
      });
      _undoRedoManager.saveState([]);
    } else {
      _showSnackbar('Canvas is already empty.');
    }
  }

  void _addNewPage() {
    final newPages = List<List<DrawnObject>>.from(_drawingState.pages)..add([]);

    setState(() {
      _drawingState = _drawingState.copyWith(
        pages: newPages,
        currentPageIndex: _drawingState.pages.length,
        clearCurrent: true,
        clearStart: true,
      );
    });
    _undoRedoManager.saveState([]);
  }

  void _deleteCurrentPage() {
    if (_drawingState.pages.length <= 1) {
      _showSnackbar('Cannot delete the last page.');
      return;
    }

    final newPages = List<List<DrawnObject>>.from(_drawingState.pages);
    newPages.removeAt(_drawingState.currentPageIndex);

    final newIndex =
        _drawingState.currentPageIndex > 0
            ? _drawingState.currentPageIndex - 1
            : 0;

    setState(() {
      _drawingState = _drawingState.copyWith(
        pages: newPages,
        currentPageIndex: newIndex,
        clearCurrent: true,
        clearStart: true,
      );
    });

    _undoRedoManager.clear();
    _showSnackbar('Page deleted successfully.');
  }

  void _changePage(int newIndex) {
    if (newIndex >= 0 && newIndex < _drawingState.pages.length) {
      setState(() {
        _drawingState = _drawingState.copyWith(
          currentPageIndex: newIndex,
          clearCurrent: true,
          clearStart: true,
        );
      });
      _undoRedoManager.saveState(_drawingState.currentPageObjects);
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
    final newPageObjects = List<DrawnObject>.from(
      _drawingState.currentPageObjects,
    )..add(
      DrawnObject(
        points: [position],
        color: textData['textColor'] as Color,
        width: _strokeWidth,
        tool: ToolType.text,
        text: textData['text'] as String,
        fontSize: textData['fontSize'] as double,
      ),
    );

    final newPages = List<List<DrawnObject>>.from(_drawingState.pages);
    newPages[_drawingState.currentPageIndex] = newPageObjects;

    setState(() {
      _drawingState = _drawingState.copyWith(pages: newPages);
    });
    _undoRedoManager.saveState(newPageObjects);
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
            activeColor: const Color.fromARGB(255, 223, 39, 11),
            inactiveColor: Colors.transparent,
            thumbColor: const Color.fromARGB(255, 4, 46, 118),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Drawing App'),
        actions: [
          IconButton(
            onPressed: _undoRedoManager.canUndo ? _undo : null,
            icon: const Icon(Icons.undo_sharp),
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
            onPressed: _addNewPage,
            icon: const Icon(Icons.add),
            tooltip: 'Add New Page',
          ),
          IconButton(
            onPressed: _deleteCurrentPage,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Current Page',
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
              child: LayoutBuilder(
                builder:
                    (context, constraints) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) {
                        final renderBox =
                            context.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(
                          details.globalPosition,
                        );
                        _onPanStart(localPosition);
                      },
                      onPanUpdate: (details) {
                        final renderBox =
                            context.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(
                          details.globalPosition,
                        );
                        _onPanUpdate(localPosition);
                      },
                      onPanEnd: (details) {
                        final renderBox =
                            context.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(
                          details.globalPosition,
                        );
                        _onPanEnd(localPosition);
                      },
                      onTapDown: (details) {
                        final renderBox =
                            context.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(
                          details.globalPosition,
                        );
                        _onTapDown(localPosition);
                      },
                      onTapUp: (details) {
                        final renderBox =
                            context.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(
                          details.globalPosition,
                        );
                        _onTapUp(localPosition);
                      },
                      child: CustomPaint(
                        painter: DrawingPainter(
                          _drawingState.currentPageObjects,
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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            color: Theme.of(context).canvasColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed:
                      _drawingState.currentPageIndex > 0
                          ? () =>
                              _changePage(_drawingState.currentPageIndex - 1)
                          : null,
                  icon: const Icon(Icons.arrow_back_ios),
                  tooltip: 'Previous Page',
                ),
                Text(
                  'Page ${_drawingState.currentPageIndex + 1} of ${_drawingState.pages.length}',
                  style: const TextStyle(fontSize: 16),
                ),
                IconButton(
                  onPressed:
                      _drawingState.currentPageIndex <
                              _drawingState.pages.length - 1
                          ? () =>
                              _changePage(_drawingState.currentPageIndex + 1)
                          : null,
                  icon: const Icon(Icons.arrow_forward_ios),
                  tooltip: 'Next Page',
                ),
              ],
            ),
          ),
          if (_showControls) ...[
            const Divider(height: 1),
            Card(
              margin: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              color: Theme.of(context).canvasColor,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
            ),
          ],
        ],
      ),
    );
  }
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

// ===========================================================================
// DRAWING STATE MANAGEMENT
// ===========================================================================

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
