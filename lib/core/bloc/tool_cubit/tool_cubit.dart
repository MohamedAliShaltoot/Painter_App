import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:painter_app/core/bloc/tool_cubit/tool_states.dart';
import 'package:painter_app/core/enums/background_type.dart';
import 'package:painter_app/core/enums/tool_type.dart';

class ToolCubit extends Cubit<ToolState> {
  ToolCubit()
    : super(
        const ToolState(
          color: Colors.black,
          strokeWidth: 4,
          tool: ToolType.pencil,
          canvasColor: Colors.white,
          backgroundType: BackgroundType.dotted,
        ),
      );

  void selectColor(Color c) => emit(state.copyWith(color: c));
  void selectTool(ToolType t) => emit(state.copyWith(tool: t));
  void changeStroke(double v) => emit(state.copyWith(strokeWidth: v));
  void changeCanvasColor(Color c) => emit(state.copyWith(canvasColor: c));
  void changeBackground(BackgroundType bg) =>
      emit(state.copyWith(backgroundType: bg));
}
