import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../features/spaces/data/datasources/space_remote_datasource.dart';
import '../../features/spaces/data/repositories/space_repository_impl.dart';
import '../../features/spaces/domain/repositories/space_repository.dart';
import '../../features/spaces/domain/usecases/create_space_usecase.dart';
import '../../features/spaces/presentation/bloc/create_space_bloc.dart';
import '../../features/spaces/presentation/bloc/spaces_bloc.dart';

final getIt = GetIt.instance;

void setupServiceLocator({required Dio dio}) {
  getIt.registerLazySingleton<SpaceRemoteDataSource>(
    () => SpaceRemoteDataSource(dio),
  );
  getIt.registerLazySingleton<SpaceRepository>(
    () => SpaceRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory(() => CreateSpaceUseCase(getIt()));
  getIt.registerLazySingleton(() => SpacesBloc());
  getIt.registerLazySingleton(
    () => CreateSpaceBloc(createSpaceUseCase: getIt()),
  );
}
