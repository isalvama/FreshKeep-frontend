import 'package:dio/dio.dart';

import '../models/space_overview_response_model.dart';

class SpaceOverviewRemoteDataSource {
  final Dio dio;

  const SpaceOverviewRemoteDataSource(this.dio);

  Future<SpaceOverviewResponseModel> getSpaceOverview({
    required String spaceId,
  }) async {
    final response = await dio.get('/api/v1/spaces/$spaceId/overview');

    return SpaceOverviewResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
