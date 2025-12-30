// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:painter_app/core/classes/drawing_painter.dart';
import 'package:painter_app/core/classes/drawing_state.dart';
import 'package:painter_app/core/classes/drawn_objects.dart';
import 'package:painter_app/core/classes/undo_redo_manager.dart';
import 'package:painter_app/core/enums/background_type.dart';
import 'package:painter_app/core/enums/tool_type.dart';
import 'package:painter_app/core/utils/app_assets.dart';
import 'package:painter_app/core/utils/app_constants.dart';
import 'package:window_manager/window_manager.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),        // fixed size
    minimumSize: Size(800, 600), //prevent resizing smaller
    maximumSize: Size(1800, 1600), // prevent resizing larger
    center: true,
    title: "My Flutter App",
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
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
      title: AppStrings.appName,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: DrawingPage(onToggleTheme: _toggleTheme, isDark: _isDark),
    );
  }
}

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

  // GESTURE HANDLERS
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

  // DRAWING OPERATIONS
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

  // TEXT INPUT DIALOG
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
                        decoration: InputDecoration(
                          hintText: AppStrings.typeHere,
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
                  child: Text(AppStrings.cancel),
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
                  child: Text(AppStrings.addText),
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

  // UI BUILDERS
  Widget _buildFontSizeSlider(double fontSize, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Text(AppStrings.fontSize),
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
        Text(AppStrings.textColor),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          showCloseIcon: true,
          closeIconColor: Colors.red,
          elevation: 6,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(left: 20, right: 1000, bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.green,
            onPressed: () {
             // ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  // MAIN BUILD METHOD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            onPressed: () {
              _showSnackbar('This feature is under development.');
            },
            icon: const Icon(Icons.menu),
            tooltip: AppStrings.appMenuToolTip,
          ),
          IconButton(
            onPressed: _undoRedoManager.canUndo ? _undo : null,
            icon: const Icon(Icons.undo_sharp),
            tooltip: AppStrings.undoToolTip,
          ),
          IconButton(
            onPressed: _undoRedoManager.canRedo ? _redo : null,
            icon: const Icon(Icons.redo),
            tooltip: AppStrings.redoToolTip,
          ),
          IconButton(
            onPressed: _clearCanvas,
            icon: const Icon(Icons.close),
            tooltip: AppStrings.clearCanvasToolTip,
          ),
          IconButton(
            onPressed: _addNewPage,
            icon: const Icon(Icons.add),
            tooltip: AppStrings.addNewPageToolTip,
          ),
          IconButton(
            onPressed: _deleteCurrentPage,
            icon: const Icon(Icons.delete),
            tooltip: AppStrings.deleteCurrentPageToolTip,
          ),
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
            tooltip: AppStrings.toggleThemeToolTip,
          ),
          IconButton(
            icon: Icon(_showControls ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            tooltip:
                _showControls
                    ? AppStrings.hideControlsToolTip
                    : AppStrings.showControlsToolTip,
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
