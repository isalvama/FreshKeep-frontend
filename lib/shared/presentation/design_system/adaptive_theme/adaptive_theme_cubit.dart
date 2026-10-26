import 'package:fresh_keep_frontend/shared/presentation/design_system/adaptive_theme/adaptive_theme_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AdaptiveThemeCubit extends Cubit<AdaptiveThemeState> {
  AdaptiveThemeCubit() : super(AdaptiveThemeState.dark);

  setLightTheme() {
    emit(AdaptiveThemeState.light);
  }

  setDarkTheme() {
    emit(AdaptiveThemeState.dark);
  }
}
