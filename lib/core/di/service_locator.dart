import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../features/shopping_receipt/data/datasources/shopping_receipt_remote_datasource.dart';
import '../../features/shopping_receipt/data/repositories/shopping_receipt_repository_impl.dart';
import '../../features/shopping_receipt/domain/repositories/shopping_receipt_repository.dart';
import '../../features/shopping_receipt/domain/usecases/confirm_shopping_receipt_usecase.dart';
import '../../features/shopping_receipt/domain/usecases/process_new_shopping_receipt_usecase.dart';
import '../../features/shopping_receipt/domain/usecases/reprocess_shopping_receipt_usecase.dart';
import '../../features/shopping_receipt/presentation/bloc/shopping_receipt_bloc.dart';
import '../../features/space_overview/data/datasources/space_overview_remote_datasource.dart';
import '../../features/space_overview/data/repositories/space_overview_repository_impl.dart';
import '../../features/space_overview/domain/repositories/space_overview_repository.dart';
import '../../features/space_overview/domain/usecases/get_space_overview_usecase.dart';
import '../../features/space_overview/presentation/bloc/space_overview_bloc.dart';
import '../../features/spaces/data/datasources/space_remote_datasource.dart';
import '../../features/spaces/data/repositories/space_repository_impl.dart';
import '../../features/spaces/domain/repositories/space_repository.dart';
import '../../features/spaces/domain/usecases/create_space_usecase.dart';
import '../../features/spaces/domain/usecases/get_user_spaces_usecase.dart';
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
  getIt.registerFactory(() => GetUserSpacesUseCase(getIt()));
  getIt.registerLazySingleton(
    () => SpacesBloc(getUserSpacesUseCase: getIt()),
  );
  getIt.registerLazySingleton(
    () => CreateSpaceBloc(createSpaceUseCase: getIt()),
  );

  getIt.registerLazySingleton<ShoppingReceiptRemoteDataSource>(
    () => ShoppingReceiptRemoteDataSource(dio),
  );
  getIt.registerLazySingleton<ShoppingReceiptRepository>(
    () => ShoppingReceiptRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory(() => ProcessNewShoppingReceiptUseCase(getIt()));
  getIt.registerFactory(() => ConfirmShoppingReceiptUseCase(getIt()));
  getIt.registerFactory(() => ReprocessShoppingReceiptUseCase(getIt()));
  getIt.registerLazySingleton(
    () => ShoppingReceiptBloc(
      processNewShoppingReceiptUseCase: getIt(),
      confirmShoppingReceiptUseCase: getIt(),
      reprocessShoppingReceiptUseCase: getIt(),
    ),
  );

  getIt.registerLazySingleton<SpaceOverviewRemoteDataSource>(
    () => SpaceOverviewRemoteDataSource(dio),
  );
  getIt.registerLazySingleton<SpaceOverviewRepository>(
    () => SpaceOverviewRepositoryImpl(remoteDataSource: getIt()),
  );
  getIt.registerFactory(() => GetSpaceOverviewUseCase(getIt()));
  getIt.registerFactory(
    () => SpaceOverviewBloc(getSpaceOverviewUseCase: getIt()),
  );
}
