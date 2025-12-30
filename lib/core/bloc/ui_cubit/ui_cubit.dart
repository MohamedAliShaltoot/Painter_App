import 'package:flutter_bloc/flutter_bloc.dart';

class UiCubit extends Cubit<bool> {
  UiCubit() : super(true);
  void toggleControls() => emit(!state);
}
